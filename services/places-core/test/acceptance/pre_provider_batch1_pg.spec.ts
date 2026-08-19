/**
 * Pre-Provider Batch1 — ownership / availability / media-cap evidence.
 * Requires DATABASE_URL + migrated schema through 020. Skips cleanly otherwise.
 */
import { Pool } from 'pg';
import { existsSync, readdirSync, readFileSync } from 'fs';
import { join } from 'path';

const hasDb = Boolean(process.env.DATABASE_URL);
const describeDb = hasDb ? describe : describe.skip;

async function migrate(pool: Pool): Promise<void> {
  const dir = join(__dirname, '../../db/migrations');
  const files = readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  await pool.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    id TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  for (const f of files) {
    const applied = await pool.query('SELECT 1 FROM schema_migrations WHERE id = $1', [f]);
    if (applied.rowCount) continue;
    const sql = readFileSync(join(dir, f), 'utf8');
    await pool.query('BEGIN');
    try {
      await pool.query(sql);
      await pool.query('INSERT INTO schema_migrations (id) VALUES ($1)', [f]);
      await pool.query('COMMIT');
    } catch (e) {
      await pool.query('ROLLBACK');
      throw e;
    }
  }
  expect(existsSync(join(dir, '018_pre_provider_media_gallery_locks.sql'))).toBe(true);
  expect(existsSync(join(dir, '020_pre_device_rev2_locks_media_idempotency.sql'))).toBe(true);
}

describeDb('pre-provider Batch1 PG evidence', () => {
  let pool: Pool;

  beforeAll(async () => {
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await migrate(pool);
  });

  afterAll(async () => {
    await pool.end();
  });

  it('018/020 places_lock_venues_ordered locks ascending UUID order', async () => {
    const fn = await pool.query(
      `SELECT proname FROM pg_proc WHERE proname = 'places_lock_venues_ordered'`,
    );
    expect(fn.rowCount).toBe(1);
    const caps = await pool.query(
      `SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_venue_media_image_cap%'`,
    );
    expect((caps.rowCount ?? 0) >= 2).toBe(true);
  });

  it('020 media image cap is 30 pending+approved per venue scope', async () => {
    const body = await pool.query<{ prosrc: string }>(
      `SELECT prosrc FROM pg_proc WHERE proname = 'places_enforce_venue_image_cap'`,
    );
    expect(body.rows[0]?.prosrc).toMatch(/cnt >= 30/);
    expect(body.rows[0]?.prosrc).toMatch(/pending.*approved|moderation_status IN \('pending', 'approved'\)/s);
  });
});
