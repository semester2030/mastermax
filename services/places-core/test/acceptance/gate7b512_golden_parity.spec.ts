/**
 * Gate 7B.5.1.3 — golden oracle for all 8 discovery sorts (strict terminal null + DB projection).
 * Independent SQL (no import of bestScoreSqlExpr / ORDER helpers from runtime).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';

const SORTS = [
  'best',
  'newest',
  'rating',
  'cheapest',
  'most_expensive',
  'near_me',
  'near_place',
  'search_rank',
] as const;

type Sort = (typeof SORTS)[number];

/** Inlined classic best_score (Gate 7B.3) — not imported from runtime. */
function oracleBestScoreSql(asOfParam: number): string {
  return `(
  (
    0.45 * (LEAST(5::numeric, GREATEST(0::numeric, COALESCE(v.weighted_rating, 0))) / 5.0)
    + 0.20 * (LN(1.0 + LEAST(COALESCE(v.reviews_count, 0), 500)::numeric) / LN(501.0))
    + 0.15 * EXP(
      -LN(2) * GREATEST(
        0,
        EXTRACT(EPOCH FROM ($${asOfParam}::timestamptz - v.created_at)) / 86400.0
      ) / 90.0
    )
    + 0.10 * CASE WHEN v.has_playable_video IS TRUE THEN 1.0 ELSE 0.0 END
  )::numeric(8,6)
)`;
}

/** Inlined haversine meters — not imported. */
function oracleDistMeters(latP: number, lngP: number): string {
  return `(
  CASE WHEN v.lat IS NULL OR v.lng IS NULL THEN NULL ELSE
  ROUND((
    6371 * acos(LEAST(1, GREATEST(-1,
      cos(radians($${latP})) * cos(radians(v.lat)) *
      cos(radians(v.lng) - radians($${lngP})) +
      sin(radians($${latP})) * sin(radians(v.lat))
    )))
  ) * 1000)::bigint END
)`;
}

const BASE_WHERE = `v.status='published' AND EXISTS (
  SELECT 1 FROM venue_type_capabilities c
  WHERE c.venue_type=v.venue_type AND c.enabled_for_discovery)`;

