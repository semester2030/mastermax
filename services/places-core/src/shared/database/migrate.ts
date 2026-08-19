import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import { Pool } from 'pg';

const PRE_024_HOOK = '024_rc4_event_slot_kill_switch_payment_combo.sql';

function sha256Hex(content: string): string {
  return createHash('sha256').update(content, 'utf8').digest('hex');
}

async function runPre024Hook(
  client: { query: (sql: string) => Promise<unknown> },
  migrationsDir: string,
): Promise<void> {
  const hook = path.join(
    migrationsDir,
    '../upgrade_hooks/pre_024_half_null_remediation.sql',
  );
  const sql = await fs.readFile(hook, 'utf8');
  await client.query(sql);
  process.stdout.write(`upgrade_hook pre_024_half_null_remediation\n`);
}

async function ensureMigrationsTable(pool: Pool): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  await pool.query(
    `ALTER TABLE schema_migrations ADD COLUMN IF NOT EXISTS checksum TEXT`,
  );
}

/**
 * Phase 4: store checksum on apply; reject content drift of already-applied files.
 *
 * `opts.stopAfterNum` applies only migrations whose numeric prefix is <= the given
 * value (e.g. 27 → apply 001..027 and stop), enabling real staged upgrade tests
 * (fresh 001→028, then upgrade 027→028) instead of asserting on an already-migrated DB.
 */
export async function migrate(
  pool: Pool,
  migrationsDir?: string,
  opts?: { stopAfterNum?: number },
): Promise<void> {
  const dir =
    migrationsDir ?? path.resolve(__dirname, '../../../db/migrations');
  const files = (await fs.readdir(dir))
    .filter((f) => f.endsWith('.sql'))
    .sort();
  await ensureMigrationsTable(pool);

  for (const file of files) {
    if (opts?.stopAfterNum !== undefined) {
      const num = Number.parseInt(file.slice(0, 3), 10);
      if (Number.isFinite(num) && num > opts.stopAfterNum) {
        break;
      }
    }
    const sql = await fs.readFile(path.join(dir, file), 'utf8');
    const checksum = sha256Hex(sql);
    const applied = await pool.query<{ checksum: string | null }>(
      'SELECT checksum FROM schema_migrations WHERE id = $1',
      [file],
    );
    if (applied.rowCount) {
      const stored = applied.rows[0].checksum;
      if (stored && stored !== checksum) {
        throw new Error(
          `FATAL: migration checksum mismatch for ${file}: stored=${stored} actual=${checksum}`,
        );
      }
      if (!stored) {
        await pool.query(
          `UPDATE schema_migrations SET checksum = $2 WHERE id = $1 AND checksum IS NULL`,
          [file, checksum],
        );
      }
      continue;
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      if (file === PRE_024_HOOK) {
        await runPre024Hook(client, dir);
      }
      await client.query(sql);
      await client.query(
        'INSERT INTO schema_migrations (id, checksum) VALUES ($1, $2)',
        [file, checksum],
      );
      await client.query('COMMIT');
      process.stdout.write(`applied ${file}\n`);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}

async function main(): Promise<void> {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error('DATABASE_URL is required');
  }
  const pool = new Pool({ connectionString: url });
  try {
    await migrate(pool);
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  main().catch((err) => {
    process.stderr.write(String(err) + '\n');
    process.exit(1);
  });
}
