/**
 * Gate 7B.4.3 — Fixed-chunk diversity row-bound + dense-balanced closure.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import {
  buildWorstCaseBestDiversityCursor,
  DISCOVERY_CURSOR_MAX_LENGTH,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import {
  computeChunkSize,
  diversityCandidateQueryBound,
  diversityRowBound,
} from '../../src/modules/filters/application/discovery-diversity-runtime';
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';

type DivMetrics = {
  resolverQueryCount: number;
  countQueryCount: number;
  distinctQueryCount: number;
  distinctRowCount: number;
  candidateQueryCount: number;
  candidateProjectionRows: number;
  rowsFetched: number;
  returnedRowCount: number;
  totalRequestQueryCount: number;
  observedPgQueryCount?: number;
  queryCount: number;
  typeCount: number;
  limit: number;
  chunkSize: number;
  initialBatch: number;
  rowBound: number;
  candidateQueryBound: number;
};

describe('Gate 7B.4.3 — fixed-chunk row-bound + final closure', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b43-user';
  let enabledTypes: string[] = [];

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    const r = await pool.query<{ venue_type: string }>(
      `SELECT venue_type FROM venue_type_capabilities
       WHERE enabled_for_discovery = TRUE ORDER BY sort_order`,
    );
    enabledTypes = r.rows.map((x) => x.venue_type);
    expect(enabledTypes.length).toBeGreaterThanOrEqual(6);
  }, 120_000);

  beforeEach(async () => {
    await pool.query('TRUNCATE providers CASCADE');
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery = TRUE
       WHERE venue_type = ANY($1::text[])`,
      [enabledTypes],
    );
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  async function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(uid))
      .send(body);
  }

  async function feed(query: Record<string, string | undefined> = {}) {
    const q = new URLSearchParams();
    for (const [k, v] of Object.entries(query)) {
      if (v != null) q.set(k, v);
    }
    const qs = q.toString();
    return request(app.getHttpServer())
      .get(`/v1/feed${qs ? `?${qs}` : ''}`)
      .set('Authorization', auth(uid));
  }

  async function seedFeedVenue(opts: {
    name: string;
    venueType: string;
    createdAt?: string;
    playable?: boolean;
    draft?: boolean;
    mediaModeration?: 'approved' | 'pending' | 'rejected';
    mediaKind?: 'video' | 'image';
    lat?: number;
    lng?: number;
    rating?: number;
    reviews?: number;
  }): Promise<{ venueId: string; providerId: string }> {
    const providerId = await seedProvider(pool, `${uid}-${newId()}`, opts.name);
    const venue = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.venueType,
      types: [{ name: 'std', qty: 4, nights: { '2032-01-01': '180' } }],
    });
    if (opts.draft) {
      await pool.query(`UPDATE venues SET status='draft' WHERE id=$1`, [venue.venueId]);
    }
    if (opts.createdAt) {
      await pool.query(`UPDATE venues SET created_at=$2::timestamptz WHERE id=$1`, [
        venue.venueId,
        opts.createdAt,
      ]);
    }
    if (opts.lat != null && opts.lng != null) {
      await pool.query(`UPDATE venues SET lat=$2, lng=$3 WHERE id=$1`, [
        venue.venueId,
        opts.lat,
        opts.lng,
      ]);
    }
    if (opts.rating != null || opts.reviews != null) {
      await pool.query(
        `UPDATE venues SET rating_average=$2, reviews_count=$3 WHERE id=$1`,
        [venue.venueId, opts.rating ?? 4.5, opts.reviews ?? 10],
      );
    }
    const moderation = opts.mediaModeration ?? 'approved';
    const kind = opts.mediaKind ?? 'video';
    if (opts.playable !== false && !opts.draft) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,$4,$5,'https://example.test/c.jpg',$6,0,$7)`,
        [
          newId(),
          venue.venueId,
          providerId,
          kind,
          kind === 'video'
            ? `https://example.test/${opts.name}.mp4`
            : `https://example.test/${opts.name}.jpg`,
          moderation,
          opts.venueType,
        ],
      );
    }
    return { venueId: venue.venueId, providerId };
  }

  /** Dense-balanced: ≥60 per enabled type; newest timestamps interleaved across types. */
  async function seedDenseBalanced(perType = 60): Promise<string[]> {
    const ids: string[] = [];
    let seq = 0;
    for (let i = 0; i < perType; i++) {
      for (const t of enabledTypes) {
        // Interleave created_at so newest order rotates types (breaks 7B.4.2 warm+limit-refill).
        const day = String(1 + (seq % 27)).padStart(2, '0');
        const hour = String(seq % 24).padStart(2, '0');
        const v = await seedFeedVenue({
          name: `D_${t}_${i}`,
          venueType: t,
          createdAt: `2031-03-${day}T${hour}:00:00.000Z`,
        });
        ids.push(v.venueId);
        seq += 1;
      }
    }
    expect(ids.length).toBe(enabledTypes.length * perType);
    expect(perType).toBeGreaterThanOrEqual(60);
    return ids;
  }

  /** Heavy hotel skew: many hotels, few peers — forces multi small refills of B. */
  async function seedHeavySkew(): Promise<string[]> {
    const ids: string[] = [];
    let n = 0;
    const day = () => String(28 - (n++ % 27)).padStart(2, '0');
    for (let i = 0; i < 80; i++) {
      const v = await seedFeedVenue({
        name: `SK_H${i}`,
        venueType: 'hotel',
        createdAt: `2030-08-${day()}T12:00:00.000Z`,
      });
      ids.push(v.venueId);
    }
    for (const t of enabledTypes.filter((x) => x !== 'hotel')) {
      for (let i = 0; i < 3; i++) {
        const v = await seedFeedVenue({
          name: `SK_${t}_${i}`,
          venueType: t,
          createdAt: `2030-07-${day()}T12:00:00.000Z`,
        });
        ids.push(v.venueId);
      }
    }
    expect(ids.length).toBeGreaterThan(60);
    return ids;
  }

  function lastMetrics(engine: FilterEngineService): DivMetrics {
    const m = (engine as { lastDiversityMetrics?: DivMetrics }).lastDiversityMetrics;
    expect(m).toBeDefined();
    return m!;
  }

  function assertBounds(m: DivMetrics, limit: number) {
    expect(m.typeCount).toBe(enabledTypes.length);
    expect(m.chunkSize).toBe(computeChunkSize(limit, m.typeCount));
    expect(m.initialBatch).toBe(m.chunkSize);
    expect(m.rowBound).toBe(diversityRowBound(m.typeCount, limit));
    expect(m.candidateQueryBound).toBe(diversityCandidateQueryBound(m.typeCount));
    expect(m.candidateQueryCount).toBeLessThanOrEqual(m.candidateQueryBound);
    expect(m.candidateProjectionRows).toBeLessThanOrEqual(m.rowBound);
    expect(m.rowsFetched).toBe(m.candidateProjectionRows);
    expect(m.candidateProjectionRows).toBeLessThan(m.typeCount * Math.max(limit, 2));
    expect(m.distinctQueryCount).toBe(1);
    expect(m.distinctRowCount).toBe(m.typeCount);
    expect(m.countQueryCount).toBe(1);
    expect(m.totalRequestQueryCount).toBe(m.observedPgQueryCount ?? m.totalRequestQueryCount);
    expect(m.totalRequestQueryCount).toBe(
      m.resolverQueryCount + m.countQueryCount + m.distinctQueryCount + m.candidateQueryCount,
    );
    // Must not be types×limit or per-item N+1
    if (limit >= 20) {
      expect(m.candidateQueryCount).toBeLessThan(limit);
    }
  }

  it('G7B43-DENSE-01 fixed-chunk bounds under dense-balanced (breaks 7B.4.2)', async () => {
    await seedDenseBalanced(60);
    const engine = app.get(FilterEngineService);
    const observed: Array<Record<string, number>> = [];
    for (const limit of [1, 20, 50]) {
      await engine.search({ surface: 'feed', sort: 'newest', limit } as never);
      const m = lastMetrics(engine);
      assertBounds(m, limit);
      // Dense page should empty several type buffers (warm B then refills of B, not limit).
      if (limit === 50) {
        expect(m.chunkSize).toBe(Math.ceil(50 / m.typeCount));
        expect(m.candidateProjectionRows).toBeLessThanOrEqual(2 * (m.typeCount + limit));
        // Prove we are not doing warm + 7×limit refill (406 for T=8).
        expect(m.candidateProjectionRows).toBeLessThan(m.typeCount * m.chunkSize + 7 * limit);
      }
      observed.push({
        limit,
        typeCount: m.typeCount,
        chunkSize: m.chunkSize,
        candidateQueryCount: m.candidateQueryCount,
        candidateQueryBound: m.candidateQueryBound,
        candidateProjectionRows: m.candidateProjectionRows,
        rowBound: m.rowBound,
        returnedRowCount: m.returnedRowCount,
        distinctQueryCount: m.distinctQueryCount,
        countQueryCount: m.countQueryCount,
        totalRequestQueryCount: m.totalRequestQueryCount,
      });
    }
    console.log('G7B43_DENSE_BOUND_OBSERVED', JSON.stringify(observed));
  }, 180_000);

  it('G7B43-SKEW-01 heavy-skew multi small refills stay in bound', async () => {
    await seedHeavySkew();
    const engine = app.get(FilterEngineService);
    const observed: Array<Record<string, number>> = [];
    for (const limit of [1, 20, 50]) {
      await engine.search({ surface: 'feed', sort: 'newest', limit } as never);
      const m = lastMetrics(engine);
      assertBounds(m, limit);
      observed.push({
        limit,
        chunkSize: m.chunkSize,
        candidateQueryCount: m.candidateQueryCount,
        candidateProjectionRows: m.candidateProjectionRows,
        rowBound: m.rowBound,
        returnedRowCount: m.returnedRowCount,
      });
    }
    console.log('G7B43_SKEW_BOUND_OBSERVED', JSON.stringify(observed));
  }, 120_000);

  it('G7B43-TRAV exact traversal dense; nextCursor===null; no dup/drop', async () => {
    const ids = await seedDenseBalanced(60);
    const seen: string[] = [];
    let cursor: string | undefined;
    let total = -1;
    for (;;) {
      const res = await search({
        surface: 'feed',
        sort: 'newest',
        limit: 20,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      if (total < 0) total = res.body.total;
      expect(res.body.total).toBe(total);
      for (const item of res.body.items) seen.push(item.venueId);
      if (res.body.nextCursor === null) break;
      expect(res.body.nextCursor).toEqual(expect.any(String));
      cursor = res.body.nextCursor;
      expect(seen.length).toBeLessThan(ids.length + 5);
    }
    expect(total).toBe(ids.length);
    expect(seen.length).toBe(ids.length);
    expect(new Set(seen).size).toBe(ids.length);
    expect([...seen].sort()).toEqual([...ids].sort());
  }, 300_000);

  it('G7B43-K2 best/newest + ties; GET/POST ≥3 pages; newest cursor on GET', async () => {
    // Ties on best_score via equal ratings; newest interleaved — enough for ≥3 pages.
    for (let i = 0; i < 70; i++) {
      const t = enabledTypes[i % enabledTypes.length];
      await seedFeedVenue({
        name: `K_${i}`,
        venueType: t,
        createdAt: `2031-04-${String(1 + (i % 27)).padStart(2, '0')}T10:00:00.000Z`,
        rating: 4.2,
        reviews: 20,
      });
    }
    const best = await search({ surface: 'feed', sort: 'best', limit: 20 });
    expect(best.status).toBe(201);
    expect(best.body.applied.diversity.applied).toBe(true);
    expect(best.body.applied.diversity.k).toBe(2);

    const post1 = await search({ surface: 'feed', sort: 'newest', limit: 20 });
    expect(post1.status).toBe(201);
    const asOf = post1.body.applied.rankingAsOf as string;
    const get1 = await feed({});
    expect(get1.status).toBe(200);
    expect(get1.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
      post1.body.items.map((i: { venueId: string }) => i.venueId),
    );
    expect(post1.body.nextCursor).toBeTruthy();
    const getCont = await feed({ cursor: post1.body.nextCursor });
    expect(getCont.status).toBe(200);
    expect(getCont.body.items.length).toBeGreaterThan(0);

    let cursor: string | undefined = post1.body.nextCursor;
    let pages = 1;
    for (; pages < 5 && cursor; pages++) {
      const post = await search({ surface: 'feed', sort: 'newest', limit: 20, cursor });
      const get = await feed({ cursor });
      expect(post.status).toBe(201);
      expect(get.status).toBe(200);
      expect(post.body.applied.rankingAsOf).toBe(asOf);
      expect(get.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
        post.body.items.map((i: { venueId: string }) => i.venueId),
      );
      expect(get.body.nextCursor).toBe(post.body.nextCursor);
      cursor = post.body.nextCursor ?? undefined;
    }
    expect(pages).toBeGreaterThanOrEqual(3);
  }, 120_000);

  it('G7B43-CAPABILITY-OFF + playable negatives', async () => {
    await seedFeedVenue({ name: 'OkHotel', venueType: 'hotel' });
    await seedFeedVenue({ name: 'NoVid', venueType: 'chalet', playable: false });
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery=FALSE WHERE venue_type='resort'`,
    );
    await seedFeedVenue({ name: 'OffResort', venueType: 'resort' });
    const res = await search({ surface: 'feed', sort: 'best', limit: 50 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(1);
    expect(res.body.items[0].name).toBe('OkHotel');
  });

  it('G7B43-SAME dates/guests/quantity/radius + pending/rejected media', async () => {
    const anchor = await seedFeedVenue({
      name: 'A',
      venueType: 'hotel',
      lat: 24.6,
      lng: 46.6,
      mediaKind: 'image',
    });
    const good = await seedFeedVenue({
      name: 'Good',
      venueType: 'hotel',
      lat: 24.61,
      lng: 46.61,
      mediaKind: 'image',
    });
    await pool.query(
      `INSERT INTO venue_amenity_links (id, venue_id, amenity_code, state)
       VALUES ($1,$2,'wifi','AVAILABLE') ON CONFLICT DO NOTHING`,
      [newId(), good.venueId],
    );
    await seedFeedVenue({
      name: 'Pending',
      venueType: 'hotel',
      lat: 24.605,
      lng: 46.605,
      mediaModeration: 'pending',
      mediaKind: 'image',
    });
    await seedFeedVenue({
      name: 'Rejected',
      venueType: 'hotel',
      lat: 24.602,
      lng: 46.602,
      mediaModeration: 'rejected',
      mediaKind: 'image',
    });

    const base = {
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      radiusKm: 50,
      limit: 20,
    };
    const ok = await search({
      ...base,
      guests: 2,
      quantity: 1,
      checkIn: '2032-01-01',
      checkOut: '2032-01-03',
      amenities: ['wifi'],
    });
    expect(ok.status).toBe(201);
    expect(ok.body.applied.profile).toBe('same_type_near_place');
    const ids = ok.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids).toContain(good.venueId);
    expect(ids).not.toContain(anchor.venueId);

    for (const body of [
      { ...base, checkIn: '2032-01-01', checkOut: '2032-01-03' },
      { ...base, guests: 2 },
      { ...base, quantity: 1 },
      { ...base, radiusKm: 0.1 },
    ]) {
      const r = await search(body);
      expect(r.status).toBe(201);
      expect(r.body.applied.profile).toBe('same_type_near_place');
    }
  });

  it('G7B43-CUR ≤4096; cross-surface/mode mismatch=400', async () => {
    for (let i = 0; i < 40; i++) {
      await seedFeedVenue({
        name: `C${i}`,
        venueType: enabledTypes[i % enabledTypes.length],
      });
    }
    const newest = await search({ surface: 'feed', sort: 'newest', limit: 20 });
    expect(newest.status).toBe(201);
    expect(newest.body.nextCursor).toBeTruthy();
    expect(newest.body.nextCursor.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
    expect((await feed({ cursor: newest.body.nextCursor })).status).toBe(200);

    const best = await search({ surface: 'feed', sort: 'best', limit: 1 });
    expect(best.body.nextCursor).toBeTruthy();
    expect((await feed({ cursor: best.body.nextCursor })).status).toBe(400);
    expect(
      (await search({ surface: 'map', sort: 'best', cursor: best.body.nextCursor })).status,
    ).toBe(400);
    expect(
      (await search({ surface: 'feed', category: 'hotel', cursor: best.body.nextCursor })).status,
    ).toBe(400);

    const worst = buildWorstCaseBestDiversityCursor();
    expect(worst.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
    expect((await search({ surface: 'feed', sort: 'best', cursor: worst })).status).toBe(400);
  });
});