describe('Gate 7B.5.1.3 — golden oracle (8 sorts)', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b513-gold';
  let types: string[] = [];

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    const r = await pool.query<{ venue_type: string }>(
      `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY sort_order`,
    );
    types = r.rows.map((x) => x.venue_type);
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  beforeEach(async () => {
    await pool.query('TRUNCATE providers CASCADE');
  });

  async function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(uid))
      .send(body);
  }

  async function seedCluster() {
    const providerId = newId();
    await pool.query(
      `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
       VALUES ($1,'Gold','Gold','company','active',$2)`,
      [providerId, `gold-${providerId}`],
    );
    const hotel = types.includes('hotel') ? 'hotel' : types[0];
    const ids: string[] = [];
    for (let i = 0; i < 18; i++) {
      const id = newId();
      ids.push(id);
      const vt = i < 14 ? hotel : types[i % types.length];
      const wr = i === 0 ? 6.75 : i === 1 ? 5.5 : 2.5 + (i % 10) * 0.25;
      await pool.query(
        `INSERT INTO venues (
           id, provider_id, name, venue_type, booking_mode, status, city, lat, lng,
           weighted_rating, reviews_count, rating_average, created_at
         ) VALUES (
           $1,$2,$3,$4,'nightly','published','Riyadh',$5,$6,
           $7,$8,$7,
           timestamptz '2026-05-01 00:00:00+00' + ($9 || ' minutes')::interval
         )`,
        [
          id,
          providerId,
          `Hotel Gold Venue ${i}`,
          vt,
          24.71 + i * 0.002,
          46.67 + i * 0.002,
          wr,
          20 + i,
          i,
        ],
      );
      await pool.query(
        `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order, starting_price_hint)
         VALUES ($1,$2,$3,'video','https://cdn.example/v.mp4',$4,'approved',0,$5)`,
        [newId(), id, providerId, `s-${id}`, 80 + i * 5],
      );
    }
    return { ids, hotel, originLat: 24.71, originLng: 46.67, anchorId: ids[3] };
  }

  type OracleRow = {
    id: string;
    weightedRating: number;
    startingPriceHint: number | null;
    bestScore: number | null;
  };

  async function oracleRows(
    sort: Sort,
    ctx: {
      rankingAsOf: string;
      lat?: number;
      lng?: number;
      radiusKm?: number;
      anchorId?: string;
      anchorType?: string;
    },
  ): Promise<OracleRow[]> {
    const params: unknown[] = [];
    let where = BASE_WHERE;
    let orderBy: string;
    // API always projects best_score; oracle must match even when sort key differs.
    params.push(ctx.rankingAsOf);
    const bestExpr = oracleBestScoreSql(1);
    let orderParamsOffset = 0;

    if (sort === 'best') {
      orderBy = `${bestExpr} DESC NULLS LAST, v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC`;
    } else if (sort === 'newest') {
      orderBy = `date_trunc('milliseconds', v.created_at) DESC NULLS LAST, v.id ASC`;
    } else if (sort === 'rating') {
      orderBy = `v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC`;
    } else if (sort === 'cheapest') {
      orderBy = `v.indicative_starting_price ASC NULLS LAST, v.id ASC`;
    } else if (sort === 'most_expensive') {
      orderBy = `v.indicative_starting_price DESC NULLS LAST, v.id ASC`;
    } else if (sort === 'near_me' || sort === 'near_place') {
      params.push(ctx.lat!, ctx.lng!, ctx.radiusKm ?? 25);
      const latP = 2;
      const lngP = 3;
      const dist = oracleDistMeters(latP, lngP);
      where += ` AND v.lat IS NOT NULL AND v.lng IS NOT NULL
        AND (
          6371 * acos(LEAST(1, GREATEST(-1,
            cos(radians($${latP})) * cos(radians(v.lat)) *
            cos(radians(v.lng) - radians($${lngP})) +
            sin(radians($${latP})) * sin(radians(v.lat))
          )))
        ) <= $4`;
      if (sort === 'near_place') {
        params.push(ctx.anchorId);
        where += ` AND v.id <> $${params.length}`;
        params.push(ctx.anchorType);
        where += ` AND v.venue_type = $${params.length}`;
      }
      orderBy = `${dist} ASC NULLS LAST, v.id ASC`;
    } else {
      params.push(['hotel']);
      const tokenP = params.length;
      const rank = `(
        SELECT COALESCE(AVG(similarity(v.search_document, t.token)), 0)::numeric(8,6)
        FROM unnest($${tokenP}::text[]) AS t(token)
      )`;
      where += ` AND (
        v.search_document ILIKE '%' || 'hotel' || '%' ESCAPE '\\'
        OR v.search_document % 'hotel'
      )`;
      orderBy = `${rank} DESC NULLS LAST, ${bestExpr} DESC NULLS LAST, v.id ASC`;
      orderParamsOffset = 0;
    }
    void orderParamsOffset;

    const r = await pool.query<{
      id: string;
      weighted_rating: string;
      starting_price_hint: string | null;
      best_score: string | null;
    }>(
      `SELECT v.id,
              v.weighted_rating::text,
              v.indicative_starting_price::text AS starting_price_hint,
              (${bestExpr})::text AS best_score
       FROM venues v WHERE ${where} ORDER BY ${orderBy}`,
      params,
    );
    return r.rows.map((x) => ({
      id: x.id,
      weightedRating: Number(x.weighted_rating),
      startingPriceHint: x.starting_price_hint != null ? Number(x.starting_price_hint) : null,
      bestScore: x.best_score != null ? Number(x.best_score) : null,
    }));
  }

  it('G7B513-GOLD-01 all 8 sorts: oracle IDs/total/projection/queryHash + strict nextCursor null', async () => {
    // Freeze wall clock so uncursored repeats share rankingAsOf → stable queryHash.
    jest.useFakeTimers({
      doNotFake: [
        'nextTick',
        'setImmediate',
        'clearImmediate',
        'setInterval',
        'clearInterval',
        'setTimeout',
        'clearTimeout',
        'queueMicrotask',
        'performance',
      ],
    });
    jest.setSystemTime(new Date('2026-08-15T12:00:00.000Z'));

    try {
      const cluster = await seedCluster();
      void SORTS; // enumerated below
      const cases: { sort: Sort; body: Record<string, unknown> }[] = [
        { sort: 'best', body: { sort: 'best', limit: 5, surface: 'search' } },
        { sort: 'newest', body: { sort: 'newest', limit: 5, surface: 'search' } },
        { sort: 'rating', body: { sort: 'rating', limit: 5, surface: 'search' } },
        { sort: 'cheapest', body: { sort: 'cheapest', limit: 5, surface: 'search' } },
        { sort: 'most_expensive', body: { sort: 'most_expensive', limit: 5, surface: 'search' } },
        {
          sort: 'near_me',
          body: {
            sort: 'near_me',
            lat: cluster.originLat,
            lng: cluster.originLng,
            radiusKm: 25,
            limit: 5,
            surface: 'circle',
          },
        },
        {
          sort: 'near_place',
          body: {
            sort: 'near_place',
            anchorVenueId: cluster.anchorId,
            sameTypeOnly: true,
            radiusKm: 25,
            limit: 5,
            surface: 'search',
          },
        },
        {
          sort: 'search_rank',
          body: { q: 'hotel', sort: 'best', limit: 5, surface: 'search' },
        },
      ];
      // search_rank: API uses sort=search_rank when q present with that sort
      cases[7] = {
        sort: 'search_rank',
        body: { q: 'hotel', sort: 'search_rank', limit: 5, surface: 'search' },
      };

      for (const c of cases) {
        const first = await search(c.body);
        expect([200, 201]).toContain(first.status);
        expect(first.body.applied.queryHash).toMatch(/^[0-9a-f]{32}$/);
        const rankingAsOf = first.body.applied.rankingAsOf as string;

        let lat = cluster.originLat;
        let lng = cluster.originLng;
        let anchorType = cluster.hotel;
        if (c.sort === 'near_place') {
          const a = await pool.query<{ lat: string; lng: string; venue_type: string }>(
            `SELECT lat::text, lng::text, venue_type FROM venues WHERE id=$1`,
            [cluster.anchorId],
          );
          lat = Number(a.rows[0].lat);
          lng = Number(a.rows[0].lng);
          anchorType = a.rows[0].venue_type;
        }

      const expectedRows = await oracleRows(c.sort, {
        rankingAsOf,
        lat,
        lng,
        radiusKm: 25,
        anchorId: cluster.anchorId,
        anchorType,
      });
      const expected = expectedRows.map((r) => r.id);
      expect(first.body.total).toBe(expected.length);
      expect(first.body.items.map((x: { venueId: string }) => x.venueId)).toEqual(
        expected.slice(0, Math.min(5, expected.length)),
      );

      const projApi = (items: Record<string, unknown>[]) =>
        items.map((x) => ({
          venueId: x.venueId,
          weightedRating: Number(x.weightedRating),
          startingPriceHint:
            x.startingPriceHint == null ? null : Number(x.startingPriceHint),
          bestScore: x.bestScore == null ? null : Number(x.bestScore),
        }));
      const projOracle = (rows: OracleRow[]) =>
        rows.map((r) => ({
          venueId: r.id,
          weightedRating: r.weightedRating,
          startingPriceHint: r.startingPriceHint,
          bestScore: r.bestScore,
        }));
      expect(projApi(first.body.items)).toEqual(
        projOracle(expectedRows.slice(0, Math.min(5, expectedRows.length))),
      );

      const repeat = await search(c.body);
      expect(repeat.body.applied.queryHash).toBe(first.body.applied.queryHash);
      expect(projApi(repeat.body.items)).toEqual(projApi(first.body.items));

      if (c.sort === 'rating') {
        expect(Number(first.body.items[0].weightedRating)).toBeGreaterThan(5);
      }

      const seen: string[] = [];
      let cursor: string | undefined;
      let pages = 0;
      let lastNext: unknown = 'unset';
      for (;;) {
        const res = await search({ ...c.body, cursor });
        expect([200, 201]).toContain(res.status);
        expect(res.body.applied.queryHash).toBe(first.body.applied.queryHash);
        expect(res.body.total).toBe(expected.length);
        const pageProj = projApi(res.body.items);
        expect(pageProj).toEqual(
          projOracle(expectedRows.slice(seen.length, seen.length + res.body.items.length)),
        );
        for (const it of res.body.items) {
          expect(seen.includes(it.venueId)).toBe(false);
          seen.push(it.venueId);
        }
        pages += 1;
        lastNext = res.body.nextCursor;
        // Strict terminal: must be null — undefined is NOT accepted.
        if (res.body.nextCursor === null) {
          expect(res.body.nextCursor).toBeNull();
          break;
        }
        expect(typeof res.body.nextCursor).toBe('string');
        cursor = res.body.nextCursor as string;
        expect(pages).toBeLessThan(80);
      }
      expect(lastNext).toBeNull();
      expect(seen).toEqual(expected);
      expect(seen.length).toBe(expected.length);
      expect(seen.length).toBe(first.body.total);
    }
    } finally {
      jest.useRealTimers();
    }
  }, 300_000);
});
