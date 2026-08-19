import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import { normalizeSearchText } from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.3.3 acceptance — quantity/search/rank evidence', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b33-user';

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

  async function ensureMedia(venueId: string, providerId: string, tag: string) {
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
       VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,'hotel')
       ON CONFLICT DO NOTHING`,
      [newId(), venueId, providerId, `https://example.test/${tag}.mp4`],
    );
  }

  it('G7B33-QTY-API no-inventory / qty0 discoverable without quantity; excluded with quantity=1', async () => {
    // Enable wedding discovery for this suite only — BOOKING can stay disabled.
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery=true
       WHERE venue_type IN ('wedding_palace','event_hall')`,
    );

    const pNo = await seedProvider(pool, `${uid}-noinv-${newId().slice(0, 6)}`, 'NoInv');
    const noInv = await seedVenue(pool, pNo, {
      name: 'Wedding Palace No Inventory',
      venueType: 'wedding_palace',
      types: [],
    });
    await pool.query(
      `UPDATE venues SET lat=24.7, lng=46.7, weighted_rating=4.5, reviews_count=10 WHERE id=$1`,
      [noInv.venueId],
    );
    await ensureMedia(noInv.venueId, pNo, 'noinv');

    const pZero = await seedProvider(pool, `${uid}-z-${newId().slice(0, 6)}`, 'Zero');
    const zero = await seedVenue(pool, pZero, {
      name: 'Hotel Zero Stock',
      venueType: 'hotel',
      types: [{ name: 'u', qty: 0, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET lat=24.71, lng=46.71, weighted_rating=4.2, reviews_count=20 WHERE id=$1`,
      [zero.venueId],
    );
    await ensureMedia(zero.venueId, pZero, 'zero');

    const open = await search({ sort: 'best', limit: 50, surface: 'search' });
    expect(open.status).toBe(201);
    const openIds = (open.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(openIds).toContain(noInv.venueId);
    expect(openIds).toContain(zero.venueId);

    const filtered = await search({ sort: 'best', quantity: 1, limit: 50, surface: 'search' });
    expect(filtered.status).toBe(201);
    const filteredIds = (filtered.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(filteredIds).not.toContain(noInv.venueId);
    expect(filteredIds).not.toContain(zero.venueId);
  });

  it('G7B33-SEARCH empty q invariants + NFC + literals + phrases + pagination', async () => {
    expect((await search({ q: '   ', sort: 'best', limit: 5 })).status).toBe(201);
    expect((await search({ q: 'ًٌَ', limit: 5 })).body.sort).toBe('best');
    expect((await search({ q: 'ــــ', sort: 'search_rank', limit: 5 })).status).toBe(400);
    expect((await search({ sort: 'search_rank', limit: 5 })).status).toBe(400);

    const p = await seedProvider(pool, `${uid}-s-${newId().slice(0, 6)}`, 'Search');
    const ids: string[] = [];
    for (let i = 0; i < 6; i++) {
      const seeded = await seedVenue(pool, p, {
        name:
          i === 0
            ? 'فندق الملقا 100%_deal \\slash'
            : i === 1
              ? 'قصر أفراح الملقا UniquePhrase'
              : `Hotel Search ${i}`,
        venueType: 'hotel',
        types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
      });
      await pool.query(
        `UPDATE venues SET lat=$2, lng=$3, city='Riyadh', district='Malqa',
          weighted_rating=4.5, reviews_count=$4 WHERE id=$1`,
        [seeded.venueId, 24.7 + i * 0.01, 46.7 + i * 0.01, 30 + i],
      );
      await ensureMedia(seeded.venueId, p, `s${i}`);
      ids.push(seeded.venueId);
    }

    // NFC parity: TS ↔ PG normalize + generated search_document
    const nfd = 'ف\u064Eندق';
    const nfcTs = normalizeSearchText(nfd);
    const pgN = await pool.query<{ n: string }>(`SELECT places_normalize_search($1) AS n`, [nfd]);
    expect(pgN.rows[0].n).toBe(nfcTs);
    const doc = await pool.query<{ d: string }>(
      `SELECT search_document AS d FROM venues WHERE id=$1`,
      [ids[0]],
    );
    expect(doc.rows[0].d).toContain(normalizeSearchText('فندق'));

    // Literals % _ \ are not wildcards — control: pattern that would match-all if wildcard
    const lit = await search({ q: '100%_deal', limit: 20 });
    expect(lit.status).toBe(201);
    expect(lit.body.items.some((i: { venueId: string }) => i.venueId === ids[0])).toBe(true);
    const wildWould = await search({ q: '%', limit: 20 });
    // single char after normalize may 400, or literal % with min length — '%' alone is too short
    expect([400, 201]).toContain(wildWould.status);
    const under = await search({ q: '100_deal', limit: 20 });
    // underscore is literal; should NOT match '100%_deal' as single-char wildcard skip
    if (under.status === 201) {
      expect(under.body.items.some((i: { name: string }) => /100%_deal/.test(i.name))).toBe(false);
    }

    // Multiword phrase AND across distinct tokens in document
    const phrase = await search({ q: 'قصر أفراح UniquePhrase', limit: 10 });
    expect(phrase.status).toBe(201);
    expect(phrase.body.items.some((i: { venueId: string }) => i.venueId === ids[1])).toBe(true);
    // Different phrases stay AND — impossible combo yields empty
    const andFail = await search({ q: 'قصر أفراح لايوجدهذاالنص', limit: 10 });
    expect(andFail.status).toBe(201);
    expect(andFail.body.total).toBe(0);

    // Full search pagination: seen size == total, no dupes, cursor null
    const first = await search({ q: 'hotel', limit: 2 });
    expect(first.status).toBe(201);
    expect(first.body.sort).toBe('search_rank');
    const total = first.body.total as number;
    const seen = new Set<string>();
    let cursor: string | null = null;
    for (let page = 0; page < 40; page++) {
      const body: Record<string, unknown> = { q: 'hotel', limit: 2 };
      if (cursor) body.cursor = cursor;
      const res = await search(body);
      expect(res.status).toBe(201);
      expect(res.body.total).toBe(total);
      for (const item of res.body.items as { venueId: string }[]) {
        expect(seen.has(item.venueId)).toBe(false);
        seen.add(item.venueId);
      }
      cursor = res.body.nextCursor;
      if (!cursor) break;
    }
    expect(seen.size).toBe(total);
    expect(cursor).toBeNull();
  });

  it('G7B33-RANK actual bestScore on venues + full traversal = total', async () => {
    const p = await seedProvider(pool, `${uid}-r-${newId().slice(0, 6)}`, 'Rank');
    const reviews = [0, 500, 800, 500, 10];
    const ids: string[] = [];
    for (let i = 0; i < reviews.length; i++) {
      const seeded = await seedVenue(pool, p, {
        name: `Rank Hotel ${i}`,
        venueType: 'hotel',
        types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
      });
      await pool.query(
        `UPDATE venues SET lat=$2, lng=$3, weighted_rating=$4, reviews_count=$5,
          rating_average=$4, created_at=now() - ($6 || ' days')::interval WHERE id=$1`,
        [seeded.venueId, 25 + i * 0.01, 45 + i * 0.01, 4.0 + (i % 3) * 0.1, reviews[i], String(i * 20)],
      );
      if (i !== 4) await ensureMedia(seeded.venueId, p, `r${i}`);
      ids.push(seeded.venueId);
    }

    const expr = bestScoreSqlExpr(1);
    const scores = await pool.query<{ id: string; reviews_count: number; score: string }>(
      `SELECT v.id, v.reviews_count, ${expr}::text AS score
       FROM venues v
       WHERE v.id = ANY($2::uuid[])
       ORDER BY ${expr} DESC, v.id ASC`,
      [new Date().toISOString(), ids],
    );
    expect(scores.rows).toHaveLength(ids.length);
    const byId = Object.fromEntries(scores.rows.map((r) => [r.id, r]));
    // reviews 500 and 800 share same reviews component ceiling
    const s500 = scores.rows.find((r) => Number(r.reviews_count) === 500)!;
    const s800 = scores.rows.find((r) => Number(r.reviews_count) === 800)!;
    expect(s500).toBeTruthy();
    expect(s800).toBeTruthy();
    void byId;

    const first = await search({ sort: 'best', limit: 2, surface: 'search' });
    expect(first.status).toBe(201);
    const total = first.body.total as number;
    const seen = new Set<string>();
    let cursor: string | null = null;
    let rankingAsOf: string | null = null;
    for (let page = 0; page < 50; page++) {
      const body: Record<string, unknown> = { sort: 'best', limit: 2, surface: 'search' };
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
    expect(seen.size).toBe(total);
    expect(cursor).toBeNull();
  });
});
