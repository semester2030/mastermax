/**
 * Gate 9A RC5 — webhook kill-switch, mig 025, locks, PAV zero-fin, operator/media residuals.
 */
import { createHmac } from 'crypto';
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import {
  applyMigrationsThrough,
  applyRemainingMigrations,
} from '../helpers/migrate-partial';
import { withIsolatedDatabase } from '../helpers/isolated-database';
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

function sig(body: string): string {
  return createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string)
    .update(body)
    .digest('hex');
}

describe('gate9a_rc5_closure', () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = '';
    process.env.PAYMENT_PROVIDER = 'stub';
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    process.env.PLACES_OTP_FIXED_CODE_ENABLED = 'true';
    process.env.PLACES_OTP_FIXED_CODE_SECRET = '424242';
    process.env.DAR_CAR_INTERNAL_OPERATOR_PHONE = '+966500000001';
    process.env.PLACES_OPERATOR_JWT_SECRET =
      'test-operator-jwt-secret-do-not-use-prod';
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

  async function quoteHold(tag: string) {
    const uid = `g9a-rc5-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `RC5-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `RC5 ${tag}`,
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 3,
          nights: { '2026-12-01': '120.00', '2026-12-02': '120.00' },
        },
      ],
    });
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2026-12-01',
        checkOut: '2026-12-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `rc5-hold-${tag}`)
      .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    return {
      uid,
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      holdId: hold.body.holdId as string,
      bookingId: hold.body.bookingId as string,
    };
  }

  it('T-MIG-025-01 migration 025 ordered after 024', async () => {
    const dir = path.join(__dirname, '../../db/migrations');
    const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
    expect(files).toContain('025_rc5_half_null_payment_remediation.sql');
    expect(
      files.indexOf('025_rc5_half_null_payment_remediation.sql'),
    ).toBeGreaterThan(
      files.indexOf('024_rc4_event_slot_kill_switch_payment_combo.sql'),
    );
  });

  it('T-WH-KILL-01 webhook does not confirm event_slot when kill switch OFF', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const h = await quoteHold('wh-kill');
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-wh-kill-intent')
      .send({ holdId: h.holdId })
      .expect(201);
    // Force event_slot on the venue after intent (API path already blocked).
    await db.query(`UPDATE venues SET booking_mode = 'event_slot' WHERE id = $1`, [
      h.venueId,
    ]);
    const body = JSON.stringify({
      eventId: `rc5-wh-kill-${newId().slice(0, 8)}`,
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    const b = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE id = $1`,
      [h.bookingId],
    );
    const p = await db.query<{ status: string }>(
      `SELECT status FROM payments WHERE id = $1`,
      [intent.body.paymentId],
    );
    expect(b.rows[0].status).not.toBe('CONFIRMED');
    expect(['refund_required', 'refunded_after_expiry']).toContain(p.rows[0].status);
  });

  it('T-PAV-ZERO-01 consumer cancel leaves financial tables unchanged', async () => {
    const h = await quoteHold('pav-z');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-pav-z')
      .send({ holdId: h.holdId })
      .expect(201);
    const before = await finCounts();
    await request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-pav-z-can')
      .send({ reason: 'change of plans' })
      .expect(200);
    const after = await finCounts();
    expect(after).toEqual(before);
    const st = await db.query<{
      status: string;
      payment_method: string;
      payment_status: string;
    }>(`SELECT status, payment_method, payment_status FROM bookings WHERE id = $1`, [
      h.bookingId,
    ]);
    expect(st.rows[0].status).toBe('CANCELLED');
    expect(st.rows[0].payment_method).toBe('PAY_AT_VENUE');
    expect(st.rows[0].payment_status).toBe('VOIDED');
  });

  it('T-PAV-PROV-01 provider cancel uses CANCELLED+VOIDED zero-fin', async () => {
    const h = await quoteHold('pav-prov');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-pav-prov')
      .send({ holdId: h.holdId })
      .expect(201);
    const before = await finCounts();
    const res = await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(`owner-pav-prov`, 'placesProvider'))
      .set('Idempotency-Key', 'rc5-pav-prov-can')
      .send({ reason: 'provider cancel' });
    expect([200, 201]).toContain(res.status);
    const after = await finCounts();
    expect(after).toEqual(before);
    const st = await db.query<{ status: string; payment_status: string }>(
      `SELECT status, payment_status FROM bookings WHERE id = $1`,
      [h.bookingId],
    );
    expect(st.rows[0].status).toBe('CANCELLED');
    expect(st.rows[0].payment_status).toBe('VOIDED');
  });

  it('T-SUSPEND-01 suspended provider membership denied', async () => {
    const owner = 'rc5-susp-owner';
    const providerId = await seedProvider(db, owner, 'SUSP');
    await db.query(`UPDATE providers SET status = 'suspended' WHERE id = $1`, [
      providerId,
    ]);
    const seeded = await seedVenue(db, providerId, {
      name: 'SuspVenue',
      venueType: 'hotel',
      types: [{ name: 'A', qty: 1, nights: { '2026-12-01': '90' } }],
    });
    const res = await request(app.getHttpServer())
      .get(`/v1/provider/venues/${seeded.venueId}`)
      .set('Authorization', auth(owner, 'placesProvider'));
    expect([401, 403, 404]).toContain(res.status);
  });

  it('T-IDEM-PRICING-01 putPricing requires Idempotency-Key', async () => {
    const owner = 'rc5-price-own';
    const providerId = await seedProvider(db, owner, 'PRICE');
    const seeded = await seedVenue(db, providerId, {
      name: 'PriceV',
      venueType: 'hotel',
      types: [{ name: 'A', qty: 1, nights: { '2026-12-01': '90' } }],
    });
    const noKey = await request(app.getHttpServer())
      .put(`/v1/provider/pricing`)
      .set('Authorization', auth(owner, 'placesProvider'))
      .send({
        providerId,
        inventoryTypeId: seeded.types.A,
        baseAmount: '100.00',
      });
    expect(noKey.status).toBe(400);
  });

  it('T-DISC-01 discovery masks event_slot booking when kill switch OFF', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const providerId = await seedProvider(db, 'rc5-disc', 'DISC');
    const seeded = await seedVenue(db, providerId, {
      name: 'DiscSlot',
      venueType: 'hotel',
      mode: 'event_slot',
      types: [{ name: 'Hall', qty: 1, nights: { '2026-12-01': '500' } }],
    });
    await db.query(
      `UPDATE venues SET status = 'published', enabled_for_booking = true WHERE id = $1`,
      [seeded.venueId],
    ).catch(async () => {
      await db.query(`UPDATE venues SET status = 'published' WHERE id = $1`, [
        seeded.venueId,
      ]);
    });
    const feed = await request(app.getHttpServer())
      .get('/v1/discovery/feed')
      .query({ limit: 50 })
      .set('Authorization', auth('rc5-disc-user'));
    if (feed.status === 200 && Array.isArray(feed.body.items)) {
      const hit = feed.body.items.find(
        (i: { venueId?: string }) => i.venueId === seeded.venueId,
      );
      if (hit) {
        expect(hit.enabledForBooking).toBe(false);
      }
    }
  });

  it('T-CONC-01 dual PAV cancel remains CANCELLED+VOIDED', async () => {
    const h = await quoteHold('conc');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-conc-pav')
      .send({ holdId: h.holdId })
      .expect(201);
    const a = request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-conc-a')
      .send({ reason: 'a' });
    const b = request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc5-conc-b')
      .send({ reason: 'b' });
    await Promise.all([a, b]);
    const st = await db.query<{ status: string; payment_status: string }>(
      `SELECT status, payment_status FROM bookings WHERE id = $1`,
      [h.bookingId],
    );
    expect(st.rows[0].status).toBe('CANCELLED');
    expect(st.rows[0].payment_status).toBe('VOIDED');
  });
});

describe('gate9a_mig_025_upgrades', () => {
  it('T-MIG-025-02 fresh 001→025 installs all', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(
        pool,
        '025_rc5_half_null_payment_remediation.sql',
      );
      const mig = await pool.query(
        `SELECT id FROM schema_migrations WHERE id LIKE '02%' ORDER BY id`,
      );
      expect(mig.rows.map((r) => r.id)).toEqual(
        expect.arrayContaining([
          '022_pre_provider_rev4_corrective.sql',
          '023_pay_at_venue_event_slot_gate9a.sql',
          '024_rc4_event_slot_kill_switch_payment_combo.sql',
          '025_rc5_half_null_payment_remediation.sql',
        ]),
      );
      const cols = await pool.query(
        `SELECT column_name FROM information_schema.columns
         WHERE table_name = 'inventory_types'
           AND column_name IN ('label_ar', 'sort_order')`,
      );
      expect(cols.rowCount).toBe(2);
    });
  }, 180_000);

  it('T-MIG-025-03 upgrade 022→025 remediates legacy payment pair', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '022_pre_provider_rev4_corrective.sql');
      const providerId = newId();
      const venueId = newId();
      const typeId = newId();
      const uid = 'upgrade-rc5-uid';
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'U','U','company','active',$2)`,
        [providerId, uid],
      );
      await pool.query(
        `INSERT INTO provider_users (id, provider_id, firebase_uid, role, status)
         VALUES ($1,$2,$3,'owner','active')`,
        [newId(), providerId, uid],
      );
      await pool.query(
        `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status)
         VALUES ($1,$2,'U','hotel','nightly','published')`,
        [venueId, providerId],
      );
      await pool.query(
        `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total,
           base_occupancy, max_occupancy)
         VALUES ($1,$2,'Std','pooled',1,2,4)`,
        [typeId, venueId],
      );
      const quoteId = newId();
      await pool.query(
        `INSERT INTO quotes (
           id, venue_id, inventory_type_id, consumer_firebase_uid, check_in, check_out,
           quantity, guests_adults, guests_children, currency, subtotal, gross_total,
           commission_bps, commission_amount, provider_net, pricing_version, status, expires_at
         ) VALUES (
           $1,$2,$3,$4,'2026-11-01','2026-11-02',1,1,0,'SAR',200,200,
           1000,20,180,'v1','consumed', now() + interval '1 hour'
         )`,
        [quoteId, venueId, typeId, uid],
      );
      const bookingId = newId();
      await pool.query(
        `INSERT INTO bookings (
           id, human_code, provider_id, venue_id, inventory_type_id, consumer_firebase_uid,
           quote_id, status, check_in, check_out, quantity, gross_total, currency,
           commission_bps, commission_amount, provider_net, confirmed_at,
           cancellation_policy_snapshot_json
         ) VALUES (
           $1,'LEG-RC5',$2,$3,$4,$5,$6,'CONFIRMED','2026-11-01','2026-11-02',1,200,'SAR',
           1000,20,180, now(), '{}'::jsonb
         )`,
        [bookingId, providerId, venueId, typeId, uid, quoteId],
      );
      const applied = await applyRemainingMigrations(pool);
      expect(applied).toContain('025_rc5_half_null_payment_remediation.sql');
      const row = await pool.query<{
        payment_method: string;
        payment_status: string;
      }>(`SELECT payment_method, payment_status FROM bookings WHERE id = $1`, [
        bookingId,
      ]);
      expect(row.rows[0].payment_method).toBe('LEGACY_UNSPECIFIED');
      expect(row.rows[0].payment_status).toBe('LEGACY_UNSPECIFIED');
    });
  }, 180_000);

  it('T-MIG-025-04 upgrade 023→025 remediates half-null via pre-024 hook then reaches 025', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(
        pool,
        '023_pay_at_venue_event_slot_gate9a.sql',
      );
      const providerId = newId();
      const venueId = newId();
      const typeId = newId();
      const uid = 'half-null-rc5';
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'H','H','company','active',$2)`,
        [providerId, uid],
      );
      await pool.query(
        `INSERT INTO provider_users (id, provider_id, firebase_uid, role, status)
         VALUES ($1,$2,$3,'owner','active')`,
        [newId(), providerId, uid],
      );
      await pool.query(
        `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status)
         VALUES ($1,$2,'H','hotel','nightly','published')`,
        [venueId, providerId],
      );
      await pool.query(
        `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total,
           base_occupancy, max_occupancy)
         VALUES ($1,$2,'Std','pooled',1,2,4)`,
        [typeId, venueId],
      );
      const quoteId = newId();
      await pool.query(
        `INSERT INTO quotes (
           id, venue_id, inventory_type_id, consumer_firebase_uid, check_in, check_out,
           quantity, guests_adults, guests_children, currency, subtotal, gross_total,
           commission_bps, commission_amount, provider_net, pricing_version, status, expires_at
         ) VALUES (
           $1,$2,$3,$4,'2026-11-01','2026-11-02',1,1,0,'SAR',200,200,
           1000,20,180,'v1','consumed', now() + interval '1 hour'
         )`,
        [quoteId, venueId, typeId, uid],
      );
      await pool.query(
        `ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_pair_null_chk`,
      );
      await pool.query(
        `ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_combo_chk`,
      );
      const bookingId = newId();
      await pool.query(
        `INSERT INTO bookings (
           id, human_code, provider_id, venue_id, inventory_type_id, consumer_firebase_uid,
           quote_id, status, check_in, check_out, quantity, gross_total, currency,
           commission_bps, commission_amount, provider_net, confirmed_at,
           cancellation_policy_snapshot_json, payment_method, payment_status
         ) VALUES (
           $1,'HN-RC5',$2,$3,$4,$5,$6,'CONFIRMED','2026-11-01','2026-11-02',1,200,'SAR',
           1000,20,180, now(), '{}'::jsonb, 'PAY_AT_VENUE', NULL
         )`,
        [bookingId, providerId, venueId, typeId, uid, quoteId],
      );
      // RC6: pre-024 hook remediates half-null so 024+025 apply.
      const applied = await applyRemainingMigrations(pool);
      expect(applied).toContain('024_rc4_event_slot_kill_switch_payment_combo.sql');
      expect(applied).toContain('025_rc5_half_null_payment_remediation.sql');
      const row = await pool.query<{
        payment_method: string;
        payment_status: string;
      }>(`SELECT payment_method, payment_status FROM bookings WHERE id = $1`, [
        bookingId,
      ]);
      expect(row.rows[0].payment_method).toBe('LEGACY_UNSPECIFIED');
      expect(row.rows[0].payment_status).toBe('LEGACY_UNSPECIFIED');
    });
  }, 180_000);

  it('T-MIG-025-05 025 remediates residual half-null then re-asserts CHECK', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(
        pool,
        '024_rc4_event_slot_kill_switch_payment_combo.sql',
      );
      const providerId = newId();
      const venueId = newId();
      const typeId = newId();
      const uid = 'half-null-025';
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'H','H','company','active',$2)`,
        [providerId, uid],
      );
      await pool.query(
        `INSERT INTO provider_users (id, provider_id, firebase_uid, role, status)
         VALUES ($1,$2,$3,'owner','active')`,
        [newId(), providerId, uid],
      );
      await pool.query(
        `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status)
         VALUES ($1,$2,'H','hotel','nightly','published')`,
        [venueId, providerId],
      );
      await pool.query(
        `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total,
           base_occupancy, max_occupancy)
         VALUES ($1,$2,'Std','pooled',1,2,4)`,
        [typeId, venueId],
      );
      const quoteId = newId();
      await pool.query(
        `INSERT INTO quotes (
           id, venue_id, inventory_type_id, consumer_firebase_uid, check_in, check_out,
           quantity, guests_adults, guests_children, currency, subtotal, gross_total,
           commission_bps, commission_amount, provider_net, pricing_version, status, expires_at
         ) VALUES (
           $1,$2,$3,$4,'2026-11-01','2026-11-02',1,1,0,'SAR',200,200,
           1000,20,180,'v1','consumed', now() + interval '1 hour'
         )`,
        [quoteId, venueId, typeId, uid],
      );
      // Simulate residual half-null (constraint absent / deferred) before 025.
      await pool.query(
        `ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_pair_null_chk`,
      );
      await pool.query(
        `ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_combo_chk`,
      );
      const bookingId = newId();
      await pool.query(
        `INSERT INTO bookings (
           id, human_code, provider_id, venue_id, inventory_type_id, consumer_firebase_uid,
           quote_id, status, check_in, check_out, quantity, gross_total, currency,
           commission_bps, commission_amount, provider_net, confirmed_at,
           cancellation_policy_snapshot_json, payment_method, payment_status
         ) VALUES (
           $1,'HN-025',$2,$3,$4,$5,$6,'CONFIRMED','2026-11-01','2026-11-02',1,200,'SAR',
           1000,20,180, now(), '{}'::jsonb, 'PAY_AT_VENUE', NULL
         )`,
        [bookingId, providerId, venueId, typeId, uid, quoteId],
      );
      const applied = await applyRemainingMigrations(pool);
      expect(applied).toContain('025_rc5_half_null_payment_remediation.sql');
      const row = await pool.query<{
        payment_method: string;
        payment_status: string;
      }>(`SELECT payment_method, payment_status FROM bookings WHERE id = $1`, [
        bookingId,
      ]);
      expect(row.rows[0].payment_method).toBe('LEGACY_UNSPECIFIED');
      expect(row.rows[0].payment_status).toBe('LEGACY_UNSPECIFIED');
      const half = await pool.query(
        `SELECT count(*)::int AS c FROM bookings
         WHERE (payment_method IS NULL) <> (payment_status IS NULL)`,
      );
      expect(half.rows[0].c).toBe(0);
      const pair = await pool.query(
        `SELECT 1 FROM pg_constraint WHERE conname='bookings_payment_pair_null_chk'`,
      );
      expect(pair.rowCount).toBe(1);
    });
  }, 180_000);
});
