export type AuthMode = 'stub' | 'firebase';
/** stub = test/dev only; pav_only = production-safe (no PSP until Gate 12). */
export type PaymentProvider = 'stub' | 'pav_only';

export interface AppEnv {
  nodeEnv: string;
  host: string;
  port: number;
  databaseUrl: string;
  authMode: AuthMode;
  paymentProvider: PaymentProvider;
  firebaseProjectId: string;
  stubWebhookSecret: string;
  holdTtlSeconds: number;
  quoteTtlSeconds: number;
  defaultCommissionBps: number;
  logLevel: string;
  webhookMaxSkewSeconds: number;
  /** Shared Cloudflare account (same as DAR CAR Functions secrets). */
  cfAccountId: string;
  cfImagesToken: string;
  cfImagesHash: string;
  cfStreamToken: string;
  cfStreamSubdomain: string;
  /** When true, use real CloudflareMediaAdapter; else stub (dev/test). */
  cloudflareMediaEnabled: boolean;
  payAtVenueEnabled: boolean;
  payAtVenueProviderAllowlist: string[];
  payAtVenueProdApproved: boolean;
  /** Default false — RC4 temporary kill switch for all event_slot booking paths. */
  eventSlotEnabled: boolean;
  internalOperatorProviderId: string;
  otpFixedCodeEnabled: boolean;
}

function req(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (!v) {
    throw new Error(`Missing environment variable ${name}`);
  }
  return v;
}

/**
 * Fail-closed production guards (Gate 3A + Phase 4):
 * - AUTH_MODE=stub forbidden when NODE_ENV=production
 * - PAYMENT_PROVIDER=stub forbidden when NODE_ENV=production
 * - Production must use PAYMENT_PROVIDER=pav_only (real PSP is Gate 12)
 * No silent fallback to stub in production.
 */
export function assertProductionGuards(
  nodeEnv: string,
  authMode: AuthMode,
  paymentProvider: string,
): void {
  if (nodeEnv !== 'production') {
    return;
  }
  if (authMode === 'stub') {
    throw new Error('FATAL: AUTH_MODE=stub is forbidden when NODE_ENV=production');
  }
  if (paymentProvider === 'stub') {
    throw new Error(
      'FATAL: PAYMENT_PROVIDER=stub is forbidden when NODE_ENV=production',
    );
  }
  if (paymentProvider !== 'pav_only') {
    throw new Error(
      `FATAL: NODE_ENV=production requires PAYMENT_PROVIDER=pav_only (got ${paymentProvider})`,
    );
  }
}

export function assertPayAtVenueProductionGuards(env: AppEnv): void {
  if (env.nodeEnv !== 'production') return;
  if (env.otpFixedCodeEnabled) {
    throw new Error(
      'FATAL: PLACES_OTP_FIXED_CODE_ENABLED is forbidden in production',
    );
  }
  if (env.payAtVenueEnabled && !env.payAtVenueProdApproved) {
    throw new Error(
      'FATAL: Pay-at-Venue enabled in production without PLACES_PAY_AT_VENUE_PROD_APPROVED',
    );
  }
}

export function loadEnv(): AppEnv {
  const hold = Number(process.env.HOLD_TTL_SECONDS ?? '720');
  const quote = Number(process.env.QUOTE_TTL_SECONDS ?? '900');
  if (hold < 300 || hold > 1200) {
    throw new Error('HOLD_TTL_SECONDS must be 300-1200');
  }
  const nodeEnv = process.env.NODE_ENV ?? 'development';
  const authMode = (process.env.AUTH_MODE ??
    (nodeEnv === 'production' ? 'firebase' : 'stub')) as AuthMode;
  const rawPayment =
    process.env.PAYMENT_PROVIDER ??
    (nodeEnv === 'production' ? 'pav_only' : 'stub');
  if (rawPayment !== 'stub' && rawPayment !== 'pav_only') {
    throw new Error(
      `FATAL: unsupported PAYMENT_PROVIDER=${rawPayment} (allowed: stub|pav_only)`,
    );
  }
  const paymentProvider = rawPayment as PaymentProvider;
  assertProductionGuards(nodeEnv, authMode, paymentProvider);

  const stubSecret =
    process.env.STUB_WEBHOOK_SECRET ??
    (nodeEnv === 'test' ? 'test-stub-secret' : undefined);
  if (authMode === 'stub' && !stubSecret) {
    throw new Error(
      'STUB_WEBHOOK_SECRET is required when AUTH_MODE=stub (no silent default outside documented test)',
    );
  }

  const cfAccountId = process.env.CF_ACCOUNT_ID ?? '';
  const cfImagesToken = process.env.CF_IMAGES_TOKEN ?? '';
  const cfImagesHash = process.env.CF_IMAGES_HASH ?? '';
  const cfStreamToken = process.env.CF_STREAM_TOKEN ?? '';
  const cfStreamSubdomain = process.env.CF_STREAM_SUBDOMAIN ?? '';

  if (nodeEnv === 'production') {
    for (const [name, value] of [
      ['CF_ACCOUNT_ID', cfAccountId],
      ['CF_IMAGES_TOKEN', cfImagesToken],
      ['CF_IMAGES_HASH', cfImagesHash],
      ['CF_STREAM_TOKEN', cfStreamToken],
      ['CF_STREAM_SUBDOMAIN', cfStreamSubdomain],
    ] as const) {
      if (!value.trim()) {
        throw new Error(`FATAL: ${name} is required when NODE_ENV=production`);
      }
    }
  }

  const cloudflareMediaEnabled =
    nodeEnv === 'production' || process.env.CLOUDFLARE_MEDIA_ENABLED === 'true';

  const env: AppEnv = {
    nodeEnv,
    host: process.env.HOST ?? '0.0.0.0',
    port: Number(process.env.PORT ?? '8080'),
    databaseUrl: req('DATABASE_URL'),
    authMode,
    paymentProvider,
    firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? 'example',
    stubWebhookSecret: stubSecret ?? 'unused-when-firebase',
    holdTtlSeconds: hold,
    quoteTtlSeconds: quote,
    defaultCommissionBps: Number(process.env.DEFAULT_COMMISSION_BPS ?? '1000'),
    logLevel: process.env.LOG_LEVEL ?? 'info',
    webhookMaxSkewSeconds: Number(process.env.WEBHOOK_MAX_SKEW_SECONDS ?? '300'),
    cfAccountId,
    cfImagesToken,
    cfImagesHash,
    cfStreamToken,
    cfStreamSubdomain,
    cloudflareMediaEnabled,
    payAtVenueEnabled: process.env.PLACES_PAY_AT_VENUE_ENABLED === 'true',
    payAtVenueProviderAllowlist: (
      process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST ?? ''
    )
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    payAtVenueProdApproved:
      process.env.PLACES_PAY_AT_VENUE_PROD_APPROVED === 'true',
    eventSlotEnabled: process.env.PLACES_EVENT_SLOT_ENABLED === 'true',
    internalOperatorProviderId:
      process.env.PLACES_INTERNAL_OPERATOR_PROVIDER_ID ?? '',
    otpFixedCodeEnabled: process.env.PLACES_OTP_FIXED_CODE_ENABLED === 'true',
  };
  assertPayAtVenueProductionGuards(env);
  return env;
}
