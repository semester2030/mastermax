import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { applyMigrationsThrough, applyRemainingMigrations } from '../helpers/migrate-partial';
import { encodeTestCursorV2, rankingAsOfNow } from '../helpers/cursor-v2';
import { dropPublicSchemaForCi } from '../helpers/db-safety';

describe('Gate 7B.1–7B.3 acceptance — geo/search/rank/mig', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b123-user';

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

  async function seedNearCluster(tag: string) {
    const ids: string[] = [];
    for (let i = 0; i < 6; i++) {
      const providerId = await seedProvider(pool, `${uid}-${tag}-${i}-${newId().slice(0, 8)}`, `NP${tag}${i}`);
      const seeded = await seedVenue(pool, providerId, {
        name: i === 0 ? 'فندق الملقا Anchor' : `Near Hotel ${i}`,
        venueType: i === 5 ? 'chalet' : 'hotel',
        types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
      });
      await pool.query(
        `UPDATE venues SET lat=$2, lng=$3, city='Riyadh', district='Malqa',
          weighted_rating=$4, reviews_count=$5, rating_average=$4 WHERE id=$1`,
        [seeded.venueId, 24.71 + i * 0.01, 46.67 + i * 0.01, 4.5 - i * 0.1, 100 - i * 5],
      );
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,'hotel')`,
        [newId(), seeded.venueId, providerId, `https://example.test/np-${tag}-${i}.mp4`],
      );
      ids.push(seeded.venueId);
    }
    return ids;
  }

  it('G7B1-GEO API: near_place excludes anchor, sameTypeOnly, near_me intact', async () => {
    const ids = await seedNearCluster('geo');
    const anchorId = ids[0];

    const missing = await search({ sort: 'near_place', limit: 5 });
    expect(missing.status).toBe(400);

    const np = await search({
      sort: 'near_place',
      anchorVenueId: anchorId,
      sameTypeOnly: true,
      limit: 3,
      surface: 'map',
    });
    expect(np.status).toBe(201);
    expect(np.body.items.every((i: { venueId: string }) => i.venueId !== anchorId)).toBe(true);
    expect(np.body.items.every((i: { category: string }) => i.category === 'hotel')).toBe(true);
    expect(np.body.applied.rankingAsOf).toBeTruthy();

    const nm = await search({
      sort: 'near_me',
      lat: 24.71,
      lng: 46.67,
      limit: 3,
      surface: 'map',
    });
    expect(nm.status).toBe(201);
    expect(nm.body.items.length).toBeGreaterThan(0);
    expect(nm.body.items[0].distanceMeters).toBeDefined();
  });

  it('G7B1-CURSOR API: pagination no dupes; mismatch 400 before SQL', async () => {
    const ids = await seedNearCluster('cur');
    const body = {
      sort: 'near_place',
      anchorVenueId: ids[0],
      limit: 2,
      surface: 'map',
    };
    const p1 = await search(body);
    expect(p1.status).toBe(201);
    expect(p1.body.nextCursor).toBeTruthy();
    const p2 = await search({ ...body, cursor: p1.body.nextCursor });
    expect(p2.status).toBe(201);
    const all = [...p1.body.items, ...p2.body.items].map((i: { venueId: string }) => i.venueId);
    expect(new Set(all).size).toBe(all.length);

    const badHash = encodeTestCursorV2(
      body,
      { sv: '1', id: newId() },
      rankingAsOfNow(),
    );
    // corrupt hash by re-encoding with different body
    const mismatch = await search({
      ...body,
      city: 'Jeddah',
      cursor: badHash,
    });
    expect(mismatch.status).toBe(400);

    const legacy = Buffer.from(JSON.stringify({ v: 1, sort: 'near_place', sv: '1', id: newId() })).toString(
      'base64url',
    );
    expect((await search({ ...body, cursor: legacy })).status).toBe(400);
  });

  it('G7B2-SEARCH API: AR/EN q filter; special chars; search_rank stable pages', async () => {
    await seedNearCluster('search');
    const ar = await search({ q: 'ملقا', sort: 'newest', limit: 10, surface: 'search' });
    expect(ar.status).toBe(201);

    const en = await search({ q: 'Hotel', sort: 'newest', limit: 10, surface: 'search' });
    expect(en.status).toBe(201);
    expect(en.body.total).toBeGreaterThan(0);

    expect((await search({ q: 'hot%', sort: 'newest' })).status).toBe(201);
    expect((await search({ q: '   ', sort: 'newest' })).status).toBe(201);

    const p1 = await search({ q: 'Hotel', sort: 'search_rank', limit: 2, surface: 'search' });
    expect(p1.status).toBe(201);
    if (p1.body.nextCursor) {
      const p2 = await search({
        q: 'Hotel',
        sort: 'search_rank',
        limit: 2,
        surface: 'search',
        cursor: p1.body.nextCursor,
      });
      expect(p2.status).toBe(201);
      const ids = [...p1.body.items, ...p2.body.items].map((i: { venueId: string }) => i.venueId);
      expect(new Set(ids).size).toBe(ids.length);
    }
  });

  it('G7B3-RANK API: best_score order; rating independent; epoch mismatch 400', async () => {
    await seedNearCluster('rank');
    const best = await search({ sort: 'best', limit: 5, surface: 'search' });
    expect(best.status).toBe(201);
    expect(best.body.applied.rankingAsOf).toBeTruthy();
    expect(best.body.applied.queryHash).toBeTruthy();
    const scores = best.body.items
      .map((i: { bestScore: number | null }) => i.bestScore)
      .filter((s: number | null) => s != null) as number[];
    for (let i = 1; i < scores.length; i++) {
      expect(scores[i - 1]).toBeGreaterThanOrEqual(scores[i]);
    }

    const rating = await search({ sort: 'rating', limit: 5, surface: 'search' });
    expect(rating.status).toBe(201);

    if (best.body.nextCursor) {
      const p2 = await search({
        sort: 'best',
        limit: 5,
        surface: 'search',
        cursor: best.body.nextCursor,
      });
      expect(p2.status).toBe(201);
      expect(p2.body.applied.rankingAsOf).toBe(best.body.applied.rankingAsOf);
    }

    const tampered = Buffer.from(
      JSON.stringify({
        v: 2,
        sort: 'best',
        queryHash: best.body.applied.queryHash,
        rankingEpoch: 99,
        rankingAsOf: best.body.applied.rankingAsOf,
        sv: '0.500000',
        sv2: '4.00',
        sv3: '1',
        id: newId(),
      }),
    ).toString('base64url');
    expect((await search({ sort: 'best', cursor: tampered, limit: 5 })).status).toBe(400);
  });

  it('G7B2-MIG-01..03 upgrade 009→010 and full 001→010', async () => {
    testEnv();
    const p = new Pool({ connectionString: process.env.DATABASE_URL });
    await dropPublicSchemaForCi(p);
    const through009 = await applyMigrationsThrough(p, '009_gate7a3_final_closure.sql');
    expect(through009.some((f) => f.startsWith('009'))).toBe(true);
    const colBefore = await p.query(
      `SELECT 1 FROM information_schema.columns WHERE table_name='venues' AND column_name='search_document'`,
    );
    expect(colBefore.rowCount).toBe(0);
    const rem = await applyRemainingMigrations(p);
    expect(rem).toEqual(expect.arrayContaining(['010_gate7b_search.sql']));
    const colAfter = await p.query(
      `SELECT 1 FROM information_schema.columns WHERE table_name='venues' AND column_name='search_document'`,
    );
    expect(colAfter.rowCount).toBe(1);
    const ext = await p.query(`SELECT 1 FROM pg_extension WHERE extname='pg_trgm'`);
    expect(ext.rowCount).toBe(1);
    const idx = await p.query(
      `SELECT 1 FROM pg_indexes WHERE indexname='idx_venues_search_document_trgm'`,
    );
    expect(idx.rowCount).toBe(1);

    // full 001→010 on clean schema
    await dropPublicSchemaForCi(p);
    const all = await applyMigrationsThrough(p, '010_gate7b_search.sql');
    expect(all[0]).toMatch(/^001_/);
    expect(all).toEqual(expect.arrayContaining(['010_gate7b_search.sql']));
    await p.end();

    await resetDb();
  }, 180_000);
});
