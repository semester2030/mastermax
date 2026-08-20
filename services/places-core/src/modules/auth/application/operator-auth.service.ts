import { createHmac, createHash, randomInt, timingSafeEqual } from 'crypto';
import { Inject, Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { APP_CONFIG } from '../../../shared/config/app-config';
import { AppEnv } from '../../../shared/config/env';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { newId } from '../../../shared/ids/ids';
import { AuditService } from '../../audit/application/audit.service';
import { SMS_PORT, SmsPort } from '../../notifications/domain/sms.port';

const CHALLENGE_TTL_SEC = 300;
const MAX_ATTEMPTS = 5;
const LOCKOUT_SEC = 900;
const SEND_COOLDOWN_SEC = 60;
/** Wave1 internal staging: 8h so operators are not bounced mid-form. */
const SESSION_TTL_SEC = Number(process.env.PLACES_OPERATOR_SESSION_TTL_SEC ?? 28800);

function b64url(buf: Buffer | string): string {
  const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return b.toString('base64url');
}

function sha256(s: string): string {
  return createHash('sha256').update(s).digest('hex');
}

export type OperatorJwtPayload = {
  iss: 'places-core';
  aud: 'places-provider-web';
  sub: string;
  claim: 'placesInternalOperator';
  onBehalfOfProviderId: string;
  jti: string;
  iat: number;
  exp: number;
};

@Injectable()
export class OperatorAuthService {
  constructor(
    private readonly pg: PgService,
    @Inject(APP_CONFIG) private readonly env: AppEnv,
    private readonly audit: AuditService,
    @Inject(SMS_PORT) private readonly sms: SmsPort,
  ) {}

  private requireJwtSecret(): string {
    const secret = (process.env.PLACES_OPERATOR_JWT_SECRET ?? '').trim();
    if (!secret) {
      if (this.env.nodeEnv === 'test') {
        return 'test-operator-jwt-secret-do-not-use-prod';
      }
      throw new AppError(
        ErrorCodes.INTERNAL,
        'PLACES_OPERATOR_JWT_SECRET not configured',
        undefined,
        true,
      );
    }
    return secret;
  }

  private envFallbackPhone(): string | null {
    const phone = (process.env.DAR_CAR_INTERNAL_OPERATOR_PHONE ?? '').trim();
    return phone || null;
  }

  private envFallbackProviderId(): string | null {
    return this.env.internalOperatorProviderId?.trim() || null;
  }

  /**
   * Resolve active provider bindings for a phone.
   * Prefer auth_provider_identities; fall back to staging env single binding.
   */
  async resolveProvidersForPhone(phoneE164: string): Promise<
    Array<{ providerId: string; displayLabel: string | null }>
  > {
    const phoneHash = sha256(phoneE164);
    let boundRows: Array<{ provider_id: string; display_label: string | null }> =
      [];
    try {
      const bound = await this.pg.query<{
        provider_id: string;
        display_label: string | null;
      }>(
        `SELECT provider_id, display_label FROM auth_provider_identities
         WHERE phone_hash = $1 AND status = 'active'
         ORDER BY created_at ASC`,
        [phoneHash],
      );
      boundRows = bound.rows;
    } catch (err) {
      // Wave1 local DBs may still be on pre-029 schema. Fall through to env bind.
      const code = (err as { code?: string }).code;
      if (code !== "42P01") throw err;
    }
    if (boundRows.length) {
      return boundRows.map((r) => ({
        providerId: r.provider_id,
        displayLabel: r.display_label,
      }));
    }
    const expected = this.envFallbackPhone();
    const providerId = this.envFallbackProviderId();
    if (expected && providerId && phoneE164 === expected) {
      return [{ providerId, displayLabel: 'env_fallback' }];
    }
    return [];
  }

  async bindProviderIdentity(input: {
    phoneE164: string;
    providerId: string;
    displayLabel?: string;
    actorUid: string;
    correlationId: string;
  }): Promise<{ id: string }> {
    const id = newId();
    const phoneHash = sha256(input.phoneE164);
    await this.pg.tx(async (c: PoolClient) => {
      await c.query(
        `INSERT INTO auth_provider_identities
           (id, phone_hash, provider_id, status, display_label)
         VALUES ($1,$2,$3,'active',$4)
         ON CONFLICT (phone_hash, provider_id) DO UPDATE
           SET status = 'active', display_label = COALESCE(EXCLUDED.display_label, auth_provider_identities.display_label),
               updated_at = now()`,
        [id, phoneHash, input.providerId, input.displayLabel ?? null],
      );
      await this.audit.write(
        {
          actorUid: input.actorUid,
          actorRole: 'placesAdmin',
          entityType: 'auth_provider_identity',
          entityId: id,
          after: { providerId: input.providerId, bound: true },
          correlationId: input.correlationId,
        },
        c,
      );
    });
    return { id };
  }

  async sendOtp(input: {
    phoneE164: string;
    correlationId: string;
    /** Required when phone maps to multiple providers. */
    providerId?: string;
  }): Promise<{
    challengeId: string;
    expiresInSec: number;
    providers?: Array<{ providerId: string; displayLabel: string | null }>;
  }> {
    const bindings = await this.resolveProvidersForPhone(input.phoneE164);
    if (!bindings.length) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid phone');
    }
    let providerId = input.providerId;
    if (!providerId) {
      if (bindings.length > 1) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          'providerId required when phone is bound to multiple providers',
          { providers: bindings },
        );
      }
      providerId = bindings[0].providerId;
    } else if (!bindings.some((b) => b.providerId === providerId)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid phone');
    }

    const phoneHash = sha256(input.phoneE164);
    const recent = await this.pg.query<{ created_at: Date }>(
      `SELECT created_at FROM auth_otp_challenges
       WHERE phone_hash = $1
       ORDER BY created_at DESC LIMIT 1`,
      [phoneHash],
    );
    if (recent.rowCount) {
      const ageMs = Date.now() - new Date(recent.rows[0].created_at).getTime();
      if (ageMs < SEND_COOLDOWN_SEC * 1000) {
        throw new AppError(
          ErrorCodes.DUPLICATE_REQUEST,
          'OTP send cooldown active',
        );
      }
    }

    const operatorPhone = this.envFallbackPhone();
    const isInternalOperator =
      Boolean(operatorPhone) && input.phoneE164 === operatorPhone;

    const fixed =
      process.env.PLACES_OTP_FIXED_CODE_ENABLED === 'true' ||
      this.env.otpFixedCodeEnabled;
    if (fixed && this.env.nodeEnv === 'production') {
      throw new AppError(
        ErrorCodes.INTERNAL,
        'Fixed OTP forbidden in production',
        undefined,
        true,
      );
    }
    const operatorDevCode =
      this.env.nodeEnv === 'production' && isInternalOperator
        ? (process.env.PLACES_OTP_FIXED_CODE_SECRET ?? '').trim().slice(0, 6)
        : '';
    const code =
      operatorDevCode.length >= 4
        ? operatorDevCode
        : fixed
          ? (process.env.PLACES_OTP_FIXED_CODE_SECRET ?? '000000').slice(0, 6)
          : String(randomInt(100000, 999999));
    const challengeId = newId();
    const expiresAt = new Date(Date.now() + CHALLENGE_TTL_SEC * 1000);
    const skipSms =
      this.env.nodeEnv === 'production' && isInternalOperator;
    await this.pg.tx(async (c: PoolClient) => {
      await c.query(
        `INSERT INTO auth_otp_challenges
           (id, phone_hash, otp_hash, expires_at, attempts, locked_until, consumed_at, provider_id)
         VALUES ($1,$2,$3,$4,0,NULL,NULL,$5)`,
        [challengeId, phoneHash, sha256(code), expiresAt.toISOString(), providerId],
      );
      await this.audit.write(
        {
          actorUid: 'system',
          actorRole: 'placesInternalOperator',
          entityType: 'auth_otp_challenge',
          entityId: challengeId,
          after: {
            sent: true,
            providerId,
            smsProvider: skipSms ? 'internal_skip' : this.sms.providerName,
          },
          correlationId: input.correlationId,
        },
        c,
      );
    });

    // Production HTTP SMS for everyone except the env-bound developer operator.
    if (!skipSms) {
      await this.sms.sendOtpSms({
        phoneE164: input.phoneE164,
        code,
        correlationId: input.correlationId,
        challengeId,
      });
    }

    if (this.env.nodeEnv === 'test' || fixed) {
      (globalThis as { __placesTestOtp?: string }).__placesTestOtp = code;
    }
    return { challengeId, expiresInSec: CHALLENGE_TTL_SEC };
  }

  async verifyOtp(input: {
    challengeId: string;
    code: string;
    correlationId: string;
  }): Promise<{
    accessToken: string;
    expiresInSec: number;
    onBehalfOfProviderId: string;
  }> {
    const secret = this.requireJwtSecret();

    /**
     * F-V2-009: failed attempts must COMMIT before the Invalid-OTP throw.
     * Phase A TX either (a) commits attempt/lockout then returns fail, or
     * (b) returns locked row snapshot for success path. Never UPDATE attempts
     * inside a TX that later rolls back on throw.
     */
    type PhaseA =
      | { kind: 'fail' }
      | {
          kind: 'ok';
          id: string;
          phone_hash: string;
          attempts: number;
          provider_id: string | null;
        };

    const phaseA = await this.pg.tx(async (c: PoolClient): Promise<PhaseA> => {
      const ch = await c.query<{
        id: string;
        phone_hash: string;
        otp_hash: string;
        expires_at: Date;
        attempts: number;
        locked_until: Date | null;
        consumed_at: Date | null;
        provider_id: string | null;
      }>(
        `SELECT id, phone_hash, otp_hash, expires_at, attempts, locked_until, consumed_at, provider_id
         FROM auth_otp_challenges WHERE id = $1 FOR UPDATE`,
        [input.challengeId],
      );
      if (!ch.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, 'Challenge not found');
      }
      const row = ch.rows[0];
      if (row.consumed_at) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Challenge consumed');
      }
      if (row.locked_until && new Date(row.locked_until) > new Date()) {
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, 'Challenge locked');
      }
      if (new Date(row.expires_at) <= new Date()) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Challenge expired');
      }

      const ok =
        row.otp_hash.length === sha256(input.code).length &&
        timingSafeEqual(
          Buffer.from(row.otp_hash),
          Buffer.from(sha256(input.code)),
        );
      if (!ok) {
        const attempts = row.attempts + 1;
        const lockedUntil =
          attempts >= MAX_ATTEMPTS
            ? new Date(Date.now() + LOCKOUT_SEC * 1000)
            : null;
        await c.query(
          `UPDATE auth_otp_challenges
           SET attempts = $2, locked_until = $3
           WHERE id = $1`,
          [row.id, attempts, lockedUntil?.toISOString() ?? null],
        );
        await c.query(
          `INSERT INTO auth_otp_attempt_events (id, challenge_id, attempt_no, outcome)
           VALUES ($1,$2,$3,$4)`,
          [
            newId(),
            row.id,
            attempts,
            lockedUntil ? 'locked' : 'invalid',
          ],
        );
        return { kind: 'fail' };
      }
      return {
        kind: 'ok',
        id: row.id,
        phone_hash: row.phone_hash,
        attempts: row.attempts,
        provider_id: row.provider_id,
      };
    });

    if (phaseA.kind === 'fail') {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid OTP');
    }

    const providerId =
      phaseA.provider_id ?? this.envFallbackProviderId();
    if (!providerId) {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        'Challenge has no bound provider',
      );
    }

    return this.pg.tx(async (c: PoolClient) => {
      const ch = await c.query<{
        consumed_at: Date | null;
        locked_until: Date | null;
        otp_hash: string;
      }>(
        `SELECT consumed_at, locked_until, otp_hash FROM auth_otp_challenges
         WHERE id = $1 FOR UPDATE`,
        [input.challengeId],
      );
      if (!ch.rowCount || ch.rows[0].consumed_at) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Challenge consumed');
      }
      if (
        ch.rows[0].locked_until &&
        new Date(ch.rows[0].locked_until) > new Date()
      ) {
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, 'Challenge locked');
      }
      const stillOk =
        ch.rows[0].otp_hash.length === sha256(input.code).length &&
        timingSafeEqual(
          Buffer.from(ch.rows[0].otp_hash),
          Buffer.from(sha256(input.code)),
        );
      if (!stillOk) {
        throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid OTP');
      }

      const prov = await c.query<{ id: string; status: string }>(
        `SELECT id, status FROM providers WHERE id = $1 FOR SHARE`,
        [providerId],
      );
      if (!prov.rowCount || prov.rows[0].status !== 'active') {
        throw new AppError(
          ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
          'Bound trial provider not active',
        );
      }

      await c.query(
        `UPDATE auth_otp_challenges SET consumed_at = now() WHERE id = $1`,
        [phaseA.id],
      );
      await c.query(
        `INSERT INTO auth_otp_attempt_events (id, challenge_id, attempt_no, outcome)
         VALUES ($1,$2,$3,'success')`,
        [newId(), phaseA.id, phaseA.attempts + 1],
      );

      const jti = newId();
      const now = Math.floor(Date.now() / 1000);
      const exp = now + SESSION_TTL_SEC;
      const subjectId = `op:${phaseA.phone_hash.slice(0, 16)}`;
      await c.query(
        `INSERT INTO auth_sessions
           (jti, subject_id, claim, on_behalf_of_provider_id, expires_at, revoked_at)
         VALUES ($1,$2,'placesInternalOperator',$3,to_timestamp($4),NULL)`,
        [jti, subjectId, providerId, exp],
      );

      const payload: OperatorJwtPayload = {
        iss: 'places-core',
        aud: 'places-provider-web',
        sub: subjectId,
        claim: 'placesInternalOperator',
        onBehalfOfProviderId: providerId,
        jti,
        iat: now,
        exp,
      };
      const accessToken = this.sign(payload, secret);

      await this.audit.write(
        {
          actorUid: subjectId,
          actorRole: 'placesInternalOperator',
          entityType: 'auth_session',
          entityId: jti,
          after: {
            onBehalfOfProviderId: providerId,
            verified: true,
          },
          correlationId: input.correlationId,
        },
        c,
      );

      return {
        accessToken,
        expiresInSec: SESSION_TTL_SEC,
        onBehalfOfProviderId: providerId,
      };
    });
  }

  async logout(input: {
    jti: string;
    actorUid: string;
    correlationId: string;
  }): Promise<{ ok: true }> {
    await this.pg.tx(async (c: PoolClient) => {
      const upd = await c.query(
        `UPDATE auth_sessions SET revoked_at = now()
         WHERE jti = $1 AND revoked_at IS NULL`,
        [input.jti],
      );
      if (!upd.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, 'Session not found');
      }
      await this.audit.write(
        {
          actorUid: input.actorUid,
          actorRole: 'placesInternalOperator',
          entityType: 'auth_session',
          entityId: input.jti,
          after: { revoked: true },
          correlationId: input.correlationId,
        },
        c,
      );
    });
    return { ok: true };
  }

  sign(payload: OperatorJwtPayload, secret: string): string {
    const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
    const body = b64url(JSON.stringify(payload));
    const sig = createHmac('sha256', secret)
      .update(`${header}.${body}`)
      .digest('base64url');
    return `${header}.${body}.${sig}`;
  }

  async verifyAccessToken(token: string): Promise<{
    uid: string;
    onBehalfOfProviderId: string;
    jti: string;
  }> {
    const secret = this.requireJwtSecret();
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid operator token');
    }
    const [header, body, sig] = parts;
    const expected = createHmac('sha256', secret)
      .update(`${header}.${body}`)
      .digest('base64url');
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid operator token');
    }
    let payload: OperatorJwtPayload;
    try {
      payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    } catch {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid operator token');
    }
    if (
      payload.iss !== 'places-core' ||
      payload.aud !== 'places-provider-web' ||
      payload.claim !== 'placesInternalOperator' ||
      !payload.jti ||
      !payload.onBehalfOfProviderId
    ) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid operator claims');
    }
    if (payload.exp * 1000 <= Date.now()) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Operator session expired');
    }
    const sess = await this.pg.query<{
      revoked_at: Date | null;
      expires_at: Date;
      on_behalf_of_provider_id: string;
    }>(
      `SELECT revoked_at, expires_at, on_behalf_of_provider_id
       FROM auth_sessions WHERE jti = $1`,
      [payload.jti],
    );
    if (!sess.rowCount) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Session unknown');
    }
    if (sess.rows[0].revoked_at) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Session revoked');
    }
    if (new Date(sess.rows[0].expires_at) <= new Date()) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Session expired');
    }
    if (
      sess.rows[0].on_behalf_of_provider_id !== payload.onBehalfOfProviderId
    ) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Session provider mismatch');
    }
    return {
      uid: payload.sub,
      onBehalfOfProviderId: payload.onBehalfOfProviderId,
      jti: payload.jti,
    };
  }
}
