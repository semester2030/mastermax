/**
 * Gate 7B.4.2 — Batched diversity prefetch bounds + final closure tests.
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
  parseCursorV2Structural,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import {
  computeInitialBatch,
  diversityCandidateQueryBound,
  diversityRowBound,
} from '../../src/modules/filters/application/discovery-diversity-runtime';
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';

type DivMetrics = {
  distinctQueryCount: number;
  candidateQueryCount: number;
  queryCount: number;
  rowsFetched: number;
  typeCount: number;
  limit: number;
  initialBatch: number;
  rowBound: number;
  candidateQueryBound: number;
};

describe('Gate 7B.4.2 — batched prefetch + final closure', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b42-user';
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
    // Restore capabilities disabled by prior tests
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

  /** >60 venues across ALL enabled discovery types, heavily hotel-skewed. */
  async function seedLargeSkewed(): Promise<string[]> {
    const ids: string[] = [];
    let n = 0;
    const day = () => String(28 - (n++ % 27)).padStart(2, '0');
    // Heavy skew: 50 hotels + 2 of every other enabled type
    for (let i = 0; i < 50; i++) {
      const v = await seedFeedVenue({
        name: `H${i}`,
        venueType: 'hotel',
        createdAt: `2030-06-${day()}T10:00:00.000Z`,
      });
      ids.push(v.venueId);
    }
    for (const t of enabledTypes.filter((x) => x !== 'hotel')) {
      for (let i = 0; i < 2; i++) {
        const v = await seedFeedVenue({
          name: `${t}_${i}`,
          venueType: t,
          createdAt: `2030-05-${day()}T10:00:00.000Z`,
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

  it('G7B42-BOUND-01 candidateQuery≤2×types; rows≤2×(types+limit) for 1/20/50', async () => {
    await seedLargeSkewed();
    const engine = app.get(FilterEngineService);
    const observed: Array<Record<string, number>> = [];

    for (const limit of [1, 20, 50]) {
      await engine.search({ surface: 'feed', sort: 'newest', limit } as never);
      const m = lastMetrics(engine);
      expect(m.typeCount).toBe(enabledTypes.length);
      expect(m.initialBatch).toBe(computeInitialBatch(limit, m.typeCount));
      expect(m.rowBound).toBe(diversityRowBound(m.typeCount, limit));
      expect(m.candidateQueryBound).toBe(diversityCandidateQueryBound(m.typeCount));
      expect(m.candidateQueryCount).toBeLessThanOrEqual(m.candidateQueryBound);
      expect(m.rowsFetched).toBeLessThanOrEqual(m.rowBound);
      // Must not regress to types×limit rows or per-item N+1 (~limit+types queries)
      expect(m.rowsFetched).toBeLessThan(m.typeCount * Math.max(limit, 2));
      if (limit >= 20) {
        expect(m.candidateQueryCount).toBeLessThan(limit);
        expect(m.candidateQueryCount).toBeLessThanOrEqual(2 * m.typeCount + 1);
      }
      observed.push({
        limit,
        typeCount: m.typeCount,
        initialBatch: m.initialBatch,
        candidateQueryCount: m.candidateQueryCount,
        candidateQueryBound: m.candidateQueryBound,
        rowsFetched: m.rowsFetched,
        rowBound: m.rowBound,
        distinctQueryCount: m.distinctQueryCount,
      });
    }
    console.log('G7B42_BOUND_OBSERVED', JSON.stringify(observed));
  });

  it('G7B42-BOUND-02 full traversal seen=expected=total; terminal null', async () => {
    const ids = await seedLargeSkewed();
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
      if (!res.body.nextCursor) break;
      cursor = res.body.nextCursor;
      expect(seen.length).toBeLessThan(ids.length + 5);
    }
    expect(total).toBe(ids.length);
    expect(seen.length).toBe(ids.length);
    expect(new Set(seen).size).toBe(ids.length);
    expect([...seen].sort()).toEqual([...ids].sort());
  });

  it('G7B42-FEED GET/POST ≥3 pages; newest cursor accepted on GET', async () => {
    for (let i = 0; i < 70; i++) {
      await seedFeedVenue({
        name: `F${i}`,
        venueType: enabledTypes[i % enabledTypes.length],
        createdAt: `2031-02-${String(28 - (i % 27)).padStart(2, '0')}T12:00:00.000Z`,
      });
    }

    // Mint once on POST — rankingAsOf is server-owned and frozen in the cursor chain.
    const post1 = await search({ surface: 'feed', sort: 'newest', limit: 20 });
    expect(post1.status).toBe(201);
    expect(post1.body.items.length).toBe(20);
    const asOf = post1.body.applied.rankingAsOf as string;
    expect(asOf).toMatch(/^\d{4}-\d{2}-\d{2}T/);

    // GET first page — item parity for newest (feed adapter strips applied).
    const get1 = await feed({});
    expect(get1.status).toBe(200);
    expect(get1.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
      post1.body.items.map((i: { venueId: string }) => i.venueId),
    );

    // Server-issued newest cursor accepted on GET.
    expect(post1.body.nextCursor).toBeTruthy();
    const getCont = await feed({ cursor: post1.body.nextCursor });
    expect(getCont.status).toBe(200);
    expect(getCont.body.items.length).toBeGreaterThan(0);
    expect(getCont.body.total).toBe(post1.body.total);

    // ≥3 shared pages via the same POST-issued cursor (stable rankingAsOf).
    let cursor: string | undefined = post1.body.nextCursor;
    let pages = 1;
    for (; pages < 5 && cursor; pages++) {
      const post = await search({
        surface: 'feed',
        sort: 'newest',
        limit: 20,
        cursor,
      });
      const get = await feed({ cursor });
      expect(post.status).toBe(201);
      expect(get.status).toBe(200);
      expect(post.body.applied.rankingAsOf).toBe(asOf);
      expect(get.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
        post.body.items.map((i: { venueId: string }) => i.venueId),
      );
      expect(get.body.nextCursor).toBe(post.body.nextCursor);
      if (post.body.nextCursor) {
        expect(parseCursorV2Structural(post.body.nextCursor, 'required').rankingAsOf).toBe(asOf);
      }
      cursor = post.body.nextCursor ?? undefined;
    }
    expect(pages).toBeGreaterThanOrEqual(3);
  });

  it('G7B42-CAPABILITY-OFF + failed filters + playable negatives', async () => {
    await seedFeedVenue({ name: 'OkHotel', venueType: 'hotel' });
    await seedFeedVenue({ name: 'NoVid', venueType: 'chalet', playable: false });
    await seedFeedVenue({
      name: 'Pending',
      venueType: 'villa',
      mediaModeration: 'pending',
    });
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery=FALSE WHERE venue_type='resort'`,
    );
    await seedFeedVenue({ name: 'OffResort', venueType: 'resort' });

    const res = await search({ surface: 'feed', sort: 'best', limit: 50 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(1);
    expect(res.body.items[0].name).toBe('OkHotel');

    const filtered = await search({
      surface: 'feed',
      sort: 'best',
      amenities: ['wifi'],
      limit: 20,
    });
    expect(filtered.status).toBe(201);
    expect(filtered.body.total).toBe(0);
  });

  it('G7B42-SAME negatives: dates/guests/quantity/radius + pending/rejected media', async () => {
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
    const pendingPeer = await seedFeedVenue({
      name: 'PendPeer',
      venueType: 'hotel',
      lat: 24.605,
      lng: 46.605,
      mediaModeration: 'pending',
      mediaKind: 'image',
    });
    const rejectedPeer = await seedFeedVenue({
      name: 'RejPeer',
      venueType: 'hotel',
      lat: 24.602,
      lng: 46.602,
      mediaModeration: 'rejected',
      mediaKind: 'image',
    });

    const ok = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      radiusKm: 50,
      guests: 2,
      quantity: 1,
      checkIn: '2032-01-01',
      checkOut: '2032-01-03',
      amenities: ['wifi'],
      limit: 20,
    });
    expect(ok.status).toBe(201);
    expect(ok.body.applied.profile).toBe('same_type_near_place');
    const ids = ok.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids).toContain(good.venueId);
    expect(ids).not.toContain(pendingPeer.venueId);
    expect(ids).not.toContain(rejectedPeer.venueId);
    expect(ids).not.toContain(anchor.venueId);

    // Tiny radius excludes peer
    const tiny = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      radiusKm: 0.1,
      limit: 20,
    });
    expect(tiny.status).toBe(201);
    expect(tiny.body.items.map((i: { venueId: string }) => i.venueId)).not.toContain(
      good.venueId,
    );

    // Impossible occupancy under dated inventory
    const none = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      guests: 40,
      quantity: 10,
      checkIn: '2032-01-01',
      checkOut: '2032-01-03',
      limit: 20,
    });
    expect(none.status).toBe(201);
    expect(none.body.total).toBe(0);
  });

  it('G7B42-CUR ≤4096; cross-surface/mode mismatch=400; newest GET ok', async () => {
    for (let i = 0; i < 45; i++) {
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
