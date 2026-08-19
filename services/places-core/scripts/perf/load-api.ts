/**
 * Gate 7B.5.1.2 — API load evidence.
 * PER_WORKLOAD=1000 → 10 workloads × 1000 = 10_000 measured requests per run.
 * Production pool max=20. --triple requires 3 consecutive PASS runs (no cherry-picking).
 * Runner: ts-node (emitDecoratorMetadata). Do NOT use tsx/esbuild — Nest DI breaks.
 */
import 'reflect-metadata';
import { promises as fs } from 'fs';
import path from 'path';
import { resolvePerfDatabaseUrl, assertSafePerfDbName, dbNameFromUrl } from './perf-db-safety';

const OUT = path.resolve(__dirname, '../../../../docs/places_core_gate7b512/raw/bench');
const CONCURRENCY = 20;
const PER_WORKLOAD = 1000;
const MIN_TOTAL = 10_000;

type Wl = { id: string; body: Record<string, unknown> };

function workloads(anchorId: string): Wl[] {
  return [
    { id: 'api_q', body: { q: 'فندق', sort: 'best', limit: 20, surface: 'search' } },
    { id: 'api_bounds', body: { minLat: 24.5, maxLat: 25, minLng: 46.4, maxLng: 47, sort: 'best', limit: 20, surface: 'map' } },
    { id: 'api_near', body: { sort: 'near_me', lat: 24.75, lng: 46.72, radiusKm: 8, limit: 20, surface: 'circle' } },
    { id: 'api_best', body: { sort: 'best', limit: 20, surface: 'search' } },
    { id: 'api_newest', body: { sort: 'newest', limit: 20, surface: 'search' } },
    { id: 'api_div', body: { sort: 'newest', limit: 20, surface: 'feed', city: 'Riyadh' } },
    {
      id: 'api_near_place',
      body: { sort: 'near_place', anchorVenueId: anchorId, radiusKm: 25, sameTypeOnly: true, limit: 20 },
    },
    { id: 'api_rating', body: { sort: 'rating', limit: 20, surface: 'search' } },
    { id: 'api_cheap', body: { sort: 'cheapest', limit: 20, surface: 'search' } },
    { id: 'api_limit50', body: { sort: 'newest', limit: 50, surface: 'search' } },
  ];
}

function pct(sorted: number[], p: number): number {
  if (!sorted.length) return 0;
  return sorted[Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1))];
}

function runIdFromArgv(): string {
  const flag = process.argv.find((a) => a.startsWith('--run='));
  if (flag) return flag.slice('--run='.length);
  return process.env.RUN_ID?.trim() || '1';
}

async function probePgActivity(perfUrl: string): Promise<Record<string, unknown>> {
  const { Pool } = await import('pg');
  const p = new Pool({ connectionString: perfUrl, max: 2 });
  try {
    const grouped = await p.query(`
      SELECT COALESCE(state, 'null') AS state,
             COALESCE(wait_event_type, 'none') AS wait_event_type,
             COALESCE(wait_event, 'none') AS wait_event,
             count(*)::int AS n
      FROM pg_stat_activity
      WHERE datname = current_database()
      GROUP BY 1, 2, 3
      ORDER BY n DESC
    `);
    // Exclude idle ClientRead from "blocking waiters" claim — those are normal idle sessions.
    const blocking = grouped.rows.filter(
      (r) =>
        r.wait_event_type !== 'none' &&
        !(r.state === 'idle' && r.wait_event === 'ClientRead'),
    );
    const temp = await p.query(`
      SELECT
        COALESCE(sum(temp_files),0)::bigint AS temp_files,
        COALESCE(sum(temp_bytes),0)::bigint AS temp_bytes
      FROM pg_stat_database WHERE datname = current_database()
    `);
    const settings = await p.query(`
      SELECT current_setting('work_mem') AS server_work_mem,
             pg_size_pretty(pg_database_size(current_database())) AS db_size
    `);
    return {
      activity_grouped: grouped.rows,
      blocking_waiters: blocking,
      blocking_waiter_count: blocking.reduce((a, r) => a + Number(r.n), 0),
      temp: temp.rows[0],
      ...settings.rows[0],
      measured: true,
    };
  } finally {
    await p.end();
  }
}

