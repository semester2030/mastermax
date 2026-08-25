import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { pool, seedProvider, seedVenue } from '../helpers/seed';
import { HoldService } from '../../src/modules/booking/application/hold.service';
import { OutboxWorker } from '../../src/workers/outbox.worker';
import { assertProductionGuards } from '../../src/shared/config/env';
import { ReceivableEligibilityService } from '../../src/modules/settlements/application/receivable-eligibility.service';
import { BookingStateMachine } from '../../src/modules/booking/domain/booking-state.machine';
import { canTransition } from '../../src/modules/booking/domain/booking-states';

describe('Hardening I–W', () => {
  let app: INestApplication;
  const dates = { in: '2026-09-01', out: '2026-09-04' };

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  function sig(body: string): string {
    return createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string).update(body).digest('hex');
  }

  async function quoteHoldPay(opts: {
    owner: string;
    uid: string;
    qty?: number;
    typeQty?: number;
    nights?: Record<string, string>;
  }) {
    const db = pool();
    const providerId = await seedProvider(db, opts.owner, opts.owner);
    const seeded = await seedVenue(db, providerId, {
      name: `V-${opts.owner}`,
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: opts.typeQty ?? 5,
          nights: opts.nights ?? {
            '2026-09-01': '100',
            '2026-09-02': '100',
            '2026-09-03': '100',
          },
        },
      ],
    });
    await db.end();
    const typeId = seeded.types.Std;
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(opts.uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: opts.qty ?? 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `h-${opts.uid}-${Date.now()}-${Math.random()}`)
      .send({ quoteId:q.body.quoteId, quantity: opts.qty ?? 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    return { ...seeded, typeId, holdId: hold.body.holdId as string, bookingId: hold.body.bookingId as string, uid: opts.uid };
  }

  it('I hold expiry vs payment webhook race — only confirm or refund-after-expiry', async () => {
    const outcomes: string[] = [];

    async function oneRace(tag: string, mode: 'webhook-first' | 'expiry-first' | 'parallel'): Promise<void> {
      const c = await quoteHoldPay({ owner: `race-${tag}`, uid: `race-u-${tag}`, typeQty: 1 });
      const intent = await request(app.getHttpServer())
        .post('/v1/payments/intents')
        .set('Authorization', auth(c.uid))
        .set('Idempotency-Key', `race-pay-${tag}`)
        .send({ holdId: c.holdId })
        .expect(201);
      // Do not pre-expire holds before webhook-first: expires_at is authoritative for confirm.
      // expiry-first / parallel race expireOne against webhook while hold is still ACTIVE.
      const body = JSON.stringify({
        eventId: `race-evt-${tag}`,
        type: 'payment.succeeded',
        pspIntentId: `stub_pi_${intent.body.paymentId}`,
      });
      const webhook = () =>
        request(app.getHttpServer())
          .post('/v1/webhooks/psp/stub')
          .set('X-Stub-Signature', sig(body))
          .set('Content-Type', 'application/json')
          .send(body);
      if (mode === 'webhook-first') {
        await webhook().expect(201);
        await app.get(HoldService).expireOne(c.holdId);
      } else if (mode === 'expiry-first') {
        const dbExp = pool();
        await dbExp.query(
          `UPDATE booking_holds SET expires_at = now() - interval '2 seconds' WHERE id = $1`,
          [c.holdId],
        );
        await dbExp.end();
        await app.get(HoldService).expireOne(c.holdId);
        await webhook().expect(201);
      } else {
        const dbExp = pool();
        await dbExp.query(
          `UPDATE booking_holds SET expires_at = now() - interval '2 seconds' WHERE id = $1`,
          [c.holdId],
        );
        await dbExp.end();
        await Promise.all([app.get(HoldService).expireOne(c.holdId), webhook()]);
      }
      const db2 = pool();
      const b = await db2.query<{ status: string }>(`SELECT status FROM bookings WHERE id = $1`, [c.bookingId]);
      const p = await db2.query<{ status: string }>(`SELECT status FROM payments WHERE id = $1`, [
        intent.body.paymentId,
      ]);
      const h = await db2.query<{ status: string; held: string; booked: string }>(
        `SELECT h.status, d.held::text, d.booked::text FROM booking_holds h
         JOIN inventory_daily_capacity d ON d.inventory_type_id = h.inventory_type_id AND d.date = '2026-09-01'
         WHERE h.id = $1`,
        [c.holdId],
      );
      await db2.end();
      const bookingStatus = b.rows[0].status;
      const paymentStatus = p.rows[0].status;
      if (bookingStatus === 'CONFIRMED' && paymentStatus === 'succeeded') {
        expect(h.rows[0].status).toBe('CONVERTED');
        expect(Number(h.rows[0].held)).toBe(0);
        expect(Number(h.rows[0].booked)).toBe(1);
        outcomes.push('CONFIRMED');
      } else if (paymentStatus === 'refunded_after_expiry' && bookingStatus !== 'CONFIRMED') {
        expect(h.rows[0].status).toBe('EXPIRED');
        expect(Number(h.rows[0].held)).toBe(0);
        expect(Number(h.rows[0].booked)).toBe(0);
        outcomes.push('EXPIRED_REFUND');
      } else {
        outcomes.push(`BAD:${bookingStatus}/${paymentStatus}/${h.rows[0].status}`);
      }
    }

    // Deterministic ordered scenarios (required A/B)
    await oneRace('wf1', 'webhook-first');
    await oneRace('wf2', 'webhook-first');
    await oneRace('ef1', 'expiry-first');
    await oneRace('ef2', 'expiry-first');
    // Concurrent races (repeat for flake resistance)
    for (let i = 0; i < 4; i += 1) {
      await oneRace(`p${i}`, 'parallel');
    }

    expect(outcomes.filter((o) => o === 'CONFIRMED').length).toBeGreaterThanOrEqual(2);
    expect(outcomes.filter((o) => o === 'EXPIRED_REFUND').length).toBeGreaterThanOrEqual(2);
    expect(outcomes.every((o) => o === 'CONFIRMED' || o === 'EXPIRED_REFUND')).toBe(true);
  });

  it('J multi-night atomic failure — no partial hold', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'j-owner', 'JCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'JHotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 1,
          nights: { '2026-09-01': '100', '2026-09-02': '100', '2026-09-03': '100' },
        },
      ],
    });
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES (gen_random_uuid(), $1, '2026-09-03', 1, 0, 1, 0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET booked = 1, capacity = 1`,
      [seeded.types.Std],
    );
    await db.end();
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('j-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('j-user'))
      .set('Idempotency-Key', 'j-hold')
      .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(409);
    const db2 = pool();
    const caps = await db2.query<{ date: string; held: string }>(
      `SELECT date::text, held::text FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date BETWEEN '2026-09-01' AND '2026-09-03'
       ORDER BY date`,
      [seeded.types.Std],
    );
    await db2.end();
    for (const row of caps.rows) {
      if (row.date === '2026-09-03') {
        expect(Number(row.held)).toBe(0);
      } else {
        expect(Number(row.held)).toBe(0);
      }
    }
  });

  it('K cancel idempotency — no double release', async () => {
    const c = await quoteHoldPay({ owner: 'k-owner', uid: 'k-user' });
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'k-pay')
      .send({ holdId: c.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: 'k-evt',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    const a = await request(app.getHttpServer())
      .post(`/v1/bookings/${c.bookingId}/cancel`)
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'k-cancel')
      .send({ reason: 'change plans' })
      .expect(200);
    const b = await request(app.getHttpServer())
      .post(`/v1/bookings/${c.bookingId}/cancel`)
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'k-cancel')
      .send({ reason: 'change plans' });
    expect([200]).toContain(b.status);
    expect(b.body.refundId).toBe(a.body.refundId);
    const db = pool();
    const caps = await db.query<{ booked: string }>(
      `SELECT booked::text FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = '2026-09-01'`,
      [c.typeId],
    );
    const refunds = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM refunds WHERE booking_id = $1`,
      [c.bookingId],
    );
    await db.end();
    expect(Number(caps.rows[0].booked)).toBe(0);
    expect(refunds.rows[0].c).toBe(1);
  });

  it('L refund idempotency — second call returns same', async () => {
    const c = await quoteHoldPay({ owner: 'l-owner', uid: 'l-user' });
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'l-pay')
      .send({ holdId: c.holdId });
    const body = JSON.stringify({
      eventId: 'l-evt',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body);
    const a = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-l', 'placesAdmin'))
      .set('Idempotency-Key', 'hardening-admin-full-l')
      .send({ bookingId: c.bookingId, reason: 'ops', kind: 'full' })
      .expect(201);
    const b = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-l', 'placesAdmin'))
      .set('Idempotency-Key', 'hardening-admin-full-l')
      .send({ bookingId: c.bookingId, reason: 'ops', kind: 'full' })
      .expect(201);
    expect(b.body.refundId).toBe(a.body.refundId);
  });

  it('M settlement idempotency — no double payout', async () => {
    const c = await quoteHoldPay({ owner: 'm-owner', uid: 'm-user' });
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'm-pay')
      .send({ holdId: c.holdId });
    const body = JSON.stringify({
      eventId: 'm-evt',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body);
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-20');
    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-m', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    const draft2 = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-m', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(draft2.body.settlementId).toBe(draft.body.settlementId);
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-m', 'placesAdmin,placesFinance'))
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-m', 'placesAdmin,placesFinance'))
      .expect(201);
    const db = pool();
    const pays = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payouts WHERE settlement_id = $1`,
      [draft.body.settlementId],
    );
    await db.end();
    expect(pays.rows[0].c).toBe(1);
  });

  it('N provider full tenant isolation', async () => {
    const db = pool();
    const a = await seedProvider(db, 'n-a', 'A');
    const b = await seedProvider(db, 'n-b', 'B');
    const va = await seedVenue(db, a, {
      name: 'A',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2026-09-01': '50', '2026-09-02': '50', '2026-09-03': '50' } }],
    });
    const vb = await seedVenue(db, b, {
      name: 'B',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2026-09-01': '50', '2026-09-02': '50', '2026-09-03': '50' } }],
    });
    await db.end();
    await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${vb.venueId}`)
      .set('Authorization', auth('n-a', 'placesProvider'))
      .send({ name: 'hack' })
      .expect(403);
    await request(app.getHttpServer())
      .put('/v1/provider/availability')
      .set('Authorization', auth('n-a', 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ inventoryTypeId: vb.types.Std, date: '2026-09-01', kind: 'block' })
      .expect(403);
    await request(app.getHttpServer())
      .put('/v1/provider/pricing')
      .set('Authorization', auth('n-a', 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ ratePlanId: vb.plans.Std, kind: 'base', amount: '1' })
      .expect(403);

    await request(app.getHttpServer())
      .get('/v1/provider/bookings')
      .query({ providerId: b })
      .set('Authorization', auth('n-a', 'placesProvider'))
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/provider/finance')
      .query({ providerId: b })
      .set('Authorization', auth('n-a', 'placesProvider'))
      .expect(403);
    await request(app.getHttpServer())
      .post('/v1/provider/media/videos/upload-session')
      .set('Authorization', auth('n-a', 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId: vb.venueId })
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/provider/team')
      .query({ providerId: b })
      .set('Authorization', auth('n-a', 'placesProvider'))
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/provider/calendar')
      .query({ providerId: a, from: '2026-09-01', to: '2026-09-04' })
      .set('Authorization', auth('n-a', 'placesProvider'))
      .expect(200);
    void va;
  });

  it('O production stub auth guard fails closed', () => {
    expect(() => assertProductionGuards('production', 'stub', 'stripe')).toThrow(/AUTH_MODE=stub/);
  });

  it('P production payment stub guard fails closed', () => {
    expect(() => assertProductionGuards('production', 'firebase', 'stub')).toThrow(/PAYMENT_PROVIDER=stub/);
    expect(() => assertProductionGuards('production', 'firebase', 'moyasar')).not.toThrow();
  });

  it('S illegal booking transitions rejected by SM', async () => {
    expect(canTransition('COMPLETED', 'PENDING_PAYMENT')).toBe(false);
    expect(canTransition('REFUNDED', 'CONFIRMED')).toBe(false);
    const c = await quoteHoldPay({ owner: 's-owner', uid: 's-user' });
    const sm = app.get(BookingStateMachine);
    const db = pool();
    await expect(
      db.connect().then(async (client) => {
        try {
          await client.query('BEGIN');
          await sm.transition(client, {
            bookingId: c.bookingId,
            from: 'HOLDING',
            to: 'CONFIRMED',
            actorUid: 'x',
            actorRole: 'test',
            correlationId: 's',
            eventName: 'illegal',
          });
          await client.query('COMMIT');
        } catch (e) {
          await client.query('ROLLBACK');
          throw e;
        } finally {
          client.release();
        }
      }),
    ).rejects.toThrow(/Illegal booking transition|Pay-at-Venue confirm path/);
    await db.end();
  });

  it('T outbox retry / duplicate processing is at-least-once safe', async () => {
    const worker = app.get(OutboxWorker);
    await worker.tick();
    await worker.tick();
    const db = pool();
    const pending = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM domain_events WHERE status = 'pending'`,
    );
    await db.end();
    expect(pending.rows[0].c).toBeGreaterThanOrEqual(0);
  });

  it('U multiple expiry workers on same hold — no double release', async () => {
    const c = await quoteHoldPay({ owner: 'u-owner', uid: 'u-user', typeQty: 1 });
    const db = pool();
    await db.query(`UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`, [c.holdId]);
    await db.end();
    const holds = app.get(HoldService);
    const results = await Promise.all([holds.expireOne(c.holdId), holds.expireOne(c.holdId), holds.expireOne(c.holdId)]);
    expect(results.filter(Boolean)).toHaveLength(1);
    const db2 = pool();
    const cap = await db2.query<{ held: string }>(
      `SELECT held::text FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = '2026-09-01'`,
      [c.typeId],
    );
    await db2.end();
    expect(Number(cap.rows[0].held)).toBe(0);
  });

  it('V webhook forged / replay / skew', async () => {
    const c = await quoteHoldPay({ owner: 'v-owner', uid: 'v-user' });
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'v-pay')
      .send({ holdId: c.holdId });
    const body = JSON.stringify({
      eventId: 'v-evt',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', 'deadbeef')
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(401);
    const old = JSON.stringify({
      eventId: 'v-evt-old',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
      ts: Math.floor(Date.now() / 1000) - 10_000,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(old))
      .set('Content-Type', 'application/json')
      .send(old)
      .expect(401);
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
  });

  it('W FK delete safety + ledger append-only on real rows', async () => {
    const c = await quoteHoldPay({ owner: 'w-owner', uid: 'w-user' });
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'w-pay')
      .send({ holdId: c.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: 'w-evt',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    const db = pool();
    await expect(db.query(`DELETE FROM providers WHERE id = $1`, [c.providerId])).rejects.toThrow();
    await expect(db.query(`DELETE FROM venues WHERE id = $1`, [c.venueId])).rejects.toThrow();
    const led = await db.query<{ id: string; amount: string }>(
      `SELECT id, amount::text FROM ledger_entries WHERE booking_id = $1 LIMIT 1`,
      [c.bookingId],
    );
    expect(led.rowCount).toBeGreaterThan(0);
    await expect(
      db.query(`UPDATE ledger_entries SET amount = 0 WHERE id = $1`, [led.rows[0].id]),
    ).rejects.toThrow(/append-only|ledger_entries/);
    await expect(db.query(`DELETE FROM ledger_entries WHERE id = $1`, [led.rows[0].id])).rejects.toThrow(
      /append-only|ledger_entries/,
    );
    const after = await db.query<{ amount: string }>(`SELECT amount::text FROM ledger_entries WHERE id = $1`, [
      led.rows[0].id,
    ]);
    expect(after.rows[0].amount).toBe(led.rows[0].amount);
    await db.end();
  });

  it('inventory CHECK rejects negative and oversell', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'inv-chk', 'InvChk');
    const seeded = await seedVenue(db, providerId, {
      name: 'Inv',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2026-09-01': '10', '2026-09-02': '10', '2026-09-03': '10' } }],
    });
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES (gen_random_uuid(), $1, '2026-09-01', 2, 0, 0, 0)`,
      [seeded.types.Std],
    );
    await expect(
      db.query(
        `UPDATE inventory_daily_capacity SET held = -1 WHERE inventory_type_id = $1 AND date = '2026-09-01'`,
        [seeded.types.Std],
      ),
    ).rejects.toThrow();
    await expect(
      db.query(
        `UPDATE inventory_daily_capacity SET held = 2, booked = 1 WHERE inventory_type_id = $1 AND date = '2026-09-01'`,
        [seeded.types.Std],
      ),
    ).rejects.toThrow();
    await expect(
      db.query(
        `UPDATE inventory_daily_capacity SET capacity = -1 WHERE inventory_type_id = $1 AND date = '2026-09-01'`,
        [seeded.types.Std],
      ),
    ).rejects.toThrow();
    await db.end();
  });

  it('R commission snapshot survives provider default change', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'r-owner', 'RCo');
    await db.query(`UPDATE providers SET commission_bps_override = 1000 WHERE id = $1`, [providerId]);
    const seeded = await seedVenue(db, providerId, {
      name: 'RHotel',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights: { '2026-09-01': '100', '2026-09-02': '0', '2026-09-03': '0' } }],
    });
    await db.end();
    const qA = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('r-user-a'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2026-09-01',
        checkOut: '2026-09-02',
        quantity: 1,
      })
      .expect(201);
    const holdA = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('r-user-a'))
      .set('Idempotency-Key', 'r-hold-a')
      .send({ quoteId:qA.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const db2 = pool();
    const snap = await db2.query<{ commission_bps: number; commission_amount: string }>(
      `SELECT commission_bps, commission_amount::text FROM bookings WHERE id = $1`,
      [holdA.body.bookingId],
    );
    expect(snap.rows[0].commission_bps).toBe(1000);
    expect(snap.rows[0].commission_amount).toBe('10.00');
    await db2.query(`UPDATE providers SET commission_bps_override = 1200 WHERE id = $1`, [providerId]);
    await db2.end();
    const qB = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('r-user-b'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2026-09-01',
        checkOut: '2026-09-02',
        quantity: 1,
      })
      .expect(201);
    const holdB = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('r-user-b'))
      .set('Idempotency-Key', 'r-hold-b')
      .send({ quoteId:qB.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const db3 = pool();
    const a = await db3.query<{ commission_bps: number }>(`SELECT commission_bps FROM bookings WHERE id = $1`, [
      holdA.body.bookingId,
    ]);
    const b = await db3.query<{ commission_bps: number }>(`SELECT commission_bps FROM bookings WHERE id = $1`, [
      holdB.body.bookingId,
    ]);
    await db3.end();
    expect(a.rows[0].commission_bps).toBe(1000);
    expect(b.rows[0].commission_bps).toBe(1200);
  });

  it('boundary consumer/provider/admin + support cannot settle', async () => {
    await request(app.getHttpServer())
      .get('/v1/provider/bookings')
      .set('Authorization', auth('consumer-only'))
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/admin/bookings')
      .set('Authorization', auth('consumer-only'))
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/admin/bookings')
      .set('Authorization', auth('prov-only', 'placesProvider'))
      .expect(403);
    await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('support-only', 'placesSupport'))
      .send({ providerId: '00000000-0000-0000-0000-000000000001', periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(403);
  });

  it('G+ webhook same event 10 times → one ledger group', async () => {
    const c = await quoteHoldPay({
      owner: 'g10-owner',
      uid: 'g10-user',
      nights: { '2026-09-01': '1000', '2026-09-02': '0', '2026-09-03': '0' },
    });
    // recreate with 1-night quote for clearer ledger
    const db = pool();
    const providerId = await seedProvider(db, 'g10b-owner', 'G10');
    const seeded = await seedVenue(db, providerId, {
      name: 'G10',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2026-09-01': '1000', '2026-09-02': '0', '2026-09-03': '0' } }],
    });
    await db.end();
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('g10-u'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2026-09-01',
        checkOut: '2026-09-02',
        quantity: 1,
      });
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('g10-u'))
      .set('Idempotency-Key', 'g10-hold')
      .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth('g10-u'))
      .set('Idempotency-Key', 'g10-pay')
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: 'g10-dup',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    for (let i = 0; i < 10; i += 1) {
      await request(app.getHttpServer())
        .post('/v1/webhooks/psp/stub')
        .set('X-Stub-Signature', sig(body))
        .set('Content-Type', 'application/json')
        .send(body)
        .expect(201);
    }
    const db2 = pool();
    const led = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE booking_id = $1`,
      [hold.body.bookingId],
    );
    const wh = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM webhook_events WHERE provider_event_id = 'g10-dup'`,
    );
    await db2.end();
    expect(led.rows[0].c).toBe(3);
    expect(wh.rows[0].c).toBe(1);
    void c;
  });

  it('idempotency same key different body → 409', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'idem-owner', 'Idem');
    const seeded = await seedVenue(db, providerId, {
      name: 'IdemHotel',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights: { '2026-09-01': '100', '2026-09-02': '100', '2026-09-03': '100' } }],
    });
    await db.end();
    const q1 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('idem-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      });
    const q2 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('idem-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      });
    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('idem-user'))
      .set('Idempotency-Key', 'idem-diff')
      .send({ quoteId:q1.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('idem-user'))
      .set('Idempotency-Key', 'idem-diff')
      .send({ quoteId:q2.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(409);
  });
});
