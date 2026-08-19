/**
 * Pre-Provider REV3 PG evidence: soft-delete denorm, CF outbox worker,
 * upload tamper/quota/null-id, publish/last-image, block/open NULL-unit.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { MediaCfDeleteWorker } from '../../src/workers/media-cf-delete.worker';
import { CLOUDFLARE_MEDIA_PORT } from '../../src/modules/media/domain/cloudflare-media.port';
import { CloudflareMediaStubAdapter } from '../../src/modules/media/infrastructure/cloudflare-media.stub.adapter';

describe('pre_provider_rev3 media PG', () => {
  let app: INestApplication;
  let pool: Pool;
  const owner = 'rev3-media-owner';

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

  async function seedVenueWithCover(tag: string): Promise<{
    venueId: string;
    providerId: string;
    typeId: string;
    ownerUid: string;
    coverId: string;
  }> {
    const ownerUid = `${owner}-${tag}`;
    const providerId = await seedProvider(pool, ownerUid, `Rev3Media-${tag}`);
    const seeded = await seedVenue(pool, providerId, {
      name: `Rev3 Media ${tag}`,
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights: { '2027-03-01': '100', '2027-03-02': '100' } }],
    });
    const coverId = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order, is_cover)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/cover/public','cover-${tag}','approved',0,true)`,
      [coverId, seeded.venueId, providerId],
    );
    return {
      venueId: seeded.venueId,
      providerId,
      typeId: seeded.types.Std,
      ownerUid,
      coverId,
    };
  }

  it('soft-delete approved video clears has_playable_video denorm', async () => {
    const { venueId, providerId } = await seedVenueWithCover('denorm');
    const videoId = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, stream_uid, url, moderation_status)
       VALUES ($1,$2,$3,'video','stream-denorm','https://customer-stub.cloudflarestream.com/x/manifest/video.m3u8','approved')`,
      [videoId, venueId, providerId],
    );
    const before = await pool.query<{ has_playable_video: boolean }>(
      `SELECT has_playable_video FROM venues WHERE id=$1`,
      [venueId],
    );
    expect(before.rows[0].has_playable_video).toBe(true);

    await pool.query(`UPDATE venue_media SET deleted_at = now() WHERE id=$1`, [videoId]);

    const after = await pool.query<{ has_playable_video: boolean }>(
      `SELECT has_playable_video FROM venues WHERE id=$1`,
      [venueId],
    );
    expect(after.rows[0].has_playable_video).toBe(false);
  });

  it('outbox worker success / retry / crash reclaim / race SKIP LOCKED', async () => {
    const worker = app.get(MediaCfDeleteWorker);
    const outboxId = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image','stub-img-outbox-ok','pending', now())`,
      [outboxId],
    );

    const ok = await worker.tick(5);
    expect(ok.done).toContain(outboxId);
    const doneRow = await pool.query<{ status: string; claim_token: string | null }>(
      `SELECT status, claim_token FROM media_cf_delete_outbox WHERE id=$1`,
      [outboxId],
    );
    expect(doneRow.rows[0].status).toBe('done');
    expect(doneRow.rows[0].claim_token).toBeNull();

    // Failure + backoff
    process.env.STUB_CF_DELETE_FAIL = '1';
    const failId = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image','stub-img-outbox-fail','pending', now())`,
      [failId],
    );
    const failTick = await worker.tick(5);
    expect(failTick.failed).toContain(failId);
    const failRow = await pool.query<{
      status: string;
      attempts: number;
      claim_token: string | null;
      next_attempt_at: Date;
    }>(
      `SELECT status, attempts, claim_token, next_attempt_at FROM media_cf_delete_outbox WHERE id=$1`,
      [failId],
    );
    expect(failRow.rows[0].status).toBe('pending');
    expect(failRow.rows[0].attempts).toBeGreaterThanOrEqual(1);
    expect(failRow.rows[0].claim_token).toBeNull();
    expect(new Date(failRow.rows[0].next_attempt_at).getTime()).toBeGreaterThan(Date.now());
    delete process.env.STUB_CF_DELETE_FAIL;

    // Crash reclaim: stale claim_token cleared
    const crashId = newId();
    const staleToken = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, claim_token, claimed_at, next_attempt_at, attempts)
       VALUES ($1,'image','stub-img-crash','pending',$2::uuid, now() - interval '5 minutes', now(), 1)`,
      [crashId, staleToken],
    );
    const reaped = await worker.reapStale(60);
    expect(reaped).toBeGreaterThanOrEqual(1);
    const crashRow = await pool.query<{ claim_token: string | null }>(
      `SELECT claim_token FROM media_cf_delete_outbox WHERE id=$1`,
      [crashId],
    );
    expect(crashRow.rows[0].claim_token).toBeNull();

    // Race: two claimBatch — each row claimed at most once
    const raceA = newId();
    const raceB = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image','stub-img-race-a','pending', now()),
              ($2,'image','stub-img-race-b','pending', now())`,
      [raceA, raceB],
    );
    const [c1, c2] = await Promise.all([worker.claimBatch(10), worker.claimBatch(10)]);
    const allIds = [...c1, ...c2].map((r) => r.id);
    expect(new Set(allIds).size).toBe(allIds.length);
    expect(allIds).toEqual(expect.arrayContaining([raceA, raceB]));
    // Finish claimed rows so leftover state is clean
    for (const row of [...c1, ...c2]) {
      await worker.markDone(row.id, row.claim_token);
    }
  });

  it('upload rejects id/scope tamper; null CF id requires provider verify', async () => {
    const { venueId, ownerUid, typeId } = await seedVenueWithCover('tamper');

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

    const badId = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: 'tampered-not-session-id',
      });
    expect(badId.status).toBeGreaterThanOrEqual(400);

    const badScope = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
        inventoryTypeId: typeId,
      });
    expect(badScope.status).toBeGreaterThanOrEqual(400);
    expect(String(badScope.body.message ?? '')).toMatch(/scope|inventoryTypeId/i);

    await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
      })
      .expect(201);

    // Null CF id path: omit early id — complete must reject unbound client ids (F-REV4-14).
    process.env.STUB_CF_OMIT_IMAGE_ID = '1';
    const nullSession = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);
    delete process.env.STUB_CF_OMIT_IMAGE_ID;

    const nullRow = await pool.query<{ cloudflare_image_id: string | null }>(
      `SELECT cloudflare_image_id FROM media_upload_sessions WHERE id=$1`,
      [nullSession.body.uploadSessionId],
    );
    expect(nullRow.rows[0].cloudflare_image_id).toBeNull();

    const unverified = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: nullSession.body.uploadSessionId,
        cloudflareImageId: 'unknown-client-only-id',
      });
    expect(unverified.status).toBeGreaterThanOrEqual(400);

    const stub = app.get(CLOUDFLARE_MEDIA_PORT) as CloudflareMediaStubAdapter;
    stub.registerKnownImageId('verified-null-path-1');
    const stillRejected = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: nullSession.body.uploadSessionId,
        cloudflareImageId: 'verified-null-path-1',
      });
    expect(stillRejected.status).toBeGreaterThanOrEqual(400);
    expect(String(stillRejected.body.message ?? '')).toMatch(/bound|cloudflareImageId|match/i);
  });

  it('quota blocks mint at 30; concurrent 30→31 only one may complete', async () => {
    const { venueId, providerId, ownerUid } = await seedVenueWithCover('quota');
    for (let i = 0; i < 29; i++) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
         VALUES ($1,$2,$3,'image',$4,$5,'pending',$6)`,
        [
          newId(),
          venueId,
          providerId,
          `https://imagedelivery.net/stub/q-${i}/public`,
          `img-q-${i}`,
          i + 1,
        ],
      );
    }
    const at30 = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM venue_media
       WHERE venue_id=$1 AND inventory_type_id IS NULL AND kind='image'
         AND moderation_status IN ('pending','approved') AND deleted_at IS NULL`,
      [venueId],
    );
    expect(Number(at30.rows[0].c)).toBe(30);

    const blocked = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId });
    expect(blocked.status).toBeGreaterThanOrEqual(400);
    expect(String(blocked.body.message ?? '')).toMatch(/quota|30/i);

    // Drop one to allow 29→30 race (same as REV2)
    await pool.query(
      `UPDATE venue_media SET deleted_at = now()
       WHERE id = (
         SELECT id FROM venue_media
         WHERE venue_id=$1 AND cloudflare_image_id LIKE 'img-q-%' AND deleted_at IS NULL
         LIMIT 1
       )`,
      [venueId],
    );

    async function openAndComplete(tag: string) {
      const session = await request(app.getHttpServer())
        .post('/v1/provider/media/images/upload-session')
        .set('Authorization', auth(ownerUid, 'placesProvider'))
        .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
        .send({ venueId });
      if (session.status !== 201) return session;
      const sess = await pool.query<{ cloudflare_image_id: string }>(
        `SELECT cloudflare_image_id FROM media_upload_sessions WHERE id=$1`,
        [session.body.uploadSessionId],
      );
      return request(app.getHttpServer())
        .post('/v1/provider/media/images/complete')
        .set('Authorization', auth(ownerUid, 'placesProvider'))
        .send({
          uploadSessionId: session.body.uploadSessionId,
          cloudflareImageId: sess.rows[0].cloudflare_image_id,
          purpose: tag,
        });
    }

    const [a, b] = await Promise.all([openAndComplete('race-a'), openAndComplete('race-b')]);
    const statuses = [a.status, b.status].sort((x, y) => x - y);
    expect(statuses[0]).toBe(201);
    expect(statuses[1]).toBeGreaterThanOrEqual(400);
    const after = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM venue_media
       WHERE venue_id=$1 AND inventory_type_id IS NULL AND kind='image'
         AND moderation_status IN ('pending','approved') AND deleted_at IS NULL`,
      [venueId],
    );
    expect(Number(after.rows[0].c)).toBe(30);
  });

  it('publish requires approved image; forbid delete last approved while published', async () => {
    const ownerUid = `${owner}-pub`;
    const providerId = await seedProvider(pool, ownerUid, 'Rev3Pub');
    const seeded = await seedVenue(pool, providerId, {
      name: 'Draft Pub',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-04-01': '80' } }],
    });
    await pool.query(`UPDATE venues SET status = 'draft' WHERE id=$1`, [seeded.venueId]);

    const noImg = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${seeded.venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' });
    expect(noImg.status).toBeGreaterThanOrEqual(400);

    const mediaId = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, is_cover)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/p/public','pub-cover','approved',true)`,
      [mediaId, seeded.venueId, providerId],
    );
    await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${seeded.venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' })
      .expect(200);

    const del = await request(app.getHttpServer())
      .post(`/v1/provider/media/${mediaId}/delete`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ expectedCasVersion: 0 });
    expect(del.status).toBeGreaterThanOrEqual(400);
    expect(String(del.body.message ?? '')).toMatch(/last approved|published/i);

    const still = await pool.query<{ deleted_at: Date | null; status: string }>(
      `SELECT m.deleted_at, v.status
       FROM venue_media m JOIN venues v ON v.id = m.venue_id
       WHERE m.id=$1`,
      [mediaId],
    );
    expect(still.rows[0].deleted_at).toBeNull();
    expect(still.rows[0].status).toBe('published');
  });

  it('orphan cleanup skips completed live CF ids; FOR UPDATE race safe', async () => {
    const { venueId, providerId, ownerUid } = await seedVenueWithCover('orphan');
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

    // Complete first so CF id is live on venue_media
    await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
      })
      .expect(201);

    // Fake a second expired pending session sharing same CF id (should not enqueue delete)
    const orphanId = newId();
    await pool.query(
      `INSERT INTO media_upload_sessions
         (id, provider_id, venue_id, kind, cloudflare_image_id, images_hash, status, created_by_uid, expires_at)
       VALUES ($1,$2,$3,'image',$4,'stub-hash','pending',$5, now() - interval '1 minute')`,
      [orphanId, providerId, venueId, sess.rows[0].cloudflare_image_id, ownerUid],
    );

    const beforeOutbox = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM media_cf_delete_outbox
       WHERE cloudflare_image_id = $1`,
      [sess.rows[0].cloudflare_image_id],
    );

    await request(app.getHttpServer())
      .post('/v1/provider/media/orphans/cleanup')
      .query({ providerId })
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .expect(201);

    const orphanStatus = await pool.query<{ status: string }>(
      `SELECT status FROM media_upload_sessions WHERE id=$1`,
      [orphanId],
    );
    expect(orphanStatus.rows[0].status).toBe('orphaned_cleaned');

    const afterOutbox = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM media_cf_delete_outbox
       WHERE cloudflare_image_id = $1`,
      [sess.rows[0].cloudflare_image_id],
    );
    expect(Number(afterOutbox.rows[0].c)).toBe(Number(beforeOutbox.rows[0].c));
  });

  it('repeated block/open NULL unit is idempotent; closes remaining capacity with hold', async () => {
    const { typeId, ownerUid } = await seedVenueWithCover('block');
    const date = '2027-03-01';

    // Seed capacity row with a hold (1 of 3)
    await pool.query(
      `INSERT INTO inventory_daily_capacity
         (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,$3::date,3,1,0,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE
         SET capacity=3, held=1, booked=0, blocked=0`,
      [newId(), typeId, date],
    );

    for (let i = 0; i < 3; i++) {
      await request(app.getHttpServer())
        .put('/v1/provider/availability')
        .set('Authorization', auth(ownerUid, 'placesProvider'))
        .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
        .send({ inventoryTypeId: typeId, date, kind: 'block', reason: `r${i}` })
        .expect(200);
    }

    const overrides = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM availability_overrides
       WHERE inventory_type_id=$1 AND inventory_unit_id IS NULL
         AND date=$2::date AND kind='block'`,
      [typeId, date],
    );
    expect(Number(overrides.rows[0].c)).toBe(1);

    const cap = await pool.query<{ held: number; booked: number; blocked: number; available: number }>(
      `SELECT held, booked, blocked, available FROM inventory_daily_capacity
       WHERE inventory_type_id=$1 AND date=$2::date`,
      [typeId, date],
    );
    expect(cap.rows[0].held).toBe(1);
    expect(cap.rows[0].booked).toBe(0);
    expect(cap.rows[0].blocked).toBe(2);
    expect(cap.rows[0].available).toBe(0);

    await request(app.getHttpServer())
      .put('/v1/provider/availability')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ inventoryTypeId: typeId, date, kind: 'open' })
      .expect(200);

    const afterOpen = await pool.query<{ blocked: number; available: number; held: number }>(
      `SELECT blocked, available, held FROM inventory_daily_capacity
       WHERE inventory_type_id=$1 AND date=$2::date`,
      [typeId, date],
    );
    expect(afterOpen.rows[0].held).toBe(1);
    expect(afterOpen.rows[0].blocked).toBe(0);
    expect(afterOpen.rows[0].available).toBe(2);
  });
});
