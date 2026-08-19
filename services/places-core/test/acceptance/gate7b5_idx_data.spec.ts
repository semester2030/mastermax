/**
 * Gate 7B.5 / 7B.5.1 — migration 013–014 additive / upgrade / decision evidence.
 */
import { Pool } from 'pg';
import { withIsolatedDatabase } from '../helpers/isolated-database';
import {
  applyMigrationsThrough,
  applyRemainingMigrations,
} from '../helpers/migrate-partial';

describe('Gate 7B.5.1 — migration 014 index decisions (G7B5-IDX-01)', () => {
  it('G7B5-IDX-01 fresh 001→014 keeps media playable; drops unused created_at; adds rating/price/static', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '014_gate7b51_perf_playable_rating.sql');
      const idx = await pool.query(
        `SELECT indexname FROM pg_indexes
         WHERE schemaname='public'
           AND indexname IN (
             'idx_venue_media_playable_video',
             'idx_venues_published_created_at',
             'idx_venues_published_rating_keyset',
             'idx_venues_published_has_playable_video',
             'idx_venues_published_indicative_price',
             'idx_venues_published_best_static',
             'idx_venues_published_id'
           )
         ORDER BY 1`,
      );
      expect(idx.rows.map((r) => r.indexname)).toEqual([
        'idx_venue_media_playable_video',
        'idx_venues_published_best_static',
        'idx_venues_published_has_playable_video',
        'idx_venues_published_id',
        'idx_venues_published_indicative_price',
        'idx_venues_published_rating_keyset',
      ]);
      const col = await pool.query(
        `SELECT column_name FROM information_schema.columns
         WHERE table_name='venues'
           AND column_name IN ('has_playable_video','indicative_starting_price','best_score_static')
         ORDER BY 1`,
      );
      expect(col.rows.map((r) => r.column_name)).toEqual([
        'best_score_static',
        'has_playable_video',
        'indicative_starting_price',
      ]);
    });
  }, 180_000);

  it('G7B5-IDX-01 upgrade 013→014 drops created_at, keeps media playable, adds 7B.5.1 artifacts', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '013_gate7b5_perf_indexes.sql');
      const before = await pool.query(
        `SELECT 1 FROM pg_indexes WHERE indexname='idx_venues_published_created_at'`,
      );
      expect(before.rowCount).toBe(1);
      await applyRemainingMigrations(pool);
      const idx = await pool.query(
        `SELECT indexname FROM pg_indexes
         WHERE indexname IN (
           'idx_venue_media_playable_video',
           'idx_venues_published_created_at',
           'idx_venues_published_rating_keyset',
           'idx_venues_published_has_playable_video',
           'idx_venues_published_indicative_price',
           'idx_venues_published_best_static',
           'idx_venues_published_id'
         )
         ORDER BY 1`,
      );
      expect(idx.rows.map((r) => r.indexname)).toEqual([
        'idx_venue_media_playable_video',
        'idx_venues_published_best_static',
        'idx_venues_published_has_playable_video',
        'idx_venues_published_id',
        'idx_venues_published_indicative_price',
        'idx_venues_published_rating_keyset',
      ]);
    });
  }, 180_000);
});

describe('Gate 7B.5 — perf DB safety (G7B5-DATA-01)', () => {
  it('refuses forbidden DB names', async () => {
    const { assertSafePerfDbName } = await import(
      '../../scripts/perf/perf-db-safety'
    );
    expect(() => assertSafePerfDbName('places_core_test')).toThrow(/REFUSED/);
    expect(() => assertSafePerfDbName('places_core_dev')).toThrow(/REFUSED/);
    expect(() => assertSafePerfDbName('prod_places')).toThrow(/REFUSED/);
    expect(() => assertSafePerfDbName('places_core_perf')).not.toThrow();
  });

  it('G7B5-DATA-01 dataset meta present on places_core_perf when available', async () => {
    const url = process.env.PERF_DATABASE_URL?.trim();
    if (!url) {
      return; // require explicit PERF_DATABASE_URL — no hardcoded personal URL
    }
    const pool = new Pool({ connectionString: url });
    try {
      const db = await pool.query(`SELECT current_database() AS d`);
      if (!String(db.rows[0].d).startsWith('places_core_perf')) {
        return;
      }
      const meta = await pool.query(`SELECT * FROM perf_dataset_meta WHERE id='current'`);
      expect(meta.rowCount).toBe(1);
      expect(Number(meta.rows[0].venue_count)).toBeGreaterThanOrEqual(50_000);
      const counts = await pool.query(`
        SELECT
          (SELECT COUNT(*)::int FROM venues v
            JOIN venue_type_capabilities c ON c.venue_type=v.venue_type
           WHERE v.status='published' AND c.enabled_for_discovery) AS discoverable,
          (SELECT COUNT(DISTINCT city)::int FROM venues) AS cities,
          (SELECT COUNT(DISTINCT district)::int FROM venues) AS districts
      `);
      expect(counts.rows[0].discoverable).toBeGreaterThanOrEqual(40_000);
      expect(counts.rows[0].cities).toBeGreaterThanOrEqual(10);
      expect(counts.rows[0].districts).toBeGreaterThanOrEqual(100);
    } catch (e: unknown) {
      if (String((e as Error)?.message || e).includes('does not exist')) {
        return;
      }
      throw e;
    } finally {
      await pool.end();
    }
  }, 60_000);
});
