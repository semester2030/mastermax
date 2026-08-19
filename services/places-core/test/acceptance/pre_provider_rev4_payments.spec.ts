/**
 * PRE-PROVIDER REV4 Batch 1 — booking / payments / availability acceptance.
 */
import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import { Pool } from 'pg';
import request from 'supertest';
import { HoldService } from '../../src/modules/booking/application/hold.service';
import { RefundService } from '../../src/modules/booking/application/refund.service';
import { newId } from '../../src/shared/ids/ids';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

function sig(body: string): string {
  return createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string)
    .update(body)
    .digest('hex');
}

describe('pre_provider_rev4 — payments / holds / availability', () => {
  let app: INestApplication;
  let db: Pool;
  const dates = { in: '2026-11-01', out: '2026-11-04' };

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

  async function seedStay(tag: string, qty = 5): Promise<{
    venueId: string;
    typeId: string;
    uid: string;
  }> {
    const uid = `rev4-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `Rev4-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `Rev4 ${tag}`,
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty,
          nights: {
            '2026-11-01': '100.00',
            '2026-11-02': '100.00',
            '2026-11-03': '100.00',
          },
        },
      ],
    });
    return { venueId: seeded.venueId, typeId: seeded.types.Std, uid };
  }

  async function quoteHold(tag: string, key: string, uidOverride?: string) {
    const s = await seedStay(tag);
    const uid = uidOverride ?? s.uid;
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
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
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', key)
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);
    return {
      ...s,
      uid,
      holdId: hold.body.holdId as string,
      bookingId: hold.body.bookingId as string,
      gross: quote.body.grossTotal as string,
    };
  }

  async function webhook(
    paymentId: string,
    type: 'payment.succeeded' | 'payment.failed',
    eventId: string,
  ) {
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

  it('F-REV4-01: same Idempotency-Key across consumers creates independent holds', async () => {
    const sharedKey = 'rev4-cross-consumer-key';
    const a = await seedStay('cross-a');
    const b = await seedStay('cross-b');
    const quoteA = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(a.uid))
      .send({
        venueId: a.venueId,
        inventoryTypeId: a.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const quoteB = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(b.uid))
      .send({
        venueId: b.venueId,
        inventoryTypeId: b.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const holdA = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(a.uid))
      .set('Idempotency-Key', sharedKey)
      .send({ quoteId: quoteA.body.quoteId, quantity: 1 })
      .expect(201);
    const holdB = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(b.uid))
      .set('Idempotency-Key', sharedKey)
      .send({ quoteId: quoteB.body.quoteId, quantity: 1 })
      .expect(201);
    expect(holdA.body.holdId).not.toBe(holdB.body.holdId);
    const rows = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM booking_holds WHERE idempotency_key = $1`,
      [sharedKey],
    );
    expect(rows.rows[0].c).toBe(2);
  });

  it('F-REV4-01/02: concurrent same-user same key barriers to one hold', async () => {
    const s = await seedStay('conc');
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
    const key = 'rev4-conc-barrier';
    const results = await Promise.all(
      Array.from({ length: 8 }, () =>
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', auth(s.uid))
          .set('Idempotency-Key', key)
          .send({ quoteId: quote.body.quoteId, quantity: 1 }),
      ),
    );
    const oks = results.filter((r) => r.status === 201 || r.status === 200);
    expect(oks.length).toBe(8);
    expect(new Set(oks.map((r) => r.body.holdId)).size).toBe(1);
  });

  it('F-REV4-03: 8 concurrent identical intent POSTs → exactly one payment row', async () => {
    const c = await quoteHold('intent-idem', 'rev4-hold-intent-idem');
    const key = 'rev4-intent-conc';
    const results = await Promise.all(
      Array.from({ length: 8 }, () =>
        request(app.getHttpServer())
          .post('/v1/payments/intents')
          .set('Authorization', auth(c.uid))
          .set('Idempotency-Key', key)
          .send({ holdId: c.holdId }),
      ),
    );
    const oks = results.filter((r) => r.status === 201 || r.status === 200);
    expect(oks.length).toBe(8);
    expect(new Set(oks.map((r) => r.body.paymentId)).size).toBe(1);
    const count = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payments WHERE hold_id = $1`,
      [c.holdId],
    );
    expect(count.rows[0].c).toBe(1);
  });

  it('F-REV4-04: admin refund requires Idempotency-Key; retry is sticky', async () => {
    const c = await quoteHold('admin-idem', 'rev4-hold-admin');
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev4-pay-admin')
      .send({ holdId: c.holdId })
      .expect(201);
    await webhook(intent.body.paymentId, 'payment.succeeded', `evt-${intent.body.paymentId}`);

    await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-rev4', 'placesAdmin'))
      .send({
        bookingId: c.bookingId,
        reason: 'missing key',
        kind: 'partial',
        amount: '50.00',
      })
      .expect(400);

    const key = 'rev4-admin-partial-sticky';
    const first = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-rev4', 'placesAdmin'))
      .set('Idempotency-Key', key)
      .send({
        bookingId: c.bookingId,
        reason: 'goodwill',
        kind: 'partial',
        amount: '33.33',
      })
      .expect(201);
    const retry = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-rev4', 'placesAdmin'))
      .set('Idempotency-Key', key)
      .send({
        bookingId: c.bookingId,
        reason: 'goodwill',
        kind: 'partial',
        amount: '33.33',
      })
      .expect(201);
    expect(retry.body.refundId).toBe(first.body.refundId);
    const count = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM refunds WHERE booking_id = $1 AND kind = 'partial'`,
      [c.bookingId],
    );
    expect(count.rows[0].c).toBe(1);
  });

  it('F-REV4-05: reclaim after PSP success before finalize does not double PSP/ledger', async () => {
    const c = await quoteHold('reclaim', 'rev4-hold-reclaim');
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev4-pay-reclaim')
      .send({ holdId: c.holdId })
      .expect(201);
    await webhook(intent.body.paymentId, 'payment.succeeded', `evt-${intent.body.paymentId}`);

    const refunds = app.get(RefundService);
    const requested = await refunds.requestRefund({
      bookingId: c.bookingId,
      actorUid: 'admin-reclaim',
      actorRole: 'placesAdmin',
      kind: 'partial',
      amount: '40.00',
      reason: 'reclaim test',
      correlationId: 'rev4-reclaim',
      idempotencyKey: 'rev4-reclaim-key',
    });
    const claimed = await refunds.claimOne(requested.refundId);
    expect(claimed).not.toBeNull();
    // Simulate PSP success persisted, finalize not yet run.
    await db.query(
      `UPDATE refunds SET psp_refund_id = $2, status = 'processing', locked_at = now() - interval '2 minutes'
       WHERE id = $1`,
      [claimed!.id, `stub_re_${claimed!.id}`],
    );
    await refunds.reapStale(1);
    await refunds.dispatchRefund(claimed!.id, 'rev4-reclaim-retry');
    const ledger = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE idempotency_key = $1`,
      [`ledger:${claimed!.id}:refund`],
    );
    expect(ledger.rows[0].c).toBe(1);
    const status = await db.query<{ status: string; psp_refund_id: string }>(
      `SELECT status, psp_refund_id FROM refunds WHERE id = $1`,
      [claimed!.id],
    );
    expect(status.rows[0].status).toBe('completed');
    expect(status.rows[0].psp_refund_id).toBe(`stub_re_${claimed!.id}`);
  });

  it('F-REV4-06: partial 33.33 then full remaining — ledger legs sum to refund (no leftover hala)', async () => {
    const uid = 'rev4-hala-user';
    const providerId = await seedProvider(db, 'owner-hala', 'Rev4-hala');
    const seeded = await seedVenue(db, providerId, {
      name: 'Rev4 Hala',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights: { '2026-11-10': '100.00' } }],
    });
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2026-11-10',
        checkOut: '2026-11-11',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    expect(quote.body.grossTotal).toBe('100.00');
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', 'rev4-hold-hala')
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', 'rev4-pay-hala')
      .send({ holdId: hold.body.holdId })
      .expect(201);
    await webhook(intent.body.paymentId, 'payment.succeeded', `evt-${intent.body.paymentId}`);

    const partial = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-hala', 'placesAdmin'))
      .set('Idempotency-Key', 'rev4-hala-partial')
      .send({
        bookingId: hold.body.bookingId,
        reason: 'partial',
        kind: 'partial',
        amount: '33.33',
      })
      .expect(201);
    expect(partial.body.amount).toBe('33.33');

    const full = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('admin-hala', 'placesAdmin'))
      .set('Idempotency-Key', 'rev4-hala-full')
      .send({
        bookingId: hold.body.bookingId,
        reason: 'remaining',
        kind: 'full',
      })
      .expect(201);
    expect(full.body.amount).toBe('66.67');

    const sum = await db.query<{ s: string }>(
      `SELECT COALESCE(SUM(amount),0)::text AS s FROM refunds
       WHERE booking_id = $1 AND status = 'completed'`,
      [hold.body.bookingId],
    );
    expect(sum.rows[0].s).toBe('100.00');

    for (const rid of [partial.body.refundId, full.body.refundId] as string[]) {
      const byKey = await db.query<{ k: string; amount: string; direction: string }>(
        `SELECT idempotency_key AS k, amount::text, direction FROM ledger_entries
         WHERE idempotency_key IN ($1,$2,$3)`,
        [`ledger:${rid}:refund`, `ledger:${rid}:comm_rev`, `ledger:${rid}:recv_rev`],
      );
      const map = Object.fromEntries(byKey.rows.map((r) => [r.k, r]));
      const refundAmt = Number(map[`ledger:${rid}:refund`].amount);
      const commAmt = Number(map[`ledger:${rid}:comm_rev`].amount);
      const recvAmt = Number(map[`ledger:${rid}:recv_rev`].amount);
      expect(map[`ledger:${rid}:refund`].direction).toBe('debit');
      expect(Math.round((commAmt + recvAmt) * 100)).toBe(Math.round(refundAmt * 100));
    }
  });

  it('F-REV4-07: retry then late webhook — old attempt never confirms; null current_attempt fail-closed', async () => {
    const c = await quoteHold('retry-late', 'rev4-hold-rl');
    const intent1 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev4-pay-rl-1')
      .send({ holdId: c.holdId })
      .expect(201);
    const oldId = intent1.body.paymentId as string;
    await webhook(oldId, 'payment.failed', `evt-fail-${oldId}`);

    const intent2 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev4-pay-rl-2')
      .send({ holdId: c.holdId })
      .expect(201);
    const newId = intent2.body.paymentId as string;
    expect(newId).not.toBe(oldId);

    // Late success on old failed payment must not confirm.
    await webhook(oldId, 'payment.succeeded', `evt-late-${oldId}`);
    const booking = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(booking.rows[0].status).toBe('PENDING_PAYMENT');

    // Null current_attempt_id on pending with mismatched intent → fail-closed.
    await db.query(`UPDATE payments SET current_attempt_id = NULL WHERE id = $1`, [newId]);
    await webhook(oldId, 'payment.succeeded', `evt-null-attempt-${oldId}`);
    const still = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(still.rows[0].status).toBe('PENDING_PAYMENT');

    // New payment with null attempt but matching psp_intent can still confirm (pendingMatch).
    await webhook(newId, 'payment.succeeded', `evt-ok-${newId}`);
    const confirmed = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [c.bookingId],
    );
    expect(confirmed.rows[0].status).toBe('CONFIRMED');
  });

  it('F-REV4-07b: late webhook then retry — old never confirms; new attempt created', async () => {
    const c = await quoteHold('late-then-retry', 'rev4-hold-ltr');
    const intent1 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev4-pay-ltr-1')
      .send({ holdId: c.holdId })
      .expect(201);
    const oldId = intent1.body.paymentId as string;
    await webhook(oldId, 'payment.failed', `evt-f-${oldId}`);

    // Clear attempt identity (fail-closed path) then late success before retry creates new.
    await db.query(
      `UPDATE payments SET current_attempt_id = NULL, status = 'failed' WHERE id = $1`,
      [oldId],
    );
    await webhook(oldId, 'payment.succeeded', `evt-late2-${oldId}`);
    expect(
      (await db.query(`SELECT status FROM bookings WHERE id = $1`, [c.bookingId])).rows[0]
        .status,
    ).not.toBe('CONFIRMED');

    const intent2 = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(c.uid))
      .set('Idempotency-Key', 'rev4-pay-ltr-2')
      .send({ holdId: c.holdId })
      .expect(201);
    expect(intent2.body.paymentId).not.toBe(oldId);
    await webhook(intent2.body.paymentId, 'payment.succeeded', `evt-n-${intent2.body.paymentId}`);
    expect(
      (await db.query(`SELECT status FROM bookings WHERE id = $1`, [c.bookingId])).rows[0]
        .status,
    ).toBe('CONFIRMED');
  });

  it('F-REV4-08: type-level block + hold release keeps available=0', async () => {
    const s = await seedStay('block', 2);
    const day = '2026-11-01';
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
      .set('Idempotency-Key', 'rev4-block-hold')
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);

    await db.query(
      `INSERT INTO availability_overrides (id, inventory_type_id, inventory_unit_id, date, kind, reason)
       VALUES ($1,$2,NULL,$3::date,'block','rev4 type block')`,
      [newId(), s.typeId, day],
    );
    // Recompute blocked as putAvailability would (held=1 → blocked=capacity-held-booked).
    const cap = await db.query<{ capacity: number; held: number; booked: number }>(
      `SELECT capacity, held, booked FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [s.typeId, day],
    );
    const row = cap.rows[0];
    const blocked = Number(row.capacity) - Number(row.held) - Number(row.booked);
    await db.query(
      `UPDATE inventory_daily_capacity SET blocked = $3
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [s.typeId, day, blocked],
    );
    const before = await db.query<{ available: number; blocked: number; held: number }>(
      `SELECT available, blocked, held FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [s.typeId, day],
    );
    expect(before.rows[0].available).toBe(0);
    expect(before.rows[0].held).toBeGreaterThan(0);

    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '2 seconds' WHERE id = $1`,
      [hold.body.holdId],
    );
    await app.get(HoldService).expireOne(hold.body.holdId);

    const after = await db.query<{ available: number; blocked: number; held: number }>(
      `SELECT available, blocked, held FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [s.typeId, day],
    );
    expect(after.rows[0].held).toBe(0);
    expect(after.rows[0].available).toBe(0);
    expect(after.rows[0].blocked).toBe(Number(row.capacity));

    const avail = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      })
      .expect(201);
    expect(avail.body.available).toBe(false);
  });

  it('F-REV4-09: event_slot quote+hold returns slotCode; stay is single day', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'true';
    const uid = 'rev4-slot-user';
    const providerId = await seedProvider(db, 'owner-slot', 'Rev4-slot');
    const seeded = await seedVenue(db, providerId, {
      name: 'Rev4 Slot Hall',
      venueType: 'hotel',
      mode: 'event_slot',
      types: [{ name: 'Hall', qty: 3, nights: { '2026-12-01': '500.00' } }],
    });
    const tpl = newId();
    await db.query(
      `INSERT INTO event_slot_templates
         (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id)
       VALUES ($1,$2,'evening','مسائية','18:00','23:00',100,500.00,$3)`,
      [tpl, seeded.venueId, seeded.types.Hall],
    );
    await db.query(
      `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
       VALUES ($1,$2,$3,'2026-12-01'::date,'open')`,
      [newId(), seeded.venueId, tpl],
    );

    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Hall,
        checkIn: '2026-12-01',
        checkOut: '2026-12-01',
        quantity: 1,
        guestsAdults: 1,
        slotCode: 'evening',
      })
      .expect(201);
    expect(quote.body.slotCode).toBe('evening');
    expect(quote.body.bookingMode).toBe('event_slot');
    expect(quote.body.grossTotal).toBe('500.00');

    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', 'rev4-slot-hold')
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);
    expect(hold.body.slotCode).toBe('evening');

    const details = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}`)
      .set('Authorization', auth(uid))
      .expect(200);
    expect(details.body.bookingMode).toBe('event_slot');
    expect(details.body.bookingStatus).toBeTruthy();
    expect(typeof details.body.enabledForBooking).toBe('boolean');
  });

  it('F-REV4-10: catalog/discovery expose bookingStatus + enabledForBooking (fail-closed missing → false)', async () => {
    const s = await seedStay('cta');
    const details = await request(app.getHttpServer())
      .get(`/v1/venues/${s.venueId}`)
      .set('Authorization', auth(s.uid))
      .expect(200);
    expect(details.body.bookingMode).toBe('nightly');
    expect(details.body.bookingStatus).toBe('BOOKING_READY');
    expect(details.body.enabledForBooking).toBe(true);

    await db.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking = FALSE WHERE venue_type = 'hotel'`,
    );
    const disabled = await request(app.getHttpServer())
      .get(`/v1/venues/${s.venueId}`)
      .set('Authorization', auth(s.uid))
      .expect(200);
    expect(disabled.body.bookingStatus).toBe('BOOKING_NOT_READY');
    expect(disabled.body.enabledForBooking).toBe(false);
    // Restore for other suites sharing DB within this file only — this is last CTA assert.
    await db.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking = TRUE WHERE venue_type = 'hotel'`,
    );
  });
});
