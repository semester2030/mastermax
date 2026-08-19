/**
 * Gate 7B.5.1.3 — concurrent media denorm (real PostgreSQL clients/transactions).
 */
import { Pool, PoolClient } from 'pg';
import { withIsolatedDatabase } from '../helpers/isolated-database';
import {
  applyMigrationsThrough,
  applyRemainingMigrations,
} from '../helpers/migrate-partial';
import { newId } from '../../src/shared/ids/ids';

const PLAYABLE_EXISTS = `
  EXISTS (
    SELECT 1 FROM venue_media m
    WHERE m.venue_id = v.id
      AND m.kind = 'video'
      AND m.moderation_status = 'approved'
      AND (
        (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
        OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
      )
  )`;

const PRICE_MIN = `
  (SELECT MIN(m.starting_price_hint) FROM venue_media m
   WHERE m.venue_id = v.id
     AND m.moderation_status = 'approved'
     AND m.starting_price_hint IS NOT NULL)`;

async function assertDenorm(pool: Pool | PoolClient, venueId: string): Promise<void> {
  const r = await pool.query(
    `SELECT v.has_playable_video AS stored_playable,
            v.indicative_starting_price::text AS stored_price,
            (${PLAYABLE_EXISTS}) AS expect_playable,
            (${PRICE_MIN})::text AS expect_price,
            v.best_score_static IS NOT NULL AS has_static,
            v.best_score_static::text AS static_score
     FROM venues v WHERE v.id = $1`,
    [venueId],
  );
  expect(r.rowCount).toBe(1);
  const row = r.rows[0];
  expect(row.stored_playable).toBe(row.expect_playable);
  expect(row.stored_price).toBe(row.expect_price);
  expect(row.has_static).toBe(true);
  // best_score_static follows has_playable_video (GENERATED) — playable bit must match formula term.
  if (row.stored_playable === true) {
    expect(Number(row.static_score)).toBeGreaterThan(0);
  }
}

async function seedProvider(pool: Pool): Promise<{ providerId: string; type: string }> {
  const providerId = newId();
  await pool.query(
    `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
     VALUES ($1,'C','C','company','active',$2)`,
    [providerId, `o-${providerId}`],
  );
  const type = (
    await pool.query<{ venue_type: string }>(
      `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY 1 LIMIT 1`,
    )
  ).rows[0].venue_type;
  return { providerId, type };
}

async function seedVenue(
  pool: Pool,
  providerId: string,
  type: string,
): Promise<string> {
  const id = newId();
  await pool.query(
    `INSERT INTO venues (
       id, provider_id, name, venue_type, booking_mode, status, city, lat, lng,
       weighted_rating, reviews_count, rating_average
     ) VALUES ($1,$2,$3,$4,'nightly','published','Riyadh',24.7,46.7,4.0,5,4.0)`,
    [id, providerId, `V-${id.slice(0, 8)}`, type],
  );
  return id;
}

async function insertPlayable(
  pool: Pool,
  venueId: string,
  providerId: string,
  price: number | null,
): Promise<string> {
  const id = newId();
  await pool.query(
    `INSERT INTO venue_media (
       id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order, starting_price_hint
     ) VALUES ($1,$2,$3,'video','https://cdn.example/v.mp4','s','approved',0,$4)`,
    [id, venueId, providerId, price],
  );
  return id;
}

/** Two clients BEGIN; caller runs overlapping work and must COMMIT each client itself. */
async function withTwoTx(
  pool: Pool,
  run: (c1: PoolClient, c2: PoolClient) => Promise<void>,
): Promise<void> {
  const c1 = await pool.connect();
  const c2 = await pool.connect();
  try {
    await c1.query('BEGIN');
    await c2.query('BEGIN');
    await c1.query(`SET LOCAL lock_timeout = '8s'`);
    await c2.query(`SET LOCAL lock_timeout = '8s'`);
    await c1.query(`SET LOCAL deadlock_timeout = '200ms'`);
    await c2.query(`SET LOCAL deadlock_timeout = '200ms'`);
    await run(c1, c2);
  } finally {
    try {
      await c1.query('ROLLBACK');
    } catch {
      /* ignore */
    }
    try {
      await c2.query('ROLLBACK');
    } catch {
      /* ignore */
    }
    c1.release();
    c2.release();
  }
}

