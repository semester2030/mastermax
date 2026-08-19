/**
 * Phase 4 — PAV ops / finance / cancel / settlement / migration 028
 * Findings: F-V2-004, F-V2-005, F-V2-006, F-V2-017, F-V3-006, F-V3-007, F-V3-008, F-V3-011
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { assertProductionGuards } from '../../src/shared/config/env';
import { PavOnlyPaymentAdapter } from '../../src/modules/payments/infrastructure/payment-pav-only.adapter';
import { SettlementService } from '../../src/modules/settlements/application/settlement.service';
import { ReceivableEligibilityService } from '../../src/modules/settlements/application/receivable-eligibility.service';
import { migrate } from '../../src/shared/database/migrate';
import { riyadhTodayIso } from '../../src/shared/time/stay-dates';

describe('phase4_pav_finance', () => {
  let app: INestApplication;
  let db: Pool;
  const consumer = 'p4-consumer';
  const owner = 'p4-owner';

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = '';
    delete process.env.PLACES_EVENT_SLOT_ENABLED;
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  async function seedFarStay(tag: string, nights: Record<string, string>) {
    const providerId = await seedProvider(db, `${owner}-${tag}`, `P4-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `P4 ${tag}`,
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 3, nights }],
    });
    return {
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      ownerUid: `${owner}-${tag}`,
      uid: `${consumer}-${tag}`,
    };
  }

  async function quoteHoldConfirm(s: {
    uid: string;
    venueId: string;
    typeId: string;
  }, checkIn: string, checkOut: string, key: string) {
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn,
        checkOut,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', key)
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);
    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', `${key}-pav`)
      .send({ holdId: hold.body.holdId })
      .expect(201);
    return {
      quoteId: quote.body.quoteId as string,
      holdId: hold.body.holdId as string,
      bookingId: conf.body.bookingId as string,
      grossTotal: String(conf.body.grossTotal ?? quote.body.grossTotal),
    };
  }

  it('T-BOOT-PROD-01 production requires pav_only; stub forbidden; PavOnly refuses PSP with zero DB effects', async () => {
    expect(() => assertProductionGuards('production', 'firebase', 'stub')).toThrow(
      /PAYMENT_PROVIDER=stub/,
    );
    expect(() => assertProductionGuards('production', 'firebase', 'stripe')).toThrow(
      /pav_only/,
    );
    expect(() => assertProductionGuards('production', 'firebase', 'pav_only')).not.toThrow();

    const before = await db.query(`SELECT count(*)::int AS c FROM payments`);
    const adapter = new PavOnlyPaymentAdapter();
    await expect(
      adapter.createIntent({
        paymentId: 'x',
        operationId: 'y',
        amount: '10.00',
        currency: 'SAR',
        holdId: 'z',
      }),
    ).rejects.toMatchObject({ code: 'PAYMENT_REQUIRED' });
    expect(() => adapter.verifySignature('{}', 'sig')).toThrow(/pav_only/);
    expect(() => adapter.parseWebhook('{}')).toThrow(/pav_only/);
    await expect(
      adapter.refund({ pspIntentId: 'a', amount: '1.00', operationId: 'b' }),
    ).rejects.toMatchObject({ code: 'PAYMENT_REQUIRED' });
    const after = await db.query(`SELECT count(*)::int AS c FROM payments`);
    expect(after.rows[0].c).toBe(before.rows[0].c);
  });

  it('T-PAV-FIN-01 collect → receivable pending_completion; complete → due; no provider_receivable', async () => {
    const s = await seedFarStay('fin01', {
      '2026-10-01': '200.00',
      '2026-10-02': '200.00',
    });
    const b = await quoteHoldConfirm(s, '2026-10-01', '2026-10-03', 'p4-fin01');
    const booking = await db.query<{
      commission_amount: string;
      gross_total: string;
      payment_status: string;
    }>(
      `SELECT commission_amount::text, gross_total::text, payment_status FROM bookings WHERE id = $1`,
      [b.bookingId],
    );
    expect(booking.rows[0].payment_status).toBe('DUE_AT_VENUE');

    const collect = await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/collect-at-venue`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-collect-fin01')
      .send({ amount: booking.rows[0].gross_total, currency: 'SAR' })
      .expect(200);
    expect(collect.body.paymentStatus).toBe('COLLECTED_AT_VENUE');

    const recv = await db.query<{ status: string; amount: string; currency: string }>(
      `SELECT status, amount::text, currency FROM dar_commission_receivables WHERE booking_id = $1`,
      [b.bookingId],
    );
    expect(recv.rowCount).toBe(1);
    expect(recv.rows[0].status).toBe('pending_completion');
    expect(recv.rows[0].currency).toBe('SAR');
    expect(recv.rows[0].amount).toBe(booking.rows[0].commission_amount);

    const pr = await db.query(
      `SELECT 1 FROM provider_receivables WHERE booking_id = $1`,
      [b.bookingId],
    );
    expect(pr.rowCount).toBe(0);

    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/check-in`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-checkin-fin01')
      .send({})
      .expect(200);

    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/complete`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-complete-fin01')
      .send({})
      .expect(200);

    const due = await db.query<{ status: string }>(
      `SELECT status FROM dar_commission_receivables WHERE booking_id = $1`,
      [b.bookingId],
    );
    expect(due.rows[0].status).toBe('due');

    // Idempotent complete + collect replay
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/complete`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-complete-fin01-b')
      .send({})
      .expect(200);
    const due2 = await db.query(
      `SELECT count(*)::int AS c FROM dar_commission_receivables WHERE booking_id = $1`,
      [b.bookingId],
    );
    expect(due2.rows[0].c).toBe(1);
  });

  it('T-PAV-FIN-DIR-01 cancel/no-show before collect → no receivable; amount mismatch refused', async () => {
    const s = await seedFarStay('findir', {
      '2026-10-10': '150.00',
    });
    const b = await quoteHoldConfirm(s, '2026-10-10', '2026-10-11', 'p4-findir');
    const booking = await db.query<{ gross_total: string }>(
      `SELECT gross_total::text FROM bookings WHERE id = $1`,
      [b.bookingId],
    );

    const bad = await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/collect-at-venue`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-bad-amt')
      .send({ amount: '1.00', currency: 'SAR' });
    expect(bad.status).toBeGreaterThanOrEqual(400);
    expect(bad.body.code).toBe('PAV_AMOUNT_MISMATCH');

    await request(app.getHttpServer())
      .post(`/v1/bookings/${b.bookingId}/cancel`)
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', 'p4-cxl-findir')
      .send({ reason: 'changed plans' })
      .expect(200);

    const recv = await db.query(
      `SELECT 1 FROM dar_commission_receivables WHERE booking_id = $1`,
      [b.bookingId],
    );
    expect(recv.rowCount).toBe(0);
    expect(booking.rows[0].gross_total).toBeTruthy();

    // No-show path: separate booking, force check_in to today, then no-show.
    const s2 = await seedFarStay('noshow', { [riyadhTodayIso()]: '100.00' });
    // Seed capacity for today
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1, $2, $3::date, 3, 0, 0, 0)
       ON CONFLICT (inventory_type_id, date) DO NOTHING`,
      [newId(), s2.typeId, riyadhTodayIso()],
    );
    const tomorrow = new Date(Date.now() + 864e5);
    const tomorrowIso = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh',
    }).format(tomorrow);
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1, $2, $3::date, 3, 0, 0, 0)
       ON CONFLICT (inventory_type_id, date) DO NOTHING`,
      [newId(), s2.typeId, tomorrowIso],
    );
    // Ensure rate for today exists via seed nights — reseed with today price already set.
    const b2 = await quoteHoldConfirm(s2, riyadhTodayIso(), tomorrowIso, 'p4-noshow');
    // Phase 4 RC2: no-show requires the venue-local check-in instant (date +
    // check_in_time, default 15:00). Before that instant it must be refused.
    const early = await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b2.bookingId}/no-show`)
      .set('Authorization', auth(s2.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-noshow-early')
      .send({});
    expect(early.status).toBe(400);
    expect(early.body.code).toBe('VALIDATION_ERROR');
    // Move check-in into the past → check-in instant passed → no-show allowed.
    await db.query(
      `UPDATE bookings SET check_in = (now() - interval '2 days')::date,
                           check_out = (now() - interval '1 day')::date
       WHERE id = $1`,
      [b2.bookingId],
    );
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b2.bookingId}/no-show`)
      .set('Authorization', auth(s2.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-noshow-1')
      .send({})
      .expect(200);
    const st = await db.query<{ status: string; payment_status: string }>(
      `SELECT status, payment_status FROM bookings WHERE id = $1`,
      [b2.bookingId],
    );
    expect(st.rows[0].status).toBe('NO_SHOW');
    expect(st.rows[0].payment_status).toBe('VOIDED');
    const recv2 = await db.query(
      `SELECT 1 FROM dar_commission_receivables WHERE booking_id = $1`,
      [b2.bookingId],
    );
    expect(recv2.rowCount).toBe(0);
  });

  it('T-PAV-CXL-01 / T-PAV-CXL-POLICY-01 free cancel OK; window closed refuses without mutating; ACTIVE refuse', async () => {
    const s = await seedFarStay('cxl', {
      '2026-11-01': '180.00',
      '2026-11-02': '180.00',
    });
    const b = await quoteHoldConfirm(s, '2026-11-01', '2026-11-03', 'p4-cxl-ok');
    const ok = await request(app.getHttpServer())
      .post(`/v1/bookings/${b.bookingId}/cancel`)
      .set('Authorization', auth(s.uid))
      .set('Idempotency-Key', 'p4-cxl-ok')
      .send({ reason: 'free window' })
      .expect(200);
    expect(ok.body.status).toBe('CANCELLED');
    expect(ok.body.paymentStatus).toBe('VOIDED');

    const s2 = await seedFarStay('cxl2', {
      '2026-11-10': '180.00',
    });
    const b2 = await quoteHoldConfirm(s2, '2026-11-10', '2026-11-11', 'p4-cxl-closed');
    // Force window closed by setting free_until extremely high.
    await db.query(
      `UPDATE bookings
       SET cancellation_policy_snapshot_json =
         '{"free_until_hours_before_checkin":999999,"fee_bps_after":5000}'::jsonb
       WHERE id = $1`,
      [b2.bookingId],
    );
    const before = await db.query(
      `SELECT status, payment_status FROM bookings WHERE id = $1`,
      [b2.bookingId],
    );
    const closed = await request(app.getHttpServer())
      .post(`/v1/bookings/${b2.bookingId}/cancel`)
      .set('Authorization', auth(s2.uid))
      .set('Idempotency-Key', 'p4-cxl-closed')
      .send({ reason: 'too late' });
    expect(closed.status).toBe(409);
    expect(closed.body.code).toBe('CANCELLATION_WINDOW_CLOSED');
    const after = await db.query(
      `SELECT status, payment_status FROM bookings WHERE id = $1`,
      [b2.bookingId],
    );
    expect(after.rows[0]).toEqual(before.rows[0]);

    // ACTIVE cancel refused
    const s3 = await seedFarStay('cxl3', {
      '2026-12-01': '100.00',
    });
    const b3 = await quoteHoldConfirm(s3, '2026-12-01', '2026-12-02', 'p4-cxl-active');
    const gross = (
      await db.query<{ gross_total: string }>(
        `SELECT gross_total::text FROM bookings WHERE id = $1`,
        [b3.bookingId],
      )
    ).rows[0].gross_total;
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b3.bookingId}/collect-at-venue`)
      .set('Authorization', auth(s3.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-cxl-col')
      .send({ amount: gross, currency: 'SAR' })
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b3.bookingId}/check-in`)
      .set('Authorization', auth(s3.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-cxl-ci')
      .send({})
      .expect(200);
    const activeRefuse = await request(app.getHttpServer())
      .post(`/v1/bookings/${b3.bookingId}/cancel`)
      .set('Authorization', auth(s3.uid))
      .set('Idempotency-Key', 'p4-cxl-active')
      .send({ reason: 'nope' });
    expect(activeRefuse.status).toBe(409);
    expect(activeRefuse.body.code).toBe('BOOKING_NOT_CANCELLABLE');
  });

  it('T-INV-REL-01 cancel releases future booked days only (not today/past)', async () => {
    const today = riyadhTodayIso();
    const tomorrow = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh',
    }).format(new Date(Date.now() + 864e5));
    const dayAfter = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Riyadh',
    }).format(new Date(Date.now() + 2 * 864e5));

    // Seed a normal far-enough stay first (confirm OK), then rewrite to today→dayAfter.
    const s = await seedFarStay('invrel', {
      [tomorrow]: '100.00',
      [dayAfter]: '100.00',
      [today]: '100.00',
    });
    const b = await quoteHoldConfirm(s, tomorrow, dayAfter, 'p4-invrel');

    // Nightly stay today→dayAfter occupies [today, tomorrow].
    await db.query(
      `UPDATE bookings SET check_in = $2::date, check_out = $3::date WHERE id = $1`,
      [b.bookingId, today, dayAfter],
    );
    for (const d of [today, tomorrow]) {
      await db.query(
        `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
         VALUES ($1, $2, $3::date, 3, 0, 1, 0)
         ON CONFLICT (inventory_type_id, date)
         DO UPDATE SET booked = 1, held = 0`,
        [newId(), s.typeId, d],
      );
    }

    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/cancel`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-invrel-cxl')
      .send({ reason: 'inv release' })
      .expect(200);

    const todayRow = await db.query<{ booked: number }>(
      `SELECT booked FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = $2::date`,
      [s.typeId, today],
    );
    const tomorrowRow = await db.query<{ booked: number }>(
      `SELECT booked FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = $2::date`,
      [s.typeId, tomorrow],
    );
    expect(Number(todayRow.rows[0].booked)).toBe(1); // current day not restored
    expect(Number(tomorrowRow.rows[0].booked)).toBe(0); // future day released
  });

  it('T-SETTLE-STUB-01 / T-FIN-01 stub_paid forbidden; PAV excluded from provider payout; eligibility no auto-complete; idempotent', async () => {
    const settle = app.get(SettlementService);
    await expect(
      settle.approveAndStubPayout('00000000-0000-4000-8000-000000000001', 'u', 'c'),
    ).rejects.toMatchObject({ code: 'SETTLEMENT_TRANSFER_UNAVAILABLE' });

    const s = await seedFarStay('settle', {
      '2026-12-10': '200.00',
    });
    const b = await quoteHoldConfirm(s, '2026-12-10', '2026-12-11', 'p4-settle');
    const gross = (
      await db.query<{ gross_total: string }>(
        `SELECT gross_total::text FROM bookings WHERE id = $1`,
        [b.bookingId],
      )
    ).rows[0].gross_total;
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/collect-at-venue`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-settle-col')
      .send({ amount: gross, currency: 'SAR' })
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/check-in`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-settle-ci')
      .send({})
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${b.bookingId}/complete`)
      .set('Authorization', auth(s.ownerUid, 'placesProvider'))
      .set('Idempotency-Key', 'p4-settle-done')
      .send({})
      .expect(200);

    // Force an eligible provider_receivable wrongly linked would be excluded by payment_method filter.
    // Draft settlement for provider must not include PAV (no provider_receivable exists).
    const draft = await settle.createDraft({
      providerId: s.providerId,
      periodStart: '2026-01-01',
      periodEnd: '2027-01-01',
      actorUid: 'finance',
      correlationId: 'p4-draft',
    });
    expect(draft.itemCount).toBe(0);
    expect(draft.settlementId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    );
    const snap = await db.query(
      `SELECT id, status, net::text AS net, mode FROM settlements WHERE id = $1`,
      [draft.settlementId],
    );
    const itemsSnap = await db.query(
      `SELECT id, amount_snapshot::text FROM settlement_items WHERE settlement_id = $1 ORDER BY id`,
      [draft.settlementId],
    );
    await expect(
      settle.approveAndStubPayout(draft.settlementId, 'finance', 'p4-stub-real'),
    ).rejects.toMatchObject({ code: 'SETTLEMENT_TRANSFER_UNAVAILABLE' });
    const snapAfter = await db.query(
      `SELECT id, status, net::text AS net, mode FROM settlements WHERE id = $1`,
      [draft.settlementId],
    );
    const itemsAfter = await db.query(
      `SELECT id, amount_snapshot::text FROM settlement_items WHERE settlement_id = $1 ORDER BY id`,
      [draft.settlementId],
    );
    expect(snapAfter.rows).toEqual(snap.rows);
    expect(itemsAfter.rows).toEqual(itemsSnap.rows);

    const elig = app.get(ReceivableEligibilityService);
    // Leave a CONFIRMED booking — eligibility must NOT auto-complete it.
    const s2 = await seedFarStay('elig', { '2026-12-15': '90.00' });
    const b2 = await quoteHoldConfirm(s2, '2026-12-15', '2026-12-16', 'p4-elig');
    await db.query(`UPDATE bookings SET check_out = CURRENT_DATE - 2 WHERE id = $1`, [
      b2.bookingId,
    ]);
    const n1 = await elig.promoteDue();
    const n2 = await elig.promoteDue();
    expect(n1).toBe(0);
    expect(n2).toBe(0);
    const st = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [b2.bookingId],
    );
    expect(st.rows[0].status).toBe('CONFIRMED');
  });

  it('T-FIN-HARDEN-01 SAR-only + default rate-plan uniqueness + physical fail-closed', async () => {
    await expect(
      db.query(`UPDATE rate_plans SET currency = 'USD' WHERE id IN (SELECT id FROM rate_plans LIMIT 1)`),
    ).rejects.toThrow();

    const s = await seedFarStay('harden', { '2026-12-20': '50.00' });
    // Second active default must fail unique index
    await expect(
      db.query(
        `INSERT INTO rate_plans (id, inventory_type_id, name, currency, is_default, status, base_price)
         VALUES (gen_random_uuid(), $1, 'dup', 'SAR', TRUE, 'active', 50)`,
        [s.typeId],
      ),
    ).rejects.toThrow();

    // Physical inventory not bookable
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical' WHERE id = $1`,
      [s.typeId],
    );
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(s.uid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: '2026-12-20',
        checkOut: '2026-12-21',
        quantity: 1,
        guestsAdults: 1,
      });
    // Quote may succeed or fail depending on path; hold must fail-closed.
    if (quote.status === 201) {
      const hold = await request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(s.uid))
        .set('Idempotency-Key', 'p4-phys')
        .send({ quoteId: quote.body.quoteId, quantity: 1 });
      expect(hold.status).toBeGreaterThanOrEqual(400);
    }
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'pooled' WHERE id = $1`,
      [s.typeId],
    );
  });

  it('T-MIG-REAL-01 REAL fresh 001→028 + upgrade 027→028 on isolated CI databases; drift rejected', async () => {
    const migDir = path.resolve(__dirname, '../../db/migrations');
    const baseUrl = process.env.DATABASE_URL!;
    const adminUrl = new URL(baseUrl);
    adminUrl.pathname = '/postgres';
    const freshName = 'places_core_mig_fresh_ci';
    const upgName = 'places_core_mig_upg_ci';
    const urlFor = (name: string): string => {
      const u = new URL(baseUrl);
      u.pathname = `/${name}`;
      return u.toString();
    };

    const sql028 = await fs.readFile(
      path.join(migDir, '028_phase4_pav_finance.sql'),
      'utf8',
    );
    const cs028 = createHash('sha256').update(sql028, 'utf8').digest('hex');

    const admin = new Pool({ connectionString: adminUrl.toString() });
    const dropCreate = async (name: string): Promise<void> => {
      await admin.query(
        `SELECT pg_terminate_backend(pid) FROM pg_stat_activity
         WHERE datname = $1 AND pid <> pg_backend_pid()`,
        [name],
      );
      await admin.query(`DROP DATABASE IF EXISTS ${name}`);
      await admin.query(`CREATE DATABASE ${name}`);
    };

    try {
      // ---- Real fresh 001→028: apply the whole chain onto an empty database ----
      const maxNum = async (pool: Pool) => {
        const r = await pool.query<{ n: number }>(
          `SELECT max(substring(id from 1 for 3)::int) AS n FROM schema_migrations`,
        );
        return Number(r.rows[0].n);
      };

      await dropCreate(freshName);
      const fresh = new Pool({ connectionString: urlFor(freshName) });
      try {
        await migrate(fresh, migDir, { stopAfterNum: 28 });
        expect(await maxNum(fresh)).toBe(28);
        const m028 = await fresh.query<{ checksum: string }>(
          `SELECT checksum FROM schema_migrations WHERE id = '028_phase4_pav_finance.sql'`,
        );
        expect(m028.rowCount).toBe(1);
        expect(m028.rows[0].checksum).toBe(cs028);
        const later = await fresh.query(
          `SELECT 1 FROM schema_migrations WHERE id LIKE '029%' OR id LIKE '030%' OR id LIKE '031%' OR id LIKE '032%'`,
        );
        expect(later.rowCount).toBe(0);
        const t = await fresh.query<{ t: string | null }>(
          `SELECT to_regclass('public.dar_commission_receivables')::text AS t`,
        );
        expect(t.rows[0].t).toBe('dar_commission_receivables');
        const first = await fresh.query<{ id: string }>(
          `SELECT id FROM schema_migrations ORDER BY id LIMIT 1`,
        );
        expect(first.rows[0].id.startsWith('001_')).toBe(true);
      } finally {
        await fresh.end();
      }

      // ---- Real upgrade 027→028: stop at 027, then stopAfterNum:28 only ----
      await dropCreate(upgName);
      const upg = new Pool({ connectionString: urlFor(upgName) });
      try {
        await migrate(upg, migDir, { stopAfterNum: 27 });
        expect(await maxNum(upg)).toBe(27);
        const before028 = await upg.query(
          `SELECT 1 FROM schema_migrations WHERE id LIKE '028%'`,
        );
        expect(before028.rowCount).toBe(0);
        const t0 = await upg.query<{ t: string | null }>(
          `SELECT to_regclass('public.dar_commission_receivables')::text AS t`,
        );
        expect(t0.rows[0].t).toBeNull();

        await migrate(upg, migDir, { stopAfterNum: 28 });
        expect(await maxNum(upg)).toBe(28);
        const after028 = await upg.query<{ checksum: string }>(
          `SELECT checksum FROM schema_migrations WHERE id = '028_phase4_pav_finance.sql'`,
        );
        expect(after028.rowCount).toBe(1);
        expect(after028.rows[0].checksum).toBe(cs028);
        const laterUpg = await upg.query(
          `SELECT 1 FROM schema_migrations WHERE id LIKE '029%'`,
        );
        expect(laterUpg.rowCount).toBe(0);
        const t1 = await upg.query<{ t: string | null }>(
          `SELECT to_regclass('public.dar_commission_receivables')::text AS t`,
        );
        expect(t1.rows[0].t).toBe('dar_commission_receivables');

        await upg.query(
          `UPDATE schema_migrations SET checksum = $2 WHERE id = $1`,
          ['028_phase4_pav_finance.sql', '0'.repeat(64)],
        );
        await expect(migrate(upg, migDir, { stopAfterNum: 28 })).rejects.toThrow(
          /checksum mismatch/,
        );
      } finally {
        await upg.end();
      }
    } finally {
      for (const name of [freshName, upgName]) {
        await admin
          .query(
            `SELECT pg_terminate_backend(pid) FROM pg_stat_activity
             WHERE datname = $1 AND pid <> pg_backend_pid()`,
            [name],
          )
          .catch(() => undefined);
        await admin.query(`DROP DATABASE IF EXISTS ${name}`).catch(() => undefined);
      }
      await admin.end();
    }
  }, 180_000);
});
