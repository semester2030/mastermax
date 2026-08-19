import { promises as fs } from 'fs';
import path from 'path';
import { Pool, PoolClient } from 'pg';

const PRE_024_HOOK = '024_rc4_event_slot_kill_switch_payment_combo.sql';

async function runPre024Hook(client: PoolClient): Promise<void> {
  const hook = path.resolve(
    __dirname,
    '../../db/upgrade_hooks/pre_024_half_null_remediation.sql',
  );
  const sql = await fs.readFile(hook, 'utf8');
  await client.query(sql);
}

async function applyOne(
  pool: Pool,
  dir: string,
  file: string,
): Promise<void> {
  const sql = await fs.readFile(path.join(dir, file), 'utf8');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (file === PRE_024_HOOK) {
      await runPre024Hook(client);
    }
    await client.query(sql);
    await client.query('INSERT INTO schema_migrations (id) VALUES ($1)', [file]);
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

/** Apply migrations whose filenames are lexicographically <= maxFile (inclusive). */
export async function applyMigrationsThrough(pool: Pool, maxFile: string): Promise<string[]> {
  const dir = path.resolve(__dirname, '../../db/migrations');
  const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  const applied: string[] = [];
  for (const file of files) {
    if (file > maxFile) break;
    const exists = await pool.query('SELECT 1 FROM schema_migrations WHERE id = $1', [file]);
    if (exists.rowCount) continue;
    await applyOne(pool, dir, file);
    applied.push(file);
  }
  return applied;
}

export async function applyRemainingMigrations(pool: Pool): Promise<string[]> {
  const dir = path.resolve(__dirname, '../../db/migrations');
  const files = (await fs.readdir(dir)).filter((f) => f.endsWith('.sql')).sort();
  const applied: string[] = [];
  for (const file of files) {
    const exists = await pool.query('SELECT 1 FROM schema_migrations WHERE id = $1', [file]);
    if (exists.rowCount) continue;
    await applyOne(pool, dir, file);
    applied.push(file);
  }
  return applied;
}