/** Overlapping statements that each COMMIT independently (required so venue FOR UPDATE can hand off). */
async function concurrentCommit(
  c1: PoolClient,
  c2: PoolClient,
  op1: Promise<unknown>,
  op2: Promise<unknown>,
): Promise<void> {
  await Promise.all([
    (async () => {
      await op1;
      await c1.query('COMMIT');
    })(),
    (async () => {
      await op2;
      await c2.query('COMMIT');
    })(),
  ]);
}

describe('Gate 7B.5.1.3 — concurrent media denorm', () => {
  it('G7B513-CONC-01 concurrent delete last two playable → has_playable_video=false', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '017_gate7b513_concurrent_media_denorm.sql');
      const { providerId, type } = await seedProvider(pool);
      const venueId = await seedVenue(pool, providerId, type);
      const m1 = await insertPlayable(pool, venueId, providerId, 100);
      const m2 = await insertPlayable(pool, venueId, providerId, 200);
      await assertDenorm(pool, venueId);
      expect(
        (await pool.query(`SELECT has_playable_video FROM venues WHERE id=$1`, [venueId])).rows[0]
          .has_playable_video,
      ).toBe(true);

      await withTwoTx(pool, async (c1, c2) => {
        await concurrentCommit(
          c1,
          c2,
          c1.query(`DELETE FROM venue_media WHERE id=$1`, [m1]),
          c2.query(`DELETE FROM venue_media WHERE id=$1`, [m2]),
        );
      });

      const row = await pool.query(
        `SELECT has_playable_video, indicative_starting_price FROM venues WHERE id=$1`,
        [venueId],
      );
      expect(row.rows[0].has_playable_video).toBe(false);
      expect(row.rows[0].indicative_starting_price).toBeNull();
      await assertDenorm(pool, venueId);
    });
  }, 180_000);

  it('G7B513-CONC-02 concurrent price updates → stored = live MIN', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '017_gate7b513_concurrent_media_denorm.sql');
      const { providerId, type } = await seedProvider(pool);
      const venueId = await seedVenue(pool, providerId, type);
      const m1 = await insertPlayable(pool, venueId, providerId, 150);
      const m2 = await insertPlayable(pool, venueId, providerId, 180);

      await withTwoTx(pool, async (c1, c2) => {
        await concurrentCommit(
          c1,
          c2,
          c1.query(`UPDATE venue_media SET starting_price_hint=40 WHERE id=$1`, [m1]),
          c2.query(`UPDATE venue_media SET starting_price_hint=55 WHERE id=$1`, [m2]),
        );
      });

      const row = await pool.query(
        `SELECT indicative_starting_price::float AS price FROM venues WHERE id=$1`,
        [venueId],
      );
      expect(row.rows[0].price).toBe(40);
      await assertDenorm(pool, venueId);
    });
  }, 180_000);

  it('G7B513-CONC-03 crossed re-parent A→B and B→A — no deadlock, denorm correct', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '017_gate7b513_concurrent_media_denorm.sql');
      const { providerId, type } = await seedProvider(pool);
      const a = await seedVenue(pool, providerId, type);
      const b = await seedVenue(pool, providerId, type);
      const mOnA = await insertPlayable(pool, a, providerId, 111);
      const mOnB = await insertPlayable(pool, b, providerId, 222);

      await withTwoTx(pool, async (c1, c2) => {
        await concurrentCommit(
          c1,
          c2,
          c1.query(`UPDATE venue_media SET venue_id=$1 WHERE id=$2`, [b, mOnA]),
          c2.query(`UPDATE venue_media SET venue_id=$1 WHERE id=$2`, [a, mOnB]),
        );
      });

      const media = await pool.query(
        `SELECT id, venue_id FROM venue_media WHERE id = ANY($1::uuid[])`,
        [[mOnA, mOnB]],
      );
      const byMedia = Object.fromEntries(media.rows.map((r) => [r.id, r.venue_id]));
      expect(byMedia[mOnA]).toBe(b);
      expect(byMedia[mOnB]).toBe(a);
      await assertDenorm(pool, a);
      await assertDenorm(pool, b);
      const venues = await pool.query(
        `SELECT id, has_playable_video, indicative_starting_price::float AS price
         FROM venues WHERE id = ANY($1::uuid[])`,
        [[a, b]],
      );
      const byId = Object.fromEntries(venues.rows.map((r) => [r.id, r]));
      expect(byId[a].has_playable_video).toBe(true);
      expect(byId[b].has_playable_video).toBe(true);
      expect(byId[a].price).toBe(222);
      expect(byId[b].price).toBe(111);
    });
  }, 180_000);

  it('G7B513-CONC-04 post-scenario stored playable/price/static match live', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '017_gate7b513_concurrent_media_denorm.sql');
      const { providerId, type } = await seedProvider(pool);
      const venueId = await seedVenue(pool, providerId, type);
      const m1 = await insertPlayable(pool, venueId, providerId, 90);
      const m2 = await insertPlayable(pool, venueId, providerId, 70);

      await withTwoTx(pool, async (c1, c2) => {
        await concurrentCommit(
          c1,
          c2,
          c1.query(`UPDATE venue_media SET starting_price_hint=33 WHERE id=$1`, [m1]),
          c2.query(`DELETE FROM venue_media WHERE id=$1`, [m2]),
        );
      });

      await assertDenorm(pool, venueId);
      const row = await pool.query(
        `SELECT has_playable_video, indicative_starting_price::float AS price
         FROM venues WHERE id=$1`,
        [venueId],
      );
      expect(row.rows[0].has_playable_video).toBe(true);
      expect(row.rows[0].price).toBe(33);
    });
  }, 180_000);

  it('G7B513-MIG-01 upgrade 016→017 preserves all media/venue data', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '016_gate7b512_denorm_reconcile.sql');
      const { providerId, type } = await seedProvider(pool);
      const venueId = await seedVenue(pool, providerId, type);
      const mediaId = await insertPlayable(pool, venueId, providerId, 125);
      const beforeMedia = await pool.query(`SELECT * FROM venue_media WHERE id=$1`, [mediaId]);
      const beforeVenue = await pool.query(
        `SELECT id, has_playable_video, indicative_starting_price::text FROM venues WHERE id=$1`,
        [venueId],
      );

      const applied = await applyRemainingMigrations(pool);
      expect(applied).toEqual([
        '017_gate7b513_concurrent_media_denorm.sql',
        '018_pre_provider_media_gallery_locks.sql',
        '019_places_cloudflare_media.sql',
        '020_pre_device_rev2_locks_media_idempotency.sql',
        '021_pre_provider_corrective_closure.sql',
        '022_pre_provider_rev4_corrective.sql',
        '023_pay_at_venue_event_slot_gate9a.sql',
        '024_rc4_event_slot_kill_switch_payment_combo.sql',
        '025_rc5_half_null_payment_remediation.sql',
        '026_wave1_rc2_palace_hall_content_only.sql',
        '027_phase3_inventory_truth.sql',
      ]);

      const afterMedia = await pool.query(`SELECT * FROM venue_media WHERE id=$1`, [mediaId]);
      // 018–020 add columns (cloudflare_image_id, deleted_at, is_cover, …) with null/false defaults;
      // core playable fields must be preserved.
      const before = beforeMedia.rows[0];
      const after = afterMedia.rows[0];
      expect(after.id).toEqual(before.id);
      expect(after.venue_id).toEqual(before.venue_id);
      expect(after.provider_id).toEqual(before.provider_id);
      expect(after.kind).toEqual(before.kind);
      expect(after.stream_uid).toEqual(before.stream_uid);
      expect(after.url).toEqual(before.url);
      expect(after.moderation_status).toEqual(before.moderation_status);
      expect(after.deleted_at).toBeNull();
      expect(afterMedia.rowCount).toBe(1);
      await assertDenorm(pool, venueId);
      const afterVenue = await pool.query(
        `SELECT id, has_playable_video, indicative_starting_price::text FROM venues WHERE id=$1`,
        [venueId],
      );
      expect(afterVenue.rows[0].id).toBe(beforeVenue.rows[0].id);
      expect(afterVenue.rows[0].has_playable_video).toBe(true);
    });
  }, 180_000);

  it('G7B513-MIG-02 fresh path 001→017 PASS', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '017_gate7b513_concurrent_media_denorm.sql');
      const mig = await pool.query(
        `SELECT id FROM schema_migrations WHERE id='017_gate7b513_concurrent_media_denorm.sql'`,
      );
      expect(mig.rowCount).toBe(1);
      const fn = await pool.query(
        `SELECT proname FROM pg_proc WHERE proname='places_lock_venues_for_media_denorm'`,
      );
      expect(fn.rowCount).toBe(1);
    });
  }, 180_000);
});
