/**
 * Gate 7B.4.1 — Bounded diversity prefetch + evidence closure tests.
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
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';
import { PgService } from '../../src/shared/database/pg.service';

describe('Gate 7B.4.1 — bounded prefetch + evidence', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b41-user';

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
    playable?: boolean;
    draft?: boolean;
    lat?: number;
    lng?: number;
  }): Promise<{ venueId: string; providerId: string }> {
    const providerId = await seedProvider(pool, `${uid}-${newId()}`, opts.name);
    const venue = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.venueType,
      types: [{ name: 'std', qty: 3, nights: { '2032-01-01': '150' } }],
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

  async function seedSkewedCatalog(opts: {
    hotels: number;
    chalets: number;
    villas: number;
  }): Promise<string[]> {
    const ids: string[] = [];
    let n = 0;
    for (let i = 0; i < opts.hotels; i++) {
      const v = await seedFeedVenue({
        name: `H${i}`,
        venueType: 'hotel',
        createdAt: `2030-03-${String(28 - (n++ % 27)).padStart(2, '0')}T12:00:00.000Z`,
      });
      ids.push(v.venueId);
    }
    for (let i = 0; i < opts.chalets; i++) {
      const v = await seedFeedVenue({
        name: `C${i}`,
        venueType: 'chalet',
        createdAt: `2030-02-${String(28 - (n++ % 27)).padStart(2, '0')}T12:00:00.000Z`,
      });
      ids.push(v.venueId);
    }
    for (let i = 0; i < opts.villas; i++) {
      const v = await seedFeedVenue({
        name: `V${i}`,
        venueType: 'villa',
        createdAt: `2030-01-${String(28 - (n++ % 27)).padStart(2, '0')}T12:00:00.000Z`,
      });
      ids.push(v.venueId);
    }
    return ids;
  }

  it('G7B41-BOUND-01 rowsFetched ≤ rowBound; beats types×limit (superseded bound formula by 7B.4.2)', async () => {
    await seedSkewedCatalog({ hotels: 40, chalets: 3, villas: 2 });
    const engine = app.get(FilterEngineService);
    const observed: Array<Record<string, number>> = [];

    for (const limit of [1, 20, 50]) {
      await engine.search({
        surface: 'feed',
        sort: 'newest',
        limit,
      } as never);
      const m = (engine as { lastDiversityMetrics?: {
        rowsFetched: number;
        typeCount: number;
        limit: number;
        rowBound: number;
        queryCount: number;
      } }).lastDiversityMetrics;
      expect(m).toBeDefined();
      expect(m!.rowsFetched).toBeLessThanOrEqual(m!.rowBound);
      if (limit >= 20 && m!.typeCount >= 3) {
        expect(m!.rowsFetched).toBeLessThan(m!.typeCount * limit);
      }
      observed.push({
        limit,
        typeCount: m!.typeCount,
        rowsFetched: m!.rowsFetched,
        rowBound: m!.rowBound,
        queryCount: m!.queryCount,
      });
    }
    console.log('G7B41_BOUND_OBSERVED', JSON.stringify(observed));
  });

  it('G7B41-BOUND-02 exact traversal seen=expected=total; no dup/drop; terminal null', async () => {
    const ids = await seedSkewedCatalog({ hotels: 8, chalets: 4, villas: 3 });
    const seen: string[] = [];
    let cursor: string | undefined;
    let total = -1;
    for (;;) {
      const res = await search({
        surface: 'feed',
        sort: 'newest',
        limit: 5,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      if (total < 0) total = res.body.total;
      expect(res.body.total).toBe(total);
      for (const item of res.body.items) seen.push(item.venueId);
      if (!res.body.nextCursor) break;
      cursor = res.body.nextCursor;
    }
    expect(total).toBe(ids.length);
    expect(seen.length).toBe(ids.length);
    expect(new Set(seen).size).toBe(ids.length);
    expect([...seen].sort()).toEqual([...ids].sort());
  });

  it('G7B41-FEED multi-page GET/POST parity with stable rankingAsOf', async () => {
    for (let i = 0; i < 6; i++) {
      await seedFeedVenue({
        name: `P${i}`,
        venueType: i % 2 === 0 ? 'hotel' : 'chalet',
        createdAt: `2031-01-${String(20 - i).padStart(2, '0')}T08:00:00.000Z`,
      });
    }
    let postCursor: string | undefined;
    let getCursor: string | undefined;
    let asOf: string | undefined;
    for (let page = 0; page < 4; page++) {
      const post = await search({
        surface: 'feed',
        sort: 'newest',
        limit: 20,
        ...(postCursor ? { cursor: postCursor } : {}),
      });
      const get = await feed(getCursor ? { cursor: getCursor } : {});
      expect(post.status).toBe(201);
      expect(get.status).toBe(200);
      expect(get.body.total).toBe(post.body.total);
      expect(get.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
        post.body.items.map((i: { venueId: string }) => i.venueId),
      );
      expect(get.body.nextCursor).toBe(post.body.nextCursor);
      if (post.body.nextCursor) {
        const c = parseCursorV2Structural(post.body.nextCursor, 'required');
        if (!asOf) asOf = c.rankingAsOf;
        expect(c.rankingAsOf).toBe(asOf);
      }
      if (!post.body.nextCursor) break;
      postCursor = post.body.nextCursor;
      getCursor = get.body.nextCursor;
    }
  });

  it('G7B41-FEED category GET/POST no diversity', async () => {
    await seedFeedVenue({ name: 'Cat1', venueType: 'hotel' });
    await seedFeedVenue({ name: 'Cat2', venueType: 'hotel' });
    const post = await search({
      surface: 'feed',
      category: 'hotel',
      sort: 'newest',
      limit: 20,
    });
    expect(post.status).toBe(201);
    expect(post.body.applied.diversity.applied).toBe(false);
    const get = await feed({ category: 'hotel' });
    expect(get.status).toBe(200);
    expect(get.body.items.map((i: { venueId: string }) => i.venueId)).toEqual(
      post.body.items.map((i: { venueId: string }) => i.venueId),
    );
    if (post.body.nextCursor) {
      expect(parseCursorV2Structural(post.body.nextCursor, 'forbidden').diversity).toBeUndefined();
    }
  });

  it('G7B41-FILTER capability-off / failed filters / playable media', async () => {
    await seedFeedVenue({ name: 'Ok', venueType: 'hotel' });
    await seedFeedVenue({ name: 'NoVid', venueType: 'chalet', playable: false });
    await seedFeedVenue({ name: 'Draft', venueType: 'villa', draft: true });
    const res = await search({ surface: 'feed', sort: 'best', limit: 20 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(1);
    expect(res.body.items[0].name).toBe('Ok');

    const badAmen = await search({
      surface: 'feed',
      sort: 'best',
      amenities: ['wifi'],
      limit: 20,
    });
    expect(badAmen.status).toBe(201);
    expect(badAmen.body.total).toBe(0);
  });

  it('G7B41-SAME dates/guests/quantity/radius + approved media', async () => {
    const anchor = await seedFeedVenue({
      name: 'Anch',
      venueType: 'hotel',
      lat: 24.7,
      lng: 46.7,
      playable: false,
    });
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
       VALUES ($1,$2,$3,'image','https://example.test/i.jpg','https://example.test/c.jpg','approved',0,'hotel')`,
      [newId(), anchor.venueId, (await pool.query(`SELECT provider_id FROM venues WHERE id=$1`, [anchor.venueId])).rows[0].provider_id],
    );
    const peer = await seedFeedVenue({
      name: 'Peer',
      venueType: 'hotel',
      lat: 24.71,
      lng: 46.71,
      playable: false,
    });
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
       VALUES ($1,$2,$3,'image','https://example.test/i2.jpg','https://example.test/c.jpg','approved',0,'hotel')`,
      [newId(), peer.venueId, (await pool.query(`SELECT provider_id FROM venues WHERE id=$1`, [peer.venueId])).rows[0].provider_id],
    );
    await pool.query(
      `INSERT INTO venue_amenity_links (id, venue_id, amenity_code, state)
       VALUES ($1,$2,'wifi','AVAILABLE') ON CONFLICT DO NOTHING`,
      [newId(), peer.venueId],
    );

    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      radiusKm: 50,
      guests: 2,
      quantity: 1,
      checkIn: '2032-01-01',
      checkOut: '2032-01-03',
      amenities: ['wifi'],
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(res.body.applied.profile).toBe('same_type_near_place');
    expect(res.body.applied.diversity.applied).toBe(false);
    expect(res.body.items.every((i: { category: string }) => i.category === 'hotel')).toBe(true);
    expect(res.body.items.map((i: { venueId: string }) => i.venueId)).toContain(peer.venueId);
  });

  it('G7B41-CUR server-issued cursor ≤4096 accepted POST+GET; cross-surface 400', async () => {
    for (let i = 0; i < 4; i++) {
      await seedFeedVenue({
        name: `Cur${i}`,
        venueType: i % 2 === 0 ? 'hotel' : 'chalet',
      });
    }
    const p1 = await search({ surface: 'feed', sort: 'best', limit: 1 });
    expect(p1.status).toBe(201);
    expect(p1.body.nextCursor).toBeTruthy();
    expect(p1.body.nextCursor.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);

    const p2 = await search({
      surface: 'feed',
      sort: 'best',
      limit: 1,
      cursor: p1.body.nextCursor,
    });
    expect(p2.status).toBe(201);

    const g2 = await feed({ cursor: p1.body.nextCursor });
    // GET feed forces newest — sort mismatch → 400
    expect(g2.status).toBe(400);

    const newest = await search({ surface: 'feed', sort: 'newest', limit: 20 });
    expect(newest.status).toBe(201);
    if (newest.body.nextCursor) {
      expect(newest.body.nextCursor.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
      expect((await feed({ cursor: newest.body.nextCursor })).status).toBe(200);
    }

    expect(
      (await search({ surface: 'map', sort: 'best', cursor: p1.body.nextCursor })).status,
    ).toBe(400);

    const worst = buildWorstCaseBestDiversityCursor();
    expect(worst.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
    expect((await search({ surface: 'feed', sort: 'best', cursor: worst })).status).toBe(400);
    expect((await feed({ cursor: worst })).status).toBe(400);
  });

  it('G7B41-SQL no OFFSET in diversity page path', async () => {
    await seedSkewedCatalog({ hotels: 5, chalets: 2, villas: 1 });
    const pg = app.get(PgService);
    const orig = pg.query.bind(pg);
    const spy = jest.spyOn(pg, 'query').mockImplementation(async (sql: string, params?: unknown[]) => {
      expect(sql).not.toMatch(/\bOFFSET\b/i);
      return orig(sql, params ?? []);
    });
    try {
      const res = await search({ surface: 'feed', sort: 'best', limit: 10 });
      expect(res.status).toBe(201);
    } finally {
      spy.mockRestore();
    }
  });
});
