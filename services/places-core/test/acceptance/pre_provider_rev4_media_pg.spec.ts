/**
 * PRE-PROVIDER REV4 Batch 2 — Cloudflare/Media PG evidence.
 * Soft-delete discovery, quota reservation 29→30→31, session bind,
 * CF uniqueness, readyToStream, hostname allowlist, venue-level publish,
 * outbox never deletes live CF refs.
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
import {
  isAllowedCloudflareDeliveryUrl,
  isAllowedCloudflareMediaHostname,
} from '../../src/modules/media/domain/cloudflare-hostname-allowlist';
import {
  PRIMARY_MEDIA_LATERAL_WHERE,
  PLAYABLE_VIDEO_ROW,
  resolveStreamUrl,
} from '../../src/modules/filters/application/discovery-surface';

describe('pre_provider_rev4 media PG', () => {
  let app: INestApplication;
  let pool: Pool;
  const owner = 'rev4-media-owner';

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
    const providerId = await seedProvider(pool, ownerUid, `Rev4Media-${tag}`);
    const seeded = await seedVenue(pool, providerId, {
      name: `Rev4 Media ${tag}`,
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights: { '2027-05-01': '100', '2027-05-02': '100' } }],
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

  it('F-REV4-12: soft-deleted media never wins discovery LATERAL / denorm', async () => {
    expect(PRIMARY_MEDIA_LATERAL_WHERE).toMatch(/deleted_at IS NULL/);
    expect(PLAYABLE_VIDEO_ROW).toMatch(/deleted_at IS NULL/);

    const { venueId, providerId, coverId } = await seedVenueWithCover('lat');
    const videoId = newId();
    const imageId = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, stream_uid, url, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video','stream-lat','https://customer-stub.cloudflarestream.com/x/manifest/video.m3u8','approved',0)`,
      [videoId, venueId, providerId],
    );
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/fallback/public','img-lat-fb','approved',1)`,
      [imageId, venueId, providerId],
    );

    const before = await pool.query<{ media_id: string; kind: string }>(
      `SELECT pm.id AS media_id, pm.kind
       FROM venues v
       LEFT JOIN LATERAL (
         SELECT m.id, m.kind, m.url, m.stream_uid, m.cover_url, m.category
         FROM venue_media m
         WHERE m.venue_id = v.id AND ${PRIMARY_MEDIA_LATERAL_WHERE}
         ORDER BY CASE WHEN ${PLAYABLE_VIDEO_ROW} THEN 0 ELSE 1 END, m.sort_order, m.id
         LIMIT 1
       ) pm ON TRUE
       WHERE v.id = $1`,
      [venueId],
    );
    expect(before.rows[0].media_id).toBe(videoId);
    expect(before.rows[0].kind).toBe('video');

    await pool.query(`UPDATE venue_media SET deleted_at = now() WHERE id=$1`, [videoId]);

    const denorm = await pool.query<{ has_playable_video: boolean }>(
      `SELECT has_playable_video FROM venues WHERE id=$1`,
      [venueId],
    );
    expect(denorm.rows[0].has_playable_video).toBe(false);

    const after = await pool.query<{ media_id: string; kind: string }>(
      `SELECT pm.id AS media_id, pm.kind
       FROM venues v
       LEFT JOIN LATERAL (
         SELECT m.id, m.kind
         FROM venue_media m
         WHERE m.venue_id = v.id AND ${PRIMARY_MEDIA_LATERAL_WHERE}
         ORDER BY CASE WHEN ${PLAYABLE_VIDEO_ROW} THEN 0 ELSE 1 END, m.sort_order, m.id
         LIMIT 1
       ) pm ON TRUE
       WHERE v.id = $1`,
      [venueId],
    );
    expect(after.rows[0].media_id).not.toBe(videoId);
    expect(after.rows[0].kind).toBe('image');
    // Soft-deleted video must not win; cover (sort 0) beats fallback image.
    expect([coverId, imageId]).toContain(after.rows[0].media_id);
  });

  it('F-REV4-13: concurrent barrier 29→30→31; session reserves before CF mint', async () => {
    const { venueId, providerId, ownerUid, typeId } = await seedVenueWithCover('quota');
    // cover + 28 = 29 venue-level images
    for (let i = 0; i < 28; i++) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
         VALUES ($1,$2,$3,'image',$4,$5,'pending',$6)`,
        [
          newId(),
          venueId,
          providerId,
          `https://imagedelivery.net/stub/q-${i}/public`,
          `img-q4-${i}`,
          i + 1,
        ],
      );
    }
    const at29 = await pool.query<{ c: string }>(
      `SELECT places_image_quota_used($1::uuid, NULL)::text AS c`,
      [venueId],
    );
    expect(Number(at29.rows[0].c)).toBe(29);

    // Inventory scope independent: can still mint when venue is near cap.
    const invSession = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId, inventoryTypeId: typeId })
      .expect(201);
    expect(invSession.body.uploadSessionId).toBeTruthy();

    // Concurrent venue-level reservations at 29 — only one may reserve the 30th slot.
    const barriers = await Promise.all(
      Array.from({ length: 8 }, () =>
        request(app.getHttpServer())
          .post('/v1/provider/media/images/upload-session')
          .set('Authorization', auth(ownerUid, 'placesProvider'))
          .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
          .send({ venueId }),
      ),
    );
    const ok = barriers.filter((r) => r.status === 201);
    const blocked = barriers.filter((r) => r.status >= 400);
    expect(ok.length).toBe(1);
    expect(blocked.length).toBe(7);
    expect(String(blocked[0].body.message ?? '')).toMatch(/quota|30/i);

    const used = await pool.query<{ c: string }>(
      `SELECT places_image_quota_used($1::uuid, NULL)::text AS c`,
      [venueId],
    );
    expect(Number(used.rows[0].c)).toBe(30);

    // 31st session blocked
    const over = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId });
    expect(over.status).toBeGreaterThanOrEqual(400);

    // Complete the reserved session → still 30 media (session frees, media takes slot)
    const sess = await pool.query<{ cloudflare_image_id: string }>(
      `SELECT cloudflare_image_id FROM media_upload_sessions WHERE id=$1`,
      [ok[0].body.uploadSessionId],
    );
    await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: ok[0].body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
      })
      .expect(201);

    const mediaCnt = await pool.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM venue_media
       WHERE venue_id=$1 AND inventory_type_id IS NULL AND kind='image'
         AND moderation_status IN ('pending','approved') AND deleted_at IS NULL`,
      [venueId],
    );
    expect(Number(mediaCnt.rows[0].c)).toBe(30);
  });

  it('F-REV4-14: reject foreign / null-bound / draft CF image ids', async () => {
    const { venueId, ownerUid, typeId } = await seedVenueWithCover('bind');
    const stub = app.get(CLOUDFLARE_MEDIA_PORT) as CloudflareMediaStubAdapter;

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
        cloudflareImageId: 'tampered-foreign-id',
      });
    expect(tamper.status).toBeGreaterThanOrEqual(400);
    expect(String(tamper.body.message ?? '')).toMatch(/match|session/i);

    const badScope = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
        inventoryTypeId: typeId,
      });
    expect(badScope.status).toBeGreaterThanOrEqual(400);

    stub.markImageDraft(sess.rows[0].cloudflare_image_id);
    const draft = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
      });
    expect(draft.status).toBeGreaterThanOrEqual(400);
    expect(String(draft.body.message ?? '')).toMatch(/ready|draft|Cloudflare/i);

    stub.clearImageDraft(sess.rows[0].cloudflare_image_id);

    await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        cloudflareImageId: sess.rows[0].cloudflare_image_id,
      })
      .expect(201);

    // Null-bound session: client cannot supply arbitrary verified id
    process.env.STUB_CF_OMIT_IMAGE_ID = '1';
    const nullSession = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);
    delete process.env.STUB_CF_OMIT_IMAGE_ID;

    stub.registerKnownImageId('verified-null-path-rev4');
    const nullComplete = await request(app.getHttpServer())
      .post('/v1/provider/media/images/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({
        uploadSessionId: nullSession.body.uploadSessionId,
        cloudflareImageId: 'verified-null-path-rev4',
      });
    expect(nullComplete.status).toBeGreaterThanOrEqual(400);
    expect(String(nullComplete.body.message ?? '')).toMatch(/bound|cloudflareImageId/i);
  });

  it('F-REV4-15: unique CF image/stream; readyToStream required', async () => {
    const { venueId, providerId, ownerUid } = await seedVenueWithCover('uniq');
    const dupId = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/u/public','dup-cf-id','approved')`,
      [dupId, venueId, providerId],
    );
    const clash = await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/u2/public','dup-cf-id','pending')`,
      [newId(), venueId, providerId],
    ).catch((e: Error) => e);
    expect(clash).toBeInstanceOf(Error);

    process.env.STUB_CF_STREAM_NOT_READY = '1';
    const streamSess = await request(app.getHttpServer())
      .post('/v1/provider/media/videos/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);
    const notReady = await request(app.getHttpServer())
      .post('/v1/provider/media/videos/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ uploadSessionId: streamSess.body.uploadSessionId });
    expect(notReady.status).toBeGreaterThanOrEqual(400);
    expect(String(notReady.body.message ?? '')).toMatch(/readyToStream/i);
    delete process.env.STUB_CF_STREAM_NOT_READY;

    const readySess = await request(app.getHttpServer())
      .post('/v1/provider/media/videos/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/provider/media/videos/complete')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ uploadSessionId: readySess.body.uploadSessionId })
      .expect(201);
  });

  it('F-REV4-16: exact hostname allowlist (no substring spoof)', () => {
    expect(isAllowedCloudflareMediaHostname('imagedelivery.net')).toBe(true);
    expect(isAllowedCloudflareMediaHostname('upload.imagedelivery.net')).toBe(true);
    expect(isAllowedCloudflareMediaHostname('customer-stub.cloudflarestream.com')).toBe(true);
    expect(isAllowedCloudflareMediaHostname('evil-imagedelivery.net')).toBe(false);
    expect(isAllowedCloudflareMediaHostname('notimagedelivery.net')).toBe(false);
    expect(
      isAllowedCloudflareDeliveryUrl('https://evil.example/imagedelivery.net/x'),
    ).toBe(false);
    expect(
      isAllowedCloudflareDeliveryUrl('https://imagedelivery.net/hash/id/public'),
    ).toBe(true);
    expect(resolveStreamUrl('https://firebasestorage.googleapis.com/v0/b/x')).toBeNull();
    expect(
      resolveStreamUrl('https://customer-abc.cloudflarestream.com/uid/manifest/video.m3u8'),
    ).toBeTruthy();
  });

  it('F-REV4-17: publish needs venue-level image; inventory-only fails; admin reject last forbidden', async () => {
    const ownerUid = `${owner}-pub`;
    const providerId = await seedProvider(pool, ownerUid, 'Rev4Pub');
    const seeded = await seedVenue(pool, providerId, {
      name: 'Draft Pub4',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-06-01': '80' } }],
    });
    await pool.query(`UPDATE venues SET status = 'draft' WHERE id=$1`, [seeded.venueId]);

    const roomOnly = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, inventory_type_id, provider_id, kind, url, cloudflare_image_id, moderation_status)
       VALUES ($1,$2,$3,$4,'image','https://imagedelivery.net/stub/room/public','room-only','approved')`,
      [roomOnly, seeded.venueId, seeded.types.Std, providerId],
    );

    const pubRoom = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${seeded.venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' });
    expect(pubRoom.status).toBeGreaterThanOrEqual(400);
    expect(String(pubRoom.body.message ?? '')).toMatch(/venue-level|approved/i);

    const venueImg = newId();
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, is_cover)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/v/public','venue-pub','approved',true)`,
      [venueImg, seeded.venueId, providerId],
    );
    await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${seeded.venueId}`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .send({ status: 'published' })
      .expect(200);

    const del = await request(app.getHttpServer())
      .post(`/v1/provider/media/${venueImg}/delete`)
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ expectedCasVersion: 0 });
    expect(del.status).toBeGreaterThanOrEqual(400);

    const adminReject = await request(app.getHttpServer())
      .patch(`/v1/admin/media/${venueImg}/moderation`)
      .set('Authorization', auth('admin-rev4', 'placesAdmin'))
      .send({ moderationStatus: 'rejected', reason: 'test', expectedCasVersion: 0 });
    expect(adminReject.status).toBeGreaterThanOrEqual(400);
    expect(String(adminReject.body.message ?? '')).toMatch(/last approved|published/i);
  });

  it('outbox: success/retry/reclaim/race; never delete live CF asset', async () => {
    const worker = app.get(MediaCfDeleteWorker);
    const { venueId, providerId } = await seedVenueWithCover('outbox');

    const okId = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image','stub-img-rev4-ok','pending', now())`,
      [okId],
    );
    const ok = await worker.tick(5);
    expect(ok.done).toContain(okId);

    process.env.STUB_CF_DELETE_FAIL = '1';
    const failId = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image','stub-img-rev4-fail','pending', now())`,
      [failId],
    );
    const failTick = await worker.tick(5);
    expect(failTick.failed).toContain(failId);
    delete process.env.STUB_CF_DELETE_FAIL;

    const crashId = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, claim_token, claimed_at, next_attempt_at, attempts)
       VALUES ($1,'image','stub-img-rev4-crash','pending',$2::uuid, now() - interval '5 minutes', now(), 1)`,
      [crashId, newId()],
    );
    expect(await worker.reapStale(60)).toBeGreaterThanOrEqual(1);

    const raceA = newId();
    const raceB = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image','stub-img-race4-a','pending', now()),
              ($2,'image','stub-img-race4-b','pending', now())`,
      [raceA, raceB],
    );
    const [c1, c2] = await Promise.all([worker.claimBatch(10), worker.claimBatch(10)]);
    const allIds = [...c1, ...c2].map((r) => r.id);
    expect(new Set(allIds).size).toBe(allIds.length);
    for (const row of [...c1, ...c2]) {
      await worker.markDone(row.id, row.claim_token);
    }

    // Live media still references CF id → worker skips CF delete, marks done
    const liveCf = 'stub-img-still-live';
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/live/public',$4,'approved')`,
      [newId(), venueId, providerId, liveCf],
    );
    const liveOutbox = newId();
    await pool.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, next_attempt_at)
       VALUES ($1,'image',$2,'pending', now())`,
      [liveOutbox, liveCf],
    );
    const stub = app.get(CLOUDFLARE_MEDIA_PORT) as CloudflareMediaStubAdapter;
    const beforeDeleted = (stub as unknown as { deletedImageIds: Set<string> }).deletedImageIds.has(
      liveCf,
    );
    const liveTick = await worker.tick(5);
    expect(liveTick.done).toContain(liveOutbox);
    expect(
      (stub as unknown as { deletedImageIds: Set<string> }).deletedImageIds.has(liveCf),
    ).toBe(beforeDeleted);

    const liveRow = await pool.query<{ deleted_at: Date | null }>(
      `SELECT deleted_at FROM venue_media WHERE cloudflare_image_id=$1 AND deleted_at IS NULL`,
      [liveCf],
    );
    expect(liveRow.rowCount).toBeGreaterThanOrEqual(1);
  });

  it('TTL expire frees quota reservation', async () => {
    const { venueId, providerId, ownerUid } = await seedVenueWithCover('ttl');
    for (let i = 0; i < 28; i++) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status)
         VALUES ($1,$2,$3,'image',$4,$5,'pending')`,
        [newId(), venueId, providerId, `https://imagedelivery.net/stub/t-${i}/public`, `ttl-${i}`],
      );
    }
    // Manually insert expired pending session occupying last slot conceptually
    await pool.query(
      `INSERT INTO media_upload_sessions
         (id, provider_id, venue_id, kind, cloudflare_image_id, images_hash, status, created_by_uid, expires_at)
       VALUES ($1,$2,$3,'image','ttl-sess','stub-hash','pending',$4, now() - interval '1 minute')`,
      [newId(), providerId, venueId, ownerUid],
    );
    // At 29 media + expired session: expire helper frees session → can reserve
    const session = await request(app.getHttpServer())
      .post('/v1/provider/media/images/upload-session')
      .set('Authorization', auth(ownerUid, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId })
      .expect(201);
    expect(session.body.uploadSessionId).toBeTruthy();
  });
});
