/**
 * Gate 7B.5.1 — weighted_rating >5 cursor consistency + full traversal.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';
import { formatWeightedRatingCursorSv } from '../../src/modules/filters/application/discovery-cursor-encode';
import { parseCursorV2Structural } from '../../src/modules/filters/application/discovery-cursor-v2';

describe('Gate 7B.5.1 — weighted_rating cursor consistency', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b51-wr';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
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

  async function seedVenue(opts: {
    name: string;
    venueType: string;
    weighted: number;
    reviews: number;
    createdAt: string;
    playable?: boolean;
  }) {
    const providerId = newId();
    await pool.query(
      `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
       VALUES ($1,$2,$2,'company','active',$3)`,
      [providerId, opts.name, `o-${opts.name}`],
    );
    const venueId = newId();
    await pool.query(
      `INSERT INTO venues (
         id, provider_id, name, venue_type, booking_mode, status, city, lat, lng,
         weighted_rating, reviews_count, rating_average, created_at
       ) VALUES ($1,$2,$3,$4,'nightly','published','Riyadh',24.7,46.7,$5,$6,$5,$7::timestamptz)`,
      [
        venueId,
        providerId,
        opts.name,
        opts.venueType,
        opts.weighted,
        opts.reviews,
        opts.createdAt,
      ],
    );
    if (opts.playable !== false) {
      await pool.query(
        `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order)
         VALUES ($1,$2,$3,'video','https://cdn.example/v.mp4',$4,'approved',0)`,
        [newId(), venueId, providerId, `s-${newId()}`],
      );
    }
    return venueId;
  }

  async function traverseAll(
    body: Record<string, unknown>,
  ): Promise<{ ids: string[]; pages: number }> {
    const ids: string[] = [];
    let cursor: string | undefined;
    let pages = 0;
    let terminalNull = false;
    for (;;) {
      const res = await search({ ...body, cursor, limit: body.limit ?? 5 });
      expect([200, 201]).toContain(res.status);
      for (const it of res.body.items) {
        expect(ids.includes(it.venueId)).toBe(false);
        ids.push(it.venueId);
      }
      pages += 1;
      if (!res.body.nextCursor) {
        terminalNull = true;
        break;
      }
      cursor = res.body.nextCursor;
      if (pages > 200) break;
    }
    expect(terminalNull).toBe(true);
    return { ids, pages };
  }

  it('G7B51-CUR-01 formatWeightedRatingCursorSv is raw toFixed(2) (no clamp)', () => {
    expect(formatWeightedRatingCursorSv(7.5)).toBe('7.50');
    expect(formatWeightedRatingCursorSv(5.01)).toBe('5.01');
    expect(formatWeightedRatingCursorSv(0)).toBe('0.00');
  });

  it('G7B51-CUR-02 rating traversal with weighted_rating > 5 — no drop/dup, cursor null', async () => {
    const types = (
      await pool.query<{ venue_type: string }>(
        `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY sort_order`,
      )
    ).rows.map((r) => r.venue_type);
    const expected: string[] = [];
    for (let i = 0; i < 18; i++) {
      const id = await seedVenue({
        name: `wr-rate-${i}`,
        venueType: types[i % types.length],
        weighted: 4 + i * 0.3, // crosses 5
        reviews: 100 - i,
        createdAt: `2026-03-01T00:00:${String(i).padStart(2, '0')}Z`,
      });
      expected.push(id);
    }
    const { ids } = await traverseAll({ sort: 'rating', surface: 'search', limit: 5 });
    expect(ids.length).toBe(expected.length);
    expect(new Set(ids).size).toBe(expected.length);
    // order: weighted DESC
    const ordered = await pool.query<{ id: string }>(
      `SELECT id FROM venues WHERE status='published'
       ORDER BY weighted_rating DESC NULLS LAST, reviews_count DESC, id ASC`,
    );
    expect(ids).toEqual(ordered.rows.map((r) => r.id));
  });

  it('G7B51-CUR-03 best + diversity traversal with weighted > 5', async () => {
    const types = (
      await pool.query<{ venue_type: string }>(
        `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY sort_order LIMIT 4`,
      )
    ).rows.map((r) => r.venue_type);
    for (let i = 0; i < 16; i++) {
      await seedVenue({
        name: `wr-best-${i}`,
        venueType: types[i % types.length],
        weighted: 5.5 + (i % 3),
        reviews: 50 + i,
        createdAt: `2026-04-01T00:${String(i).padStart(2, '0')}:00Z`,
        playable: true,
      });
    }
    const best = await traverseAll({ sort: 'best', surface: 'search', limit: 4 });
    expect(best.ids.length).toBe(16);

    const div = await traverseAll({ sort: 'best', surface: 'feed', limit: 4 });
    expect(div.ids.length).toBe(16);
    expect(new Set(div.ids).size).toBe(16);

    // cursor payload carries raw >5
    const first = await search({ sort: 'rating', surface: 'search', limit: 1 });
    expect(first.body.nextCursor).toBeTruthy();
    const decoded = parseCursorV2Structural(first.body.nextCursor, 'forbidden');
    expect(Number(decoded.sv)).toBeGreaterThan(5);
  });
});
