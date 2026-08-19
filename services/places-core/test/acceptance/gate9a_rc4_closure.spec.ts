/**
 * Gate 9A RC4 — kill switch, migration 024, hold expiry atomicity, PAV cancel.
 */
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
import { HoldService } from '../../src/modules/booking/application/hold.service';
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

describe('gate9a_rc4_closure', () => {
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
    const uid = `g9a-rc4-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `RC4-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `RC4 ${tag}`,
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
      .set('Idempotency-Key', `rc4-hold-${tag}`)
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
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

  it('T-MIG-024-01 migration 024 file ordered after 023', async () => {
    const dir = path.join(__dirname, '../../db/migrations');
    const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
    expect(files).toContain('024_rc4_event_slot_kill_switch_payment_combo.sql');
    expect(
      files.indexOf('024_rc4_event_slot_kill_switch_payment_combo.sql'),
    ).toBeGreaterThan(files.indexOf('023_pay_at_venue_event_slot_gate9a.sql'));
  });

  it('T-MIG-024-02 palace/hall discovery+booking stay closed (026 opens provider content only)', async () => {
    const r = await db.query<{
      venue_type: string;
      d: boolean;
      b: boolean;
      p: boolean;
    }>(
      `SELECT venue_type, enabled_for_discovery AS d, enabled_for_booking AS b,
              enabled_for_provider AS p
       FROM venue_type_capabilities
       WHERE venue_type IN ('wedding_palace', 'event_hall')`,
    );
    expect(r.rowCount).toBe(2);
    for (const row of r.rows) {
      expect(row.d).toBe(false);
      expect(row.b).toBe(false);
      expect(row.p).toBe(true);
    }
  });

  it('T-MIG-024-03 half-null payment pair rejected', async () => {
    const providerId = await seedProvider(db, 'half-null', 'HN');
    const seeded = await seedVenue(db, providerId, {
      name: 'HN',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2026-12-01': '100' } }],
    });
    await expect(
      db.query(
        `INSERT INTO bookings (
           id, provider_id, venue_id, inventory_type_id, consumer_firebase_uid,
           status, check_in, check_out, quantity, gross_total, currency,
           payment_method, payment_status, commission_bps, commission_amount, provider_net
         ) VALUES (
           $1,$2,$3,$4,'x','HOLDING','2026-12-01','2026-12-02',1,100,'SAR',
           'PAY_AT_VENUE',NULL,1000,10,90
         )`,
        [newId(), providerId, seeded.venueId, seeded.types.R],
      ),
    ).rejects.toThrow();
  });

  it('T-KILL-01 event_slot quote rejected when kill switch OFF', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const providerId = await seedProvider(db, 'kill-own', 'Kill');
    const seeded = await seedVenue(db, providerId, {
      name: 'Kill Hotel',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2026-12-01': '100' } }],
    });
    await db.query(`UPDATE venues SET booking_mode = 'event_slot' WHERE id = $1`, [
      seeded.venueId,
    ]);
    const res = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('kill-uid'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.R,
        checkIn: '2026-12-01',
        checkOut: '2026-12-01',
        quantity: 1,
        guestsAdults: 1,
        slotCode: 'evening',
      });
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('EVENT_SLOT_DISABLED');
  });

  it('T-KILL-02 wedding_palace allowed as content; event_slot booking still refused', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const providerId = await seedProvider(db, 'prov-kill', 'PK');
    const content = await request(app.getHttpServer())
      .post('/v1/provider/venues')
      .set('Authorization', auth('prov-kill', 'placesProvider'))
      .send({
        providerId,
        name: 'Palace',
        venueType: 'wedding_palace',
        bookingMode: 'nightly',
      });
    expect(content.status).toBe(201);

    const slotted = await request(app.getHttpServer())
      .post('/v1/provider/venues')
      .set('Authorization', auth('prov-kill', 'placesProvider'))
      .send({
        providerId,
        name: 'Palace Slots',
        venueType: 'wedding_palace',
        bookingMode: 'event_slot',
      });
    expect([400, 403]).toContain(slotted.status);
  });

  it('T-KILL-03 event_slot availability rejected when kill switch OFF', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const providerId = await seedProvider(db, 'kill-av', 'KillAv');
    const seeded = await seedVenue(db, providerId, {
      name: 'Kill Av Hotel',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2026-12-01': '100' } }],
    });
    await db.query(`UPDATE venues SET booking_mode = 'event_slot' WHERE id = $1`, [
      seeded.venueId,
    ]);
    const res = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth('kill-av-uid'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.R,
        checkIn: '2026-12-01',
        checkOut: '2026-12-02',
        quantity: 1,
      });
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('EVENT_SLOT_DISABLED');
  });

  it('T-KILL-04 event_slot hold rejected when kill switch OFF', async () => {
    const providerId = await seedProvider(db, 'kill-hold', 'KillHold');
    const seeded = await seedVenue(db, providerId, {
      name: 'Kill Hold Hotel',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2026-12-01': '100' } }],
    });
    // Create quote while nightly, then flip venue to event_slot and disable kill switch path.
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('kill-hold-uid'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.R,
        checkIn: '2026-12-01',
        checkOut: '2026-12-02',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    await db.query(`UPDATE venues SET booking_mode = 'event_slot' WHERE id = $1`, [
      seeded.venueId,
    ]);
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const res = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth('kill-hold-uid'))
      .set('Idempotency-Key', 'rc4-kill-hold')
      .send({ quoteId: quote.body.quoteId, quantity: 1 });
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('EVENT_SLOT_DISABLED');
  });

  it('T-KILL-05 historical GET/cancel remain allowed under kill switch', async () => {
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    const h = await quoteHold('kill-hist');
    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-kill-hist-conf')
      .send({ holdId: h.holdId })
      .expect(201);
    const get = await request(app.getHttpServer())
      .get(`/v1/bookings/${conf.body.bookingId}`)
      .set('Authorization', auth(h.uid))
      .expect(200);
    expect(get.body.id).toBe(conf.body.bookingId);
    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${conf.body.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-kill-hist-can')
      .send({ reason: 'changed plans' })
      .expect(200);
    expect(cancel.body.paymentStatus).toBe('VOIDED');
  });

  it('T-EXP-01 extend then expiry refuses (atomic expires_at)', async () => {
    const h = await quoteHold('exp-ext');
    // Force near-expiry then extend by bumping expires_at (simulates extend race)
    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '1 second' WHERE id = $1`,
      [h.holdId],
    );
    // Extend atomically past now
    await db.query(
      `UPDATE booking_holds SET expires_at = now() + interval '10 minutes',
          extensions = 1 WHERE id = $1 AND status = 'ACTIVE'`,
      [h.holdId],
    );
    const holds = app.get(HoldService);
    const expired = await holds.expireOne(h.holdId);
    expect(expired).toBe(false);
    const st = await db.query<{ status: string }>(
      `SELECT status FROM booking_holds WHERE id = $1`,
      [h.holdId],
    );
    expect(st.rows[0].status).toBe('ACTIVE');
  });

  it('T-EXP-02 due hold expires with status=ACTIVE AND expires_at<=now()', async () => {
    const h = await quoteHold('exp-due');
    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '5 seconds' WHERE id = $1`,
      [h.holdId],
    );
    const holds = app.get(HoldService);
    const expired = await holds.expireOne(h.holdId);
    expect(expired).toBe(true);
    const st = await db.query<{ status: string }>(
      `SELECT status FROM booking_holds WHERE id = $1`,
      [h.holdId],
    );
    expect(st.rows[0].status).toBe('EXPIRED');
  });

  it('T-PAV-RC4-01 nightly confirm→cancel VOIDED + zero financials', async () => {
    const before = await finCounts();
    const h = await quoteHold('pav-can');
    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-pav-conf')
      .send({ holdId: h.holdId })
      .expect(201);
    expect(conf.body.paymentStatus).toBe('DUE_AT_VENUE');
    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${conf.body.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-pav-can')
      .send({ reason: 'test' })
      .expect(200);
    expect(cancel.body.status).toBe('CANCELLED');
    expect(cancel.body.paymentStatus).toBe('VOIDED');
    expect(cancel.body.refundId).toBeUndefined();
    const after = await finCounts();
    expect(after).toEqual(before);
  });

  it('T-PAV-RC4-02 dual cancel stable (idempotent)', async () => {
    const h = await quoteHold('dual-can');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-dual-conf')
      .send({ holdId: h.holdId })
      .expect(201);
    const a = request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-dual-can-a')
      .send({ reason: 'a' });
    const b = request(app.getHttpServer())
      .post(`/v1/bookings/${h.bookingId}/cancel`)
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc4-dual-can-b')
      .send({ reason: 'b' });
    const results = await Promise.all([a, b]);
    const oks = results.filter((r) => r.status === 200);
    expect(oks.length).toBeGreaterThanOrEqual(1);
    const st = await db.query<{ status: string; payment_status: string }>(
      `SELECT status, payment_status FROM bookings WHERE id = $1`,
      [h.bookingId],
    );
    expect(st.rows[0].status).toBe('CANCELLED');
    expect(st.rows[0].payment_status).toBe('VOIDED');
  });

  it('T-INV-RC4-01 inventory create requires Idempotency-Key', async () => {
    const providerId = await seedProvider(db, 'inv-own', 'INV');
    const seeded = await seedVenue(db, providerId, {
      name: 'Inv',
      venueType: 'hotel',
      types: [{ name: 'A', qty: 1, nights: { '2026-12-01': '90' } }],
    });
    const noKey = await request(app.getHttpServer())
      .post('/v1/provider/inventory-types')
      .set('Authorization', auth('inv-own', 'placesProvider'))
      .send({
        providerId,
        venueId: seeded.venueId,
        code: 'B',
        labelAr: 'ب',
        inventoryModel: 'pooled',
        quantityTotal: 2,
        baseOccupancy: 2,
        maxOccupancy: 4,
      });
    expect(noKey.status).toBe(400);
    const ok = await request(app.getHttpServer())
      .post('/v1/provider/inventory-types')
      .set('Authorization', auth('inv-own', 'placesProvider'))
      .set('Idempotency-Key', 'inv-create-1')
      .send({
        providerId,
        venueId: seeded.venueId,
        code: 'B',
        labelAr: 'ب',
        inventoryModel: 'pooled',
        quantityTotal: 2,
        baseOccupancy: 2,
        maxOccupancy: 4,
      })
      .expect(201);
    expect(ok.body.inventoryModel).toBe('pooled');
    expect(ok.body.quantityTotal).toBe(2);
    expect(ok.body.code).toBe('B');
  });
});

