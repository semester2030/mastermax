/**
 * Gate 7B.4 acceptance — Mixed Feed Diversity + cursor + feed parity + boundedness.
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
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  parseCursorV2Structural,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';
import { PgService } from '../../src/shared/database/pg.service';
import { VenueTypeCapabilityPolicy } from '../../src/modules/filters/application/venue-type-capability.policy';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { AppError } from '../../src/shared/errors/app-error';
import { encodeTestCursorV2 } from '../helpers/cursor-v2';

describe('Gate 7B.4 — Mixed Feed Diversity + Feed parity', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b4-user';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  beforeEach(async () => {
    await pool.query('TRUNCATE providers CASCADE');
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
    bestScoreHints?: { weighted: number; reviews: number; verified?: boolean };
    playable?: boolean;
    draft?: boolean;
    providerId?: string;
  }): Promise<{ venueId: string; providerId: string }> {
    const providerId =
      opts.providerId ?? (await seedProvider(pool, `${uid}-${newId()}`, opts.name));
    const venue = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.venueType,
      types: [{ name: 'std', qty: 2, nights: { '2032-01-01': '150' } }],
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
    if (opts.bestScoreHints) {
      await pool.query(
        `UPDATE venues SET weighted_rating=$2, reviews_count=$3, verified=$4,
                rating_average=$2, filter_data_completeness=1 WHERE id=$1`,
        [
          venue.venueId,
          opts.bestScoreHints.weighted,
          opts.bestScoreHints.reviews,
          opts.bestScoreHints.verified ?? true,
        ],
      );
    }
    if (opts.playable !== false && !opts.draft) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,$5)`,
        [
          newId(),
          venue.venueId,
          providerId,
          `https://example.test/${opts.name}.mp4`,
          opts.venueType,
        ],
      );
    }
    return { venueId: venue.venueId, providerId };
  }

  function decodeCursor(raw: string, mode: 'required' | 'forbidden' = 'required') {
    return parseCursorV2Structural(raw, mode);
  }

  it('G7B4-DIV-02/03 best+newest mixed feed apply K=2 metadata', async () => {
    await seedFeedVenue({ name: 'H1', venueType: 'hotel' });
    await seedFeedVenue({ name: 'C1', venueType: 'chalet' });
    await seedFeedVenue({ name: 'H2', venueType: 'hotel' });
    await seedFeedVenue({ name: 'C2', venueType: 'chalet' });
    const best = await search({ surface: 'feed', sort: 'best', limit: 2 });
    expect(best.status).toBe(201);
    expect(best.body.applied.diversity).toEqual({
      applied: true,
      version: DIVERSITY_VERSION_CURRENT,
      k: DIVERSITY_K_DEFAULT,
    });
    expect(best.body.nextCursor).toBeTruthy();
    const cb = decodeCursor(best.body.nextCursor);
    expect(cb.diversityVersion).toBe(1);
    expect(cb.diversityK).toBe(2);
    expect(cb.diversity).toBeDefined();

    const newest = await search({ surface: 'feed', sort: 'newest', limit: 2 });
    expect(newest.status).toBe(201);
    expect(newest.body.applied.diversity.applied).toBe(true);
    expect(newest.body.sort).toBe('newest');
    expect(newest.body.nextCursor).toBeTruthy();
  });

  it('G7B4-DIV-04/05 H,H,H,H,C,H,C across pages — no drop/dupe; terminal null', async () => {
    const ids: string[] = [];
    for (let i = 0; i < 4; i++) {
      const v = await seedFeedVenue({
        name: `H${i}`,
        venueType: 'hotel',
        createdAt: `2030-01-${String(10 - i).padStart(2, '0')}T12:00:00.000Z`,
      });
      ids.push(v.venueId);
    }
    const c0 = await seedFeedVenue({
      name: 'C0',
      venueType: 'chalet',
      createdAt: '2030-01-05T12:00:00.000Z',
    });
    ids.push(c0.venueId);
    const h4 = await seedFeedVenue({
      name: 'H4',
      venueType: 'hotel',
      createdAt: '2030-01-04T12:00:00.000Z',
    });
    ids.push(h4.venueId);
    const c1 = await seedFeedVenue({
      name: 'C1',
      venueType: 'chalet',
      createdAt: '2030-01-03T12:00:00.000Z',
    });
    ids.push(c1.venueId);

    const seen: string[] = [];
    let cursor: string | undefined;
    let pages = 0;
    let total = -1;
    for (;;) {
      const res = await search({
        surface: 'feed',
        sort: 'newest',
        limit: 2,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      expect(res.body.applied.diversity.applied).toBe(true);
      if (total < 0) total = res.body.total;
      expect(res.body.total).toBe(total);
      for (const item of res.body.items) {
        seen.push(item.venueId);
      }
      pages += 1;
      if (!res.body.nextCursor) break;
      cursor = res.body.nextCursor;
      expect(pages).toBeLessThan(20);
    }
    expect(total).toBe(ids.length);
    expect(seen.length).toBe(ids.length);
    expect(new Set(seen).size).toBe(ids.length);
    expect([...seen].sort()).toEqual([...ids].sort());
    const typesRes = await pool.query<{ id: string; venue_type: string }>(
      `SELECT id::text AS id, venue_type FROM venues WHERE id = ANY($1::uuid[])`,
      [seen],
    );
    const typeById = new Map(typesRes.rows.map((r) => [r.id, r.venue_type]));
    const typeSeq = seen.map((id) => typeById.get(id)!);
    // Newest + K=2 with this timeline (not pure newest H×4…).
    expect(typeSeq.join(',')).toBe('hotel,hotel,chalet,hotel,hotel,chalet,hotel');
  });

  it('G7B4-DIV-06 mono-type exhausts without deadlock/encode failure', async () => {
    for (let i = 0; i < 5; i++) {
      await seedFeedVenue({ name: `Mono${i}`, venueType: 'hotel' });
    }
    const seen: string[] = [];
    let cursor: string | undefined;
    for (;;) {
      const res = await search({
        surface: 'feed',
        sort: 'best',
        limit: 2,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      seen.push(...res.body.items.map((i: { venueId: string }) => i.venueId));
      if (!res.body.nextCursor) break;
      const decoded = decodeCursor(res.body.nextCursor);
      expect(decoded.diversity!.streak).toBeLessThanOrEqual(2);
      cursor = res.body.nextCursor;
    }
    expect(seen.length).toBe(5);
    expect(new Set(seen).size).toBe(5);
  });

  it('G7B4-DIV-07 three types; exact tuple ties → id ASC', async () => {
    const hints = { weighted: 5, reviews: 20, verified: true };
    const a = await seedFeedVenue({ name: 'A', venueType: 'hotel', bestScoreHints: hints });
    const b = await seedFeedVenue({ name: 'B', venueType: 'chalet', bestScoreHints: hints });
    const c = await seedFeedVenue({ name: 'C', venueType: 'villa', bestScoreHints: hints });
    // Force identical created_at for newest sort ties across types
    const ts = '2031-06-01T10:00:00.000Z';
    await pool.query(`UPDATE venues SET created_at=$1::timestamptz WHERE id = ANY($2::uuid[])`, [
      ts,
      [a.venueId, b.venueId, c.venueId],
    ]);
    const res = await search({ surface: 'feed', sort: 'newest', limit: 3 });
    expect(res.status).toBe(201);
    expect(res.body.items).toHaveLength(3);
    const ids = res.body.items.map((i: { venueId: string }) => i.venueId);
    // Among equal sort keys, diversity picks by sort dirs then id ASC within eligible pool.
    expect(ids).toEqual([...ids].sort());
  });

  it('G7B4-DIV-08 limits 1/20/50 page bounds', async () => {
    for (let i = 0; i < 8; i++) {
      await seedFeedVenue({
        name: `L${i}`,
        venueType: i % 2 === 0 ? 'hotel' : 'chalet',
      });
    }
    for (const limit of [1, 20, 50]) {
      const res = await search({ surface: 'feed', sort: 'best', limit });
      expect(res.status).toBe(201);
      expect(res.body.items.length).toBeLessThanOrEqual(Math.min(limit, 8));
    }
  });

  it('G7B4-DIV-09 deleted bookmark resumes without replay/500', async () => {
    await seedFeedVenue({ name: 'DelH1', venueType: 'hotel' });
    await seedFeedVenue({ name: 'DelC1', venueType: 'chalet' });
    await seedFeedVenue({ name: 'DelH2', venueType: 'hotel' });
    const p1 = await search({ surface: 'feed', sort: 'newest', limit: 1 });
    expect(p1.status).toBe(201);
    expect(p1.body.nextCursor).toBeTruthy();
    const emitted = p1.body.items[0]?.venueId as string;
    // Soft-delete from discovery (published→draft) — keyset must resume past bookmark.
    await pool.query(`UPDATE venues SET status='draft' WHERE id=$1`, [emitted]);
    const p2 = await search({
      surface: 'feed',
      sort: 'newest',
      limit: 1,
      cursor: p1.body.nextCursor,
    });
    expect(p2.status).toBe(201);
    expect(p2.body.items.map((i: { venueId: string }) => i.venueId)).not.toContain(emitted);
  });

  it('G7B4-DIV-10 draft/capability-off/unplayable excluded from total+sequence', async () => {
    await seedFeedVenue({ name: 'Ok', venueType: 'hotel' });
    await seedFeedVenue({ name: 'Draft', venueType: 'hotel', draft: true });
    await seedFeedVenue({ name: 'NoVid', venueType: 'chalet', playable: false });
    const res = await search({ surface: 'feed', sort: 'best', limit: 20 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(1);
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].name).toBe('Ok');
  });

  it('G7B4-CUR-01/02/07 cursor round-trip; perTypeAfter advances emitted only; rankingAsOf fixed', async () => {
    for (let i = 0; i < 6; i++) {
      await seedFeedVenue({
        name: `Cur${i}`,
        venueType: i % 2 === 0 ? 'hotel' : 'chalet',
      });
    }
    const p1 = await search({ surface: 'feed', sort: 'best', limit: 2 });
    expect(p1.status).toBe(201);
    const c1 = decodeCursor(p1.body.nextCursor);
    expect(c1.diversityVersion).toBe(1);
    expect(c1.diversityK).toBe(2);
    const emittedTypes = new Set(
      p1.body.items.map((i: { category: string }) => i.category),
    );
    for (const t of Object.keys(c1.diversity!.perTypeAfter)) {
      expect(emittedTypes.has(t)).toBe(true);
    }
    const asOf = c1.rankingAsOf;
    const p2 = await search({
      surface: 'feed',
      sort: 'best',
      limit: 2,
      cursor: p1.body.nextCursor,
    });
    expect(p2.status).toBe(201);
    expect(p2.body.applied.rankingAsOf).toBe(asOf);
    if (p2.body.nextCursor) {
      expect(decodeCursor(p2.body.nextCursor).rankingAsOf).toBe(asOf);
    }
  });

  it('G7B4-CUR-03/05 mismatch and malformed → 400', async () => {
    await seedFeedVenue({ name: 'M', venueType: 'hotel' });
    await seedFeedVenue({ name: 'N', venueType: 'chalet' });
    const ok = await search({ surface: 'feed', sort: 'best', limit: 1 });
    const cur = ok.body.nextCursor as string;

    expect((await search({ surface: 'map', sort: 'best', cursor: cur })).status).toBe(400);
    expect((await search({ surface: 'feed', sort: 'newest', cursor: cur })).status).toBe(400);
    expect((await search({ surface: 'feed', category: 'hotel', sort: 'best', cursor: cur })).status).toBe(
      400,
    );
    expect((await search({ surface: 'feed', sort: 'best', cursor: '%%%' })).status).toBe(400);

    const forbiddenOnMixed = encodeTestCursorV2(
      { surface: 'feed', sort: 'best' },
      { sv: '0.500000', sv2: '4.00', sv3: '1', id: newId() },
    );
    expect(
      (await search({ surface: 'feed', sort: 'best', cursor: forbiddenOnMixed })).status,
    ).toBe(400);
  });

  it('G7B4-CUR-04 structural/mode errors fail before SQL (query spy)', async () => {
    const calls: string[] = [];
    const pg = {
      query: async (sql: string) => {
        calls.push(sql);
        return { rows: [], rowCount: 0 };
      },
    } as unknown as PgService;
    const engine = new FilterEngineService(pg, new VenueTypeCapabilityPolicy(pg));
    calls.length = 0;
    await expect(
      engine.search({ surface: 'feed', sort: 'best', cursor: 'not-b64' } as DiscoverySearchDto),
    ).rejects.toBeInstanceOf(AppError);
    expect(calls).toEqual([]);
  });

  it('G7B4-CUR-06 worst-case cursor ≤4096 accepted by POST and GET', async () => {
    const worst = buildWorstCaseBestDiversityCursor();
    expect(worst.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
    // Shape-ok but hash will mismatch → 400 after parse; still proves DTO accepts length.
    const post = await search({ surface: 'feed', sort: 'best', cursor: worst });
    expect(post.status).toBe(400);
    expect(post.body.message ?? JSON.stringify(post.body)).not.toMatch(/must be shorter/i);

    const get = await feed({ cursor: worst });
    expect(get.status).toBe(400);
    expect(JSON.stringify(get.body)).not.toMatch(/must be shorter/i);
  });

  it('G7B4-FEED-01 GET feed matches POST feed newest page-by-page', async () => {
    for (let i = 0; i < 5; i++) {
      await seedFeedVenue({
        name: `Parity${i}`,
        venueType: i % 2 === 0 ? 'hotel' : 'chalet',
        createdAt: `2030-02-${String(10 - i).padStart(2, '0')}T08:00:00.000Z`,
      });
    }
    let postCursor: string | undefined;
    let getCursor: string | undefined;
    for (let page = 0; page < 5; page++) {
      const post = await search({
        surface: 'feed',
        sort: 'newest',
        limit: 20,
        ...(postCursor ? { cursor: postCursor } : {}),
      });
      // GET feed fixed limit=20
      const get = await feed(getCursor ? { cursor: getCursor } : {});
      expect(post.status).toBe(201);
      expect(get.status).toBe(200);
      expect(get.body.total).toBe(post.body.total);
      expect(get.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
        post.body.items.map((i: { venueId: string }) => i.venueId),
      );
      expect(get.body.nextCursor).toBe(post.body.nextCursor);
      if (!post.body.nextCursor) break;
      postCursor = post.body.nextCursor;
      getCursor = get.body.nextCursor;
    }
  });

  it('G7B4-FEED-02 category feed pure newest — diversity applied=false', async () => {
    await seedFeedVenue({ name: 'CatH1', venueType: 'hotel' });
    await seedFeedVenue({ name: 'CatH2', venueType: 'hotel' });
    const res = await search({
      surface: 'feed',
      category: 'hotel',
      sort: 'newest',
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(res.body.applied.diversity.applied).toBe(false);
    if (res.body.nextCursor) {
      const c = decodeCursor(res.body.nextCursor, 'forbidden');
      expect(c.diversity).toBeUndefined();
    }
  });

  it('G7B4-FEED-03 / SURF-02 approved playable enforced before diversity', async () => {
    await seedFeedVenue({ name: 'Play', venueType: 'hotel' });
    await seedFeedVenue({ name: 'Silent', venueType: 'chalet', playable: false });
    const res = await search({ surface: 'feed', sort: 'best', limit: 10 });
    expect(res.body.total).toBe(1);
    expect(res.body.items[0].name).toBe('Play');
  });

  it('G7B4-SURF-01 map/circle/search not reordered with diversity state', async () => {
    await seedFeedVenue({ name: 'S1', venueType: 'hotel' });
    await seedFeedVenue({ name: 'S2', venueType: 'chalet' });
    for (const surface of ['map', 'circle', 'search']) {
      const res = await search({ surface, sort: 'best', limit: 10 });
      expect(res.status).toBe(201);
      expect(res.body.applied.diversity.applied).toBe(false);
      if (res.body.nextCursor) {
        expect(decodeCursor(res.body.nextCursor, 'forbidden').diversity).toBeUndefined();
      }
    }
  });

  it('G7B4-SURF-03 feed cursor rejected on other surface', async () => {
    await seedFeedVenue({ name: 'X1', venueType: 'hotel' });
    await seedFeedVenue({ name: 'X2', venueType: 'chalet' });
    const feedPage = await search({ surface: 'feed', sort: 'best', limit: 1 });
    const bad = await search({
      surface: 'search',
      sort: 'best',
      cursor: feedPage.body.nextCursor,
    });
    expect(bad.status).toBe(400);
  });

  it('G7B4-PERF-01/02 batched candidateQuery ≤ 2×types; rows ≤ 2×(types+limit)', async () => {
    for (let i = 0; i < 6; i++) {
      await seedFeedVenue({
        name: `Q${i}`,
        venueType: i % 3 === 0 ? 'hotel' : i % 3 === 1 ? 'chalet' : 'villa',
      });
    }
    const engine = app.get(FilterEngineService);
    const res = await search({ surface: 'feed', sort: 'best', limit: 5 });
    expect(res.status).toBe(201);
    const m = (engine as { lastDiversityMetrics?: {
      rowsFetched: number;
      typeCount: number;
      limit: number;
      rowBound: number;
      candidateQueryCount: number;
      candidateQueryBound: number;
    } }).lastDiversityMetrics;
    expect(m).toBeDefined();
    expect(m!.rowsFetched).toBeLessThanOrEqual(m!.rowBound);
    expect(m!.candidateQueryCount).toBeLessThanOrEqual(m!.candidateQueryBound);
    expect(m!.rowsFetched).toBeLessThan(m!.typeCount * m!.limit);
  });
});
