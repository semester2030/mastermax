/**
 * Isolated Postgres database for migration tests (Gate 7B.3.5A).
 * Uses DATABASE_URL host/user/password; never hard-codes credentials.
 * Never drops public on the caller's primary database.
 */
import { Pool } from 'pg';
import { randomBytes } from 'crypto';

function requireDatabaseUrl(): string {
  const url = process.env.DATABASE_URL;
  if (!url || !String(url).trim()) {
    throw new Error('DATABASE_URL is required for isolated migration tests');
  }
  return url;
}

/** Safe SQL identifier: lowercase alphanumeric + underscore only. */
export function randomIsolatedDbName(prefix = 'g7b35a'): string {
  const suffix = `${Date.now()}_${randomBytes(4).toString('hex')}`;
  const raw = `${prefix}_${suffix}`.toLowerCase().replace(/[^a-z0-9_]/g, '_');
  return raw.slice(0, 63);
}

export async function withIsolatedDatabase<T>(
  run: (pool: Pool, dbName: string) => Promise<T>,
): Promise<T> {
  const baseUrl = requireDatabaseUrl();
  const dbName = randomIsolatedDbName();
  // Admin connection = same URL (any DB on the server can CREATE DATABASE).
  const admin = new Pool({ connectionString: baseUrl });
  let isolated: Pool | undefined;
  try {
    await admin.query(`CREATE DATABASE ${quoteIdent(dbName)}`);
    const isolatedUrl = new URL(baseUrl);
    isolatedUrl.pathname = `/${dbName}`;
    isolated = new Pool({ connectionString: isolatedUrl.toString() });
    return await run(isolated, dbName);
  } finally {
    if (isolated) {
      try {
        await isolated.end();
      } catch {
        /* ignore */
      }
    }
    try {
      await admin.query(
        `SELECT pg_terminate_backend(pid)
         FROM pg_stat_activity
         WHERE datname = $1 AND pid <> pg_backend_pid()`,
        [dbName],
      );
      await admin.query(`DROP DATABASE IF EXISTS ${quoteIdent(dbName)}`);
    } finally {
      await admin.end().catch(() => undefined);
    }
  }
}

function quoteIdent(name: string): string {
  if (!/^[a-z][a-z0-9_]*$/.test(name)) {
    throw new Error(`unsafe database name: ${name}`);
  }
  return `"${name}"`;
}
