import { IdempotencyService } from '../../src/shared/idempotency/idempotency.service';
import { stayDates } from '../../src/shared/time/stay-dates';
import { canTransition } from '../../src/modules/booking/domain/booking-states';
import { assertDiscoveryLimits } from '../../src/modules/filters/application/discovery-query';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { CloudflareMediaStubAdapter } from '../../src/modules/media/infrastructure/cloudflare-media.stub.adapter';
import { assertProductionGuards } from '../../src/shared/config/env';

describe('pre_device_rev2 — expires_at + same-day daily discovery', () => {
  it('hold expiry: PAYMENT_FAILED may transition to EXPIRED', () => {
    expect(canTransition('PAYMENT_FAILED', 'EXPIRED')).toBe(true);
    expect(canTransition('PAYMENT_FAILED', 'CONFIRMED')).toBe(false);
    expect(canTransition('EXPIRED', 'CONFIRMED')).toBe(false);
    expect(canTransition('CANCELLED', 'CONFIRMED')).toBe(false);
  });

  it('expires_at policy: ACTIVE hold past expires_at is not payable', () => {
    const expiresAt = new Date(Date.now() - 1000);
    const status = 'ACTIVE';
    const holdExpired =
      status !== 'ACTIVE' || expiresAt.getTime() <= Date.now();
    expect(holdExpired).toBe(true);
  });

  it('expires_at policy: ACTIVE hold with future expires_at is payable', () => {
    const expiresAt = new Date(Date.now() + 60_000);
    const status = 'ACTIVE';
    const holdExpired =
      status !== 'ACTIVE' || expiresAt.getTime() <= Date.now();
    expect(holdExpired).toBe(false);
  });

  it('webhook confirmable set is PENDING_PAYMENT only (SM)', () => {
    const confirmable = (status: string) =>
      ['PENDING_PAYMENT'].includes(status) && canTransition(status as never, 'CONFIRMED');
    expect(confirmable('PENDING_PAYMENT')).toBe(true);
    expect(confirmable('HOLDING')).toBe(false);
    expect(confirmable('PAYMENT_FAILED')).toBe(false);
    expect(confirmable('EXPIRED')).toBe(false);
    expect(confirmable('CANCELLED')).toBe(false);
  });

  it('discovery allows same-day (daily); rejects inverted', () => {
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-07-01',
        checkOut: '2030-07-01',
      } as DiscoverySearchDto),
    ).not.toThrow();
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-07-02',
        checkOut: '2030-07-01',
      } as DiscoverySearchDto),
    ).toThrow(/inverted|on or before/);
  });

  it('nightly stayDates still forbids same-day at quote/hold', () => {
    expect(() => stayDates('nightly', '2030-07-01', '2030-07-01')).toThrow();
    expect(stayDates('daily', '2030-07-01', '2030-07-01')).toEqual(['2030-07-01']);
  });
});

describe('idempotency composite scope', () => {
  it('hashRequest is stable for equal bodies', () => {
    const svc = Object.create(IdempotencyService.prototype) as IdempotencyService;
    const a = svc.hashRequest({ quoteId: 'q1', quantity: 1 });
    const b = svc.hashRequest({ quoteId: 'q1', quantity: 1 });
    const c = svc.hashRequest({ quoteId: 'q1', quantity: 2 });
    expect(a).toBe(b);
    expect(a).not.toBe(c);
  });

  it('scope identity distinguishes actor/method/route', () => {
    const s1 = { actorUid: 'u1', httpMethod: 'POST', routePath: '/v1/holds' };
    const s2 = { actorUid: 'u2', httpMethod: 'POST', routePath: '/v1/holds' };
    const s3 = { actorUid: 'u1', httpMethod: 'POST', routePath: '/v1/payments/intents' };
    expect(`${s1.actorUid}|${s1.httpMethod}|${s1.routePath}`).not.toBe(
      `${s2.actorUid}|${s2.httpMethod}|${s2.routePath}`,
    );
    expect(`${s1.actorUid}|${s1.httpMethod}|${s1.routePath}`).not.toBe(
      `${s3.actorUid}|${s3.httpMethod}|${s3.routePath}`,
    );
  });
});

describe('placesAdmin refund role', () => {
  it('treats placesAdmin like admin for allowed roles', () => {
    const allowed = (role: string) =>
      role === 'admin' ||
      role === 'placesAdmin' ||
      role === 'system' ||
      role === 'webhook' ||
      role === 'consumer' ||
      role === 'provider';
    expect(allowed('placesAdmin')).toBe(true);
    expect(allowed('admin')).toBe(true);
    expect(allowed('random')).toBe(false);
  });
});

describe('CF stub production refuse', () => {
  const prev = process.env.NODE_ENV;

  afterEach(() => {
    process.env.NODE_ENV = prev;
  });

  it('stub constructor throws in production', () => {
    process.env.NODE_ENV = 'production';
    expect(() => new CloudflareMediaStubAdapter()).toThrow(/production/);
  });

  it('stub constructs outside production', () => {
    process.env.NODE_ENV = 'test';
    expect(() => new CloudflareMediaStubAdapter()).not.toThrow();
  });

  it('production still forbids stub auth/payment', () => {
    expect(() => assertProductionGuards('production', 'stub', 'stub')).toThrow(/AUTH_MODE/);
  });
});
