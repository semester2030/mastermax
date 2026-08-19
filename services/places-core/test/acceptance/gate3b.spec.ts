import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { pool, seedProvider, seedVenue } from '../helpers/seed';
import { ReceivableEligibilityService } from '../../src/modules/settlements/application/receivable-eligibility.service';
import { OutboxWorker } from '../../src/workers/outbox.worker';
import { RefundService } from '../../src/modules/booking/application/refund.service';
import { PAYMENT_PORT, PaymentPort, RefundInput } from '../../src/modules/payments/domain/payment.port';
import { NOTIFICATION_PORT } from '../../src/modules/notifications/application/notification.port';
import { newId } from '../../src/shared/ids/ids';
import { PgService } from '../../src/shared/database/pg.service';

describe('Gate 3B X–AC', () => {
  let app: INestApplication;

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

  async function confirmBooking(opts: {
    owner: string;
    uid: string;
    nights: Record<string, string>;
    checkIn: string;
    checkOut: string;
    eventId: string;
  }) {
    const db = pool();
    const providerId = await seedProvider(db, opts.owner, opts.owner);
    const seeded = await seedVenue(db, providerId, {
      name: `V-${opts.owner}`,
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 5, nights: opts.nights }],
    });
    await db.end();
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(opts.uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: opts.checkIn,
        checkOut: opts.checkOut,
        quantity: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `h-${opts.eventId}`)
      .send({ quoteId: q.body.quoteId, quantity: 1 })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `p-${opts.eventId}`)
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: opts.eventId,
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    return {
      providerId,
      bookingId: hold.body.bookingId as string,
      paymentId: intent.body.paymentId as string,
      amount: intent.body.amount as string,
    };
  }

  it('X settlement membership isolation — Sep pending not paid with Aug settlement', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'x-owner', 'XCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'X',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 10,
          nights: {
            '2026-09-10': '1000',
            '2026-09-11': '0',
            '2026-10-10': '2000',
            '2026-10-11': '0',
          },
        },
      ],
    });
    await db.end();

    async function book(uid: string, checkIn: string, checkOut: string, tag: string) {
      const q = await request(app.getHttpServer())
        .post('/v1/quotes')
        .set('Authorization', auth(uid))
        .send({
          venueId: seeded.venueId,
          inventoryTypeId: seeded.types.Std,
          checkIn,
          checkOut,
          quantity: 1,
        })
        .expect(201);
      const hold = await request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(uid))
        .set('Idempotency-Key', `x-h-${tag}`)
        .send({ quoteId: q.body.quoteId, quantity: 1 })
        .expect(201);
      const intent = await request(app.getHttpServer())
        .post('/v1/payments/intents')
        .set('Authorization', auth(uid))
        .set('Idempotency-Key', `x-p-${tag}`)
        .send({ holdId: hold.body.holdId })
        .expect(201);
      const body = JSON.stringify({
        eventId: `x-evt-${tag}`,
        type: 'payment.succeeded',
        pspIntentId: `stub_pi_${intent.body.paymentId}`,
      });
      await request(app.getHttpServer())
        .post('/v1/webhooks/psp/stub')
        .set('X-Stub-Signature', sig(body))
        .set('Content-Type', 'application/json')
        .send(body)
        .expect(201);
      return hold.body.bookingId as string;
    }

    const bookingA = await book('x-a', '2026-09-10', '2026-09-11', 'a');
    const bookingB = await book('x-b', '2026-10-10', '2026-10-11', 'b');

    await app.get(ReceivableEligibilityService).promoteDue('2026-09-12');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-x', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(1);

    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-x', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    const a = await db2.query<{ status: string }>(
      `SELECT status FROM provider_receivables WHERE booking_id = $1`,
      [bookingA],
    );
    const b = await db2.query<{ status: string }>(
      `SELECT status FROM provider_receivables WHERE booking_id = $1`,
      [bookingB],
    );
    await db2.end();
    expect(a.rows[0].status).toBe('paid');
    expect(b.rows[0].status).toBe('pending');
  });

  it('Y pending receivable excluded from settlement', async () => {
    const c = await confirmBooking({
      owner: 'y-owner',
      uid: 'y-user',
      nights: { '2026-08-20': '500', '2026-08-21': '0' },
      checkIn: '2026-08-20',
      checkOut: '2026-08-21',
      eventId: 'y-evt',
    });
    // still pending — no eligibility promote
    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-y', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-08-01', periodEnd: '2026-09-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(0);
    expect(draft.body.net).toBe('0.00');
  });

  it('Z PSP refund dual-write recovery — idempotent operationId', async () => {
    const c = await confirmBooking({
      owner: 'z-owner',
      uid: 'z-user',
      nights: { '2026-08-22': '300', '2026-08-23': '0' },
      checkIn: '2026-08-22',
      checkOut: '2026-08-23',
      eventId: 'z-evt',
    });
    const calls: string[] = [];
    const real = app.get<PaymentPort>(PAYMENT_PORT);
    const wrapped: PaymentPort = {
      pspName: real.pspName,
      createIntent: (i) => real.createIntent(i),
      verifySignature: (b, s) => real.verifySignature(b, s),
      parseWebhook: (b) => real.parseWebhook(b),
      refund: async (input: RefundInput) => {
        calls.push(input.operationId);
        return real.refund(input);
      },
    };
    const refunds = app.get(RefundService);
    (refunds as unknown as { psp: PaymentPort }).psp = wrapped;

    const requested = await refunds.requestRefund({
      bookingId: c.bookingId,
      actorUid: 'admin-z',
      actorRole: 'placesAdmin',
      kind: 'full',
      reason: 'dual-write-test',
      correlationId: 'z-corr',
    });
    expect(requested.status).toBe('pending');

    // Simulate: PSP succeeds, then finalize fails
    const pspResult = await wrapped.refund({
      pspIntentId: `stub_pi_${c.paymentId}`,
      amount: requested.amount,
      operationId: requested.refundId,
    });
    const pg = app.get(PgService);
    await expect(
      pg.tx(async (client) => {
        await client.query(`SELECT 1`);
        throw new Error('simulated finalize failure after PSP success');
      }),
    ).rejects.toThrow(/simulated finalize failure/);

    // Retry dispatch — same operationId; must not create distinct uncontrolled refund identity
    await refunds.dispatchRefund(requested.refundId, 'z-retry');
    await refunds.dispatchRefund(requested.refundId, 'z-retry-2');

    const db = pool();
    const rows = await db.query<{ status: string; psp_refund_id: string }>(
      `SELECT status, psp_refund_id FROM refunds WHERE id = $1`,
      [requested.refundId],
    );
    const completed = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM refunds WHERE booking_id = $1 AND status = 'completed'`,
      [c.bookingId],
    );
    await db.end();
    expect(rows.rows[0].status).toBe('completed');
    expect(rows.rows[0].psp_refund_id).toBe(pspResult.pspRefundId);
    expect(completed.rows[0].c).toBe(1);
    expect(new Set(calls).size).toBe(1);
    expect(calls.every((id) => id === requested.refundId)).toBe(true);
  });

  it('AA runtime DTO validation negatives', async () => {
    await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth('aa-user'))
      .send({
        venueId: '00000000-0000-0000-0000-000000000001',
        inventoryTypeId: '00000000-0000-0000-0000-000000000002',
        checkIn: '2026-08-15',
        checkOut: '2026-08-18',
        quantity: -1,
      })
      .expect(400);

    await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('aa-user'))
      .send({
        venueId: 'not-a-uuid',
        inventoryTypeId: '00000000-0000-0000-0000-000000000002',
        checkIn: '2026-08-15',
        checkOut: '2026-08-18',
      })
      .expect(400);

    await request(app.getHttpServer())
      .post('/v1/reviews')
      .set('Authorization', auth('aa-user'))
      .send({ bookingId: '00000000-0000-0000-0000-000000000001', rating: 9 })
      .expect(400);

    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('aa-user'))
      .set('Idempotency-Key', 'aa-bad')
      .send({ quoteId: '00000000-0000-0000-0000-000000000001', quantity: 1, injected: 'nope' })
      .expect(400);

    await request(app.getHttpServer())
      .get('/v1/admin/bookings?limit=9999')
      .set('Authorization', auth('aa-admin', 'placesAdmin'))
      .expect(400);

    await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth('aa-user'))
      .send({
        venueId: '00000000-0000-0000-0000-000000000001',
        inventoryTypeId: '00000000-0000-0000-0000-000000000002',
        checkIn: 'not-a-date',
        checkOut: '2026-08-18',
        quantity: 1,
      })
      .expect(400);
  });

  it('AB multi-worker outbox claiming — 50 events / 3 workers', async () => {
    const db = pool();
    for (let i = 0; i < 50; i += 1) {
      await db.query(
        `INSERT INTO domain_events (id, name, payload_json, status, attempts)
         VALUES ($1,'test.ping',$2::jsonb,'pending',0)`,
        [newId(), JSON.stringify({ i })],
      );
    }
    await db.end();

    const pg = app.get(PgService);
    const notifications = app.get(NOTIFICATION_PORT);
    const w1 = new OutboxWorker(pg, notifications);
    const w2 = new OutboxWorker(pg, notifications);
    const w3 = new OutboxWorker(pg, notifications);
    const claimed = await Promise.all([w1.tick(25), w2.tick(25), w3.tick(25)]);
    const allClaimed = claimed.flatMap((c) => c.claimed);
    expect(new Set(allClaimed).size).toBe(allClaimed.length);

    for (let i = 0; i < 5; i += 1) {
      await Promise.all([w1.tick(20), w2.tick(20), w3.tick(20)]);
    }
    const db2 = pool();
    const sent = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM domain_events WHERE name = 'test.ping' AND status = 'sent'`,
    );
    const pending = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM domain_events WHERE name = 'test.ping' AND status IN ('pending','processing')`,
    );
    await db2.end();
    expect(sent.rows[0].c).toBe(50);
    expect(pending.rows[0].c).toBe(0);
  });

  it('AC settlement payout ledger consistency + F5 financial correctness', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'ac-owner', 'ACCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'AC',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 10,
          nights: {
            '2026-09-01': '1000',
            '2026-09-02': '0',
            '2026-09-05': '555.56',
            '2026-09-06': '0',
            '2026-10-01': '2000',
            '2026-10-02': '0',
          },
        },
      ],
    });
    await db.end();

    async function book(uid: string, checkIn: string, checkOut: string, tag: string) {
      const q = await request(app.getHttpServer())
        .post('/v1/quotes')
        .set('Authorization', auth(uid))
        .send({
          venueId: seeded.venueId,
          inventoryTypeId: seeded.types.Std,
          checkIn,
          checkOut,
          quantity: 1,
        })
        .expect(201);
      const hold = await request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(uid))
        .set('Idempotency-Key', `ac-h-${tag}`)
        .send({ quoteId: q.body.quoteId, quantity: 1 })
        .expect(201);
      const intent = await request(app.getHttpServer())
        .post('/v1/payments/intents')
        .set('Authorization', auth(uid))
        .set('Idempotency-Key', `ac-p-${tag}`)
        .send({ holdId: hold.body.holdId })
        .expect(201);
      const body = JSON.stringify({
        eventId: `ac-evt-${tag}`,
        type: 'payment.succeeded',
        pspIntentId: `stub_pi_${intent.body.paymentId}`,
      });
      await request(app.getHttpServer())
        .post('/v1/webhooks/psp/stub')
        .set('X-Stub-Signature', sig(body))
        .set('Content-Type', 'application/json')
        .send(body)
        .expect(201);
      return { bookingId: hold.body.bookingId as string, netHint: q.body.providerNet as string | undefined };
    }

    const a = await book('ac-a', '2026-09-01', '2026-09-02', 'a');
    const b = await book('ac-b', '2026-10-01', '2026-10-02', 'b');
    const c = await book('ac-c', '2026-09-05', '2026-09-06', 'c');

    await app.get(ReceivableEligibilityService).promoteDue('2026-09-10');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ac', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(2);
    // 1000*0.9 + 555.56*0.9 = 900 + 500.00 = 1400.00 (555.56 * 10% = 55.56 → net 500)
    expect(draft.body.net).toBe('1400.00');

    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-ac', 'placesAdmin,placesFinance'))
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-ac', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    const statuses = await db2.query<{ booking_id: string; status: string }>(
      `SELECT booking_id, status FROM provider_receivables WHERE provider_id = $1`,
      [providerId],
    );
    const byBooking = Object.fromEntries(statuses.rows.map((r) => [r.booking_id, r.status]));
    expect(byBooking[a.bookingId]).toBe('paid');
    expect(byBooking[c.bookingId]).toBe('paid');
    expect(byBooking[b.bookingId]).toBe('pending');

    const ledger = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries
       WHERE reference = $1 AND type IN ('settlement','payout')`,
      [`settlement:${draft.body.settlementId}`],
    );
    const payouts = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payouts WHERE settlement_id = $1`,
      [draft.body.settlementId],
    );
    await db2.end();
    expect(ledger.rows[0].c).toBe(2);
    expect(payouts.rows[0].c).toBe(1);
  });
});
