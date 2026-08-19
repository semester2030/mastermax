/**
 * Pre-Device REV2 PG evidence: image cap concurrency, upload tampering, orphan cleanup.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';

describe('pre_device_rev2 PG — cap / tamper / orphan', () => {
  let app: INestApplication;
  let pool: Pool;
  const owner = 'rev2-pg-owner';

  beforeAll(async () => {
    testEnv();
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  async function seedPublishedVenue(tag: string): Promise<{
    venueId: string;
    providerId: string;
    typeId: string;
    ownerUid: string;
  }> {
    const ownerUid = `${owner}-${tag}`;
    const providerId = await seedProvider(pool, ownerUid, `Rev2Pg-${tag}`);
    const seeded = await seedVenue(pool, providerId, {
      name: `Rev2 Venue ${tag}`,
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2027-02-01': '100' } }],
    });
    // Publish path requires ≥1 approved image (REV2).
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order, is_cover)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/cover/public','cover-${tag}','approved',0,true)`,
      [newId(), seeded.venueId, providerId],
    );
    return {
      venueId: seeded.venueId,
      providerId,
      typeId: seeded.types.Std,
      ownerUid,
    };
  }

  it('concurrent 29→30 pending+approved image cap: exactly one of two inserts wins', async () => {
    const { venueId, providerId, ownerUid } = await seedPublishedVenue('cap');
    // Cover already counts as 1 approved; add 28 more → 29 total.
    for (let i = 0; i < 28; i++) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
         VALUES ($1,$2,$3,'image',$4,$5,'pending',$6)`,
        [
          newId(),
          venueId,
          providerId,
          `https://imagedelivery.net/stub/img-${i}/public`,
          `img-cap-${i}`,
          i + 1,
        ],
      );
    }
    const count = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM venue_media
       WHERE venue_id=$1 AND inventory_type_id IS NULL AND kind='image'
         AND moderation_status IN ('pending','approved') AND deleted_at IS NULL`,
      [venueId],
    );
    expect(Number(count.rows[0].c)).toBe(29);

    async function openSession() {
      return request(app.getHttpServer())
        .post('/v1/provider/media/images/upload-session')
        .set('Authorization', auth(ownerUid, 'placesProvider'))
        .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
        .send({ venueId });
    }

    // At 29 live images, session reservation means only one concurrent open may succeed.
    const [sA, sB] = await Promise.all([openSession(), openSession()]);
    expect([sA.status, sB.status].sort((a, b) => a - b)).toEqual([201, 400]);
    const session = [sA, sB].find((r) => r.status === 201)!;
    const sess = await pool.query<{ cloudflare_image_id: string }>(
      `SELECT cloudflare_image_id FROM media_upload_sessions WHERE id=$1`,
      [session.body.uploadSessionId],
    );
    const complete = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
        purpose: 'race-win',
      });
    expect(complete.status).toBe(201);
    const after = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM venue_media
       WHERE venue_id=$1 AND inventory_type_id IS NULL AND kind='image'
         AND moderation_status IN ('pending','approved') AND deleted_at IS NULL`,
      [venueId],
    );
    expect(Number(after.rows[0].c)).toBe(30);
  });

  it('upload complete rejects tampered cloudflareImageId', async () => {
    const { venueId, ownerUid } = await seedPublishedVenue('tamper');
    const session = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);

    const sess = await pool.query<{ cloudflare_image_id: string }>(
      `SELECT cloudflare_image_id FROM media_upload_sessions WHERE id=$1`,
      [session.body.uploadSessionId],
    );
    expect(sess.rows[0].cloudflare_image_id).toBeTruthy();

    const tamper = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: 'tampered-not-session-id',
      });
    expect(tamper.status).toBeGreaterThanOrEqual(400);
    expect(String(tamper.body.message ?? '')).toMatch(/match|cloudflareImageId/i);

    const ok = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
      });
    expect(ok.status).toBe(201);
    expect(ok.body.mediaId).toBeTruthy();
  });

  it('orphan cleanup marks expired pending upload sessions', async () => {
    const { venueId, providerId, ownerUid } = await seedPublishedVenue('orphan');
    const session = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);

    await pool.query(
      `UPDATE media_upload_sessions SET expires_at = now() - interval '1 minute' WHERE id=$1`,
      [session.body.uploadSessionId],
    );

    const cleaned = await request(app.getHttpServer())
      .post('/v1/provider/media/orphans/cleanup')
      .query({ providerId })
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .expect(201);
    expect(cleaned.body.cleaned).toBeGreaterThanOrEqual(1);

    const row = await pool.query<{ status: string }>(
      `SELECT status FROM media_upload_sessions WHERE id=$1`,
      [session.body.uploadSessionId],
    );
    expect(row.rows[0].status).toBe('orphaned_cleaned');

    const outbox = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM media_cf_delete_outbox WHERE status='pending'`,
    );
    expect(Number(outbox.rows[0].c)).toBeGreaterThanOrEqual(1);
  });
});
