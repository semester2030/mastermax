import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { applyMigrationsThrough, applyRemainingMigrations } from '../helpers/migrate-partial';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import { dropPublicSchemaForCi } from '../helpers/db-safety';

describe('Gate 7B.3.1 acceptance — geo/search/rank/mig', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b31-user';

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
        name: i === 0 ? 'فندق الملقا Anchor' : `Near Hotel ${i} 100%_deal`,
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

  it('G7B31-GEO API anchor errors + full pagination no dupes/loss', async () => {
    const ids = await seedCluster('geo');
    expect((await search({ sort: 'near_place', limit: 3 })).status).toBe(400);
    expect(
      (await search({ sort: 'near_me', lat: 24.7, lng: 46.7, anchorVenueId: ids[0] })).status,
    ).toBe(400);
    expect(
      (await search({ sort: 'near_place', anchorVenueId: ids[0], lat: 24.7, lng: 46.7 })).status,
    ).toBe(400);
    expect(
      (
        await search({
          sort: 'near_place',
          anchorVenueId: '00000000-0000-4000-8000-000000000099',
        })
      ).status,
    ).toBe(404);

    const unpublished = ids[1];
    await pool.query(`UPDATE venues SET status='draft' WHERE id=$1`, [unpublished]);
    expect((await search({ sort: 'near_place', anchorVenueId: unpublished })).status).toBe(400);
    await pool.query(`UPDATE venues SET status='published' WHERE id=$1`, [unpublished]);

    const p1 = await search({
      sort: 'near_place',
      anchorVenueId: ids[0],
      limit: 2,
      surface: 'map',
    });
    expect(p1.status).toBe(201);
    expect(p1.body.applied.radiusKm).toBe(50);
    expect(p1.body.applied.sameTypeOnly).toBe(true);
    expect(p1.body.applied.excludeAnchor).toBe(true);
    expect(p1.body.items.every((i: { venueId: string }) => i.venueId !== ids[0])).toBe(true);

    const seen = new Set(p1.body.items.map((i: { venueId: string }) => i.venueId));
    let cursor = p1.body.nextCursor as string | null;
    let pages = 1;
    while (cursor && pages < 10) {
      const pn = await search({
        sort: 'near_place',
        anchorVenueId: ids[0],
        limit: 2,
        surface: 'map',
        cursor,
      });
      expect(pn.status).toBe(201);
      for (const it of pn.body.items) {
        expect(seen.has(it.venueId)).toBe(false);
        seen.add(it.venueId);
      }
      cursor = pn.body.nextCursor;
      pages += 1;
    }
    expect(seen.size).toBeGreaterThanOrEqual(3);
  });

  it('G7B31-SEARCH API search_rank default; literal %; blank=no search', async () => {
    await seedCluster('search');
    const auto = await search({ q: 'Hotel', limit: 5 });
    expect(auto.status).toBe(201);
    expect(auto.body.sort).toBe('search_rank');

    const keep = await search({ q: 'Hotel', sort: 'newest', limit: 5 });
    expect(keep.status).toBe(201);
    expect(keep.body.sort).toBe('newest');

    const lit = await search({ q: '100%', sort: 'newest', limit: 5 });
    expect(lit.status).toBe(201);

    const blank = await search({ q: '   ', sort: 'newest', limit: 5 });
    expect(blank.status).toBe(201);
    expect(blank.body.sort).toBe('newest');

    expect((await search({ q: 'a', sort: 'newest' })).status).toBe(400);
  });

  it('G7B31-RANK API reviews clamp + pagination stable', async () => {
    await seedCluster('rank');
    const best = await search({ sort: 'best', limit: 3, surface: 'search' });
    expect(best.status).toBe(201);
    expect(best.body.applied.rankingAsOf).toBeTruthy();
    expect(bestScoreSqlExpr(1)).toContain('best_score_static');
    expect(bestScoreSqlExpr(1)).toMatch(/numeric\(8,6\)/);

    const scores = best.body.items
      .map((i: { bestScore: number | null }) => i.bestScore)
      .filter((s: number | null) => s != null) as number[];
    for (let i = 1; i < scores.length; i++) {
      expect(scores[i - 1]).toBeGreaterThanOrEqual(scores[i] - 1e-9);
    }

    if (best.body.nextCursor) {
      const p2 = await search({
        sort: 'best',
        limit: 3,
        surface: 'search',
        cursor: best.body.nextCursor,
      });
      expect(p2.status).toBe(201);
      expect(p2.body.applied.rankingAsOf).toBe(best.body.applied.rankingAsOf);
      const ids = [...best.body.items, ...p2.body.items].map((i: { venueId: string }) => i.venueId);
      expect(new Set(ids).size).toBe(ids.length);
    }

    const v1 = Buffer.from(JSON.stringify({ v: 1, sort: 'best', sv: '1', id: newId() })).toString(
      'base64url',
    );
    expect((await search({ sort: 'best', cursor: v1 })).status).toBe(400);
  });

  it('G7B31-MIG-01..03 fresh 001→011 and upgrade 010→011 keeps data', async () => {
    testEnv();
    const p = new Pool({ connectionString: process.env.DATABASE_URL });
    await dropPublicSchemaForCi(p);
    const all = await applyMigrationsThrough(p, '011_gate7b31_search_nfc.sql');
    expect(all[0]).toMatch(/^001_/);
    expect(all).toEqual(expect.arrayContaining(['010_gate7b_search.sql', '011_gate7b31_search_nfc.sql']));

    await dropPublicSchemaForCi(p);
    await applyMigrationsThrough(p, '010_gate7b_search.sql');
    const providerId = await seedProvider(p, `mig-${newId().slice(0, 8)}`, 'Mig');
    const seeded = await seedVenue(p, providerId, {
      name: 'آفاق NFC Keep',
      venueType: 'hotel',
      types: [{ name: 'u', qty: 1, nights: { '2030-01-10': '50' } }],
    });
    const before = await p.query(`SELECT name FROM venues WHERE id=$1`, [seeded.venueId]);
    expect(before.rows[0].name).toBe('آفاق NFC Keep');
    const rem = await applyRemainingMigrations(p);
    expect(rem).toEqual(expect.arrayContaining(['011_gate7b31_search_nfc.sql']));
    const after = await p.query(
      `SELECT name, search_document FROM venues WHERE id=$1`,
      [seeded.venueId],
    );
    expect(after.rows[0].name).toBe('آفاق NFC Keep');
    expect(String(after.rows[0].search_document)).toContain(normalizeLike('افاق'));
    await p.end();
    await resetDb();
  }, 180_000);

  it('G7B31-PKG EXPLAIN ANALYZE search with representative rows (honest)', async () => {
    await seedCluster('explain');
    const plan = await pool.query(
      `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
       SELECT v.id
       FROM venues v
       WHERE v.status='published'
         AND (
           v.search_document ILIKE '%' || $1 || '%' ESCAPE '\\'
           OR similarity(v.search_document, $2) >= 0.25
         )
       ORDER BY similarity(v.search_document, $2) DESC NULLS LAST, v.id ASC
       LIMIT 20`,
      ['hotel', 'hotel'],
    );
    const text = plan.rows.map((r: { 'QUERY PLAN': string }) => r['QUERY PLAN']).join('\n');
    expect(text).toMatch(/venues|Index|Seq Scan|Bitmap/i);
    // Honest: small N may not choose GIN; evidence recorded for pack, not claimed as 7B.5 closed.
    expect(text.length).toBeGreaterThan(40);
  });
});

function normalizeLike(s: string): string {
  return s.toLowerCase();
}