describe('gate9a_mig_024_upgrades', () => {
  it('T-MIG-024-04 fresh 001→024 installs all', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(
        pool,
        '024_rc4_event_slot_kill_switch_payment_combo.sql',
      );
      const mig = await pool.query(
        `SELECT id FROM schema_migrations WHERE id LIKE '02%' ORDER BY id`,
      );
      expect(mig.rows.map((r) => r.id)).toEqual(
        expect.arrayContaining([
          '022_pre_provider_rev4_corrective.sql',
          '023_pay_at_venue_event_slot_gate9a.sql',
          '024_rc4_event_slot_kill_switch_payment_combo.sql',
        ]),
      );
      const caps = await pool.query(
        `SELECT enabled_for_booking FROM venue_type_capabilities
         WHERE venue_type = 'wedding_palace'`,
      );
      expect(caps.rows[0].enabled_for_booking).toBe(false);
    });
  }, 180_000);

  it('T-MIG-024-05 upgrade 022→024 data-bearing', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '022_pre_provider_rev4_corrective.sql');
      // Seed legacy booking shape pre-023
      const providerId = newId();
      const venueId = newId();
      const typeId = newId();
      const uid = 'upgrade-uid';
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
           $1,'LEG-RC4',$2,$3,$4,$5,$6,'CONFIRMED','2026-11-01','2026-11-02',1,200,'SAR',
           1000,20,180, now(), '{}'::jsonb
         )`,
        [bookingId, providerId, venueId, typeId, uid, quoteId],
      );
      await applyRemainingMigrations(pool);
      const row = await pool.query<{
        payment_method: string;
        payment_status: string;
      }>(`SELECT payment_method, payment_status FROM bookings WHERE id = $1`, [
        bookingId,
      ]);
      expect(row.rows[0].payment_method).toBe('LEGACY_UNSPECIFIED');
      expect(row.rows[0].payment_status).toBe('LEGACY_UNSPECIFIED');
      const pair = await pool.query(
        `SELECT 1 FROM pg_constraint WHERE conname='bookings_payment_pair_null_chk'`,
      );
      expect(pair.rowCount).toBe(1);
    });
  }, 180_000);

  it('T-MIG-024-06 upgrade 023→024', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(
        pool,
        '023_pay_at_venue_event_slot_gate9a.sql',
      );
      const applied = await applyRemainingMigrations(pool);
      expect(applied).toContain(
        '024_rc4_event_slot_kill_switch_payment_combo.sql',
      );
    });
  }, 180_000);
});