function poolSnap(pg: {
  pool: { totalCount: number; idleCount: number; waitingCount: number };
  poolMax: number;
}) {
  return {
    totalCount: pg.pool.totalCount,
    idleCount: pg.pool.idleCount,
    waitingCount: pg.pool.waitingCount,
    max: pg.poolMax,
  };
}

async function runOnce(runId: string): Promise<number> {
  const { perfUrl, dbName } = await resolvePerfDatabaseUrl();
  assertSafePerfDbName(dbName);
  if (dbNameFromUrl(perfUrl) === 'places_core_test') {
    throw new Error('REFUSED: load harness must not use places_core_test');
  }

  process.env.NODE_ENV = 'test';
  process.env.DATABASE_URL = perfUrl;
  process.env.AUTH_MODE = 'stub';
  process.env.STUB_WEBHOOK_SECRET = 'test-stub-secret';
  process.env.HOLD_TTL_SECONDS = '720';
  process.env.QUOTE_TTL_SECONDS = '900';
  process.env.DEFAULT_COMMISSION_BPS = '1000';
  process.env.PORT = '0';
  if (!process.env.PG_WORK_MEM) process.env.PG_WORK_MEM = '16MB';
  process.env.PG_POOL_MAX = '20';

  const { Pool } = await import('pg');
  const { createTestApp, auth } = await import('../../test/helpers/test-app');
  const { PgService } = await import('../../src/shared/database/pg.service');
  const request = (await import('supertest')).default;

  const admin = new Pool({ connectionString: perfUrl });
  await admin.query('VACUUM (ANALYZE) venues');
  const anchor = await admin.query<{ id: string }>(
    `SELECT id FROM venues WHERE status='published' AND venue_type='hotel'
       AND lat BETWEEN 24.6 AND 25 AND lng BETWEEN 46.5 AND 47
     ORDER BY created_at DESC LIMIT 1`,
  );
  await admin.end();
  if (!anchor.rowCount) throw new Error('no anchor');

  const rssBefore = process.memoryUsage();
  const pgBefore = await probePgActivity(perfUrl);
  const app = await createTestApp();
  const pg = app.get(PgService);
  const poolBefore = poolSnap(pg);
  if (poolBefore.max !== 20) {
    throw new Error(`PG_POOL_MAX not applied: pool.max=${poolBefore.max} (expected 20)`);
  }
  const appWorkMem = (await pg.pool.query<{ work_mem: string }>('SHOW work_mem')).rows[0]
    ?.work_mem;

  async function runPool(body: Record<string, unknown>, n: number, concurrency: number) {
    const samples: number[] = [];
    let errors = 0;
    let i = 0;
    async function worker() {
      while (true) {
        const idx = i++;
        if (idx >= n) return;
        const t0 = Date.now();
        try {
          const res = await request(app.getHttpServer())
            .post('/v1/discovery/search')
            .set('Authorization', auth('g7b512-load'))
            .send(body);
          if (res.status >= 400) errors += 1;
          samples.push(Date.now() - t0);
        } catch {
          errors += 1;
          samples.push(Date.now() - t0);
        }
      }
    }
    await Promise.all(Array.from({ length: concurrency }, () => worker()));
    return { samples, errors };
  }

  const results: Record<string, unknown>[] = [];
  let totalReq = 0;
  let totalErr = 0;
  let exitCode = 0;
  let poolAfterLoad = poolBefore;
  let pgAfterLoad: Record<string, unknown> = {};
  try {
    const wls = workloads(anchor.rows[0].id);
    process.stdout.write(`RUN${runId} COLD_WARM...\n`);
    for (const wl of wls) {
      await runPool(wl.body, 30, 10);
    }
    for (const wl of wls) {
      process.stdout.write(`RUN${runId} LOAD ${wl.id} (n=${PER_WORKLOAD})...\n`);
      await runPool(wl.body, 50, 10);
      const { samples, errors } = await runPool(wl.body, PER_WORKLOAD, CONCURRENCY);
      samples.sort((a, b) => a - b);
      totalReq += samples.length;
      totalErr += errors;
      const row = {
        id: wl.id,
        n: samples.length,
        concurrency: CONCURRENCY,
        errors,
        p50_ms: pct(samples, 50),
        p95_ms: pct(samples, 95),
        p99_ms: pct(samples, 99),
        mean_ms: samples.reduce((a, b) => a + b, 0) / samples.length,
        max_ms: samples[samples.length - 1],
        samples_ms: samples,
      };
      results.push(row);
      if (errors > 0 || row.p95_ms > 500 || row.p99_ms > 1000) {
        exitCode = 3;
        process.stderr.write(
          `BUDGET_FAIL run=${runId} ${wl.id} p95=${row.p95_ms} p99=${row.p99_ms} errors=${errors}\n`,
        );
      }
    }
    poolAfterLoad = poolSnap(pg);
    pgAfterLoad = await probePgActivity(perfUrl);
  } finally {
    const rssAfterLoad = process.memoryUsage();
    await app.close();
    // After close: Nest PgService pool ended — capture process RSS + PG activity only.
    const rssAfterClose = process.memoryUsage();
    const pgAfterClose = await probePgActivity(perfUrl);

    if (totalErr > 0 || totalReq < MIN_TOTAL) exitCode = Math.max(exitCode, 2);
    if (poolAfterLoad.waitingCount !== 0) {
      process.stderr.write(`POOL_WAITER_FAIL after-load waitingCount=${poolAfterLoad.waitingCount}\n`);
      exitCode = Math.max(exitCode, 4);
    }

    const summary = {
      run_id: runId,
      dbName,
      pool_max_forced: 20,
      app_work_mem: appWorkMem,
      pool_before: poolBefore,
      pool_after_load: poolAfterLoad,
      pool_after_close_note: 'Nest PgService.pool.end() completed; waitingCount must be 0 at after_load',
      rss_before: rssBefore,
      rss_after_load: rssAfterLoad,
      rss_after_close: rssAfterClose,
      pg_before: pgBefore,
      pg_after_load: pgAfterLoad,
      pg_after_close: pgAfterClose,
      concurrency: CONCURRENCY,
      per_workload: PER_WORKLOAD,
      total_requests: totalReq,
      total_errors: totalErr,
      results,
      budgets: { api_p95_ms: 500, api_p99_ms: 1000, min_total: MIN_TOTAL },
      exit_code: exitCode,
      ts: new Date().toISOString(),
    };
    await fs.mkdir(OUT, { recursive: true });
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const base = `api_load_run${runId}`;
    await fs.writeFile(path.join(OUT, `${base}.json`), JSON.stringify(summary, null, 2));
    await fs.writeFile(path.join(OUT, `${base}_${stamp}.json`), JSON.stringify(summary, null, 2));
    const csv = [
      'id,p50,p95,p99,errors,n',
      ...results.map(
        (r: any) => `${r.id},${r.p50_ms},${r.p95_ms},${r.p99_ms},${r.errors},${r.n}`,
      ),
    ].join('\n');
    await fs.writeFile(path.join(OUT, `${base}.csv`), csv + '\n');
    process.stdout.write(
      JSON.stringify(
        { runId, totalReq, totalErr, exitCode, poolMax: poolBefore.max, appWorkMem },
        null,
        2,
      ) + '\n',
    );
  }
  return exitCode;
}

async function main(): Promise<void> {
  const triple = process.argv.includes('--triple');
  if (triple) {
    // Optional cold barrier (saved as run0) — evidence runs remain 1..3 and ALL must PASS.
    process.stdout.write('\n=== COLD_BARRIER run0 (retained; not a substitute for runs 1–3) ===\n');
    await runOnce('0');
    await new Promise((r) => setTimeout(r, 2000));
    let worst = 0;
    for (let i = 1; i <= 3; i++) {
      process.stdout.write(`\n=== TRIPLE RUN ${i}/3 ===\n`);
      const code = await runOnce(String(i));
      worst = Math.max(worst, code);
      if (code !== 0) {
        process.stderr.write(`TRIPLE_FAIL run=${i} exit=${code}\n`);
        process.exit(code);
      }
      process.stdout.write(`TRIPLE_RUN_PASS run=${i}\n`);
      await new Promise((r) => setTimeout(r, 2000));
    }
    if (worst !== 0) process.exit(worst);
    process.stdout.write('TRIPLE_PASS\n');
    return;
  }
  const code = await runOnce(runIdFromArgv());
  if (code !== 0) process.exit(code);
}

main().catch((e) => {
  process.stderr.write(String(e?.stack || e) + '\n');
  process.exit(1);
});
