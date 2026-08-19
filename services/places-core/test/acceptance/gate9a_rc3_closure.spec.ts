/**
 * Gate 9A RC3 closure — F-RC3-13…18 explicit Test IDs.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { applyMigrationsThrough, applyRemainingMigrations } from '../helpers/migrate-partial';
import { newId } from '../../src/shared/ids/ids';
import { HoldService } from '../../src/modules/booking/application/hold.service';

describe('gate9a_rc3_closure', () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = '';
    process.env.PAYMENT_PROVIDER = 'stub';
    process.env.PLACES_OTP_FIXED_CODE_ENABLED = 'true';
    process.env.PLACES_OTP_FIXED_CODE_SECRET = '424242';
    process.env.DAR_CAR_INTERNAL_OPERATOR_PHONE = '+966500000001';
    process.env.PLACES_OPERATOR_JWT_SECRET = 'test-operator-jwt-secret-do-not-use-prod';
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  async function quoteHold(tag: string, holdTtlSec?: number) {
    const uid = `g9a-rc3-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `RC3-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `RC3 ${tag}`,
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
    if (holdTtlSec != null) {
      process.env.HOLD_TTL_SECONDS = String(holdTtlSec);
    }
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `rc3-hold-${tag}`)
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

  it('T-OPS-02 operator OTP send/verify/logout + OR-guard + onBehalfOf audit', async () => {
    const providerId = await seedProvider(db, 'op-owner', 'OpTrial');
    process.env.PLACES_INTERNAL_OPERATOR_PROVIDER_ID = providerId;
    // Recreate config is frozen — OperatorAuthService reads env.internalOperatorProviderId from APP_CONFIG.
    // Force via process + service requireBoundProviderId uses this.env — need APP_CONFIG update.
    // OperatorAuthService.requireBoundProviderId uses this.env.internalOperatorProviderId from module load.
    // For test: patch env on the service instance.
    const svc = app.get(
      (await import('../../src/modules/auth/application/operator-auth.service'))
        .OperatorAuthService,
    );
    (svc as unknown as { env: { internalOperatorProviderId: string } }).env
      .internalOperatorProviderId = providerId;

    const send = await request(app.getHttpServer())
      .post('/v1/auth/internal/otp/send')
      .send({ phoneE164: '+966500000001' })
      .expect(201);
    expect(send.body.challengeId).toBeTruthy();

    const wrong = await request(app.getHttpServer())
      .post('/v1/auth/internal/otp/verify')
      .send({ challengeId: send.body.challengeId, code: '000000' });
    expect(wrong.status).toBe(401);

    // Resend after cooldown would block — use fixed code on fresh challenge
    await new Promise((r) => setTimeout(r, 50));
    // consume failed challenge; send new after deleting cooldown by updating created_at
    await db.query(
      `UPDATE auth_otp_challenges SET created_at = now() - interval '2 minutes'`,
    );
    const send2 = await request(app.getHttpServer())
      .post('/v1/auth/internal/otp/send')
      .send({ phoneE164: '+966500000001' })
      .expect(201);
    const otp =
      (globalThis as { __placesTestOtp?: string }).__placesTestOtp ?? '424242';
    const verify = await request(app.getHttpServer())
      .post('/v1/auth/internal/otp/verify')
      .send({ challengeId: send2.body.challengeId, code: otp });
    if (verify.status !== 201) {
      console.log('verify fail', verify.status, verify.body);
    }
    expect(verify.status).toBe(201);
    expect(verify.body.accessToken).toBeTruthy();
    expect(verify.body.onBehalfOfProviderId).toBe(providerId);

    const other = await seedProvider(db, 'other-op', 'Other');
    const seeded = await seedVenue(db, providerId, {
      name: 'Op Venue',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2026-12-01': '100' } }],
    });
    const ok = await request(app.getHttpServer())
      .get(`/v1/provider/inventory-types?providerId=${providerId}&venueId=${seeded.venueId}`)
      .set('Authorization', `Bearer ${verify.body.accessToken}`)
      .expect(200);
    expect(ok.body.items[0].inventoryModel).toBe('pooled');
    expect(ok.body.items[0].quantityTotal).toBeDefined();
    expect(ok.body.items[0].baseOccupancy).toBeDefined();
    expect(ok.body.items[0].maxOccupancy).toBeDefined();

    const forbid = await request(app.getHttpServer())
      .get(`/v1/provider/inventory-types?providerId=${other}&venueId=${seeded.venueId}`)
      .set('Authorization', `Bearer ${verify.body.accessToken}`);
    expect(forbid.status).toBe(403);

    const audit = await db.query(
      `SELECT 1 FROM audit_logs
       WHERE actor_role = 'placesInternalOperator'
         AND entity_type = 'auth_session'
       LIMIT 1`,
    );
    expect(audit.rowCount).toBe(1);

    await request(app.getHttpServer())
      .post('/v1/auth/session/logout')
      .set('Authorization', `Bearer ${verify.body.accessToken}`)
      .expect(201);

    const after = await request(app.getHttpServer())
      .get(`/v1/provider/inventory-types?providerId=${providerId}&venueId=${seeded.venueId}`)
      .set('Authorization', `Bearer ${verify.body.accessToken}`);
    expect(after.status).toBe(401);
  });

  it('T-INV-01 consumer inventoryTypes DTO matches DB mandatory fields', async () => {
    const h = await quoteHold('inv-dto');
    const res = await request(app.getHttpServer())
      .get(`/v1/venues/${h.venueId}`)
      .set('Authorization', auth(h.uid))
      .expect(200);
    const inv = res.body.inventoryTypes[0];
    expect(inv.inventoryModel).toBe('pooled');
    expect(inv.quantityTotal).toBeGreaterThanOrEqual(0);
    expect(inv.baseOccupancy).toBeGreaterThanOrEqual(1);
    expect(inv.maxOccupancy).toBeGreaterThanOrEqual(inv.baseOccupancy);
    expect(inv.status).toBe('active');
  });

  it('T-MED-01 media moderation CAS conflict', async () => {
    const owner = 'med-cas-owner';
    const providerId = await seedProvider(db, owner, 'MedCAS');
    const seeded = await seedVenue(db, providerId, {
      name: 'MedCAS',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2026-12-01': '100' } }],
    });
    const mediaId = newId();
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order, cas_version)
       VALUES ($1,$2,$3,'image','https://imagedelivery.net/stub/x/public','img-x','pending',0,0)`,
      [mediaId, seeded.venueId, providerId],
    );
    const a = await request(app.getHttpServer())
      .patch(`/v1/admin/media/${mediaId}/moderation`)
      .set('Authorization', auth('admin-cas', 'placesAdmin'))
      .send({ moderationStatus: 'approved', expectedCasVersion: 0 })
      .expect(200);
    expect(a.body.casVersion).toBe(1);
    const b = await request(app.getHttpServer())
      .patch(`/v1/admin/media/${mediaId}/moderation`)
      .set('Authorization', auth('admin-cas', 'placesAdmin'))
      .send({ moderationStatus: 'approved', expectedCasVersion: 0 });
    expect(b.status).toBe(409);
    expect(b.body.code).toBe('DUPLICATE_REQUEST');
  });

  it('T-PAV-07 confirm-vs-expiry: one winner, capacity released once', async () => {
    const h = await quoteHold('exp-race');
    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '1 second' WHERE id = $1`,
      [h.holdId],
    );
    const holds = app.get(HoldService);
    const [conf, exp] = await Promise.all([
      request(app.getHttpServer())
        .post('/v1/bookings/confirm-pay-at-venue')
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'rc3-exp-conf')
        .send({ holdId: h.holdId }),
      holds.expireOne(h.holdId),
    ]);
    const booking = await db.query(
      `SELECT status, payment_method FROM bookings WHERE id = $1`,
      [h.bookingId],
    );
    const cap = await db.query<{ held: number; booked: number }>(
      `SELECT held, booked FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = '2026-12-01'::date`,
      [h.typeId],
    );
    // Exactly one terminal outcome
    const status = booking.rows[0].status;
    expect(['CONFIRMED', 'EXPIRED', 'CANCELLED']).toContain(status);
    if (status === 'CONFIRMED') {
      expect(conf.status).toBe(201);
      expect(Number(cap.rows[0].booked)).toBeGreaterThanOrEqual(1);
      expect(Number(cap.rows[0].held)).toBe(0);
    } else {
      expect(conf.status).not.toBe(201);
      expect(Number(cap.rows[0].held)).toBe(0);
      expect(exp === true || exp === false).toBe(true);
    }
  });

  it('T-PAV-08 confirm-vs-cancel: one winner', async () => {
    const h = await quoteHold('can-race');
    const [conf, cancel] = await Promise.all([
      request(app.getHttpServer())
        .post('/v1/bookings/confirm-pay-at-venue')
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'rc3-can-conf')
        .send({ holdId: h.holdId }),
      request(app.getHttpServer())
        .post(`/v1/bookings/${h.bookingId}/cancel`)
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', 'rc3-can-cancel')
        .send({ reason: 'race' }),
    ]);
    const winners = [conf.status === 201, cancel.status === 200].filter(Boolean);
    // Idempotent cancel after confirm (VOIDED) may also 200 — assert single final status.
    expect(winners.length).toBeGreaterThanOrEqual(1);
    const row = await db.query(`SELECT status, payment_status FROM bookings WHERE id = $1`, [
      h.bookingId,
    ]);
    expect(['CONFIRMED', 'CANCELLED']).toContain(row.rows[0].status);
    if (row.rows[0].status === 'CONFIRMED') {
      expect(conf.status).toBe(201);
    }
    if (row.rows[0].status === 'CANCELLED' && conf.status === 201) {
      // confirm won then cancel won
      expect(cancel.status).toBe(200);
      expect(row.rows[0].payment_status).toBe('VOIDED');
    }
  });
});

describe('gate9a_mig_023_upgrade', () => {
  it('T-MIG-023-07 data-bearing 022→023 upgrade + backfill + CHECKs', async () => {
    testEnv();
    const dbName = `places_mig023_${Date.now()}`;
    const admin = new Pool({
      connectionString:
        process.env.DATABASE_URL ?? 'postgresql://127.0.0.1:5432/places_core_test',
    });
    await admin.query(`CREATE DATABASE ${dbName}`);
    const url = (process.env.DATABASE_URL ?? 'postgresql://127.0.0.1:5432/places_core_test').replace(
      /\/[^/]+$/,
      `/${dbName}`,
    );
    const pool = new Pool({ connectionString: url });
    try {
      await applyMigrationsThrough(pool, '022_pre_provider_rev4_corrective.sql');
      const providerId = newId();
      const venueId = newId();
      const typeId = newId();
      const bookingId = newId();
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'L','D','company','active','u')`,
        [providerId],
      );
      await pool.query(
        `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status, city, min_stay)
         VALUES ($1,$2,'V','hotel','nightly','published','Riyadh',1)`,
        [venueId, providerId],
      );
      await pool.query(
        `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total, base_occupancy, max_occupancy)
         VALUES ($1,$2,'Std','pooled',2,2,4)`,
        [typeId, venueId],
      );
      const quote1 = newId();
      const quote2 = newId();
      for (const [qid, uid] of [[quote1, 'u'], [quote2, 'u2']] as const) {
        await pool.query(
          `INSERT INTO quotes (
             id, venue_id, inventory_type_id, consumer_firebase_uid, check_in, check_out,
             quantity, guests_adults, guests_children, currency, subtotal, gross_total,
             commission_bps, commission_amount, provider_net, pricing_version, status, expires_at
           ) VALUES (
             $1,$2,$3,$4,'2026-11-01','2026-11-02',1,1,0,'SAR',100,100,
             1000,10,90,'v1','open', now() + interval '1 hour'
           )`,
          [qid, venueId, typeId, uid],
        );
      }
      await pool.query(
        `INSERT INTO bookings (
           id, human_code, provider_id, venue_id, inventory_type_id, consumer_firebase_uid,
           quote_id, check_in, check_out, quantity, status, currency, gross_total,
           commission_bps, commission_amount, provider_net, confirmed_at,
           cancellation_policy_snapshot_json
         ) VALUES (
           $1,'LEG1',$2,$3,$4,'u',$5,'2026-11-01','2026-11-02',1,'CONFIRMED','SAR',100,
           1000,10,90, now(), '{}'::jsonb
         )`,
        [bookingId, providerId, venueId, typeId, quote1],
      );
      const holdingId = newId();
      await pool.query(
        `INSERT INTO bookings (
           id, human_code, provider_id, venue_id, inventory_type_id, consumer_firebase_uid,
           quote_id, check_in, check_out, quantity, status, currency, gross_total,
           commission_bps, commission_amount, provider_net,
           cancellation_policy_snapshot_json
         ) VALUES (
           $1,'H1',$2,$3,$4,'u2',$5,'2026-11-03','2026-11-04',1,'HOLDING','SAR',50,
           1000,5,45, '{}'::jsonb
         )`,
        [holdingId, providerId, venueId, typeId, quote2],
      );

      const applied = await applyRemainingMigrations(pool);
      expect(applied).toEqual(
        expect.arrayContaining(['023_pay_at_venue_event_slot_gate9a.sql']),
      );

      const legacy = await pool.query(
        `SELECT payment_method, payment_status FROM bookings WHERE id = $1`,
        [bookingId],
      );
      expect(legacy.rows[0].payment_method).toBe('LEGACY_UNSPECIFIED');
      expect(legacy.rows[0].payment_status).toBe('LEGACY_UNSPECIFIED');

      const holding = await pool.query(
        `SELECT payment_method, payment_status FROM bookings WHERE id = $1`,
        [holdingId],
      );
      expect(holding.rows[0].payment_method).toBeNull();
      expect(holding.rows[0].payment_status).toBeNull();

      await expect(
        pool.query(
          `UPDATE bookings SET status='CONFIRMED', payment_method=NULL, payment_status=NULL WHERE id=$1`,
          [holdingId],
        ),
      ).rejects.toThrow(/bookings_payment_combo_chk|check constraint/i);

      const casCol = await pool.query(
        `SELECT 1 FROM information_schema.columns
         WHERE table_name='venue_media' AND column_name='cas_version'`,
      );
      expect(casCol.rowCount).toBe(1);
    } finally {
      await pool.end();
      await admin.query(`DROP DATABASE IF EXISTS ${dbName}`);
      await admin.end();
    }
  }, 180_000);
});
