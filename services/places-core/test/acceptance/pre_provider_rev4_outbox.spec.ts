/**
 * PRE-PROVIDER REV4 — domain_events OutboxWorker claim_token / reclaim (F-REV4-18).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { NOTIFICATION_PORT, NotificationPort } from '../../src/modules/notifications/application/notification.port';
import { PgService } from '../../src/shared/database/pg.service';
import { newId } from '../../src/shared/ids/ids';
import { OutboxWorker } from '../../src/workers/outbox.worker';
import { createTestApp, resetDb, testEnv } from '../helpers/test-app';

describe('pre_provider_rev4 — events outbox reclaim', () => {
  let app: INestApplication;
  let db: Pool;
  let pg: PgService;
  let notifications: NotificationPort;

  beforeAll(async () => {
    testEnv();
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
    pg = app.get(PgService);
    notifications = app.get(NOTIFICATION_PORT);
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await db.end();
  });

  it('F-REV4-18: fresh claim is not reaped; two workers do not double-notify under reclaim window', async () => {
    const eventId = newId();
    await db.query(
      `INSERT INTO domain_events (id, name, payload_json, status, attempts)
       VALUES ($1,'test.rev4.outbox',$2::jsonb,'pending',0)`,
      [eventId, JSON.stringify({ uid: 'rev4-outbox-user', n: 1 })],
    );

    const w1 = new OutboxWorker(pg, notifications);
    const claimed = await w1.claimBatch(1);
    expect(claimed).toHaveLength(1);
    expect(claimed[0].id).toBe(eventId);
    const token1 = claimed[0].claim_token;

    // Within reclaim window: reapStale must not release the claim.
    expect(await w1.reapStale(60)).toBe(0);
    const stillProcessing = await db.query<{ status: string; claim_token: string }>(
      `SELECT status, claim_token::text FROM domain_events WHERE id = $1`,
      [eventId],
    );
    expect(stillProcessing.rows[0].status).toBe('processing');
    expect(stillProcessing.rows[0].claim_token).toBe(token1);

    const w2 = new OutboxWorker(pg, notifications);
    expect(await w2.claimBatch(1)).toHaveLength(0);

    // Complete notify + markSent under original claim.
    await notifications.handle('test.rev4.outbox', {
      uid: 'rev4-outbox-user',
      eventId,
      n: 1,
    });
    expect(await w1.markSent(eventId, token1)).toBe(true);

    const notif = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM notifications WHERE source_event_id = $1`,
      [eventId],
    );
    expect(notif.rows[0].c).toBe(1);
  });

  it('F-REV4-18: stale reclaim + claim_token — old markSent loses; notify stays idempotent by eventId', async () => {
    const eventId = newId();
    await db.query(
      `INSERT INTO domain_events (id, name, payload_json, status, attempts)
       VALUES ($1,'test.rev4.reclaim',$2::jsonb,'pending',0)`,
      [eventId, JSON.stringify({ uid: 'rev4-reclaim-user', n: 2 })],
    );

    const w1 = new OutboxWorker(pg, notifications);
    const w2 = new OutboxWorker(pg, notifications);
    const c1 = await w1.claimBatch(1);
    expect(c1).toHaveLength(1);
    const token1 = c1[0].claim_token;

    // Age claim past reclaim window and release.
    await db.query(
      `UPDATE domain_events SET claimed_at = now() - interval '10 minutes' WHERE id = $1`,
      [eventId],
    );
    expect(await w2.reapStale(60)).toBe(1);

    const c2 = await w2.claimBatch(1);
    expect(c2).toHaveLength(1);
    expect(c2[0].claim_token).not.toBe(token1);
    const token2 = c2[0].claim_token;

    // Simulate both workers notifying (crash-after-send / slow handler race).
    await notifications.handle('test.rev4.reclaim', {
      uid: 'rev4-reclaim-user',
      eventId,
      n: 2,
    });
    await notifications.handle('test.rev4.reclaim', {
      uid: 'rev4-reclaim-user',
      eventId,
      n: 2,
    });

    // Stale claimer cannot mark sent; current claimer can.
    expect(await w1.markSent(eventId, token1)).toBe(false);
    expect(await w2.markSent(eventId, token2)).toBe(true);

    const notif = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM notifications WHERE source_event_id = $1`,
      [eventId],
    );
    expect(notif.rows[0].c).toBe(1);

    const status = await db.query<{ status: string; claim_token: string | null }>(
      `SELECT status, claim_token FROM domain_events WHERE id = $1`,
      [eventId],
    );
    expect(status.rows[0].status).toBe('sent');
    expect(status.rows[0].claim_token).toBeNull();
  });

  it('F-REV4-18: concurrent tick under reclaim window delivers once', async () => {
    const ids = Array.from({ length: 5 }, () => newId());
    for (const id of ids) {
      await db.query(
        `INSERT INTO domain_events (id, name, payload_json, status, attempts)
         VALUES ($1,'test.rev4.race',$2::jsonb,'pending',0)`,
        [id, JSON.stringify({ uid: 'rev4-race', id })],
      );
    }
    const w1 = new OutboxWorker(pg, notifications);
    const w2 = new OutboxWorker(pg, notifications);
    await Promise.all([w1.tick(10), w2.tick(10)]);
    // Drain any leftovers (should be none if both ran).
    await Promise.all([w1.tick(10), w2.tick(10)]);

    const sent = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM domain_events WHERE name = 'test.rev4.race' AND status = 'sent'`,
    );
    expect(sent.rows[0].c).toBe(5);
    const notif = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM notifications
       WHERE event_name = 'test.rev4.race' AND source_event_id = ANY($1::uuid[])`,
      [ids],
    );
    expect(notif.rows[0].c).toBe(5);
  });
});
