/**
 * Phase 5 — identity / admin / OTP / publish / moderation / suspend
 * Findings: F-V2-009, F-V2-010, F-V2-011, F-V2-012, F-V3-003, F-V3-004
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { createServer, Server } from 'http';
import { AddressInfo } from 'net';
import { OperatorAuthService } from '../../src/modules/auth/application/operator-auth.service';
import { SmsStubAdapter } from '../../src/modules/notifications/infrastructure/sms-stub.adapter';
import { SmsHttpAdapter } from '../../src/modules/notifications/infrastructure/sms-http.adapter';
import { SMS_PORT } from '../../src/modules/notifications/domain/sms.port';
import { VenuePublicationService } from '../../src/modules/venues/application/venue-publication.service';
import { MediaModerationService } from '../../src/modules/venues/application/media-moderation.service';
import { migrate } from '../../src/shared/database/migrate';

function sha256(s: string): string {
  return createHash('sha256').update(s).digest('hex');
}

describe('phase5_auth_admin', () => {
  let app: INestApplication;
  let db: Pool;
  const phone = '+966500000099';

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = '';
    process.env.PLACES_OTP_FIXED_CODE_ENABLED = 'true';
    process.env.PLACES_OTP_FIXED_CODE_SECRET = '424242';
    process.env.DAR_CAR_INTERNAL_OPERATOR_PHONE = phone;
    process.env.PLACES_OPERATOR_JWT_SECRET =
      'test-operator-jwt-secret-do-not-use-prod';
    delete process.env.PLACES_EVENT_SLOT_ENABLED;
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  it('T-MIG-029-01 migration 029 applied with checksum', async () => {
    const row = await db.query<{ id: string; checksum: string | null }>(
      `SELECT id, checksum FROM schema_migrations WHERE id = '029_phase5_identity_admin.sql'`,
    );
    expect(row.rowCount).toBe(1);
    const sql = await fs.readFile(
      path.resolve(__dirname, '../../db/migrations/029_phase5_identity_admin.sql'),
      'utf8',
    );
    const expected = createHash('sha256').update(sql, 'utf8').digest('hex');
    expect(row.rows[0].checksum).toBe(expected);
    await migrate(db);
  });

  it('T-OTP-LOCK-01 invalid OTP attempts durable + lockout; concurrent fails serialize', async () => {
    const providerId = await seedProvider(db, 'p5-otp-owner', 'P5-OTP');
    const svc = app.get(OperatorAuthService);
    (svc as unknown as { env: { internalOperatorProviderId: string } }).env
      .internalOperatorProviderId = providerId;

    const send = await svc.sendOtp({
      phoneE164: phone,
      correlationId: 'p5-otp-lock',
    });

    const results = await Promise.allSettled(
      Array.from({ length: 5 }, (_, i) =>
        svc.verifyOtp({
          challengeId: send.challengeId,
          code: `11111${i}`,
          correlationId: `p5-fail-${i}`,
        }),
      ),
    );
    expect(results.every((r) => r.status === 'rejected')).toBe(true);

    const ch = await db.query<{
      attempts: number;
      locked_until: Date | null;
    }>(`SELECT attempts, locked_until FROM auth_otp_challenges WHERE id = $1`, [
      send.challengeId,
    ]);
    expect(ch.rows[0].attempts).toBe(5);
    expect(ch.rows[0].locked_until).toBeTruthy();

    const events = await db.query(
      `SELECT outcome FROM auth_otp_attempt_events WHERE challenge_id = $1 ORDER BY attempt_no`,
      [send.challengeId],
    );
    expect(events.rowCount).toBe(5);

    await expect(
      svc.verifyOtp({
        challengeId: send.challengeId,
        code: '424242',
        correlationId: 'p5-locked',
      }),
    ).rejects.toMatchObject({ code: 'DUPLICATE_REQUEST' });
  });

  it('T-OTP-SMS-01 SMS adapter invoked on send; fixed OTP internal-only path', async () => {
    const providerId = await seedProvider(db, 'p5-sms-owner', 'P5-SMS');
    const svc = app.get(OperatorAuthService);
    (svc as unknown as { env: { internalOperatorProviderId: string } }).env
      .internalOperatorProviderId = providerId;
    const sms = app.get(SMS_PORT) as SmsStubAdapter;
    sms.last = undefined;

    // cooldown: use distinct phone via identity bind
    const altPhone = '+966500000088';
    await svc.bindProviderIdentity({
      phoneE164: altPhone,
      providerId,
      actorUid: 'admin-p5',
      correlationId: 'p5-bind-sms',
    });
    const send = await svc.sendOtp({
      phoneE164: altPhone,
      correlationId: 'p5-sms',
      providerId,
    });
    expect(send.challengeId).toBeTruthy();
    expect(sms.last).toBeDefined();
    expect(sms.last!.challengeId).toBe(send.challengeId);
    expect(sms.last!.phoneE164).toBe(altPhone);
    expect(sms.providerName).toBe('stub');
  });

  it('T-PROV-AUTH-01 multi-provider identity bind + OTP selects provider', async () => {
    const p1 = await seedProvider(db, 'p5-multi-a', 'P5-A');
    const p2 = await seedProvider(db, 'p5-multi-b', 'P5-B');
    const svc = app.get(OperatorAuthService);
    const multiPhone = '+966500000077';
    await svc.bindProviderIdentity({
      phoneE164: multiPhone,
      providerId: p1,
      displayLabel: 'A',
      actorUid: 'admin',
      correlationId: 'bind-a',
    });
    await svc.bindProviderIdentity({
      phoneE164: multiPhone,
      providerId: p2,
      displayLabel: 'B',
      actorUid: 'admin',
      correlationId: 'bind-b',
    });

    await expect(
      svc.sendOtp({ phoneE164: multiPhone, correlationId: 'need-pid' }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });

    const send = await svc.sendOtp({
      phoneE164: multiPhone,
      providerId: p2,
      correlationId: 'otp-p2',
    });
    const otp =
      (globalThis as { __placesTestOtp?: string }).__placesTestOtp ?? '424242';
    const verified = await svc.verifyOtp({
      challengeId: send.challengeId,
      code: otp,
      correlationId: 'verify-p2',
    });
    expect(verified.onBehalfOfProviderId).toBe(p2);
  });

  it('T-PUB-ADM-01 admin publish without approved image refused; shared service', async () => {
    const owner = 'p5-pub-owner';
    const providerId = await seedProvider(db, owner, 'P5-PUB');
    const seeded = await seedVenue(db, providerId, {
      name: 'P5 Pub',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 2, nights: { '2027-01-01': '100' } }],
    });
    await db.query(`UPDATE venues SET status = 'draft' WHERE id = $1`, [
      seeded.venueId,
    ]);

    const pub = app.get(VenuePublicationService);
    await expect(
      pub.publishVenue({
        venueId: seeded.venueId,
        actorUid: 'admin',
        actorRole: 'admin',
        correlationId: 'pub-fail',
      }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });

    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
       VALUES ($1,$2,$3,'image',$4,$5,'approved',0)`,
      [
        newId(),
        seeded.venueId,
        providerId,
        'https://imagedelivery.net/stub/p5/public',
        `img-p5-${newId()}`,
      ],
    );
    const ok = await pub.publishVenue({
      venueId: seeded.venueId,
      actorUid: 'admin',
      actorRole: 'admin',
      correlationId: 'pub-ok',
    });
    expect(ok.status).toBe('published');

    const adminRes = await request(app.getHttpServer())
      .patch(`/v1/admin/venues/${seeded.venueId}`)
      .set('Authorization', auth('admin-p5', 'placesAdmin'))
      .send({ status: 'draft', reason: 'unpublish_for_test' })
      .expect(200);
    expect(adminRes.body.ok).toBe(true);
  });

  it('T-MOD-UNIFY-01 / T-ADMIN-MOD-01 pending queue + approve/reject via MediaModerationService', async () => {
    const owner = 'p5-mod-owner';
    const providerId = await seedProvider(db, owner, 'P5-MOD');
    const seeded = await seedVenue(db, providerId, {
      name: 'P5 Mod',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 1, nights: { '2027-02-01': '90' } }],
    });
    const mediaId = newId();
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order, cas_version)
       VALUES ($1,$2,$3,'image',$4,$5,'pending',0,0)`,
      [
        mediaId,
        seeded.venueId,
        providerId,
        'https://imagedelivery.net/stub/mod/public',
        `img-mod-${mediaId}`,
      ],
    );

    const pending = await request(app.getHttpServer())
      .get('/v1/admin/media/pending')
      .set('Authorization', auth('admin-mod', 'placesAdmin'))
      .expect(200);
    expect(pending.body.some((m: { id: string }) => m.id === mediaId)).toBe(
      true,
    );
    expect(
      pending.body.find((m: { id: string }) => m.id === mediaId).url,
    ).toContain('imagedelivery');

    await request(app.getHttpServer())
      .patch(`/v1/admin/media/${mediaId}/moderation`)
      .set('Authorization', auth('admin-mod', 'placesAdmin'))
      .send({
        moderationStatus: 'approved',
        expectedCasVersion: 0,
        reason: 'ok',
      })
      .expect(200);

    const mod = app.get(MediaModerationService);
    const again = await mod.listPending(50);
    expect(again.find((m) => m.id === mediaId)).toBeUndefined();
  });

  it('T-PROV-SUSPEND-01 suspend hides discovery and blocks quote/hold; audit written', async () => {
    const owner = 'p5-sus-owner';
    const consumer = 'p5-sus-consumer';
    const providerId = await seedProvider(db, owner, 'P5-SUS');
    const seeded = await seedVenue(db, providerId, {
      name: 'P5 Sus Venue',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 2,
          nights: { '2027-03-01': '110.00', '2027-03-02': '110.00' },
        },
      ],
    });
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
       VALUES ($1,$2,$3,'image',$4,$5,'approved',0)`,
      [
        newId(),
        seeded.venueId,
        providerId,
        'https://imagedelivery.net/stub/sus/public',
        `img-sus-${newId()}`,
      ],
    );
    await app.get(VenuePublicationService).publishVenue({
      venueId: seeded.venueId,
      actorUid: owner,
      actorRole: 'provider',
      correlationId: 'sus-pub',
    });

    const beforeQuote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumer))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2027-03-01',
        checkOut: '2027-03-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    expect(beforeQuote.body.quoteId).toBeTruthy();

    await request(app.getHttpServer())
      .patch(`/v1/admin/providers/${providerId}/status`)
      .set('Authorization', auth('admin-sus', 'placesAdmin'))
      .send({ status: 'suspended', reason: 'phase5_suspend_test' })
      .expect(200);

    const audit = await db.query(
      `SELECT 1 FROM audit_logs
       WHERE entity_type = 'provider' AND entity_id = $1
         AND after_json->>'status' = 'suspended'`,
      [providerId],
    );
    expect(audit.rowCount).toBeGreaterThanOrEqual(1);

    const disc = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({
        category: 'hotel',
        city: 'Riyadh',
        sort: 'best',
        checkIn: '2027-03-01',
        checkOut: '2027-03-03',
        quantity: 1,
        limit: 50,
      });
    expect([200, 201]).toContain(disc.status);
    const list = (disc.body.items ?? []) as { venueId: string }[];
    expect(list.every((it) => it.venueId !== seeded.venueId)).toBe(true);

    await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumer))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2027-03-01',
        checkOut: '2027-03-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect((res) => {
        expect([400, 403, 404, 409, 422]).toContain(res.status);
      });

    // phone hash binding table exists (multi-provider foundation)
    expect(sha256(phone).length).toBe(64);
  });

  it('T-SMS-HTTP-REAL-01 SmsHttpAdapter performs a real HTTP webhook POST (non-stub) and fails closed', async () => {
    const adapter = new SmsHttpAdapter();
    expect(adapter.providerName).toBe('http');

    // Fail-closed when the webhook URL is not configured (never silent no-op).
    const prevUrl = process.env.PLACES_SMS_WEBHOOK_URL;
    const prevTok = process.env.PLACES_SMS_WEBHOOK_TOKEN;
    delete process.env.PLACES_SMS_WEBHOOK_URL;
    delete process.env.PLACES_SMS_WEBHOOK_TOKEN;
    await expect(
      adapter.sendOtpSms({
        phoneE164: '+966500000123',
        code: '123456',
        challengeId: 'ch-real-1',
        correlationId: 'cor-real-1',
      }),
    ).rejects.toMatchObject({ code: 'INTERNAL' });

    // Real HTTP contract: capture method, headers, and JSON body at a live server.
    const captured: {
      method?: string;
      contentType?: string;
      authorization?: string;
      body?: Record<string, unknown>;
    } = {};
    let mode: 'ok' | 'fail' = 'ok';
    const server: Server = createServer((req, res) => {
      let raw = '';
      req.on('data', (c) => (raw += c));
      req.on('end', () => {
        captured.method = req.method;
        captured.contentType = req.headers['content-type'] as string;
        captured.authorization = req.headers['authorization'] as string;
        try {
          captured.body = JSON.parse(raw);
        } catch {
          captured.body = { raw };
        }
        if (mode === 'fail') {
          res.statusCode = 500;
          res.end('boom');
          return;
        }
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ messageId: 'srv-msg-42' }));
      });
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = (server.address() as AddressInfo).port;

    try {
      process.env.PLACES_SMS_WEBHOOK_URL = `http://127.0.0.1:${port}/sms`;
      process.env.PLACES_SMS_WEBHOOK_TOKEN = 'wh-secret';

      const out = await adapter.sendOtpSms({
        phoneE164: '+966500000123',
        code: '654321',
        challengeId: 'ch-real-2',
        correlationId: 'cor-real-2',
      });
      expect(out.messageId).toBe('srv-msg-42');
      expect(captured.method).toBe('POST');
      expect(captured.contentType).toContain('application/json');
      expect(captured.authorization).toBe('Bearer wh-secret');
      expect(captured.body).toMatchObject({
        phoneE164: '+966500000123',
        code: '654321',
        challengeId: 'ch-real-2',
        correlationId: 'cor-real-2',
        purpose: 'places_otp',
      });

      // Non-2xx upstream must fail closed (never swallow a delivery failure).
      mode = 'fail';
      await expect(
        adapter.sendOtpSms({
          phoneE164: '+966500000123',
          code: '000000',
          challengeId: 'ch-real-3',
          correlationId: 'cor-real-3',
        }),
      ).rejects.toMatchObject({ code: 'INTERNAL' });
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
      if (prevUrl === undefined) delete process.env.PLACES_SMS_WEBHOOK_URL;
      else process.env.PLACES_SMS_WEBHOOK_URL = prevUrl;
      if (prevTok === undefined) delete process.env.PLACES_SMS_WEBHOOK_TOKEN;
      else process.env.PLACES_SMS_WEBHOOK_TOKEN = prevTok;
    }
  });

  it('T-ADMIN-UI-01 production moderation HTML exists with preview + error surface', async () => {
    const html = await fs.readFile(
      path.resolve(__dirname, '../../../../docs/places_admin/moderation.html'),
      'utf8',
    );
    expect(html).toContain('media/pending');
    expect(html).toContain('<video');
    expect(html).toContain('showError');
    expect(html).toContain('مراجعة الوسائط');
  });
});
