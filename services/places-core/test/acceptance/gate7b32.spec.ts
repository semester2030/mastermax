import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import { normalizeSearchText } from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.3.2 acceptance — geo/search/rank evidence', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b32-user';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

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

  async function seedCluster(tag: string) {
    const ids: string[] = [];
    for (let i = 0; i < 8; i++) {
      const providerId = await seedProvider(pool, `${uid}-${tag}-${i}-${newId().slice(0, 8)}`, `P${i}`);
      const seeded = await seedVenue(pool, providerId, {
        name: i === 0 ? 'فندق الملقا Anchor' : `Near Hotel ${i} 100%_deal \\slash`,
        venueType: i === 7 ? 'chalet' : 'hotel',
        types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
      });
      await pool.query(
        `UPDATE venues SET lat=$2, lng=$3, city='Riyadh', district='Malqa',
          weighted_rating=$4, reviews_count=$5, rating_average=$4,
          created_at=now() - ($6 || ' days')::interval WHERE id=$1`,
        [
          seeded.venueId,
          24.71 + i * 0.008,
          46.67 + i * 0.008,
          4.8 - i * 0.05,
          i === 2 ? 0 : i === 3 ? 500 : i === 4 ? 800 : 50 + i,
          String(i * 10),
        ],
      );
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,'hotel')`,
        [newId(), seeded.venueId, providerId, `https://example.test/${tag}-${i}.mp4`],
      );
      ids.push(seeded.venueId);
    }
    return ids;
  }

  it('G7B32-GEO capability disabled / null coords / unpublished / full traversal', async () => {
    const ids = await seedCluster('geo');

    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery=false WHERE venue_type='hotel'`,
    );
    expect((await search({ sort: 'near_place', anchorVenueId: ids[0] })).status).toBe(400);
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery=true WHERE venue_type='hotel'`,
    );

    await pool.query(`UPDATE venues SET lat=NULL, lng=NULL WHERE id=$1`, [ids[1]]);
    expect((await search({ sort: 'near_place', anchorVenueId: ids[1] })).status).toBe(400);
    await pool.query(`UPDATE venues SET lat=24.72, lng=46.68 WHERE id=$1`, [ids[1]]);

    await pool.query(`UPDATE venues SET lat=999, lng=46.68 WHERE id=$1`, [ids[1]]);
    expect((await search({ sort: 'near_place', anchorVenueId: ids[1] })).status).toBe(400);
    await pool.query(`UPDATE venues SET lat=24.72, lng=46.68 WHERE id=$1`, [ids[1]]);

    expect(
      (
        await search({
          sort: 'near_place',
          anchorVenueId: '00000000-0000-4000-8000-000000000099',
        })
      ).status,
    ).toBe(404);

    await pool.query(`UPDATE venues SET status='draft' WHERE id=$1`, [ids[2]]);
    expect((await search({ sort: 'near_place', anchorVenueId: ids[2] })).status).toBe(400);
    await pool.query(`UPDATE venues SET status='published' WHERE id=$1`, [ids[2]]);

    // Full traversal — hotels only (exclude anchor + sameTypeOnly)
    const expected = new Set(ids.filter((_, i) => i !== 0 && i !== 7));
    const seen = new Set<string>();
    let cursor: string | null = null;
    for (let page = 0; page < 20; page++) {
      const body: Record<string, unknown> = {
        sort: 'near_place',
        anchorVenueId: ids[0],
        limit: 2,
        surface: 'map',
      };
      if (cursor) body.cursor = cursor;
      const res = await search(body);
      expect(res.status).toBe(201);
      for (const item of res.body.items as { venueId: string }[]) {
        expect(seen.has(item.venueId)).toBe(false);
        seen.add(item.venueId);
      }
      cursor = res.body.nextCursor;
      if (!cursor) break;
    }
    expect(seen).toEqual(expected);
    expect(cursor).toBeNull();
  });

  it('G7B32-SEARCH NFC parity + literals + phrase pagination', async () => {
    const ids = await seedCluster('search');
    const nfd = 'ف\u064Eندق'; // fatha on first letter
    const nfc = normalizeSearchText(nfd);
    const db = await pool.query<{ n: string }>(
      `SELECT places_normalize_search($1) AS n`,
      [nfd],
    );
    expect(db.rows[0].n).toBe(nfc);

    const a = await search({ q: 'Hotel', limit: 3 });
    const b = await search({ q: 'hotel', limit: 3 });
    expect(a.status).toBe(201);
    expect(a.body.sort).toBe('search_rank');
    expect(a.body.applied.queryHash).toBe(b.body.applied.queryHash);

    const literal = await search({ q: '100%_deal', limit: 5 });
    expect(literal.status).toBe(201);
    expect(literal.body.items.length).toBeGreaterThan(0);

    const slash = await search({ q: '\\slash', limit: 5 });
    expect(slash.status).toBe(201);

    const seen = new Set<string>();
    let cursor: string | null = null;
    for (let page = 0; page < 20; page++) {
      const body: Record<string, unknown> = { q: 'hotel', limit: 2 };
      if (cursor) body.cursor = cursor;
      const res = await search(body);
      expect(res.status).toBe(201);
      for (const item of res.body.items as { venueId: string }[]) {
        expect(seen.has(item.venueId)).toBe(false);
        seen.add(item.venueId);
      }
      cursor = res.body.nextCursor;
      if (!cursor) break;
    }
    expect(seen.size).toBeGreaterThan(0);
    expect(cursor).toBeNull();
    // seeded search cluster hotels must appear among results
    expect(ids.slice(1, 7).some((id) => seen.has(id))).toBe(true);
  });

  it('G7B32-RANK PG values 0/500/>500 + full traversal', async () => {
    await seedCluster('rank');
    const reviewsOnly = await pool.query<{ r: number; s: string }>(
      `SELECT r,
         (LN(1.0 + LEAST(r, 500)::numeric) / LN(501.0))::numeric(8,6)::text AS s
       FROM (VALUES (0), (500), (800)) AS t(r)`,
    );
    const byR = Object.fromEntries(reviewsOnly.rows.map((row) => [Number(row.r), row.s]));
    expect(byR[0]).toBe('0.000000');
    expect(Number(byR[500])).toBeCloseTo(1, 5);
    expect(byR[500]).toBe(byR[800]);
    // Gate 7B.5.1: reviews term lives in venues.best_score_static; query adds freshness.
    expect(bestScoreSqlExpr(1)).toContain('best_score_static');
    expect(bestScoreSqlExpr(1)).toContain('numeric(8,6)');

    const seen = new Set<string>();
    let cursor: string | null = null;
    let rankingAsOf: string | null = null;
    for (let page = 0; page < 30; page++) {
      const body: Record<string, unknown> = { sort: 'best', limit: 3, surface: 'search' };
      if (cursor) body.cursor = cursor;
      const res = await search(body);
      expect(res.status).toBe(201);
      if (!rankingAsOf) rankingAsOf = res.body.applied.rankingAsOf;
      else expect(res.body.applied.rankingAsOf).toBe(rankingAsOf);
      for (const item of res.body.items as { venueId: string }[]) {
        expect(seen.has(item.venueId)).toBe(false);
        seen.add(item.venueId);
      }
      cursor = res.body.nextCursor;
      if (!cursor) break;
    }
    expect(seen.size).toBeGreaterThan(0);
    expect(cursor).toBeNull();
  });

  it('G7B32-HTTP rankingAsOf body field forbidden (whitelist)', async () => {
    const res = await search({
      sort: 'best',
      rankingAsOf: new Date().toISOString(),
      limit: 1,
    });
    expect(res.status).toBe(400);
  });
});
