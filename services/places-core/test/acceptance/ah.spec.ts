import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { pool, seedProvider, seedVenue } from '../helpers/seed';
import { HoldService } from '../../src/modules/booking/application/hold.service';
import { RefundService } from '../../src/modules/booking/application/refund.service';

describe('Acceptance A–H', () => {
  let app: INestApplication;
  const consumer = (n = 'c1') => auth(n);
  // Stay ≥48h ahead so customer_cancel is full refund (receivable → adjusted).
  const dates = { in: '2026-09-01', out: '2026-09-04' };

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  async function pay(holdId: string, uid: string, key: string) {
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', key)
      .send({ holdId })
      .expect(201);
    const paymentId = intent.body.paymentId as string;
    const body = JSON.stringify({
      eventId: `evt-${paymentId}`,
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${paymentId}`,
    });
    const sig = createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string).update(body).digest('hex');
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig)
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    return { paymentId, intent: intent.body };
  }

  it('A hotel 100 rooms / 3 types / 3 nights different prices', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-a', 'HotelCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'Hotel A',
      venueType: 'hotel',
      types: [
        { name: 'Standard', qty: 50, nights: { '2026-09-01': '100', '2026-09-02': '110', '2026-09-03': '120' } },
        { name: 'Deluxe', qty: 30, nights: { '2026-09-01': '200', '2026-09-02': '220', '2026-09-03': '240' } },
        { name: 'Suite', qty: 20, nights: { '2026-09-01': '400', '2026-09-02': '420', '2026-09-03': '440' } },
      ],
    });
    await db.end();
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', consumer('alice'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Deluxe,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
        guestsAdults: 2,
      })
      .expect(201);
    const nights = (quote.body.items as { kind: string; amount: string }[]).filter((i) => i.kind === 'night');
    expect(nights).toHaveLength(3);
    expect(nights.map((n) => n.amount)).toEqual(['200.00', '220.00', '240.00']);
    expect(quote.body.grossTotal).toBe('660.00');
    const av = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', consumer('alice'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Deluxe,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      })
      .expect(201);
    expect(av.body.remaining).toBe(30);
    (global as { hotelSeed?: typeof seeded }).hotelSeed = seeded;
  });

  it('B serviced apartment 20 with one blocked and one maintenance = 18', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-b', 'AptCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'Serviced',
      venueType: 'serviced_apartment',
      types: [{ name: 'Studio', qty: 20, nights: { '2026-09-01': '150', '2026-09-02': '150', '2026-09-03': '150' } }],
    });
    // Unit-level status: each blocked/maintenance unit counts +1 (not type-level full close).
    await db.query(
      `INSERT INTO inventory_units (id, inventory_type_id, label, status) VALUES
       (gen_random_uuid(), $1, 'A1', 'blocked'),
       (gen_random_uuid(), $1, 'A2', 'maintenance')`,
      [seeded.types.Studio],
    );
    await db.end();
    const av = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', consumer('bob'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Studio,
        checkIn: '2026-09-01',
        checkOut: '2026-09-02',
        quantity: 1,
      })
      .expect(201);
    expect(av.body.remaining).toBe(18);
    expect(av.body.available).toBe(true);
  });

  it('C single chalet second booking same date is 409', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-c', 'ChaletCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'Chalet 1',
      venueType: 'chalet',
      types: [{ name: 'Whole', qty: 1, nights: { '2026-09-01': '900', '2026-09-02': '900', '2026-09-03': '900' } }],
    });
    await db.end();
    const q1 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', consumer('c-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Whole,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', consumer('c-user'))
      .set('Idempotency-Key', 'c-hold-1')
      .send({ quoteId: q1.body.quoteId, quantity: 1 })
      .expect(201);
    const q2 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', consumer('c-user-2'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Whole,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      })
      .expect(201);
    const r2 = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', consumer('c-user-2'))
      .set('Idempotency-Key', 'c-hold-2')
      .send({ quoteId: q2.body.quoteId, quantity: 1 });
    expect(r2.status).toBe(409);
    expect(r2.body.code).toBe('AVAILABILITY_CHANGED');
  });

  it('D resort concurrent holds do not oversell a type', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-d', 'ResortCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'Resort',
      venueType: 'resort',
      types: [
        { name: 'T1', qty: 8, nights: { '2026-09-01': '300', '2026-09-02': '300', '2026-09-03': '300' } },
        { name: 'T2', qty: 8, nights: { '2026-09-01': '320', '2026-09-02': '320', '2026-09-03': '320' } },
        { name: 'T3', qty: 4, nights: { '2026-09-01': '500', '2026-09-02': '500', '2026-09-03': '500' } },
      ],
    });
    await db.end();
    const quotes = [];
    for (let i = 0; i < 6; i += 1) {
      const q = await request(app.getHttpServer())
        .post('/v1/quotes')
        .set('Authorization', consumer(`d-${i}`))
        .send({
          venueId: seeded.venueId,
          inventoryTypeId: seeded.types.T3,
          checkIn: dates.in,
          checkOut: dates.out,
          quantity: 1,
        });
      quotes.push({ uid: `d-${i}`, quoteId: q.body.quoteId });
    }
    const results = await Promise.all(
      quotes.map((q, i) =>
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', consumer(q.uid))
          .set('Idempotency-Key', `d-hold-${i}`)
          .send({ quoteId: q.quoteId, quantity: 1 }),
      ),
    );
    const ok = results.filter((r) => r.status === 201);
    const fail = results.filter((r) => r.status === 409);
    expect(ok).toHaveLength(4);
    expect(fail).toHaveLength(2);
  });

  it('E last room 100 concurrent qty=1 capacity=1 → one hold', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-e', 'RaceCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'LastRoom',
      venueType: 'hotel',
      types: [{ name: 'Deluxe', qty: 1, nights: { '2026-09-01': '100', '2026-09-02': '100', '2026-09-03': '100' } }],
    });
    await db.end();
    const quotes = [];
    for (let i = 0; i < 100; i += 1) {
      const q = await request(app.getHttpServer())
        .post('/v1/quotes')
        .set('Authorization', consumer(`e-${i}`))
        .send({
          venueId: seeded.venueId,
          inventoryTypeId: seeded.types.Deluxe,
          checkIn: dates.in,
          checkOut: dates.out,
          quantity: 1,
        });
      quotes.push({ uid: `e-${i}`, quoteId: q.body.quoteId });
    }
    const results = await Promise.all(
      quotes.map((q, i) =>
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', consumer(q.uid))
          .set('Idempotency-Key', `e-hold-${i}`)
          .send({ quoteId: q.quoteId, quantity: 1 }),
      ),
    );
    expect(results.filter((r) => r.status === 201)).toHaveLength(1);
    expect(results.filter((r) => r.status === 409)).toHaveLength(99);
    const db2 = pool();
    const cap = await db2.query<{ held: string; available: number }>(
      `SELECT held::text, available FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = '2026-09-01'`,
      [seeded.types.Deluxe],
    );
    await db2.end();
    expect(Number(cap.rows[0].held)).toBe(1);
    expect(cap.rows[0].available).toBe(0);
  });

  it('F payment retry same idempotency key → one payment', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-f', 'PayCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'PayHotel',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 5, nights: { '2026-09-01': '100', '2026-09-02': '100', '2026-09-03': '100' } }],
    });
    await db.end();
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', consumer('f-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      });
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', consumer('f-user'))
      .set('Idempotency-Key', 'f-hold')
      .send({ quoteId: q.body.quoteId, quantity: 1 })
      .expect(201);
    const a = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', consumer('f-user'))
      .set('Idempotency-Key', 'f-pay')
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const b = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', consumer('f-user'))
      .set('Idempotency-Key', 'f-pay')
      .send({ holdId: hold.body.holdId });
    expect([200, 201]).toContain(b.status);
    expect(a.body.paymentId).toBe(b.body.paymentId);
    await pay(hold.body.holdId, 'f-user', 'f-pay-2');
    const db2 = pool();
    const pays = await db2.query(`SELECT count(*)::int AS c FROM payments WHERE hold_id = $1`, [hold.body.holdId]);
    const books = await db2.query(`SELECT count(*)::int AS c FROM bookings WHERE hold_id = $1 AND status = 'CONFIRMED'`, [
      hold.body.holdId,
    ]);
    await db2.end();
    expect(pays.rows[0].c).toBe(1);
    expect(books.rows[0].c).toBe(1);
    (global as { refundBookingHold?: string }).refundBookingHold = hold.body.holdId;
  });

  it('G duplicate webhook one ledger group', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-g', 'WhCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'WhHotel',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights: { '2026-09-01': '1000', '2026-09-02': '0', '2026-09-03': '0' } }],
    });
    await db.end();
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', consumer('g-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2026-09-01',
        checkOut: '2026-09-02',
        quantity: 1,
      });
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', consumer('g-user'))
      .set('Idempotency-Key', 'g-hold')
      .send({ quoteId: q.body.quoteId, quantity: 1 })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', consumer('g-user'))
      .set('Idempotency-Key', 'g-pay')
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: 'evt-dup-g',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    const sig = createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string).update(body).digest('hex');
    await request(app.getHttpServer()).post('/v1/webhooks/psp/stub').set('X-Stub-Signature', sig).set('Content-Type', 'application/json').send(body).expect(201);
    await request(app.getHttpServer()).post('/v1/webhooks/psp/stub').set('X-Stub-Signature', sig).set('Content-Type', 'application/json').send(body).expect(201);
    const db2 = pool();
    const led = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries le
       JOIN bookings b ON b.id = le.booking_id WHERE b.hold_id = $1`,
      [hold.body.holdId],
    );
    await db2.end();
    expect(led.rows[0].c).toBe(3);
  });

  it('H refund keeps ledger and receivable consistent', async () => {
    const db = pool();
    const holdId = (global as { refundBookingHold?: string }).refundBookingHold;
    const b = await db.query<{ id: string; status: string; provider_id: string }>(
      `SELECT id, status, provider_id FROM bookings WHERE hold_id = $1`,
      [holdId],
    );
    expect(b.rows[0].status).toBe('CONFIRMED');
    await db.end();
    await request(app.getHttpServer())
      .post(`/v1/bookings/${b.rows[0].id}/cancel`)
      .set('Authorization', consumer('f-user'))
      .set('Idempotency-Key', 'h-cancel')
      .send({ reason: 'guest cancel' })
      .expect(200);
    await app.get(RefundService).dispatchPending();
    const db2 = pool();
    const rec = await db2.query<{ status: string; amount: string }>(
      `SELECT status, amount::text FROM provider_receivables WHERE booking_id = $1`,
      [b.rows[0].id],
    );
    const led = await db2.query<{ direction: string; type: string; amount: string }>(
      `SELECT direction, type, amount::text FROM ledger_entries WHERE booking_id = $1`,
      [b.rows[0].id],
    );
    await db2.end();
    expect(rec.rows[0].status).toBe('adjusted');
    const debit = led.rows.filter((r) => r.direction === 'debit').reduce((s, r) => s + Number(r.amount), 0);
    const credit = led.rows.filter((r) => r.direction === 'credit').reduce((s, r) => s + Number(r.amount), 0);
    expect(debit).toBeCloseTo(credit, 2);
  });

  it('security provider A cannot read provider B bookings', async () => {
    const listed = await request(app.getHttpServer())
      .get('/v1/provider/bookings')
      .set('Authorization', auth('owner-a', 'placesProvider'))
      .expect(200);
    const ids = (listed.body as { provider_id?: string; id: string }[]).map((r) => r.id);
    const db = pool();
    const b = await db.query(`SELECT b.id FROM bookings b JOIN providers p ON p.id = b.provider_id WHERE p.firebase_owner_uid = 'owner-f'`);
    await db.end();
    for (const id of b.rows.map((r) => r.id)) {
      expect(ids).not.toContain(id);
    }
  });

  it('expire hold then payment succeeds → no confirm', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'owner-x', 'ExpCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'Exp',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2026-09-01': '80', '2026-09-02': '80', '2026-09-03': '80' } }],
    });
    await db.end();
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', consumer('x-user'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: dates.in,
        checkOut: dates.out,
        quantity: 1,
      });
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', consumer('x-user'))
      .set('Idempotency-Key', 'x-hold')
      .send({ quoteId: q.body.quoteId, quantity: 1 })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', consumer('x-user'))
      .set('Idempotency-Key', 'x-pay')
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const db2 = pool();
    await db2.query(`UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`, [
      hold.body.holdId,
    ]);
    await db2.end();
    await app.get(HoldService).expireDue();
    const body = JSON.stringify({
      eventId: 'evt-after-expiry',
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    const sig = createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string).update(body).digest('hex');
    await request(app.getHttpServer()).post('/v1/webhooks/psp/stub').set('X-Stub-Signature', sig).set('Content-Type', 'application/json').send(body).expect(201);
    const db3 = pool();
    const b = await db3.query<{ status: string }>(`SELECT status FROM bookings WHERE hold_id = $1`, [hold.body.holdId]);
    const p = await db3.query<{ status: string }>(`SELECT status FROM payments WHERE id = $1`, [intent.body.paymentId]);
    await db3.end();
    expect(b.rows[0].status).not.toBe('CONFIRMED');
    expect(p.rows[0].status).toBe('refunded_after_expiry');
  });
});
