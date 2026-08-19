/**
 * Gate 7B.5.1 — HTTP evidence: deep cursor walk, diversity runtime, same-type results.
 * PERF DB only. Stores raw samples + exit codes under docs/places_core_gate7b51/raw/.
 */
import { promises as fs } from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { resolvePerfDatabaseUrl, assertSafePerfDbName, dbNameFromUrl } from './perf-db-safety';

const OUT = path.resolve(__dirname, '../../../../docs/places_core_gate7b51/raw');

type SuperAgent = {
  post: (url: string) => {
    set: (k: string, v: string) => {
      send: (body: Record<string, unknown>) => Promise<{
        status: number;
        body: {
          items?: { venueId: string }[];
          total?: number;
          nextCursor?: string | null;
        };
      }>;
    };
  };
};

async function main(): Promise<void> {
  const { perfUrl, dbName } = await resolvePerfDatabaseUrl();
  assertSafePerfDbName(dbName);
  if (dbNameFromUrl(perfUrl) === 'places_core_test') {
    throw new Error('REFUSED: evidence harness must not use places_core_test');
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

  const { createTestApp, auth: authFn } = await import('../../test/helpers/test-app');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const request = require('supertest') as (server: unknown) => SuperAgent;
  const app = await createTestApp();
  const pool = new Pool({ connectionString: perfUrl });

  const evidence: Record<string, unknown> = {
    dbName,
    ts: new Date().toISOString(),
    exit_code: 0,
  };

  try {
    const anchor = await pool.query<{ id: string; venue_type: string }>(
      `SELECT id, venue_type FROM venues
       WHERE status='published' AND venue_type='hotel'
         AND lat BETWEEN 24.6 AND 25 AND lng BETWEEN 46.5 AND 47
       ORDER BY created_at DESC LIMIT 1`,
    );
    if (!anchor.rowCount) throw new Error('no anchor');
    const anchorId = anchor.rows[0].id;

    const deep = await walkCursor(app, request, authFn, {
      sort: 'newest',
      limit: 50,
      surface: 'search',
    });
    evidence.cursor_deep = deep;
    if (
      Number(deep.seen) !== Number(deep.total) ||
      Number(deep.dupes) > 0 ||
      deep.terminal_cursor !== null
    ) {
      evidence.exit_code = 2;
    }

    const divSamples: number[] = [];
    let divItems = 0;
    let divStatus = 0;
    for (let i = 0; i < 20; i++) {
      const t0 = Date.now();
      const res = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', authFn('g7b51-ev'))
        .send({ sort: 'newest', limit: 20, surface: 'feed', city: 'Riyadh' });
      divSamples.push(Date.now() - t0);
      divStatus = res.status;
      divItems = res.body?.items?.length ?? 0;
      if (res.status >= 400) {
        evidence.exit_code = 3;
        break;
      }
    }
    divSamples.sort((a, b) => a - b);
    evidence.diversity_runtime = {
      n: divSamples.length,
      status: divStatus,
      items_last: divItems,
      samples_ms: divSamples,
      p95_ms: divSamples[Math.ceil(0.95 * divSamples.length) - 1],
      real_results: divItems > 0,
    };
    if (divItems <= 0) evidence.exit_code = 3;

    const amen = await pool.query<{ amenity_code: string }>(
      `SELECT DISTINCT l.amenity_code
       FROM venue_amenity_links l
       JOIN venues v ON v.id = l.venue_id
       WHERE v.venue_type = $1 AND l.state = 'AVAILABLE'
       ORDER BY 1 LIMIT 2`,
      [anchor.rows[0].venue_type],
    );
    const amenities = amen.rows.map((r) => r.amenity_code);
    const sameBody: Record<string, unknown> = {
      sort: 'near_place',
      anchorVenueId: anchorId,
      radiusKm: 30,
      sameTypeOnly: true,
      limit: 20,
      surface: 'search',
    };
    if (amenities.length) sameBody.amenities = amenities;
    const sameSamples: number[] = [];
    let sameItems = 0;
    let sameTotal = 0;
    for (let i = 0; i < 20; i++) {
      const t0 = Date.now();
      const res = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', authFn('g7b51-ev'))
        .send(sameBody);
      sameSamples.push(Date.now() - t0);
      sameItems = res.body?.items?.length ?? 0;
      sameTotal = res.body?.total ?? 0;
      if (res.status >= 400) {
        evidence.exit_code = 4;
        break;
      }
    }
    sameSamples.sort((a, b) => a - b);
    evidence.same_type = {
      amenities,
      n: sameSamples.length,
      items_last: sameItems,
      total: sameTotal,
      samples_ms: sameSamples,
      p95_ms: sameSamples[Math.ceil(0.95 * sameSamples.length) - 1],
      real_results: sameItems > 0 && sameTotal > 0,
    };
    if (!(sameItems > 0 && sameTotal > 0)) evidence.exit_code = 4;

    await fs.mkdir(path.join(OUT, 'bench'), { recursive: true });
    await fs.writeFile(
      path.join(OUT, 'bench', 'http_evidence.json'),
      JSON.stringify(evidence, null, 2),
    );
    process.stdout.write(JSON.stringify({ dbName, exit_code: evidence.exit_code }, null, 2) + '\n');
    process.exitCode = Number(evidence.exit_code) || 0;
  } finally {
    await app.close();
    await pool.end();
  }
}

async function walkCursor(
  app: { getHttpServer: () => unknown },
  request: (server: unknown) => SuperAgent,
  authFn: (u: string) => string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const seen: string[] = [];
  const pageSizes: number[] = [];
  const samples: number[] = [];
  let cursor: string | undefined;
  let total = -1;
  let pages = 0;
  let terminal: string | null = 'unset';
  for (;;) {
    const t0 = Date.now();
    const res = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', authFn('g7b51-ev'))
      .send({ ...body, cursor });
    samples.push(Date.now() - t0);
    if (res.status >= 400) {
      return { error: res.status, body: res.body, seen: seen.length, pages };
    }
    total = res.body.total ?? -1;
    pageSizes.push(res.body.items?.length ?? 0);
    for (const it of res.body.items ?? []) seen.push(it.venueId);
    pages += 1;
    if (!res.body.nextCursor) {
      terminal = null;
      break;
    }
    cursor = res.body.nextCursor;
    if (pages > 2000) break;
  }
  const dupes = seen.length - new Set(seen).size;
  return {
    pages,
    seen: seen.length,
    total,
    dupes,
    terminal_cursor: terminal,
    page_sizes: pageSizes.slice(0, 5).concat(pageSizes.slice(-2)),
    samples_ms: samples,
    ok: seen.length === total && dupes === 0 && terminal === null,
  };
}

main().catch((e) => {
  process.stderr.write(String(e?.stack || e) + '\n');
  process.exit(1);
});
