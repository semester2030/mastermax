/**
 * Wave1 RC2 — venue publish gate.
 *
 * The provider web UI now pre-disables "published" and translates the rejection,
 * so these tests pin the server truth the UI mirrors: publishing needs one
 * approved venue-level image, an approved video is not a substitute, and a
 * rejected publish must leave the venue in `draft` on re-read.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';

describe('wave1_rc2 venue publish gate', () => {
  let app: INestApplication;
  let pool: Pool;

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

  /** A draft venue with an approved video but zero approved images. */
  async function seedDraftWithVideoOnly(tag: string): Promise<{
    venueId: string;
    providerId: string;
    ownerUid: string;
    typeId: string;
  }> {
    const ownerUid = `rc2-publish-${tag}`;
    const providerId = await seedProvider(pool, ownerUid, `Rc2Publish-${tag}`);
    const seeded = await seedVenue(pool, providerId, {
      name: `Rc2 Publish ${tag}`,
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2027-06-01': '100' } }],
    });
    await pool.query(`UPDATE venues SET status = 'draft' WHERE id = $1`, [
      seeded.venueId,
    ]);
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, stream_uid, url, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video',$4,
               'https://customer-stub.cloudflarestream.com/x/manifest/video.m3u8',
               'approved',0)`,
      [newId(), seeded.venueId, providerId, `stream-${tag}`],
    );
    return {
      venueId: seeded.venueId,
      providerId,
      ownerUid,
      typeId: seeded.types.Std,
    };
  }

  async function insertImage(
    venueId: string,
    providerId: string,
    tag: string,
    moderation: 'pending' | 'approved',
    inventoryTypeId: string | null,
  ): Promise<string> {
    const id = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id,
          moderation_status, sort_order, inventory_type_id)
       VALUES ($1,$2,$3,'image',
               'https://imagedelivery.net/stub/${tag}/public',$4,$5,1,$6)`,
      [id, venueId, providerId, `img-${tag}`, moderation, inventoryTypeId],
    );
    return id;
  }

  async function storedStatus(venueId: string): Promise<string> {
    const row = await pool.query<{ status: string }>(
      `SELECT status FROM venues WHERE id = $1`,
      [venueId],
    );
    return row.rows[0].status;
  }

  it('publish without an approved venue image is rejected and stays draft', async () => {
    const { venueId, providerId, ownerUid } =
      await seedDraftWithVideoOnly('reject');

    // An approved video plus a pending image must still not unlock publish.
    await insertImage(venueId, providerId, 'reject', 'pending', null);

    const res = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(String(res.body.message)).toMatch(/approved venue-level image/i);

    expect(await storedStatus(venueId)).toBe('draft');

    // Re-read through the API the provider web page uses.
    const reread = await request(app.getHttpServer())
      .get(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .expect(200);
    expect(reread.body.status).toBe('draft');
  });

  it('publish succeeds after one venue image is approved and survives re-read', async () => {
    const { venueId, providerId, ownerUid } =
      await seedDraftWithVideoOnly('accept');
    const imageId = await insertImage(
      venueId,
      providerId,
      'accept',
      'pending',
      null,
    );

    const blocked = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' });
    expect(blocked.status).toBe(400);
    expect(await storedStatus(venueId)).toBe('draft');

    await pool.query(
      `UPDATE venue_media SET moderation_status = 'approved',
              cas_version = cas_version + 1
       WHERE id = $1`,
      [imageId],
    );

    await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' })
      .expect(200);

    expect(await storedStatus(venueId)).toBe('published');

    const reread = await request(app.getHttpServer())
      .get(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .expect(200);
    expect(reread.body.status).toBe('published');
  });

  it('an approved unit-level image does not satisfy publish', async () => {
    const { venueId, providerId, ownerUid, typeId } =
      await seedDraftWithVideoOnly('unit');
    await insertImage(venueId, providerId, 'unit', 'approved', typeId);

    const res = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' });

    expect(res.status).toBe(400);
    expect(await storedStatus(venueId)).toBe('draft');
  });

  it('listMedia exposes inventoryTypeId so the UI can count venue-level images', async () => {
    const { venueId, providerId, ownerUid, typeId } =
      await seedDraftWithVideoOnly('scope');
    await insertImage(venueId, providerId, 'scope-venue', 'approved', null);
    await insertImage(venueId, providerId, 'scope-unit', 'approved', typeId);

    const res = await request(app.getHttpServer())
      .get('/v1/provider/media')
      .query({ providerId, venueId })
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .expect(200);

    const images = (res.body as { kind: string; inventoryTypeId: unknown }[])
      .filter((m) => m.kind === 'image');
    expect(images).toHaveLength(2);
    expect(images.filter((m) => m.inventoryTypeId == null)).toHaveLength(1);
    expect(images.filter((m) => m.inventoryTypeId === typeId)).toHaveLength(1);
  });
});
