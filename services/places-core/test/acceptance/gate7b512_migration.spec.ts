/**
 * Gate 7B.5.1.2 — Migration 016 reconciliation + upgrade/fresh paths.
 */
import { Pool } from 'pg';
import { withIsolatedDatabase } from '../helpers/isolated-database';
import {
  applyMigrationsThrough,
  applyRemainingMigrations,
} from '../helpers/migrate-partial';
import { newId } from '../../src/shared/ids/ids';

const PLAYABLE = `
  EXISTS (
    SELECT 1 FROM venue_media m
    WHERE m.venue_id = v.id AND m.kind='video' AND m.moderation_status='approved'
      AND (
        (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
        OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
      )
  )`;

const PRICE = `
  (SELECT MIN(m.starting_price_hint) FROM venue_media m
   WHERE m.venue_id = v.id AND m.moderation_status='approved'
     AND m.starting_price_hint IS NOT NULL)`;

async function assertMatch(pool: Pool, id: string): Promise<void> {
  const r = await pool.query(
    `SELECT v.has_playable_video AS sp, (${PLAYABLE}) AS ep,
            v.indicative_starting_price::text AS spr, (${PRICE})::text AS epr
     FROM venues v WHERE id=$1`,
    [id],
  );
  expect(r.rows[0].sp).toBe(r.rows[0].ep);
  expect(r.rows[0].spr).toBe(r.rows[0].epr);
}

describe('Gate 7B.5.1.2 — migration 016 denorm reconcile', () => {
  it('G7B512-MIG-01 upgrade 014→stale→015→016 repairs A+B; data preserved', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '014_gate7b51_perf_playable_rating.sql');

      const providerId = newId();
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'R','R','company','active',$2)`,
        [providerId, `o-${providerId}`],
      );
      const type = (
        await pool.query<{ venue_type: string }>(
          `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY 1 LIMIT 1`,
        )
      ).rows[0].venue_type;

      const a = newId();
      const b = newId();
      for (const id of [a, b]) {
        await pool.query(
          `INSERT INTO venues (
             id, provider_id, name, venue_type, booking_mode, status, city, lat, lng,
             weighted_rating, reviews_count, rating_average
           ) VALUES ($1,$2,$3,$4,'nightly','published','Riyadh',24.7,46.7,4.1,8,4.1)`,
          [id, providerId, `V-${id.slice(0, 8)}`, type],
        );
      }

      const mediaId = newId();
      await pool.query(
        `INSERT INTO venue_media (
           id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order, starting_price_hint
         ) VALUES ($1,$2,$3,'video','https://cdn.example/a.mp4','s','approved',0,175)`,
        [mediaId, a, providerId],
      );

      // Re-parent under 014 trigger → A stays stale (bug).
      await pool.query(`UPDATE venue_media SET venue_id=$1 WHERE id=$2`, [b, mediaId]);

      const stale = await pool.query(
        `SELECT has_playable_video, indicative_starting_price::float AS price
         FROM venues WHERE id=$1`,
        [a],
      );
      expect(stale.rows[0].has_playable_video).toBe(true); // stale wrong
      expect(stale.rows[0].price).toBe(175);

      const t0 = Date.now();
      const applied = await applyRemainingMigrations(pool);
      const elapsed = Date.now() - t0;
      expect(applied).toEqual([
        '015_gate7b511_media_denorm_reparent.sql',
        '016_gate7b512_denorm_reconcile.sql',
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

      await assertMatch(pool, a);
      await assertMatch(pool, b);
      const after = await pool.query(
        `SELECT id, has_playable_video, indicative_starting_price::float AS price
         FROM venues WHERE id = ANY($1::uuid[])`,
        [[a, b]],
      );
      const byId = Object.fromEntries(after.rows.map((r) => [r.id, r]));
      expect(byId[a].has_playable_video).toBe(false);
      expect(byId[a].price).toBeNull();
      expect(byId[b].has_playable_video).toBe(true);
      expect(byId[b].price).toBe(175);

      // Data preserved: media still on B
      const media = await pool.query(`SELECT venue_id FROM venue_media WHERE id=$1`, [mediaId]);
      expect(media.rows[0].venue_id).toBe(b);
      expect(elapsed).toBeLessThan(60_000);
    });
  }, 180_000);

  it('G7B512-MIG-02 fresh 001→016 installs reconcile migration', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '016_gate7b512_denorm_reconcile.sql');
      const mig = await pool.query(
        `SELECT id FROM schema_migrations WHERE id='016_gate7b512_denorm_reconcile.sql'`,
      );
      expect(mig.rowCount).toBe(1);
    });
  }, 180_000);

  it('G7B512-MIG-03 upgrade 014→016 via remaining applies 015+016', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '014_gate7b51_perf_playable_rating.sql');
      const applied = await applyRemainingMigrations(pool);
      expect(applied).toContain('016_gate7b512_denorm_reconcile.sql');
      const all = await pool.query(`SELECT id FROM schema_migrations ORDER BY id`);
      expect(all.rows.map((r) => r.id).slice(-14)).toEqual([
        '014_gate7b51_perf_playable_rating.sql',
        '015_gate7b511_media_denorm_reparent.sql',
        '016_gate7b512_denorm_reconcile.sql',
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
    });
  }, 180_000);
});
