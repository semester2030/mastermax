/**
 * Gate 7B.5.1.3 — small API smoke after Migration 017 (full triple inherited when read-path identical).
 */
import 'reflect-metadata';

async function main() {
  const perfUrl =
    process.env.PERF_DATABASE_URL || 'postgresql://127.0.0.1:5432/places_core_perf';
  process.env.NODE_ENV = 'test';
  process.env.DATABASE_URL = perfUrl;
  process.env.AUTH_MODE = 'stub';
  process.env.STUB_WEBHOOK_SECRET = 'test-stub-secret';
  process.env.HOLD_TTL_SECONDS = '720';
  process.env.QUOTE_TTL_SECONDS = '900';
  process.env.DEFAULT_COMMISSION_BPS = '1000';
  process.env.PORT = '0';
  process.env.PG_WORK_MEM = process.env.PG_WORK_MEM || '16MB';
  process.env.PG_POOL_MAX = '20';

  const { createTestApp, auth } = await import('../../test/helpers/test-app');
  const { PgService } = await import('../../src/shared/database/pg.service');
  const request = (await import('supertest')).default;

  const app = await createTestApp();
  const pg = app.get(PgService);
  const bodies = [
    { sort: 'best', limit: 20, surface: 'search' },
    { q: 'فندق', sort: 'best', limit: 20, surface: 'search' },
    { sort: 'newest', limit: 20, surface: 'search' },
  ];
  let errors = 0;
  const samples: number[] = [];
  for (const body of bodies) {
    for (let i = 0; i < 40; i++) {
      const t0 = Date.now();
      const res = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth('g7b513-smoke'))
        .send(body);
      samples.push(Date.now() - t0);
      if (res.status >= 400) errors += 1;
    }
  }
  samples.sort((a, b) => a - b);
  const p95 = samples[Math.ceil(0.95 * samples.length) - 1];
  const snap = {
    totalCount: pg.pool.totalCount,
    idleCount: pg.pool.idleCount,
    waitingCount: pg.pool.waitingCount,
    max: pg.poolMax,
  };
  await app.close();
  const out = {
    n: samples.length,
    errors,
    p95_ms: p95,
    pool: snap,
    inherit_triple: true,
    verdict: errors === 0 && snap.waitingCount === 0 && p95 <= 500 ? 'SMOKE_PASS' : 'SMOKE_FAIL',
  };
  process.stdout.write(JSON.stringify(out, null, 2) + '\n');
  if (out.verdict !== 'SMOKE_PASS') process.exit(3);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
