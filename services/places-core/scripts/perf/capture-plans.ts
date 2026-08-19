/**
 * Gate 7B.5 — capture EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT JSON)
 * using real Candidate Builder SQL (buildDiscoveryQuery + discoveryPageSql).
 */
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import { Pool } from 'pg';
import {
  applyDiscoveryDefaults,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import { discoveryPageSql } from '../../src/modules/filters/application/discovery-page-sql';
import { resolveNearPlaceAnchor } from '../../src/modules/filters/application/discovery-anchor';
import {
  LabelPhrase,
  prepareSearchQuery,
  planSearchTokens,
} from '../../src/modules/filters/application/discovery-search-contract';
import { normalizeRankingAsOf } from '../../src/modules/filters/application/discovery-cursor-encode';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { DATASET_SEED, DATASET_VERSION, resolvePerfDatabaseUrl } from './perf-db-safety';
import { buildPgPoolOptions, resolvePgWorkMemOption } from '../../src/shared/database/pg.service';

const OUT = path.resolve(__dirname, '../../../../docs/places_core_gate7b51/raw');
const WARMUPS = 5;
const MEASURES = 30;

type Workload = { id: string; label: string; body: DiscoverySearchDto };

function workloads(anchorId: string): Workload[] {
  return [
    { id: 'q_ar', label: 'search q Arabic', body: { q: 'فندق', sort: 'best', limit: 20, surface: 'search' } },
    { id: 'q_en', label: 'search q English', body: { q: 'Apartment Near', sort: 'best', limit: 20, surface: 'search' } },
    { id: 'q_multi', label: 'search multiword', body: { q: 'Luxury Villa', sort: 'best', limit: 20, surface: 'search' } },
    { id: 'q_escape', label: 'search escaped', body: { q: "O'Brien Hotel", sort: 'best', limit: 20, surface: 'search' } },
    {
      id: 'bounds_normal',
      label: 'bounds normal',
      body: { minLat: 24.5, maxLat: 25.0, minLng: 46.4, maxLng: 47.0, sort: 'best', limit: 20, surface: 'map' },
    },
    {
      id: 'bounds_dense',
      label: 'bounds dense',
      body: { minLat: 24.7, maxLat: 24.86, minLng: 46.67, maxLng: 46.83, sort: 'newest', limit: 20, surface: 'map' },
    },
    {
      id: 'bounds_anti',
      label: 'bounds antimeridian',
      body: { minLat: 20, maxLat: 25, minLng: 179.0, maxLng: -179.0, sort: 'best', limit: 20, surface: 'map' },
    },
    {
      id: 'near_me_dense',
      label: 'near_me dense',
      body: { sort: 'near_me', lat: 24.75, lng: 46.72, radiusKm: 8, limit: 20, surface: 'circle' },
    },
    {
      id: 'near_me_sparse',
      label: 'near_me sparse',
      body: { sort: 'near_me', lat: 18.3, lng: 42.6, radiusKm: 40, limit: 20, surface: 'circle' },
    },
    {
      id: 'near_place',
      label: 'near_place same-type',
      body: {
        sort: 'near_place',
        anchorVenueId: anchorId,
        radiusKm: 25,
        sameTypeOnly: true,
        limit: 20,
        surface: 'search',
      },
    },
    { id: 'best_score', label: 'best_score', body: { sort: 'best', limit: 20, surface: 'search' } },
    { id: 'newest', label: 'newest', body: { sort: 'newest', limit: 20, surface: 'search' } },
    { id: 'rating', label: 'rating', body: { sort: 'rating', limit: 20, surface: 'search' } },
    { id: 'cheapest', label: 'cheapest', body: { sort: 'cheapest', limit: 20, surface: 'search' } },
    { id: 'most_expensive', label: 'most_expensive', body: { sort: 'most_expensive', limit: 20, surface: 'search' } },
    {
      id: 'div_best_dense',
      label: 'diversity best dense',
      body: {
        sort: 'best',
        limit: 20,
        surface: 'feed',
        minLat: 24.7,
        maxLat: 24.86,
        minLng: 46.67,
        maxLng: 46.83,
      },
    },
    {
      id: 'div_newest_skew',
      label: 'diversity newest skew city',
      body: { sort: 'newest', limit: 20, surface: 'feed', city: 'Riyadh' },
    },
    {
      id: 'same_type_full',
      label: 'same-type near_place (real results)',
      body: {
        sort: 'near_place',
        anchorVenueId: anchorId,
        radiusKm: 30,
        sameTypeOnly: true,
        limit: 20,
        surface: 'search',
      },
    },
    {
      id: 'cursor_deep_20',
      label: 'cursor page0 limit20 (HTTP deep walk in capture-http-evidence)',
      body: { sort: 'newest', limit: 20, surface: 'search' },
    },
    {
      id: 'cursor_deep_50',
      label: 'cursor page0 limit50 (HTTP deep walk in capture-http-evidence)',
      body: { sort: 'newest', limit: 50, surface: 'search' },
    },
  ];
}

async function loadLabels(pool: Pool): Promise<LabelPhrase[]> {
  const res = await pool.query<{
    venue_type: string;
    label_ar: string | null;
    label_en: string | null;
  }>(
    `SELECT venue_type, label_ar, label_en
     FROM venue_type_capabilities WHERE enabled_for_discovery = TRUE`,
  );
  const out: LabelPhrase[] = [];
  for (const row of res.rows) {
    if (row.label_ar) out.push({ phrase: row.label_ar, venueTypes: [row.venue_type] });
    if (row.label_en) out.push({ phrase: row.label_en, venueTypes: [row.venue_type] });
  }
  return out;
}

async function buildPageSql(
  pool: Pool,
  body: DiscoverySearchDto,
): Promise<{ sql: string; params: unknown[] }> {
  const canonical = applyDiscoveryDefaults({ ...body });
  const rankingAsOf = normalizeRankingAsOf(null);
  const buildOpts: Parameters<typeof buildDiscoveryQuery>[1] = {
    rankingAsOf,
    excludeAnchor: true,
  };

  if (canonical.sort === 'near_place' && canonical.anchorVenueId) {
    buildOpts.anchor = await resolveNearPlaceAnchor(pool as never, canonical.anchorVenueId);
  }

  if (canonical.q) {
    const tokens = prepareSearchQuery(canonical.q);
    if (tokens) {
      const planned = planSearchTokens(tokens, await loadLabels(pool));
      buildOpts.searchPlans = planned.plans;
      buildOpts.phrasePlans = planned.phrasePlans;
    }
  }

  const built = buildDiscoveryQuery(canonical, buildOpts);
  const limit = canonical.limit ?? 20;
  const pageParams = [...built.whereParams, ...built.sortParams, ...built.cursorParams, limit + 1];
  const sql = discoveryPageSql(built, built.whereSql, pageParams.length);
  return { sql, params: pageParams };
}

async function explainOnce(pool: Pool, sql: string, params: unknown[]): Promise<unknown> {
  const r = await pool.query(`EXPLAIN (ANALYZE, BUFFERS, SETTINGS, FORMAT JSON) ${sql}`, params);
  return r.rows[0]['QUERY PLAN'];
}

function latencyMs(plan: unknown): number {
  const root = Array.isArray(plan) ? plan[0] : plan;
  const p = root as {
    Plan?: { 'Actual Total Time'?: number };
    'Planning Time'?: number;
    'Execution Time'?: number;
  };
  return Number(p?.['Execution Time'] ?? p?.Plan?.['Actual Total Time'] ?? 0) + Number(p?.['Planning Time'] ?? 0);
}

function percentile(sorted: number[], p: number): number {
  if (!sorted.length) return 0;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

async function main(): Promise<void> {
  const tag = process.argv.includes('--after') ? 'after' : 'baseline';
  const { perfUrl, dbName } = await resolvePerfDatabaseUrl();
  const pool = new Pool({
    connectionString: perfUrl,
    max: 8,
    // Baseline always pins work_mem=4MB for replayable comparison.
    // After uses PG_WORK_MEM when set; otherwise server default (no hard-coded 32MB).
    options: buildPgPoolOptions(
      process.argv.includes('--after') ? resolvePgWorkMemOption() : '4MB',
    ),
  });
  try {
    const meta = await pool.query(`SELECT * FROM perf_dataset_meta WHERE id='current'`);
    if (!meta.rowCount) throw new Error('perf dataset missing — run seed-dataset.ts first');

    const anchor = await pool.query<{ id: string }>(
      `SELECT id FROM venues
       WHERE status='published' AND venue_type='hotel'
         AND lat IS NOT NULL AND lng IS NOT NULL
         AND lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180
         AND lat BETWEEN 24.6 AND 25.0 AND lng BETWEEN 46.5 AND 47.0
       ORDER BY created_at DESC LIMIT 1`,
    );
    if (!anchor.rowCount) throw new Error('no anchor venue');

    const results: Record<string, unknown>[] = [];
    for (const wl of workloads(anchor.rows[0].id)) {
      process.stdout.write(`WORKLOAD ${wl.id}...\n`);
      const built = await buildPageSql(pool, wl.body);
      for (let i = 0; i < WARMUPS; i++) {
        await pool.query(built.sql, built.params);
      }
      const samples: number[] = [];
      let lastPlan: unknown = null;
      for (let i = 0; i < MEASURES; i++) {
        lastPlan = await explainOnce(pool, built.sql, built.params);
        samples.push(latencyMs(lastPlan));
      }
      samples.sort((a, b) => a - b);
      const planPath = path.join(OUT, 'explain', `${tag}_${wl.id}.json`);
      await fs.mkdir(path.dirname(planPath), { recursive: true });
      await fs.writeFile(planPath, JSON.stringify(lastPlan, null, 2));
      const sqlHash = createHash('sha256').update(built.sql).digest('hex').slice(0, 16);
      results.push({
        id: wl.id,
        label: wl.label,
        warmups: WARMUPS,
        measures: MEASURES,
        cold_cache_claimed: false,
        sql_hash: sqlHash,
        p50_ms: percentile(samples, 50),
        p95_ms: percentile(samples, 95),
        p99_ms: percentile(samples, 99),
        mean_ms: samples.reduce((a, b) => a + b, 0) / samples.length,
        samples_ms: samples,
        explain_file: `raw/explain/${tag}_${wl.id}.json`,
      });
    }

    const summary = {
      tag,
      dbName,
      dataset_version: DATASET_VERSION,
      dataset_seed: DATASET_SEED,
      meta: meta.rows[0],
      warmups: WARMUPS,
      measures: MEASURES,
      results,
      ts: new Date().toISOString(),
    };
    await fs.mkdir(path.join(OUT, 'bench'), { recursive: true });
    await fs.writeFile(path.join(OUT, 'bench', `${tag}_workloads.json`), JSON.stringify(summary, null, 2));
    const csv = [
      'id,label,p50_ms,p95_ms,p99_ms,mean_ms',
      ...results.map(
        (r) => `${r.id},${JSON.stringify(r.label)},${r.p50_ms},${r.p95_ms},${r.p99_ms},${r.mean_ms}`,
      ),
    ].join('\n');
    await fs.writeFile(path.join(OUT, 'bench', `${tag}_workloads.csv`), csv + '\n');
    process.stdout.write(JSON.stringify({ tag, count: results.length, dbName }, null, 2) + '\n');
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  process.stderr.write(String(e?.stack || e) + '\n');
  process.exit(1);
});
