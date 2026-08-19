/**
 * Gate 7B.5 — refuse shared/prod/test DBs for performance work.
 * Only places_core_perf* names are allowed.
 */
import { Pool } from 'pg';

const FORBIDDEN_EXACT = new Set([
  'places_core_test',
  'places_core_dev',
  'places',
  'postgres',
  'template0',
  'template1',
]);

export const PERF_DB_NAME = 'places_core_perf';
export const DATASET_VERSION = 'g7b5-v1';
export const DATASET_SEED = 20260814;

export function assertSafePerfDbName(name: string): void {
  const n = String(name || '')
    .trim()
    .toLowerCase();
  if (!n) throw new Error('PERF_DB: empty database name');
  if (FORBIDDEN_EXACT.has(n)) {
    throw new Error(`PERF_DB_REFUSED: forbidden database name "${n}"`);
  }
  if (n.includes('prod') || n.includes('production')) {
    throw new Error(`PERF_DB_REFUSED: production-like name "${n}"`);
  }
  if (!/^places_core_perf([_][a-z0-9_]+)?$/.test(n)) {
    throw new Error(
      `PERF_DB_REFUSED: name must match places_core_perf* (got "${n}")`,
    );
  }
}

export function adminUrlFrom(envUrl: string): URL {
  return new URL(envUrl);
}

export function dbNameFromUrl(url: string): string {
  const u = new URL(url);
  return decodeURIComponent((u.pathname || '/').replace(/^\//, ''));
}

export function withDbName(baseUrl: string, dbName: string): string {
  assertSafePerfDbName(dbName);
  const u = new URL(baseUrl);
  u.pathname = `/${dbName}`;
  return u.toString();
}

/**
 * Resolve PERF_DATABASE_URL or create/use places_core_perf from DATABASE_URL admin.
 * Never returns places_core_test / places_core_dev.
 */
export async function resolvePerfDatabaseUrl(): Promise<{
  perfUrl: string;
  dbName: string;
  created: boolean;
}> {
  const explicit = process.env.PERF_DATABASE_URL?.trim();
  if (explicit) {
    const name = dbNameFromUrl(explicit);
    assertSafePerfDbName(name);
    return { perfUrl: explicit, dbName: name, created: false };
  }

  const base = process.env.DATABASE_URL?.trim();
  if (!base) {
    throw new Error(
      'PERF_DB_UNAVAILABLE: set PERF_DATABASE_URL (places_core_perf*) or DATABASE_URL for admin CREATE DATABASE',
    );
  }
  const baseName = dbNameFromUrl(base);
  if (baseName === PERF_DB_NAME || /^places_core_perf/.test(baseName)) {
    assertSafePerfDbName(baseName);
    return { perfUrl: base, dbName: baseName, created: false };
  }

  const admin = new Pool({ connectionString: base });
  let created = false;
  try {
    const exists = await admin.query(
      `SELECT 1 FROM pg_database WHERE datname = $1`,
      [PERF_DB_NAME],
    );
    if (!exists.rowCount) {
      assertSafePerfDbName(PERF_DB_NAME);
      await admin.query(`CREATE DATABASE "${PERF_DB_NAME}"`);
      created = true;
    }
  } finally {
    await admin.end();
  }
  return {
    perfUrl: withDbName(base, PERF_DB_NAME),
    dbName: PERF_DB_NAME,
    created,
  };
}

/** Drop + recreate perf DB (never touches places_core_test). */
export async function recreatePerfDatabase(adminUrl: string, dbName: string): Promise<string> {
  assertSafePerfDbName(dbName);
  const admin = new Pool({ connectionString: adminUrl });
  try {
    await admin.query(
      `SELECT pg_terminate_backend(pid)
       FROM pg_stat_activity
       WHERE datname = $1 AND pid <> pg_backend_pid()`,
      [dbName],
    );
    await admin.query(`DROP DATABASE IF EXISTS "${dbName}"`);
    await admin.query(`CREATE DATABASE "${dbName}"`);
  } finally {
    await admin.end();
  }
  return withDbName(adminUrl, dbName);
}
