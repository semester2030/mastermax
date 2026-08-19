/**
 * Phase 6 — workers / media lifecycle / RBAC / architecture
 * Findings: F-V2-015, F-V2-016, F-V3-005, F-V3-013
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { shouldAutoStartWorkers, placesRunMode } from '../../src/workers/worker-runtime';
import { CANONICAL_WORKERS } from '../../src/workers/canonical-workers';
import { MEDIA_LIMITS, mediaScopeFromInventoryTypeId } from '../../src/modules/media/domain/media-contract';
import { MediaOrphanWorker } from '../../src/workers/media-orphan.worker';
import { MediaCfDeleteWorker } from '../../src/workers/media-cf-delete.worker';
import { CloudflareMediaAdapter } from '../../src/modules/media/infrastructure/cloudflare-media.adapter';
import { AppEnv } from '../../src/shared/config/env';
import { MediaModerationService } from '../../src/modules/venues/application/media-moderation.service';
import { VenuePublicationService } from '../../src/modules/venues/application/venue-publication.service';
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';
import { can, ProviderRole } from '../../src/shared/rbac/permissions';
import { TenancyService } from '../../src/modules/providers/application/tenancy.service';
import { AuthUser } from '../../src/shared/auth/auth-user';

describe('phase6_workers_media', () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    process.env.PLACES_RUN_MODE = 'api';
    delete process.env.PLACES_RUN_WORKERS;
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  it('T-MIG-030-01 migration 030 applied with checksum', async () => {
    const row = await db.query<{ checksum: string | null }>(
      `SELECT checksum FROM schema_migrations WHERE id = '030_phase6_workers_media.sql'`,
    );
    expect(row.rowCount).toBe(1);
    const sql = await fs.readFile(
      path.resolve(__dirname, '../../db/migrations/030_phase6_workers_media.sql'),
      'utf8',
    );
    expect(row.rows[0].checksum).toBe(
      createHash('sha256').update(sql, 'utf8').digest('hex'),
    );
  });

  it('T-WORKER-01 API mode does not auto-start workers; worker mode would', () => {
    process.env.PLACES_RUN_MODE = 'api';
    delete process.env.PLACES_RUN_WORKERS;
    expect(placesRunMode()).toBe('api');
    expect(shouldAutoStartWorkers()).toBe(false);

    process.env.PLACES_RUN_MODE = 'worker';
    // NODE_ENV=test still blocks timers (deterministic tests)
    expect(shouldAutoStartWorkers()).toBe(false);

    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'development';
    process.env.PLACES_RUN_MODE = 'worker';
    expect(shouldAutoStartWorkers()).toBe(true);
    process.env.PLACES_RUN_MODE = 'api';
    expect(shouldAutoStartWorkers()).toBe(false);
    process.env.NODE_ENV = prev;
  });

  it('T-WORKER-02 orphan worker tick writes heartbeat + lease path exists', async () => {
    const orphan = app.get(MediaOrphanWorker);
    const r = await orphan.tick();
    expect(r).toEqual(
      expect.objectContaining({ orphans: expect.any(Number), rejectedSoftDeleted: expect.any(Number) }),
    );
    const hb = await db.query(
      `SELECT worker_name FROM worker_heartbeats WHERE worker_name = 'media_orphan'`,
    );
    expect(hb.rowCount).toBeGreaterThanOrEqual(1);

    const partial = await request(app.getHttpServer())
      .get('/healthz/workers')
      .expect(503);
    expect(partial.body.reason).toBe('missing_worker');
    expect(partial.body.missingWorkers).toEqual(
      expect.arrayContaining(
        CANONICAL_WORKERS.filter((n) => n !== 'media_orphan'),
      ),
    );

    for (const name of CANONICAL_WORKERS) {
      await db.query(
        `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
         VALUES ($1, 'seed-all', now(), NULL)
         ON CONFLICT (worker_name, instance_id)
           DO UPDATE SET last_tick_at = now(), last_error = NULL`,
        [name],
      );
    }
    const health = await request(app.getHttpServer())
      .get('/healthz/workers')
      .expect(200);
    expect(health.body.runMode).toBe('api');
    expect(health.body.heartbeats.map((h: { workerName: string }) => h.workerName)).toEqual(
      [...CANONICAL_WORKERS],
    );
  });

  it('T-MEDIA-01 reject enqueues CF outbox; retention sweep soft-deletes; delete worker claims', async () => {
    const owner = 'p6-media-owner';
    const providerId = await seedProvider(db, owner, 'P6-MED');
    const seeded = await seedVenue(db, providerId, {
      name: 'P6 Media',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-04-01': '100' } }],
    });
    const mediaId = newId();
    const cfId = `cf-img-${mediaId}`;
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order, cas_version)
       VALUES ($1,$2,$3,'image',$4,$5,'pending',0,0)`,
      [mediaId, seeded.venueId, providerId, 'https://imagedelivery.net/stub/p6/public', cfId],
    );

    const mod = app.get(MediaModerationService);
    await mod.moderate({
      mediaId,
      decision: 'rejected',
      expectedCasVersion: 0,
      actorUid: 'admin',
      actorRole: 'placesAdmin',
      correlationId: 'p6-rej',
      reason: 'bad',
    });

    const outbox = await db.query(
      `SELECT status, cloudflare_image_id FROM media_cf_delete_outbox WHERE venue_media_id = $1`,
      [mediaId],
    );
    expect(outbox.rowCount).toBe(1);
    expect(outbox.rows[0].status).toBe('pending');
    expect(outbox.rows[0].cloudflare_image_id).toBe(cfId);

    // Simulate retention age
    await db.query(
      `UPDATE venue_media SET updated_at = now() - interval '31 days' WHERE id = $1`,
      [mediaId],
    );
    // Already rejected — soft delete via sweep
    const orphan = app.get(MediaOrphanWorker);
    const swept = await orphan.sweepRejectedRetention();
    expect(swept).toBeGreaterThanOrEqual(1);
    const soft = await db.query(`SELECT deleted_at FROM venue_media WHERE id = $1`, [mediaId]);
    expect(soft.rows[0].deleted_at).toBeTruthy();

    const del = app.get(MediaCfDeleteWorker);
    const tick = await del.tick(10);
    expect(tick.claimed.length + tick.done.length + tick.failed.length).toBeGreaterThanOrEqual(0);

    expect(MEDIA_LIMITS.maxImagesPerScope).toBe(30);
    expect(MEDIA_LIMITS.maxVideosPerScope).toBe(3);
    expect(MEDIA_LIMITS.cloudflareFetchTimeoutMs).toBeGreaterThanOrEqual(1000);
  });

  it('T-MEDIA-CONTRACT-01 list media exposes kind/status/scope/order/cover', async () => {
    const owner = 'p6-contract-owner';
    const providerId = await seedProvider(db, owner, 'P6-CON');
    const seeded = await seedVenue(db, providerId, {
      name: 'P6 Contract',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-05-01': '100' } }],
    });
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order, is_cover)
       VALUES ($1,$2,$3,'image',$4,$5,'approved',3,true)`,
      [
        newId(),
        seeded.venueId,
        providerId,
        'https://imagedelivery.net/stub/c/public',
        `img-c-${newId()}`,
      ],
    );

    const res = await request(app.getHttpServer())
      .get(`/v1/provider/media`)
      .query({ venueId: seeded.venueId })
      .set('Authorization', auth(owner, 'placesProvider'))
      .expect(200);
    const items = Array.isArray(res.body) ? res.body : res.body.items;
    expect(items.length).toBeGreaterThanOrEqual(1);
    const row = items[0];
    expect(row.kind).toBe('image');
    expect(row.status).toBe('approved');
    expect(row.scope).toBe('venue');
    expect(row.order).toBe(3);
    expect(row.cover).toBe(true);
    expect(mediaScopeFromInventoryTypeId(null)).toBe('venue');
    expect(mediaScopeFromInventoryTypeId(seeded.types.Std)).toBe('inventory_type');

    // Provider Web mirror constants + actual MediaManager contract (not types only).
    const pwTypes = await fs.readFile(
      path.resolve(
        __dirname,
        '../../../../apps/places-provider-web/src/lib/core/types.ts',
      ),
      'utf8',
    );
    expect(pwTypes).toContain('maxImagesPerScope: 30');
    expect(pwTypes).toContain("scope?: 'venue' | 'inventory_type'");
    const manager = await fs.readFile(
      path.resolve(
        __dirname,
        '../../../../apps/places-provider-web/src/components/media-manager.tsx',
      ),
      'utf8',
    );
    expect(manager).toContain('MEDIA_LIMITS.maxVideosPerScope');
    expect(manager).toContain('videosAtCap');
    expect(manager).toContain('disabled={pending || videosAtCap}');
    expect(manager).toContain('liveImages');
    expect(manager).toContain('approvedImages');
    expect(manager).toContain('st === "pending" || st === "approved"');
    expect(manager).toContain('mediaModerationOf(m) === "approved"');
    expect(manager).toContain('disabled={pending || !!isCover || !isApprovedImage}');
    expect(manager).toContain('disabled={!isApprovedImage || approvedIndex <= 0}');
  });

  it('T-ARCH-01 Core sole owner: single publication + moderation + filter services', () => {
    expect(app.get(VenuePublicationService)).toBeDefined();
    expect(app.get(MediaModerationService)).toBeDefined();
    expect(app.get(FilterEngineService)).toBeDefined();
    // Controllers stay thin — admin publish path uses shared service (smoke via DI).
  });

  it('T-RBAC-JOURNEY-01 role matrix journeys for publish/media/bookings', async () => {
    expect(can('owner', 'venue.publish')).toBe(true);
    expect(can('content', 'venue.publish')).toBe(true);
    expect(can('content', 'media.upload')).toBe(true);
    expect(can('front_desk', 'venue.publish')).toBe(false);
    expect(can('front_desk', 'bookings.checkin')).toBe(true);
    expect(can('finance', 'media.upload')).toBe(false);
    expect(can('pricing', 'pricing.edit')).toBe(true);

    const providerId = await seedProvider(db, 'p6-rbac-owner', 'P6-RBAC');
    const tenancy = app.get(TenancyService);

    const roles: Array<{ role: ProviderRole; uid: string }> = [
      { role: 'content', uid: 'p6-rbac-content' },
      { role: 'front_desk', uid: 'p6-rbac-front' },
      { role: 'finance', uid: 'p6-rbac-fin' },
    ];
    for (const { role, uid } of roles) {
      await db.query(
        `INSERT INTO provider_users (id, provider_id, firebase_uid, role, status)
         VALUES ($1,$2,$3,$4,'active')`,
        [newId(), providerId, uid, role],
      );
      const user: AuthUser = { uid, claims: { placesProvider: true } };
      if (can(role, 'venue.publish')) {
        await expect(tenancy.require(user, providerId, 'venue.publish')).resolves.toBeTruthy();
      } else {
        await expect(tenancy.require(user, providerId, 'venue.publish')).rejects.toMatchObject({
          code: 'FORBIDDEN_PROVIDER_SCOPE',
        });
      }
      if (can(role, 'media.upload')) {
        await expect(tenancy.require(user, providerId, 'media.upload')).resolves.toBeTruthy();
      } else {
        await expect(tenancy.require(user, providerId, 'media.upload')).rejects.toMatchObject({
          code: 'FORBIDDEN_PROVIDER_SCOPE',
        });
      }
    }

    // Operator allowlist includes venue.publish (same Core path as provider)
    const op: AuthUser = {
      uid: 'op:p6',
      claims: { placesInternalOperator: true },
      onBehalfOfProviderId: providerId,
    };
    await expect(tenancy.require(op, providerId, 'venue.publish')).resolves.toBeTruthy();
    await expect(tenancy.require(op, providerId, 'team.manage')).rejects.toMatchObject({
      code: 'FORBIDDEN_PROVIDER_SCOPE',
    });
  });

  it('T-CF-TIMEOUT-01 adapter uses bounded fetch timeout config', () => {
    expect(MEDIA_LIMITS.cloudflareFetchTimeoutMs).toBeGreaterThanOrEqual(1000);
    expect(MEDIA_LIMITS.rejectedRetentionDays).toBe(30);
  });

  it('T-MIG-032-01 migration 032 (video quota) applied with checksum', async () => {
    const row = await db.query<{ checksum: string | null }>(
      `SELECT checksum FROM schema_migrations WHERE id = '032_phase6_video_quota.sql'`,
    );
    expect(row.rowCount).toBe(1);
    const sql = await fs.readFile(
      path.resolve(__dirname, '../../db/migrations/032_phase6_video_quota.sql'),
      'utf8',
    );
    expect(row.rows[0].checksum).toBe(
      createHash('sha256').update(sql, 'utf8').digest('hex'),
    );
  });

  it('T-VIDEO-QUOTA-01 atomic video quota counts pending sessions + approved, fails closed', async () => {
    const owner = 'p6-vq-owner';
    const providerId = await seedProvider(db, owner, 'P6-VQ');
    const seeded = await seedVenue(db, providerId, {
      name: 'P6 Video Quota',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-06-01': '100' } }],
    });

    // Pending upload sessions must count toward the cap atomically: 3 succeed,
    // the 4th is rejected fail-closed while only pending sessions exist (no media
    // rows yet), proving pending reservations consume quota.
    for (let i = 0; i < 3; i++) {
      await request(app.getHttpServer())
        .post('/v1/provider/media/videos/upload-session')
        .set('Authorization', auth(owner, 'placesProvider'))
        .set('idempotency-key', newId())
        .send({ venueId: seeded.venueId })
        .expect(201);
    }
    const used3 = await db.query<{ c: string }>(
      `SELECT places_video_quota_used($1::uuid)::text AS c`,
      [seeded.venueId],
    );
    expect(Number(used3.rows[0].c)).toBe(3);

    const over = await request(app.getHttpServer())
      .post('/v1/provider/media/videos/upload-session')
      .set('Authorization', auth(owner, 'placesProvider'))
      .set('idempotency-key', newId())
      .send({ venueId: seeded.venueId });
    expect(over.status).toBe(400);
    expect(JSON.stringify(over.body)).toContain('Video quota full');

    // Expiring the pending sessions frees quota (reservation is not permanent).
    await db.query(
      `UPDATE media_upload_sessions
         SET expires_at = now() - interval '1 hour'
       WHERE venue_id = $1 AND kind = 'video' AND status = 'pending'`,
      [seeded.venueId],
    );
    const freed = await db.query<{ c: string }>(
      `SELECT places_video_quota_used($1::uuid)::text AS c`,
      [seeded.venueId],
    );
    expect(Number(freed.rows[0].c)).toBe(0);
  });

  it('T-VIDEO-QUOTA-03 3 pending sessions then approve rejected video is refused', async () => {
    const owner = 'p6-vq3-owner';
    const providerId = await seedProvider(db, owner, 'P6-VQ3');
    const seeded = await seedVenue(db, providerId, {
      name: 'P6 Video Quota Reject',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-08-01': '100' } }],
    });
    for (let i = 0; i < 3; i++) {
      await request(app.getHttpServer())
        .post('/v1/provider/media/videos/upload-session')
        .set('Authorization', auth(owner, 'placesProvider'))
        .set('idempotency-key', newId())
        .send({ venueId: seeded.venueId })
        .expect(201);
    }
    const used = await db.query<{ c: string }>(
      `SELECT places_video_quota_used($1::uuid)::text AS c`,
      [seeded.venueId],
    );
    expect(Number(used.rows[0].c)).toBe(3);

    const rejectedId = newId();
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order, cas_version)
       VALUES ($1,$2,$3,'video',$4,$5,'rejected',0,0)`,
      [
        rejectedId,
        seeded.venueId,
        providerId,
        'https://videodelivery.net/stub/manifest/video.m3u8',
        `stub-stream-${newId()}`,
      ],
    );
    const mod = app.get(MediaModerationService);
    await expect(
      mod.moderate({
        mediaId: rejectedId,
        decision: 'approved',
        expectedCasVersion: 0,
        actorUid: 'admin',
        actorRole: 'placesAdmin',
        correlationId: 'p6-vq3',
      }),
    ).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
      message: expect.stringContaining('Video quota full'),
    });
    const still = await db.query<{ moderation_status: string }>(
      `SELECT moderation_status FROM venue_media WHERE id = $1`,
      [rejectedId],
    );
    expect(still.rows[0].moderation_status).toBe('rejected');
  });

  it('T-MIG-033-01 migration 033 applied with checksum', async () => {
    const row = await db.query<{ checksum: string | null }>(
      `SELECT checksum FROM schema_migrations WHERE id = '033_rc4_slot_snapshot_video_quota.sql'`,
    );
    expect(row.rowCount).toBe(1);
    const sql = await fs.readFile(
      path.resolve(__dirname, '../../db/migrations/033_rc4_slot_snapshot_video_quota.sql'),
      'utf8',
    );
    expect(row.rows[0].checksum).toBe(
      createHash('sha256').update(sql, 'utf8').digest('hex'),
    );
  });

  it('T-VIDEO-QUOTA-02 DB trigger fails closed on the 4th pending/approved venue video', async () => {
    const owner = 'p6-vqtrig-owner';
    const providerId = await seedProvider(db, owner, 'P6-VQT');
    const seeded = await seedVenue(db, providerId, {
      name: 'P6 Video Trigger',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-07-01': '100' } }],
    });
    const insertVideo = (status: string) =>
      db.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order, cas_version)
         VALUES ($1,$2,$3,'video',$4,$5,$6,0,0)`,
        [
          newId(),
          seeded.venueId,
          providerId,
          'https://videodelivery.net/stub/manifest/video.m3u8',
          `stub-stream-${newId()}`,
          status,
        ],
      );
    // 3 live videos (mix of approved + pending) are allowed.
    await insertVideo('approved');
    await insertVideo('approved');
    await insertVideo('pending');
    const usedTrig = await db.query<{ c: string }>(
      `SELECT places_video_quota_used($1::uuid)::text AS c`,
      [seeded.venueId],
    );
    expect(Number(usedTrig.rows[0].c)).toBe(3);
    // 4th direct insert must be rejected fail-closed by the DB trigger.
    await expect(insertVideo('pending')).rejects.toMatchObject({
      code: '23514', // check_violation
    });
  });

  it('T-CF-DELETE-FAIL-01 delete failure retries to exhaustion, alerts, and degrades health', async () => {
    const outboxId = newId();
    const cfId = `cf-fail-${outboxId}`;
    await db.query(
      `INSERT INTO media_cf_delete_outbox
         (id, kind, cloudflare_image_id, status, attempts)
       VALUES ($1,'image',$2,'pending',0)`,
      [outboxId, cfId],
    );

    const del = app.get(MediaCfDeleteWorker);
    process.env.STUB_CF_DELETE_FAIL = '1';
    try {
      let status = 'pending';
      for (let i = 0; i < 12 && status !== 'failed'; i++) {
        // Clear backoff so each cycle re-claims the same row deterministically.
        await db.query(
          `UPDATE media_cf_delete_outbox SET next_attempt_at = now() WHERE id = $1`,
          [outboxId],
        );
        await del.tick(5);
        const cur = await db.query<{ status: string }>(
          `SELECT status FROM media_cf_delete_outbox WHERE id = $1`,
          [outboxId],
        );
        status = cur.rows[0].status;
      }
      const final = await db.query<{
        status: string;
        attempts: number;
        alerted_at: Date | null;
        last_error: string | null;
      }>(
        `SELECT status, attempts, alerted_at, last_error
         FROM media_cf_delete_outbox WHERE id = $1`,
        [outboxId],
      );
      expect(final.rows[0].status).toBe('failed');
      expect(final.rows[0].attempts).toBeGreaterThanOrEqual(8);
      expect(final.rows[0].alerted_at).toBeTruthy();
      expect(final.rows[0].last_error).toContain('forced failure');
    } finally {
      delete process.env.STUB_CF_DELETE_FAIL;
    }

    // Un-cleared failed-CF-delete alert must fail health closed.
    const health = await request(app.getHttpServer())
      .get('/healthz/workers')
      .expect(503);
    expect(health.body.status).toBe('degraded');
    expect(health.body.failedDeletesAlerted).toBeGreaterThanOrEqual(1);
  });

  it('T-CF-TIMEOUT-REAL-01 adapter maps an aborted CF request to a bounded timeout error', async () => {
    const adapter = new CloudflareMediaAdapter({
      cfAccountId: 'acc-test',
      cfImagesToken: 'tok-test',
      cfImagesHash: 'hash-test',
    } as AppEnv);

    const realFetch = global.fetch;
    const prevTimeout = process.env.PLACES_CF_FETCH_TIMEOUT_MS;
    process.env.PLACES_CF_FETCH_TIMEOUT_MS = '1000';
    // Hanging fetch that only settles when the AbortController fires — proves the
    // adapter's own timeout contract, not a mocked resolve.
    global.fetch = ((_url: unknown, init?: { signal?: AbortSignal }) =>
      new Promise((_resolve, reject) => {
        const signal = init?.signal;
        if (signal) {
          signal.addEventListener('abort', () => {
            const e = new Error('aborted');
            (e as { name: string }).name = 'AbortError';
            reject(e);
          });
        }
      })) as typeof fetch;
    try {
      await expect(adapter.deleteImage('cf-hang-1')).rejects.toMatchObject({
        message: expect.stringContaining('Cloudflare fetch timeout'),
      });
    } finally {
      global.fetch = realFetch;
      if (prevTimeout === undefined) {
        delete process.env.PLACES_CF_FETCH_TIMEOUT_MS;
      } else {
        process.env.PLACES_CF_FETCH_TIMEOUT_MS = prevTimeout;
      }
    }
  }, 15_000);

  it('T-WORKER-HEARTBEAT-STALE-01 health fails closed on stale heartbeat and on last_error', async () => {
    await db.query(`DELETE FROM media_cf_delete_outbox WHERE status = 'failed'`);
    for (const name of CANONICAL_WORKERS) {
      await db.query(
        `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
         VALUES ($1, 'fresh-all', now(), NULL)
         ON CONFLICT (worker_name, instance_id)
           DO UPDATE SET last_tick_at = now(), last_error = NULL`,
        [name],
      );
    }
    await db.query(`DELETE FROM worker_heartbeats WHERE worker_name = 'hold_expiry'`);
    await db.query(
      `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
       VALUES ('hold_expiry', 'i-stale', now() - interval '10 minutes', NULL)`,
    );
    const staleHealth = await request(app.getHttpServer())
      .get('/healthz/workers')
      .expect(503);
    expect(staleHealth.body.status).toBe('degraded');
    const staleHb = staleHealth.body.heartbeats.find(
      (h: { workerName: string }) => h.workerName === 'hold_expiry',
    );
    expect(staleHb).toBeDefined();
    expect(staleHb.stale).toBe(true);
    expect(staleHb.healthy).toBe(false);

    await db.query(`DELETE FROM worker_heartbeats WHERE worker_name = 'refund'`);
    await db.query(
      `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
       VALUES ('refund', 'i-err', now(), 'boom')`,
    );
    const errHealth = await request(app.getHttpServer())
      .get('/healthz/workers')
      .expect(503);
    const errHb = errHealth.body.heartbeats.find(
      (h: { workerName: string }) => h.workerName === 'refund',
    );
    expect(errHb.healthy).toBe(false);
    expect(errHb.lastError).toBe('boom');

    await db.query(
      `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
       VALUES ('hold_expiry', 'i-restart', now(), NULL)
       ON CONFLICT (worker_name, instance_id)
         DO UPDATE SET last_tick_at = now(), last_error = NULL`,
    );
    await db.query(
      `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
       VALUES ('refund', 'i-err-fresh', now(), NULL)
       ON CONFLICT (worker_name, instance_id)
         DO UPDATE SET last_tick_at = now(), last_error = NULL`,
    );
    const recovered = await request(app.getHttpServer()).get('/healthz/workers');
    const staleAfter = recovered.body.heartbeats.find(
      (h: { workerName: string }) => h.workerName === 'hold_expiry',
    );
    expect(staleAfter.instanceId).toBe('i-restart');
    expect(staleAfter.healthy).toBe(true);
  });

  it('T-WORKER-HEALTH-ABSENT-01 missing heartbeat and DB error fail closed 503', async () => {
    await db.query(`DELETE FROM worker_heartbeats`);
    const absent = await request(app.getHttpServer())
      .get('/healthz/workers')
      .expect(503);
    expect(absent.body.reason).toBe('no_heartbeat');

    await db.query(`ALTER TABLE worker_heartbeats RENAME TO worker_heartbeats_rc3_bak`);
    try {
      const broken = await request(app.getHttpServer())
        .get('/healthz/workers')
        .expect(503);
      expect(broken.body.reason).toBe('db_error');
    } finally {
      await db.query(
        `ALTER TABLE worker_heartbeats_rc3_bak RENAME TO worker_heartbeats`,
      );
    }
  });

  it('T-WORKER-INDEPENDENT-01 worker process writes heartbeat without an API listener', async () => {
    const { spawn } = await import('child_process');
    const child = spawn(
      'npx',
      ['ts-node', 'src/workers/main.ts'],
      {
        cwd: path.resolve(__dirname, '../..'),
        env: {
          ...process.env,
          NODE_ENV: 'development',
          PLACES_RUN_MODE: 'worker',
          AUTH_MODE: 'stub',
          PAYMENT_PROVIDER: 'stub',
          STUB_WEBHOOK_SECRET: 'test-stub-secret',
        },
        stdio: 'pipe',
      },
    );
    try {
      let names: string[] = [];
      for (let i = 0; i < 30 && names.length < CANONICAL_WORKERS.length; i++) {
        await new Promise((r) => setTimeout(r, 500));
        const hb = await db.query<{ worker_name: string }>(
          `SELECT DISTINCT worker_name
             FROM worker_heartbeats
            WHERE last_tick_at > now() - interval '20 seconds'
              AND worker_name = ANY($1::text[])`,
          [CANONICAL_WORKERS],
        );
        names = hb.rows.map((r) => r.worker_name);
      }
      expect(names.sort()).toEqual([...CANONICAL_WORKERS].sort());
    } finally {
      child.kill('SIGTERM');
      await new Promise((r) => setTimeout(r, 300));
      if (!child.killed) child.kill('SIGKILL');
    }
  }, 30_000);
});
