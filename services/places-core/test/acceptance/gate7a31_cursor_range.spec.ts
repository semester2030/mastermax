import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { encodeTestCursorV2 } from '../helpers/cursor-v2';
import { newId } from '../../src/shared/ids/ids';
import { seedProvider, seedVenue } from '../helpers/seed';
import {
  CURSOR_DISTANCE_METERS_MAX,
  CURSOR_PG_INT_MAX,
  CURSOR_PRICE_MAX_TEXT,
  DISCOVERY_FILTER_PRICE_MAX,
  encodeCursor,
} from '../../src/modules/filters/application/discovery-cursor';

describe('Gate 7A.3.1 — cursor numeric range + price domain (API)', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7a31-cursor-range';

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

  async function expectValidationReject(sort: string, cursor: string, extra: Record<string, unknown> = {}) {
    const res = await search({ sort, cursor, limit: 5, ...extra });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
    expect(res.status).not.toBe(500);
  }

  it('accepts price cursors above filter max within NUMERIC(12,2)', async () => {
    const overBody = { sort: 'cheapest', limit: 5 };
    const overFilter = await search({
      ...overBody,
      cursor: encodeTestCursorV2(overBody, { sv: '1000001.00', id: newId() }),
    });
    expect(overFilter.status).toBe(201);
    expect(overFilter.body.code).not.toBe('INTERNAL');

    const atMaxBody = { sort: 'most_expensive', limit: 5 };
    const atNumericMax = await search({
      ...atMaxBody,
      cursor: encodeTestCursorV2(atMaxBody, { sv: CURSOR_PRICE_MAX_TEXT, id: newId() }),
    });
    expect(atNumericMax.status).toBe(201);

    await expectValidationReject(
      'cheapest',
      encodeCursor({ v: 1, sort: 'cheapest', sv: '10000000000', id: newId() }),
    );
    await expectValidationReject(
      'cheapest',
      encodeCursor({ v: 1, sort: 'cheapest', sv: '9999999999.999', id: newId() }),
    );
  });

  it('paginates cheapest venues priced above 1_000_000 without cursor self-reject', async () => {
    const prices = [1_500_000, 2_000_000, 2_500_000, 3_000_000, 3_500_000];
    const venueIds: string[] = [];
    for (const [i, price] of prices.entries()) {
      const providerId = await seedProvider(pool, `hi-price-${i}-${newId()}`, `Hi${i}`);
      const seeded = await seedVenue(pool, providerId, {
        name: `HiPrice-${price}`,
        venueType: 'hotel',
        types: [{ name: 'Std', qty: 3, nights: { '2034-06-01': String(price) } }],
      });
      venueIds.push(seeded.venueId);
      await pool.query(
        `UPDATE rate_rules SET amount=$2 WHERE rate_plan_id=$1 AND kind='base'`,
        [seeded.plans.Std, String(price)],
      );
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
         VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,'hotel',$5)`,
        [newId(), seeded.venueId, providerId, `https://example.test/hi-${i}.mp4`, price],
      );
    }

    const pageBody = {
      surface: 'search',
      category: 'hotel',
      sort: 'cheapest',
      checkIn: '2034-06-01',
      checkOut: '2034-06-02',
      quantity: 1,
      limit: 2,
    };
    const page1 = await search(pageBody);
    expect(page1.status).toBe(201);
    expect(page1.body.total).toBeGreaterThanOrEqual(5);
    expect(page1.body.items.length).toBe(2);
    expect(page1.body.nextCursor).toBeTruthy();
    for (const item of page1.body.items) {
      expect(Number(item.startingPriceHint)).toBeGreaterThan(DISCOVERY_FILTER_PRICE_MAX);
    }

    const page2 = await search({ ...pageBody, cursor: page1.body.nextCursor });
    expect(page2.status).toBe(201);
    expect(page2.body.code).not.toBe('INTERNAL');
    expect(page2.body.total).toBe(page1.body.total);
    expect(page2.body.items.length).toBe(2);
    for (const item of page2.body.items) {
      expect(Number(item.startingPriceHint)).toBeGreaterThan(DISCOVERY_FILTER_PRICE_MAX);
    }

    const ids1 = page1.body.items.map((i: { venueId: string }) => i.venueId);
    const ids2 = page2.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids1.some((id: string) => ids2.includes(id))).toBe(false);

    const page3 = await search({ ...pageBody, cursor: page2.body.nextCursor });
    expect(page3.status).toBe(201);
    expect(page3.body.total).toBe(page1.body.total);
    const all = [...ids1, ...ids2, ...page3.body.items.map((i: { venueId: string }) => i.venueId)];
    const unique = new Set(all);
    expect(unique.size).toBe(all.length);
    for (const id of venueIds) {
      expect(all).toContain(id);
    }
  });

  it('maxPrice filter still rejects values above 1_000_000 (DTO contract)', async () => {
    const res = await search({
      sort: 'cheapest',
      maxPrice: DISCOVERY_FILTER_PRICE_MAX + 1,
      limit: 5,
    });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  it('rejects out-of-range non-price cursors as VALIDATION_ERROR', async () => {
    await expectValidationReject(
      'rating',
      encodeCursor({ v: 1, sort: 'rating', sv: '100.00', sv2: '1', id: newId() }),
    );
    await expectValidationReject(
      'rating',
      encodeCursor({
        v: 1,
        sort: 'rating',
        sv: '4',
        sv2: String(CURSOR_PG_INT_MAX + 1),
        id: newId(),
      }),
    );
    await expectValidationReject(
      'near_me',
      encodeCursor({
        v: 1,
        sort: 'near_me',
        sv: String(CURSOR_DISTANCE_METERS_MAX + 1),
        id: newId(),
      }),
      { lat: 24.7, lng: 46.7 },
    );
    await expectValidationReject(
      'newest',
      encodeCursor({ v: 1, sort: 'newest', sv: '2035-99-99T99:99:99Z', id: newId() }),
    );
  });
});
