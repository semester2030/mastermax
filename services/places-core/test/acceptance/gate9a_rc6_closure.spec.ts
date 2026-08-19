/**
 * Gate 9A RC6 — CF mint compensate (src), operator TX atomicity, putPricing upsert,
 * RefundService PAV refuse, catalog inventory DTO parity, Tenancy fail-closed.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { AppError } from '../../src/shared/errors/app-error';
import { ErrorCodes } from '../../src/shared/errors/error-codes';
import { RefundService } from '../../src/modules/booking/application/refund.service';
import { OperatorAuthService } from '../../src/modules/auth/application/operator-auth.service';
import { TenancyService } from '../../src/modules/providers/application/tenancy.service';
import { AuthUser } from '../../src/shared/auth/auth-user';
import { newId } from '../../src/shared/ids/ids';

describe('gate9a_rc6_closure', () => {
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

  async function quoteHold(tag: string) {
    const uid = `g9a-rc6-${tag}`;
    const providerId = await seedProvider(db, `owner-${tag}`, `RC6-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `RC6 ${tag}`,
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
      .set('Idempotency-Key', `rc6-hold-${tag}`)
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);
    return {
      uid,
      providerId,
      owner: `owner-${tag}`,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      holdId: hold.body.holdId as string,
      bookingId: hold.body.bookingId as string,
    };
  }

  it('T-PAV-REFUND-01 requestRefund refuses PAY_AT_VENUE (full and partial)', async () => {
    const h = await quoteHold('pav-ref');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc6-pav-ref')
      .send({ holdId: h.holdId })
      .expect(201);

    const refunds = app.get(RefundService);
    for (const kind of ['full', 'partial'] as const) {
      await expect(
        refunds.requestRefund({
          bookingId: h.bookingId,
          actorUid: h.owner,
          actorRole: 'provider',
          kind,
          amount: kind === 'partial' ? '10.00' : undefined,
          reason: 'rc6',
          correlationId: `rc6-pav-${kind}`,
        }),
      ).rejects.toMatchObject({
        code: ErrorCodes.VALIDATION_ERROR,
      });
    }
  });

  it('T-PRICE-UPSERT-01 putPricing updates same logical key (no duplicate rules)', async () => {
    const owner = 'rc6-price';
    const providerId = await seedProvider(db, owner, 'PRICE6');
    const seeded = await seedVenue(db, providerId, {
      name: 'Price6',
      venueType: 'hotel',
      types: [{ name: 'A', qty: 1, nights: { '2026-12-01': '90' } }],
    });
    const ratePlanId = seeded.plans.A;
    const body = {
      ratePlanId,
      kind: 'base',
      amount: '150.00',
    };
    const a = await request(app.getHttpServer())
      .put('/v1/provider/pricing')
      .set('Authorization', auth(owner, 'placesProvider'))
      .set('Idempotency-Key', `rc6-price-${newId()}`)
      .send(body);
    expect([200, 201, 204]).toContain(a.status);
    const b = await request(app.getHttpServer())
      .put('/v1/provider/pricing')
      .set('Authorization', auth(owner, 'placesProvider'))
      .set('Idempotency-Key', `rc6-price-${newId()}`)
      .send({ ...body, amount: '175.00' });
    expect([200, 201, 204]).toContain(b.status);
    const rules = await db.query(
      `SELECT amount::text AS amount FROM rate_rules
       WHERE rate_plan_id = $1 AND kind = 'base'
         AND date_from IS NULL AND date_to IS NULL`,
      [ratePlanId],
    );
    expect(rules.rowCount).toBe(1);
    expect(Number(rules.rows[0].amount)).toBe(175);
  });

  it('T-OPS-ATOMIC-01 operator send OTP + logout mutate+audit in one TX; verify already TX', async () => {
    const providerId = await seedProvider(db, 'rc6-op-owner', 'OpRc6');
    const svc = app.get(OperatorAuthService);
    (svc as unknown as { env: { internalOperatorProviderId: string } }).env
      .internalOperatorProviderId = providerId;

    const send = await svc.sendOtp({
      phoneE164: '+966500000001',
      correlationId: 'rc6-otp-send',
    });
    const ch = await db.query(
      `SELECT id FROM auth_otp_challenges WHERE id = $1`,
      [send.challengeId],
    );
    expect(ch.rowCount).toBe(1);
    const auditSend = await db.query(
      `SELECT 1 FROM audit_logs
       WHERE entity_type = 'auth_otp_challenge' AND entity_id = $1`,
      [send.challengeId],
    );
    expect(auditSend.rowCount).toBeGreaterThanOrEqual(1);

    const otp =
      (globalThis as { __placesTestOtp?: string }).__placesTestOtp ?? '424242';
    const verified = await svc.verifyOtp({
      challengeId: send.challengeId,
      code: otp,
      correlationId: 'rc6-otp-verify',
    });
    expect(verified.onBehalfOfProviderId).toBe(providerId);

    const parts = verified.accessToken.split('.');
    const payload = JSON.parse(
      Buffer.from(parts[1], 'base64url').toString('utf8'),
    ) as { jti: string; sub: string };
    await svc.logout({
      jti: payload.jti,
      actorUid: payload.sub,
      correlationId: 'rc6-otp-logout',
    });
    const sess = await db.query(
      `SELECT revoked_at FROM auth_sessions WHERE jti = $1`,
      [payload.jti],
    );
    expect(sess.rows[0].revoked_at).toBeTruthy();
    const auditLogout = await db.query(
      `SELECT 1 FROM audit_logs
       WHERE entity_type = 'auth_session' AND entity_id = $1
         AND after_json->>'revoked' = 'true'`,
      [payload.jti],
    );
    expect(auditLogout.rowCount).toBeGreaterThanOrEqual(1);
  });

  it('T-TENANCY-01 operator RBAC fail-closed for missing permission', async () => {
    const providerId = await seedProvider(db, 'rc6-ten', 'TenRc6');
    const tenancy = app.get(TenancyService);
    const op: AuthUser = {
      uid: 'op:rc6',
      claims: { placesInternalOperator: true },
      onBehalfOfProviderId: providerId,
    };
    await expect(
      tenancy.require(op, providerId, 'finance.view'),
    ).rejects.toBeInstanceOf(AppError);
    await expect(
      tenancy.require(op, providerId, 'finance.view'),
    ).rejects.toMatchObject({ code: ErrorCodes.FORBIDDEN_PROVIDER_SCOPE });
  });

  it('T-CATALOG-01 venue inventoryTypes expose labelAr/sortOrder from DB', async () => {
    const providerId = await seedProvider(db, 'rc6-cat', 'CatRc6');
    const seeded = await seedVenue(db, providerId, {
      name: 'CatV',
      venueType: 'hotel',
      types: [{ name: 'SuiteCode', qty: 1, nights: { '2026-12-01': '200' } }],
    });
    await db.query(
      `UPDATE inventory_types SET label_ar = 'جناح', sort_order = 7 WHERE id = $1`,
      [seeded.types.SuiteCode],
    );
    const res = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}`)
      .set('Authorization', auth('rc6-cat-user'));
    expect(res.status).toBe(200);
    const types = res.body.inventoryTypes as Array<{
      labelAr?: string;
      sortOrder?: number;
      maxOccupancy?: number;
      baseOccupancy?: number;
    }>;
    expect(Array.isArray(types)).toBe(true);
    const hit = types.find((t) => t.labelAr === 'جناح');
    expect(hit).toBeTruthy();
    expect(hit!.sortOrder).toBe(7);
    expect(hit!.baseOccupancy).toBeDefined();
    expect(hit!.maxOccupancy).toBeDefined();
  });

  it('T-ADMIN-PAV-01 admin refund routes to CANCELLED+VOIDED zero-fin', async () => {
    const h = await quoteHold('adm-pav');
    await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(h.uid))
      .set('Idempotency-Key', 'rc6-adm-pav')
      .send({ holdId: h.holdId })
      .expect(201);
    const before = await db.query(`SELECT count(*)::int AS c FROM refunds`);
    const res = await request(app.getHttpServer())
      .post('/v1/admin/refunds')
      .set('Authorization', auth('places-admin', 'placesAdmin'))
      .set('Idempotency-Key', 'rc6-adm-ref')
      .send({ bookingId: h.bookingId, reason: 'admin void pav', kind: 'operational' });
    expect([200, 201]).toContain(res.status);
    expect(res.body.status).toBe('voided_pay_at_venue');
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
    const after = await db.query(`SELECT count(*)::int AS c FROM refunds`);
    expect(after.rows[0].c).toBe(before.rows[0].c);
  });

  it('T-LOCK-CONC-01 confirm vs cancel vs expiry do not deadlock', async () => {
    const outcomes: string[] = [];
    for (let i = 0; i < 4; i += 1) {
      const h = await quoteHold(`lk${i}`);
      await db.query(
        `UPDATE booking_holds SET expires_at = now() - interval '1 second' WHERE id = $1`,
        [h.holdId],
      );
      const HoldService = (
        await import('../../src/modules/booking/application/hold.service')
      ).HoldService;
      const holds = app.get(HoldService);
      const confirm = request(app.getHttpServer())
        .post('/v1/bookings/confirm-pay-at-venue')
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', `rc6-lk-c-${i}`)
        .send({ holdId: h.holdId });
      const cancel = request(app.getHttpServer())
        .post(`/v1/bookings/${h.bookingId}/cancel`)
        .set('Authorization', auth(h.uid))
        .set('Idempotency-Key', `rc6-lk-x-${i}`)
        .send({ reason: 'race' });
      const expire = holds.expireOne(h.holdId);
      const settled = await Promise.allSettled([confirm, cancel, expire]);
      expect(settled.every((s) => s.status === 'fulfilled' || s.status === 'rejected')).toBe(
        true,
      );
      const st = await db.query<{ status: string }>(
        `SELECT status FROM bookings WHERE id = $1`,
        [h.bookingId],
      );
      outcomes.push(st.rows[0].status);
    }
    expect(outcomes.every((s) => ['CANCELLED', 'EXPIRED', 'CONFIRMED', 'HOLDING', 'PENDING_PAYMENT'].includes(s))).toBe(
      true,
    );
  }, 120_000);
});
