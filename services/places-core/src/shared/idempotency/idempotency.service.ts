import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { AppError } from '../errors/app-error';
import { ErrorCodes } from '../errors/error-codes';
import { sha256Hex } from '../ids/ids';
import { PgService } from '../database/pg.service';

export interface IdempotentRecord {
  responseCode: number;
  responseBody: unknown;
}

/** Composite idempotency scope (migration 020 PK). */
export interface IdempotencyScope {
  actorUid: string;
  httpMethod: string;
  routePath: string;
}

@Injectable()
export class IdempotencyService {
  constructor(private readonly pg: PgService) {}

  hashRequest(body: unknown): string {
    return sha256Hex(JSON.stringify(body ?? {}));
  }

  async begin(
    key: string | undefined,
    requestBody: unknown,
    required: boolean,
    scope: IdempotencyScope,
    client?: PoolClient,
  ): Promise<IdempotentRecord | null> {
    if (!key) {
      if (required) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Idempotency-Key required');
      }
      return null;
    }
    const hash = this.hashRequest(requestBody);
    const sql = `SELECT request_hash, response_code, response_body FROM idempotency_keys
       WHERE actor_uid = $1 AND http_method = $2 AND route_path = $3 AND key = $4
         AND (expires_at IS NULL OR expires_at > now())
       FOR UPDATE`;
    const params = [scope.actorUid, scope.httpMethod, scope.routePath, key];
    const found = client
      ? await client.query<{
          request_hash: string;
          response_code: number;
          response_body: unknown;
        }>(sql, params)
      : await this.pg.query<{
          request_hash: string;
          response_code: number;
          response_body: unknown;
        }>(sql, params);
    if (!found.rowCount) {
      return null;
    }
    if (found.rows[0].request_hash !== hash) {
      throw new AppError(ErrorCodes.IDEMPOTENCY_CONFLICT, 'Idempotency key reused with different body');
    }
    return {
      responseCode: found.rows[0].response_code,
      responseBody: found.rows[0].response_body,
    };
  }

  /**
   * Single-TX begin + business + save where feasible (F-REV3-05).
   * Reserves the idempotency row first so concurrent same-key callers serialize.
   */
  async runScoped<T>(
    key: string | undefined,
    requestBody: unknown,
    required: boolean,
    scope: IdempotencyScope,
    ttlHours: number | null,
    fn: (client: PoolClient) => Promise<{ responseCode: number; responseBody: T }>,
  ): Promise<T> {
    if (!key) {
      if (required) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Idempotency-Key required');
      }
      return this.pg.tx(async (c) => {
        const out = await fn(c);
        return out.responseBody;
      });
    }
    const hash = this.hashRequest(requestBody);
    return this.pg.tx(async (c) => {
      // Transaction advisory lock on actor+route+key (single algorithm).
      await c.query(
        `SELECT pg_advisory_xact_lock(
           hashtext($1 || E'\\x1f' || $2 || E'\\x1f' || $3 || E'\\x1f' || $4)
         )`,
        [scope.actorUid, scope.httpMethod, scope.routePath, key],
      );
      // Claim / lock the scope key so concurrent callers serialize on one row.
      await c.query(
        `INSERT INTO idempotency_keys
           (actor_uid, http_method, route_path, key, request_hash, response_code, response_body, expires_at)
         VALUES ($1,$2,$3,$4,$5,0,'null'::jsonb,
           CASE WHEN $6::int IS NULL THEN NULL ELSE now() + ($6::int || ' hours')::interval END)
         ON CONFLICT (actor_uid, http_method, route_path, key) DO NOTHING`,
        [scope.actorUid, scope.httpMethod, scope.routePath, key, hash, ttlHours],
      );
      const locked = await c.query<{
        request_hash: string;
        response_code: number;
        response_body: unknown;
        expires_at: Date | null;
      }>(
        `SELECT request_hash, response_code, response_body, expires_at
         FROM idempotency_keys
         WHERE actor_uid = $1 AND http_method = $2 AND route_path = $3 AND key = $4
         FOR UPDATE`,
        [scope.actorUid, scope.httpMethod, scope.routePath, key],
      );
      if (!locked.rowCount) {
        throw new AppError(ErrorCodes.INTERNAL, 'Idempotency claim failed', undefined, true);
      }
      const row = locked.rows[0];
      const expired =
        row.expires_at != null && new Date(row.expires_at).getTime() <= Date.now();
      const hasResponse = row.response_code !== 0 && row.response_body != null;
      if (!expired && hasResponse) {
        if (row.request_hash !== hash) {
          throw new AppError(
            ErrorCodes.IDEMPOTENCY_CONFLICT,
            'Idempotency key reused with different body',
          );
        }
        return row.response_body as T;
      }
      // Expired (or claim-only) rows may adopt a new body hash in this TX.
      if (!expired && row.request_hash !== hash) {
        throw new AppError(
          ErrorCodes.IDEMPOTENCY_CONFLICT,
          'Idempotency key reused with different body',
        );
      }
      const out = await fn(c);
      await c.query(
        `UPDATE idempotency_keys
         SET request_hash = $5,
             response_code = $6,
             response_body = $7::jsonb,
             expires_at = CASE WHEN $8::int IS NULL THEN NULL
                               ELSE now() + ($8::int || ' hours')::interval END,
             created_at = now()
         WHERE actor_uid = $1 AND http_method = $2 AND route_path = $3 AND key = $4`,
        [
          scope.actorUid,
          scope.httpMethod,
          scope.routePath,
          key,
          hash,
          out.responseCode,
          JSON.stringify(out.responseBody),
          ttlHours,
        ],
      );
      return out.responseBody;
    });
  }

  async save(
    key: string,
    requestBody: unknown,
    responseCode: number,
    responseBody: unknown,
    ttlHours: number | null,
    scope: IdempotencyScope,
    client?: PoolClient,
  ): Promise<void> {
    const hash = this.hashRequest(requestBody);
    // UPSERT when missing or expired so expired-key replay stores the new response.
    const sql = `INSERT INTO idempotency_keys
       (actor_uid, http_method, route_path, key, request_hash, response_code, response_body, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb,
         CASE WHEN $8::int IS NULL THEN NULL ELSE now() + ($8::int || ' hours')::interval END)
       ON CONFLICT (actor_uid, http_method, route_path, key) DO UPDATE
       SET request_hash = EXCLUDED.request_hash,
           response_code = EXCLUDED.response_code,
           response_body = EXCLUDED.response_body,
           expires_at = EXCLUDED.expires_at,
           created_at = now()
       WHERE idempotency_keys.expires_at IS NOT NULL
         AND idempotency_keys.expires_at <= now()`;
    const params = [
      scope.actorUid,
      scope.httpMethod,
      scope.routePath,
      key,
      hash,
      responseCode,
      JSON.stringify(responseBody),
      ttlHours,
    ];
    if (client) {
      await client.query(sql, params);
      return;
    }
    await this.pg.query(sql, params);
  }
}
