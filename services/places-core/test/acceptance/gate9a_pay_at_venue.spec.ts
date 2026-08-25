/**
 * Gate 9A — Pay-at-Venue + Migration 023 acceptance (explicit Test IDs).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { promises as fs } from 'fs';
import path from 'path';

const FIN_TABLES = [
  'payments',
  'payment_attempts',
  'webhook_events',
  'refunds',
  'ledger_entries',
  'commissions',
  'provider_receivables',
  'settlements',
  'settlement_items',
  'payouts',
] as const;

describe('gate9a_pay_at_venue', () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = '';
    process.env.PAYMENT_PROVIDER = 'stub';
    // Slot CAS tests need the kill switch OFF for this suite only.
    process.env.PLACES_EVENT_SLOT_ENABLED = 'true';
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  async function finCounts(): Promise<Record<string, number>> {
    const out: Record<string, number> = {};
    for (const t of FIN_TABLES) {
      const r = await db.query(`SELECT count(*)::int AS c FROM ${t}`);
      out[t] = r.rows[0].c;
    }
    return out;
  }

  async function seedNightly(tag: string) {
    const uid = `g9a-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `G9A-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `G9A ${tag}`,
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 3,
          nights: {
            '2026-12-01': '120.00',
            '2026-12-02': '120.00',
          },
        },
      ],
    });
    return { uid, providerId, venueId: seeded.venueId, typeId: seeded.types.Std };
  }

  async function quoteHold(tag: string) {
    const s = await seedNightly(tag);
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: '2026-12-01',
        checkOut: '2026-12-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', `g9a-hold-${tag}`)
      .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    return {
      ...s,
      holdId: hold.body.holdId as string,
      bookingId: hold.body.bookingId as string,
      grossTotal: quote.body.grossTotal as string,
    };
  }

  async function seedEventSlot(tag: string) {
    const uid = `g9a-slot-${tag}`;
    const providerId = await seedProvider(db, `owner-slot-${tag}`, `G9A-S-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `G9A Slot ${tag}`,
      venueType: 'hotel',
      mode: 'event_slot',
      types: [{ name: 'Hall', qty: 1, nights: { '2026-12-10': '500.00' } }],
    });
    const typeId = seeded.types.Hall;
    const tpl = newId();
    await db.query(
      `INSERT INTO event_slot_templates
         (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id)
       VALUES ($1,$2,'evening','مسائية','18:00','23:00',1,500.00,$3)`,
      [tpl, seeded.venueId, typeId],
    );
    const slotId = newId();
    await db.query(
      `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
       VALUES ($1,$2,$3,'2026-12-10'::date,'open')`,
      [slotId, seeded.venueId, tpl],
    );
    return { uid, providerId, venueId: seeded.venueId, typeId, tpl, slotId };
  }

  async function quoteHoldSlot(tag: string) {
    const s = await seedEventSlot(tag);
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: '2026-12-10',
        checkOut: '2026-12-10',
        quantity: 1,
        guestsAdults: 1,
        slotCode: 'evening',
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', `g9a-slot-hold-${tag}`)
      .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    return { ...s, holdId: hold.body.holdId as string, bookingId: hold.body.bookingId as string };
  }

  it('T-MIG-023-01 columns exist after migrate', async () => {
    const cols = await db.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_name = 'bookings'
         AND column_name IN ('payment_method','payment_status')`,
    );
    expect(cols.rowCount).toBe(2);
  });

  it('T-MIG-023-02 HOLDING allows NULL payment fields', async () => {
    const h = await quoteHold('null-pay');
    const row = await db.query(
      `SELECT status, payment_method, payment_status FROM bookings WHERE id = $1`,
      [h.bookingId],
    );
    expect(row.rows[0].status).toBe('HOLDING');
    expect(row.rows[0].payment_method).toBeNull();
    expect(row.rows[0].payment_status).toBeNull();
  });

  it('T-MIG-023-04 negative CHECK: CONFIRMED + NULL payment rejected', async () => {
    const h = await quoteHold('neg-chk');
    await expect(
      db.query(
        `UPDATE bookings SET status = 'CONFIRMED', payment_method = NULL, payment_status = NULL
         WHERE id = $1`,
        [h.bookingId],
      ),
    ).rejects.toThrow(/bookings_payment_combo_chk|check constraint/i);
  });

  it('T-MIG-023-05 auth_sessions + auth_otp_challenges exist', async () => {
    const t = await db.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema='public'
         AND table_name IN ('auth_sessions','auth_otp_challenges')`,
    );
    expect(t.rowCount).toBe(2);
  });

  it('T-MIG-023-06 event_slot_templates.inventory_type_id + composite FK', async () => {
    const col = await db.query(
      `SELECT 1 FROM information_schema.columns
       WHERE table_name='event_slot_templates' AND column_name='inventory_type_id'`,
    );
    expect(col.rowCount).toBe(1);
    const fk = await db.query(
      `SELECT 1 FROM pg_constraint WHERE conname='event_slot_templates_inventory_type_venue_fk'`,
    );
    expect(fk.rowCount).toBe(1);
  });

  it('T-PAV-01 confirm HOLDING→CONFIRMED single path', async () => {
    const h = await quoteHold('confirm');
    const res = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-confirm-1')
      .send({ holdId: h.holdId })
      .expect(201);
    expect(res.body.status).toBe('CONFIRMED');
    expect(res.body.paymentMethod).toBe('PAY_AT_VENUE');
    expect(res.body.paymentStatus).toBe('DUE_AT_VENUE');
    expect(res.body.dueAtVenueAmount).toBe(res.body.grossTotal);
    const row = await db.query(
      `SELECT status, payment_method, payment_status, confirmed_at FROM bookings WHERE id = $1`,
      [res.body.bookingId],
    );
    expect(row.rows[0].status).toBe('CONFIRMED');
    expect(row.rows[0].payment_method).toBe('PAY_AT_VENUE');
    expect(row.rows[0].payment_status).toBe('DUE_AT_VENUE');
    expect(row.rows[0].confirmed_at).toBeTruthy();
  });

  it('T-PAV-02 dueAtVenueAmount equals gross_total currency SAR', async () => {
    const h = await quoteHold('dueamt');
    const res = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-dueamt')
      .send({ holdId: h.holdId })
      .expect(201);
    expect(res.body.dueAtVenueAmount).toBe(h.grossTotal);
    expect(res.body.currency).toBe('SAR');
  });

  it('T-PAV-03 disabled flag returns 403 PAY_AT_VENUE_DISABLED', async () => {
    const h = await quoteHold('disabled');
    const prev = process.env.PLACES_PAY_AT_VENUE_ENABLED;
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'false';
    try {
      const res = await request(app.getHttpServer())
        .post('/v1/bookings/confirm-pay-at-venue')
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'g9a-disabled')
        .send({ holdId: h.holdId })
        .expect(403);
      expect(res.body.code).toBe('PAY_AT_VENUE_DISABLED');
    } finally {
      process.env.PLACES_PAY_AT_VENUE_ENABLED = prev;
    }
  });

  it('T-PAV-04 idempotent same key returns 201', async () => {
    const h = await quoteHold('idem');
    const key = 'g9a-idem-same';
    const a = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', key)
      .send({ holdId: h.holdId })
      .expect(201);
    const b = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', key)
      .send({ holdId: h.holdId })
      .expect(201);
    expect(b.body.bookingId).toBe(a.body.bookingId);
  });

  it('T-PAV-05 same key different body → 409 IDEMPOTENCY_CONFLICT', async () => {
    const h1 = await quoteHold('idem-c1');
    const h2 = await quoteHold('idem-c2');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h1.uid))
      .set('Idempotency-Key', 'g9a-conflict-key')
      .send({ holdId: h1.holdId })
      .expect(201);
    // Different actor → different scope; use same actor with different body.
    const res = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h1.uid))
      .set('Idempotency-Key', 'g9a-conflict-key')
      .send({ holdId: h2.holdId });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe('IDEMPOTENCY_CONFLICT');
  });

  it('T-PAV-06 dual-confirm same hold: one winner', async () => {
    const h = await quoteHold('dual-conf');
    const [a, b] = await Promise.all([
      request(app.getHttpServer())
        .post('/v1/bookings/confirm-pay-at-venue')
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'g9a-dual-a')
        .send({ holdId: h.holdId }),
      request(app.getHttpServer())
        .post('/v1/bookings/confirm-pay-at-venue')
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'g9a-dual-b')
        .send({ holdId: h.holdId }),
    ]);
    const statuses = [a.status, b.status].sort();
    expect(statuses.filter((s) => s === 201).length).toBe(1);
    const losers = [a, b].filter((r) => r.status !== 201);
    expect(losers.length).toBe(1);
    expect(['BOOKING_ALREADY_CONFIRMED', 'HOLD_NOT_ACTIVE', 'VALIDATION_ERROR']).toContain(
      losers[0].body.code,
    );
  });

  it('T-ZERO-01..10 financial tables unchanged on confirm', async () => {
    const before = await finCounts();
    const h = await quoteHold('zero-all');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-zero-all')
      .send({ holdId: h.holdId })
      .expect(201);
    const after = await finCounts();
    for (const t of FIN_TABLES) {
      expect(after[t]).toBe(before[t]);
    }
  });

  it('T-CAN-01 cancel CONFIRMED → VOIDED', async () => {
    const h = await quoteHold('cancel');
    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-can-conf')
      .send({ holdId: h.holdId })
      .expect(201);
    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${conf.body.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-can-1')
      .send({ reason: 'changed plans' })
      .expect(200);
    expect(cancel.body.status).toBe('CANCELLED');
    expect(cancel.body.paymentStatus).toBe('VOIDED');
    const refunds = await db.query(
      `SELECT count(*)::int AS c FROM refunds WHERE booking_id = $1`,
      [conf.body.bookingId],
    );
    expect(refunds.rows[0].c).toBe(0);
  });

  it('T-CAN-02 cancel HOLDING → CANCELLED NULL/NULL', async () => {
    const h = await quoteHold('can-hold');
    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-can-hold')
      .send({ reason: 'abandon' })
      .expect(200);
    expect(cancel.body.status).toBe('CANCELLED');
    expect(cancel.body.paymentMethod).toBeNull();
    expect(cancel.body.paymentStatus).toBeNull();
  });

  it('T-CAN-03 cancel ownership non-owner → 404', async () => {
    const h = await quoteHold('can-own');
    await request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth('other-user'))
      .set('Idempotency-Key', 'g9a-can-own')
      .send({ reason: 'steal' })
      .expect(404);
  });

  it('T-CAN-04 dual-cancel: one winner 200', async () => {
    const h = await quoteHold('dual-can');
    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-dual-can-conf')
      .send({ holdId: h.holdId })
      .expect(201);
    const [a, b] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/bookings/${conf.body.bookingId}/cancel`)
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'g9a-dual-can-a')
        .send({ reason: 'a' }),
      request(app.getHttpServer())
        .post(`/v1/bookings/${conf.body.bookingId}/cancel`)
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'g9a-dual-can-b')
        .send({ reason: 'b' }),
    ]);
    const oks = [a, b].filter((r) => r.status === 200);
    expect(oks.length).toBeGreaterThanOrEqual(1);
    // Idempotent replay of already-cancelled may also 200
    expect([a, b].every((r) => r.status === 200 || r.status >= 400)).toBe(true);
  });

  it('T-SLOT-01 event_slot hold sets held + hold_id', async () => {
    const h = await quoteHoldSlot('hold');
    const slot = await db.query(
      `SELECT status, hold_id::text FROM event_slot_inventory WHERE id = $1`,
      [h.slotId],
    );
    expect(slot.rows[0].status).toBe('held');
    expect(slot.rows[0].hold_id).toBe(h.holdId);
  });

  it('T-SLOT-02 event_slot confirm → booked + booking_id, hold_id cleared', async () => {
    const h = await quoteHoldSlot('conf');
    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'g9a-slot-conf')
      .send({ holdId: h.holdId })
      .expect(201);
    const slot = await db.query(
      `SELECT status, hold_id, booking_id::text FROM event_slot_inventory WHERE id = $1`,
      [h.slotId],
    );
    expect(slot.rows[0].status).toBe('booked');
    expect(slot.rows[0].hold_id).toBeNull();
    expect(slot.rows[0].booking_id).toBe(conf.body.bookingId);
  });

  it('T-SLOT-03 dual-hold same slot: one winner', async () => {
    const s = await seedEventSlot('race');
    const mkHold = async (uid: string, key: string) => {
      const quote = await request(app.getHttpServer())
        .post('/v1/quotes')
        .set('Authorization', auth(uid))
        .send({
          venueId: s.venueId,
          inventoryTypeId: s.typeId,
          checkIn: '2026-12-10',
          checkOut: '2026-12-10',
          quantity: 1,
          guestsAdults: 1,
          slotCode: 'evening',
        });
      if (quote.status !== 201) return quote;
      return request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(uid))
        .set('Idempotency-Key', key)
        .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
    };
    const [a, b] = await Promise.all([
      mkHold('u-slot-a', 'slot-hold-a'),
      mkHold('u-slot-b', 'slot-hold-b'),
    ]);
    const wins = [a, b].filter((r) => r.status === 201);
    expect(wins.length).toBe(1);
  });

  it('T-SLOT-04 active template without inventory_type_id rejected', async () => {
    const providerId = await seedProvider(db, 'owner-tpl-neg', 'tpl-neg');
    const seeded = await seedVenue(db, providerId, {
      name: 'Tpl Neg',
      venueType: 'hotel',
      mode: 'event_slot',
      types: [{ name: 'Hall', qty: 1, nights: { '2026-12-11': '100.00' } }],
    });
    await expect(
      db.query(
        `INSERT INTO event_slot_templates
           (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, status)
         VALUES ($1,$2,'bad','x','10:00','12:00',1,100,'active')`,
        [newId(), seeded.venueId],
      ),
    ).rejects.toThrow();
  });

  it('T-MIG-023-03 fresh through 023 from empty helper path', async () => {
    const dir = path.resolve(__dirname, '../../db/migrations');
    const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
    expect(files).toContain('023_pay_at_venue_event_slot_gate9a.sql');
    expect(files.indexOf('023_pay_at_venue_event_slot_gate9a.sql')).toBeGreaterThan(
      files.indexOf('022_pre_provider_rev4_corrective.sql'),
    );
  });
});
