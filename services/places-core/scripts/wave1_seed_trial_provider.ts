#!/usr/bin/env ts-node
/**
 * Wave1 additive seed — INSERT only. Never DROP/TRUNCATE/RESET.
 * Binds trial provider UUID for PLACES_INTERNAL_OPERATOR_PROVIDER_ID.
 */
import { Pool } from 'pg';
import { randomUUID } from 'crypto';

async function main(): Promise<void> {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL required');
  const providerId =
    process.env.PLACES_INTERNAL_OPERATOR_PROVIDER_ID ||
    '11111111-1111-4111-8111-111111111111';
  const ownerUid = process.env.WAVE1_TRIAL_OWNER_UID || 'wave1-trial-owner';
  const pool = new Pool({ connectionString: url });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exists = await client.query(`SELECT 1 FROM providers WHERE id = $1`, [
      providerId,
    ]);
    if (!exists.rowCount) {
      await client.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'Wave1 Trial Provider','مزود تجريبي Wave1','company','active',$2)`,
        [providerId, ownerUid],
      );
      await client.query(
        `INSERT INTO provider_users (id, provider_id, firebase_uid, role, status)
         VALUES ($1,$2,$3,'owner','active')`,
        [randomUUID(), providerId, ownerUid],
      );
      process.stdout.write(`seeded provider ${providerId}\n`);
    } else {
      process.stdout.write(`provider already present ${providerId}\n`);
    }
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((e) => {
  process.stderr.write(String(e) + '\n');
  process.exit(1);
});
