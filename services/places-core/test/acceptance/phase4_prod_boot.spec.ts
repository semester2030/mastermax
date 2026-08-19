/**
 * Phase 4 RC2 — REAL production boot under NODE_ENV=production + PAYMENT_PROVIDER=pav_only.
 *
 * Unlike a unit assertion on assertProductionGuards(), this compiles and boots the
 * actual AppModule DI graph (PgService, ports, guards, workers gated off) with the
 * production env frozen at import time, proving the app starts and wires the
 * PavOnly payment adapter — and that stub payment is refused at load.
 * Findings: F-V2-004 (production boot), F-V3-006/007 (PAV finance guards).
 */
import 'reflect-metadata';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Pool } from 'pg';
import path from 'path';
import { migrate } from '../../src/shared/database/migrate';
import { loadEnv } from '../../src/shared/config/env';
import { PAYMENT_PORT } from '../../src/modules/payments/domain/payment.port';
import { PavOnlyPaymentAdapter } from '../../src/modules/payments/infrastructure/payment-pav-only.adapter';
import { SMS_PORT } from '../../src/modules/notifications/domain/sms.port';
import { SmsHttpAdapter } from '../../src/modules/notifications/infrastructure/sms-http.adapter';

const ENV_KEYS = [
  'NODE_ENV',
  'AUTH_MODE',
  'PAYMENT_PROVIDER',
  'PLACES_RUN_MODE',
  'PLACES_RUN_WORKERS',
  'CF_ACCOUNT_ID',
  'CF_IMAGES_TOKEN',
  'CF_IMAGES_HASH',
  'CF_STREAM_TOKEN',
  'CF_STREAM_SUBDOMAIN',
  'PLACES_PAY_AT_VENUE_ENABLED',
  'PLACES_PAY_AT_VENUE_PROD_APPROVED',
  'PLACES_OTP_FIXED_CODE_ENABLED',
  'DATABASE_URL',
] as const;

describe('phase4_prod_boot', () => {
  let app: INestApplication;
  let db: Pool;
  const saved: Record<string, string | undefined> = {};

  beforeAll(async () => {
    for (const k of ENV_KEYS) saved[k] = process.env[k];

    // Real production configuration — pav_only + firebase, CF configured, PAV
    // enabled and prod-approved, workers gated to API mode (no timers in test).
    process.env.NODE_ENV = 'production';
    process.env.AUTH_MODE = 'firebase';
    process.env.PAYMENT_PROVIDER = 'pav_only';
    process.env.PLACES_RUN_MODE = 'api';
    delete process.env.PLACES_RUN_WORKERS;
    process.env.CF_ACCOUNT_ID = 'prod-acc';
    process.env.CF_IMAGES_TOKEN = 'prod-img-token';
    process.env.CF_IMAGES_HASH = 'prod-img-hash';
    process.env.CF_STREAM_TOKEN = 'prod-stream-token';
    process.env.CF_STREAM_SUBDOMAIN = 'prod-sub';
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROD_APPROVED = 'true';
    delete process.env.PLACES_OTP_FIXED_CODE_ENABLED;
    process.env.DATABASE_URL =
      process.env.DATABASE_URL ?? 'postgresql://127.0.0.1:5432/places_core_ci';

    // Ensure the CI schema exists (idempotent; never destructive here).
    db = new Pool({ connectionString: process.env.DATABASE_URL });
    await migrate(db, path.resolve(__dirname, '../../db/migrations'));

    // AppModule freezes env at import time → import AFTER setting production env.
    const { AppModule } = await import('../../src/app.module');
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
    for (const k of ENV_KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  });

  it('T-BOOT-PROD-REAL-01 AppModule boots in production and wires the PavOnly + HTTP-SMS adapters', () => {
    expect(app).toBeDefined();
    const port = app.get(PAYMENT_PORT);
    expect(port).toBeInstanceOf(PavOnlyPaymentAdapter);
    // Production must select the real HTTP SMS adapter, never the stub (F-V2-010).
    const sms = app.get(SMS_PORT);
    expect(sms).toBeInstanceOf(SmsHttpAdapter);
  });

  it('T-BOOT-PROD-REAL-02 booted PavOnly adapter refuses PSP with zero DB effect', async () => {
    const before = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payments`,
    );
    const port = app.get<PavOnlyPaymentAdapter>(PAYMENT_PORT);
    await expect(
      port.createIntent({
        paymentId: 'x',
        operationId: 'y',
        amount: '10.00',
        currency: 'SAR',
        holdId: 'z',
      }),
    ).rejects.toMatchObject({ code: 'PAYMENT_REQUIRED' });
    const after = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payments`,
    );
    expect(after.rows[0].c).toBe(before.rows[0].c);
  });

  it('T-BOOT-PROD-REAL-03 loadEnv fails closed for stub payment / stub auth in production', () => {
    const prevPay = process.env.PAYMENT_PROVIDER;
    const prevAuth = process.env.AUTH_MODE;
    try {
      process.env.PAYMENT_PROVIDER = 'stub';
      expect(() => loadEnv()).toThrow(/PAYMENT_PROVIDER=stub/);
      process.env.PAYMENT_PROVIDER = 'pav_only';
      process.env.AUTH_MODE = 'stub';
      expect(() => loadEnv()).toThrow(/AUTH_MODE=stub/);
    } finally {
      process.env.PAYMENT_PROVIDER = prevPay;
      process.env.AUTH_MODE = prevAuth;
    }
  });
});
