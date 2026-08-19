import { Inject, Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { APP_CONFIG } from '../config/app-config';
import { AppEnv } from '../config/env';
import { notePgQuery } from './pg-request-probe';

/** Must equal SEARCH_SIMILARITY_THRESHOLD in discovery-search-contract.ts */
const PG_TRGM_SIMILARITY_THRESHOLD = 0.25;

/** Parse PG_WORK_MEM like "32MB" / "4MB"; empty/unset → no override (server default). */
export function resolvePgWorkMemOption(
  raw: string | undefined = process.env.PG_WORK_MEM,
): string | undefined {
  if (raw == null) return undefined;
  const v = String(raw).trim();
  if (!v || v.toLowerCase() === 'default' || v === '0') return undefined;
  if (!/^\d+(MB|GB|kB)$/i.test(v)) {
    throw new Error(`PG_WORK_MEM invalid "${v}" (expected e.g. 32MB, or empty for default)`);
  }
  return v;
}

/**
 * Build libpq options string.
 * - pg_trgm.similarity_threshold aligned with search `%` operator (0.25).
 * - optional work_mem via PG_WORK_MEM (not hard-coded).
 * - max_parallel_workers_per_gather=0 under concurrent discovery (parallel
 *   gather worsens p95 when many requests each spawn workers).
 *
 * Memory note: work_mem is per-sort/hash node per backend. With pool max=M and
 * worst-case ~2 sort nodes per request, budget ≈ M * 2 * work_mem.
 * Example: M=20, work_mem=16MB → ~640MB upper bound for sort memory.
 */
export function buildPgPoolOptions(workMem?: string): string {
  const parts = [
    `-c pg_trgm.similarity_threshold=${PG_TRGM_SIMILARITY_THRESHOLD}`,
    '-c max_parallel_workers_per_gather=0',
    '-c jit=off',
  ];
  const wm = workMem ?? resolvePgWorkMemOption();
  if (wm) parts.push(`-c work_mem=${wm}`);
  return parts.join(' ');
}

@Injectable()
export class PgService implements OnModuleDestroy {
  readonly pool: Pool;
  /** Resolved pool max (production default 20). */
  readonly poolMax: number;

  constructor(@Inject(APP_CONFIG) env: AppEnv) {
    // Production default max=20. Test default max=40 unless PG_POOL_MAX overrides
    // (perf harness forces PG_POOL_MAX=20 to match production pool sizing).
    const envMax = process.env.PG_POOL_MAX?.trim();
    const max = envMax
      ? Math.max(1, Number.parseInt(envMax, 10) || 20)
      : process.env.NODE_ENV === 'test'
        ? 40
        : 20;
    this.poolMax = max;
    this.pool = new Pool({
      connectionString: env.databaseUrl,
      // Keep well under PG max_connections (often 100); waiters queue instead of TCP storms.
      max,
      idleTimeoutMillis: 10_000,
      connectionTimeoutMillis: process.env.NODE_ENV === 'test' ? 60_000 : 10_000,
      options: buildPgPoolOptions(),
    });
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<QueryResult<T>> {
    notePgQuery();
    return this.pool.query<T>(sql, params);
  }

  async tx<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await fn(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async ping(): Promise<void> {
    await this.pool.query('SELECT 1');
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}
