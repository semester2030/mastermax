/**
 * REV3 acceptance: payment retry webhooks, partial→full refund, idempotency TX.
 */
import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

function sig(body: string): string {
  return createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string)
    .update(body)
    .digest('hex');
}

describe('pre_provider_rev3 — payments / refunds / idempotency', () => {
  let app: INestApplication;
  let db: Pool;
  const dates = { in: '2026-10-01', out: '2026-10-04' };

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await db.end();
  });

  async function seedStay(tag: string): Promise<{
    venueId: string;
    typeId: string;
    uid: string;
  }> {
    const uid = `rev3-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `Rev3-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `Rev3 ${tag}`,
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 5,
          nights: {
            '2026-10-01': '100.00',
            '2026-10-02': '100.00',
            '2026-10-03': '100.00',
          },
        },
      ],
    });
    return { venueId: seeded.venueId, typeId: seeded.types.Std, uid };
  }

  async function quoteHold(tag: string, key: string) {
    const s = await seedStay(tag);
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', key)
      .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    return { ...s, holdId: hold.body.holdId as string, bookingId: hold.body.bookingId as string, gross: quote.body.grossTotal as string };
  }

  async function webhook(paymentId: string, type: 'payment.succeeded' | 'payment.failed', eventId: string) {
    const body = JSON.stringify({
      eventId,
      type,
      pspIntentId: `stub_pi_${paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
  }

  it('late failed webhook after payment retry does not mark new payment failed', async () => {
    const c = await quoteHold('late-fail', 'rev3-hold-lf');
    const intent1 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev3-pay-lf-1')
      .send({ holdId: c.holdId })
      .expect(201);
    const oldPaymentId = intent1.body.paymentId as string;

    await webhook(oldPaymentId, 'payment.failed', `evt-fail-${oldPaymentId}`);

    const bookingAfterFail = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(bookingAfterFail.rows[0].status).toBe('PAYMENT_FAILED');

    const intent2 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev3-pay-lf-2')
      .send({ holdId: c.holdId })
      .expect(201);
    const newPaymentId = intent2.body.paymentId as string;
    expect(newPaymentId).not.toBe(oldPaymentId);

    // Late failed webhook for OLD payment must not disturb new pending payment / booking.
    await webhook(oldPaymentId, 'payment.failed', `evt-fail-late-${oldPaymentId}`);

    const payments = await db.query<{ id: string; status: string }>(
      `SELECT id, status FROM payments WHERE hold_id = $1 ORDER BY created_at`,
      [c.holdId],
    );
    expect(payments.rows).toHaveLength(2);
    expect(payments.rows.find((p) => p.id === oldPaymentId)?.status).toBe('failed');
    expect(payments.rows.find((p) => p.id === newPaymentId)?.status).toBe('pending');

    const booking = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(booking.rows[0].status).toBe('PENDING_PAYMENT');
  });

  it('late succeeded webhook on old failed payment does not confirm after retry', async () => {
    const c = await quoteHold('late-succ', 'rev3-hold-ls');
    const intent1 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev3-pay-ls-1')
      .send({ holdId: c.holdId })
      .expect(201);
    const oldPaymentId = intent1.body.paymentId as string;
    await webhook(oldPaymentId, 'payment.failed', `evt-fail-${oldPaymentId}`);

    const intent2 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev3-pay-ls-2')
      .send({ holdId: c.holdId })
      .expect(201);
    const newPaymentId = intent2.body.paymentId as string;

    // Late success on OLD payment must not confirm booking.
    await webhook(oldPaymentId, 'payment.succeeded', `evt-succ-late-${oldPaymentId}`);

    const booking = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(booking.rows[0].status).toBe('PENDING_PAYMENT');

    const oldPay = await db.query<{ status: string }>(
      `SELECT status FROM payments WHERE id = $1`,
      [oldPaymentId],
    );
    expect(['refund_required', 'refunded_after_expiry']).toContain(oldPay.rows[0].status);

    // Current pending payment can still confirm.
    await webhook(newPaymentId, 'payment.succeeded', `evt-succ-${newPaymentId}`);
    const confirmed = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(confirmed.rows[0].status).toBe('CONFIRMED');

    const snap = await request(app.getHttpServer())
      .get(`/v1/payments/${newPaymentId}`)
      .set('Authorization', auth(c.uid))
      .expect(200);
    expect(snap.body.bookingStatus).toBe('CONFIRMED');
    expect(snap.body.status).toBe('succeeded');
  });

  it('partial refund then remaining full refund to last hala; partial never releases inventory', async () => {
    const c = await quoteHold('partial', 'rev3-hold-pr');
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev3-pay-pr')
      .send({ holdId: c.holdId })
      .expect(201);
    await webhook(intent.body.paymentId, 'payment.succeeded', `evt-${intent.body.paymentId}`);

    const bookedBefore = await db.query<{ booked: string }>(
      `SELECT booked::text FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = '2026-10-01'`,
      [c.typeId],
    );
    expect(Number(bookedBefore.rows[0].booked)).toBe(1);

    const partial = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-rev3', 'placesAdmin'))
      .set('Idempotency-Key', 'rev3-admin-partial')
      .send({
        bookingId: c.bookingId,
        reason: 'goodwill',
        kind: 'partial',
        amount: '100.00',
      })
      .expect(201);
    expect(partial.body.amount).toBe('100.00');

    const bookedAfterPartial = await db.query<{ booked: string }>(
      `SELECT booked::text FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = '2026-10-01'`,
      [c.typeId],
    );
    expect(Number(bookedAfterPartial.rows[0].booked)).toBe(1);

    const bookingStill = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(bookingStill.rows[0].status).toBe('CONFIRMED');

    const remaining = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-rev3', 'placesAdmin'))
      .set('Idempotency-Key', 'rev3-admin-full-remaining')
      .send({
        bookingId: c.bookingId,
        reason: 'ops full remaining',
        kind: 'full',
      })
      .expect(201);
    // gross 300 − partial 100 = 200.00 last-hala remaining
    expect(remaining.body.amount).toBe('200.00');

    const sum = await db.query<{ s: string }>(
      `SELECT COALESCE(SUM(amount),0)::text AS s FROM refunds
       WHERE booking_id = $1 AND status = 'completed'`,
      [c.bookingId],
    );
    expect(sum.rows[0].s).toBe('300.00');
  });

  it('concurrent same user same idempotency key yields one hold', async () => {
    const s = await seedStay('idem-conc');
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    const key = 'rev3-conc-hold-key';
    const results = await Promise.all(
      Array.from({ length: 8 }, () =>
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', auth(s.uid))
          .set('Idempotency-Key', key)
          .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } }),
      ),
    );
    const oks = results.filter((r) => r.status === 201 || r.status === 200);
    expect(oks.length).toBe(8);
    const holdIds = new Set(oks.map((r) => r.body.holdId));
    expect(holdIds.size).toBe(1);

    const holds = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM booking_holds WHERE idempotency_key = $1`,
      [key],
    );
    expect(holds.rows[0].c).toBe(1);
  });

  it('idempotency expired key replay stores new response', async () => {
    const s = await seedStay('idem-exp');
    const quote1 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    const key = 'rev3-expired-key';
    const first = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', key)
      .send({ quoteId:quote1.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const firstHoldId = first.body.holdId as string;

    // Expire the idempotency row (simulate TTL).
    await db.query(
      `UPDATE idempotency_keys
       SET expires_at = now() - interval '1 minute'
       WHERE actor_uid = $1 AND key = $2`,
      [s.uid, key],
    );

    // New quote for a fresh hold (prior quote consumed).
    const quote2 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    const second = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', key)
      .send({ quoteId:quote2.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);

    // Expired HTTP key + new quote → NEW hold (F-REV4-02), not sticky old hold.
    expect(second.body.holdId).not.toBe(firstHoldId);

    const idem = await db.query<{ expires_at: Date; response_body: { holdId: string } }>(
      `SELECT expires_at, response_body FROM idempotency_keys
       WHERE actor_uid = $1 AND key = $2`,
      [s.uid, key],
    );
    expect(new Date(idem.rows[0].expires_at).getTime()).toBeGreaterThan(Date.now());
    expect(idem.rows[0].response_body.holdId).toBe(second.body.holdId);
  });

  it('GET booking omits commission fields', async () => {
    const c = await quoteHold('leak', 'rev3-hold-leak');
    const res = await request(app.getHttpServer())
      .get(`/v1/bookings/${c.bookingId}`)
      .set('Authorization', auth(c.uid))
      .expect(200);
    expect(res.body.commission_bps).toBeUndefined();
    expect(res.body.commission_amount).toBeUndefined();
    expect(res.body.provider_net).toBeUndefined();
    expect(res.body.status).toBeTruthy();
    expect(res.body.gross_total).toBeTruthy();
  });
});
