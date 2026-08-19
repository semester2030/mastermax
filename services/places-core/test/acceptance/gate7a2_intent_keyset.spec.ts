import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { newId } from '../../src/shared/ids/ids';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7A.2 — Intent applicability and keyset FC91–FC114', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-fc7a2-intent';

  beforeAll(async () => {
    testEnv();
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

  function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send(body);
  }

  async function insertIntent(options: {
    code: string;
    types: string[];
    expansion: Record<string, unknown>;
    status?: 'active' | 'inactive';
  }): Promise<void> {
    await pool.query(
      `INSERT INTO intent_presets
         (id, code, label_ar, label_en, applicable_venue_types, expands_to_jsonb, status)
       VALUES ($1,$2,$2,$2,$3,$4,$5)
       ON CONFLICT (code) DO UPDATE
       SET applicable_venue_types=EXCLUDED.applicable_venue_types,
           expands_to_jsonb=EXCLUDED.expands_to_jsonb,
           status=EXCLUDED.status`,
      [
        newId(),
        options.code,
        options.types,
        JSON.stringify(options.expansion),
        options.status ?? 'active',
      ],
    );
  }

  async function seedSearchVenue(options: {
    name: string;
    type?: string;
    price?: number | null;
    amenities?: string[];
    maxOccupancy?: number;
    stars?: number;
    weighted?: number;
    reviews?: number;
    createdAt?: string;
    lat?: number;
    lng?: number;
  }): Promise<string> {
    const providerId = await seedProvider(pool, `intent-${options.name}-${newId()}`, options.name);
    const venue = await seedVenue(pool, providerId, {
      name: options.name,
      venueType: options.type ?? 'hotel',
      types: [{ name: 'standard', qty: 10, nights: { '2035-01-01': '200' } }],
    });
    await pool.query(
      `UPDATE venues
       SET stars=$2, weighted_rating=$3, reviews_count=$4,
           created_at=COALESCE($5::timestamptz, created_at), lat=$6, lng=$7
       WHERE id=$1`,
      [
        venue.venueId,
        options.stars ?? null,
        options.weighted ?? 0,
        options.reviews ?? 0,
        options.createdAt ?? null,
        options.lat ?? 24.7,
        options.lng ?? 46.7,
      ],
    );
    if (options.maxOccupancy != null) {
      await pool.query('UPDATE inventory_types SET max_occupancy=$2 WHERE venue_id=$1', [
        venue.venueId,
        options.maxOccupancy,
      ]);
    }
    if (options.price !== null) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status,
            sort_order, category, starting_price_hint)
         VALUES ($1,$2,$3,'video',$4,$5,'approved',0,$6,$7)`,
        [
          newId(),
          venue.venueId,
          providerId,
          `https://example.test/${options.name}.mp4`,
          `https://example.test/${options.name}.jpg`,
          options.type ?? 'hotel',
          options.price ?? 200,
        ],
      );
    }
    for (const code of options.amenities ?? []) {
      await pool.query(
        `INSERT INTO venue_amenity_links
           (id, venue_id, amenity_code, scope, state)
         VALUES ($1,$2,$3,'venue','AVAILABLE')`,
        [newId(), venue.venueId, code],
      );
    }
    return venue.venueId;
  }

  it('FC91 rejects an unknown intent', async () => {
    const res = await search({ intent: 'fc91_unknown' });
    // FC91: unknown intent is a validation failure.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC92 rejects an inactive intent', async () => {
    await insertIntent({ code: 'fc92_inactive', types: ['*'], expansion: {}, status: 'inactive' });
    const res = await search({ intent: 'fc92_inactive' });
    // FC92: inactive presets cannot be resolved.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC93 rejects an intent/category applicability mismatch', async () => {
    const res = await search({ intent: 'honeymoon', category: 'apartment' });
    // FC93: applicable_venue_types is enforced when category is explicit.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC94 permits wildcard intent applicability', async () => {
    await seedSearchVenue({ name: 'WildcardApartment', type: 'apartment', amenities: ['family'], maxOccupancy: 8 });
    const res = await search({ intent: 'family', category: 'apartment' });
    // FC94: '*' intent applicability permits any enabled explicit category.
    expect(res.status).toBe(201);
  });

  it('FC95 scopes candidates to applicable venue types when category is absent', async () => {
    const allowed = await seedSearchVenue({
      name: 'ScopedChalet',
      type: 'chalet',
      amenities: ['privacy'],
    });
    const excluded = await seedSearchVenue({
      name: 'UnscopedHotel',
      type: 'hotel',
      amenities: ['privacy'],
    });
    const res = await search({ intent: 'high_privacy', limit: 50 });
    expect(res.status).toBe(201);
    const ids = res.body.items.map((item: { venueId: string }) => item.venueId);
    // FC95: no-category intent emits and enforces scopedVenueTypes.
    expect(res.body.applied.appliedConstraints.scopedVenueTypes).toEqual([
      'chalet',
      'villa',
      'rest_house',
      'resort',
    ]);
    expect(ids).toContain(allowed);
    expect(ids).not.toContain(excluded);
  });

  it('FC96 keeps a compatible explicit category unchanged', async () => {
    await seedSearchVenue({ name: 'ExplicitVilla', type: 'villa', amenities: ['privacy'] });
    const res = await search({ intent: 'high_privacy', category: 'villa' });
    expect(res.status).toBe(201);
    // FC96: compatible category remains the applied category, not an inferred replacement.
    expect(res.body.applied.category).toBe('villa');
    expect(res.body.applied.appliedConstraints.scopedVenueTypes).toBeUndefined();
  });

  it('FC97 unions explicit and intent amenities', async () => {
    const matching = await seedSearchVenue({
      name: 'AmenityUnion',
      type: 'hotel',
      amenities: ['family', 'wifi'],
      maxOccupancy: 8,
    });
    await seedSearchVenue({
      name: 'IntentAmenityOnly',
      type: 'hotel',
      amenities: ['family'],
      maxOccupancy: 8,
    });
    const res = await search({ intent: 'family', category: 'hotel', amenities: ['wifi'] });
    expect(res.status).toBe(201);
    // FC97: both explicit and expanded amenity predicates are required.
    expect(res.body.items.map((item: { venueId: string }) => item.venueId)).toEqual([matching]);
  });

  it('FC98 applies guestsMin when guests is absent', async () => {
    await seedSearchVenue({ name: 'FamilyCapacity', amenities: ['family'], maxOccupancy: 8 });
    const res = await search({ intent: 'family', category: 'hotel' });
    expect(res.status).toBe(201);
    // FC98: guestsMin expansion is visible in applied constraints and resolved guests.
    expect(res.body.applied.guests).toBe(4);
    expect(res.body.applied.appliedConstraints.guestsMin).toBe(4);
  });

  it('FC99 rejects explicit guests below guestsMin', async () => {
    const res = await search({ intent: 'family', category: 'hotel', guests: 2 });
    // FC99: conflicting explicit guests is rejected, never overwritten.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC100 preserves compatible explicit guests', async () => {
    await seedSearchVenue({ name: 'LargeFamily', amenities: ['family'], maxOccupancy: 12 });
    const res = await search({ intent: 'family', category: 'hotel', guests: 8 });
    expect(res.status).toBe(201);
    // FC100: an explicit value above guestsMin remains 8.
    expect(res.body.applied.guests).toBe(8);
    expect(res.body.applied.appliedConstraints.guestsExplicit).toBe(8);
  });

  it('FC101 rejects explicit guests above guestsMax', async () => {
    await insertIntent({
      code: 'fc101_guests_max',
      types: ['*'],
      expansion: { guestsMax: 2 },
    });
    const res = await search({ intent: 'fc101_guests_max', guests: 3 });
    // FC101: guestsMax conflict is rejected without silent mutation.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC102 applies starsMin when absent', async () => {
    await insertIntent({
      code: 'fc102_stars',
      types: ['hotel'],
      expansion: { starsMin: 4 },
    });
    const matching = await seedSearchVenue({ name: 'FourStars', stars: 4 });
    await seedSearchVenue({ name: 'ThreeStars', stars: 3 });
    const res = await search({ intent: 'fc102_stars', category: 'hotel' });
    expect(res.status).toBe(201);
    // FC102: starsMin expansion reaches the real discovery predicate.
    expect(res.body.items.map((item: { venueId: string }) => item.venueId)).toEqual([matching]);
  });

  it('FC103 rejects explicit starsMin below the intent minimum', async () => {
    await insertIntent({
      code: 'fc103_stars_conflict',
      types: ['hotel'],
      expansion: { starsMin: 4 },
    });
    const res = await search({ intent: 'fc103_stars_conflict', category: 'hotel', starsMin: 3 });
    // FC103: weaker explicit starsMin conflicts instead of being overwritten.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC104 rejects an unimplemented intent expansion', async () => {
    await insertIntent({
      code: 'fc104_deferred',
      types: ['*'],
      expansion: { nightsMin: 7 },
    });
    const res = await search({ intent: 'fc104_deferred' });
    // FC104: deferred expansion keys cannot produce fake behavior.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC105 emits a cursor only when LIMIT+1 proves another row', async () => {
    for (let index = 0; index < 3; index++) {
      await seedSearchVenue({ name: `HasMore-${index}`, price: 100 + index });
    }
    const res = await search({ category: 'hotel', sort: 'cheapest', limit: 2 });
    expect(res.status).toBe(201);
    // FC105: a third fetched row yields nextCursor while only two items are returned.
    expect(res.body.items).toHaveLength(2);
    expect(res.body.nextCursor).toBeTruthy();
  });

  it('FC106 returns null cursor when exactly limit rows exist', async () => {
    await seedSearchVenue({ name: 'ExactLimit-1', price: 100 });
    await seedSearchVenue({ name: 'ExactLimit-2', price: 200 });
    const res = await search({ category: 'hotel', sort: 'cheapest', limit: 2 });
    expect(res.status).toBe(201);
    // FC106: page fullness alone does not imply hasMore.
    expect(res.body.nextCursor).toBeNull();
  });

  it('FC107 returns null cursor for a short final page', async () => {
    await seedSearchVenue({ name: 'ShortPage', price: 100 });
    const res = await search({ category: 'hotel', sort: 'cheapest', limit: 2 });
    expect(res.status).toBe(201);
    // FC107: a short page is terminal.
    expect(res.body.items).toHaveLength(1);
    expect(res.body.nextCursor).toBeNull();
  });

  it('FC108 keeps total stable across cursor pages', async () => {
    for (let index = 0; index < 4; index++) {
      await seedSearchVenue({ name: `StableTotal-${index}`, price: 100 + index });
    }
    const first = await search({ category: 'hotel', sort: 'cheapest', limit: 2 });
    expect(first.status).toBe(201);
    const second = await search({
      category: 'hotel',
      sort: 'cheapest',
      limit: 2,
      cursor: first.body.nextCursor,
    });
    expect(second.status).toBe(201);
    // FC108: COUNT is independent of page cursor.
    expect(second.body.total).toBe(first.body.total);
  });

  it('FC109 keyset pages do not duplicate rows', async () => {
    for (let index = 0; index < 4; index++) {
      await seedSearchVenue({ name: `NoDuplicate-${index}`, price: 100 + index });
    }
    const first = await search({ category: 'hotel', sort: 'cheapest', limit: 2 });
    const second = await search({
      category: 'hotel',
      sort: 'cheapest',
      limit: 2,
      cursor: first.body.nextCursor,
    });
    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    const ids = [...first.body.items, ...second.body.items].map(
      (item: { venueId: string }) => item.venueId,
    );
    // FC109: strict cursor comparison prevents duplicate venue IDs.
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('FC110 cheapest ties use venue id as deterministic tiebreaker', async () => {
    const ids = [
      await seedSearchVenue({ name: 'CheapTie-1', price: 250 }),
      await seedSearchVenue({ name: 'CheapTie-2', price: 250 }),
      await seedSearchVenue({ name: 'CheapTie-3', price: 250 }),
    ];
    const res = await search({ category: 'hotel', sort: 'cheapest', limit: 10 });
    expect(res.status).toBe(201);
    // FC110: equal ascending prices are ordered by ascending venue UUID.
    expect(res.body.items.map((item: { venueId: string }) => item.venueId)).toEqual(ids.sort());
  });

  it('FC111 most_expensive cursor traverses descending prices', async () => {
    for (const price of [100, 300, 200]) {
      await seedSearchVenue({ name: `Expensive-${price}`, price });
    }
    const first = await search({ category: 'hotel', sort: 'most_expensive', limit: 2 });
    expect(first.status).toBe(201);
    const second = await search({
      category: 'hotel',
      sort: 'most_expensive',
      limit: 2,
      cursor: first.body.nextCursor,
    });
    expect(second.status).toBe(201);
    // FC111: descending keyset preserves the complete price order.
    expect([...first.body.items, ...second.body.items].map((item) => item.startingPriceHint)).toEqual([
      300, 200, 100,
    ]);
  });

  it('FC112 newest cursor traverses descending timestamps', async () => {
    for (let day = 1; day <= 3; day++) {
      await seedSearchVenue({
        name: `Newest-${day}`,
        createdAt: `2035-02-0${day}T00:00:00.000Z`,
      });
    }
    const first = await search({ category: 'hotel', sort: 'newest', limit: 2 });
    const second = await search({
      category: 'hotel',
      sort: 'newest',
      limit: 2,
      cursor: first.body.nextCursor,
    });
    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    // FC112: newest keyset reaches all rows once across the timestamp boundary.
    expect(
      new Set(
        [...first.body.items, ...second.body.items].map((item: { venueId: string }) => item.venueId),
      ).size,
    ).toBe(3);
  });

  it('FC113 rating and best include reviews_count as secondary key', async () => {
    const lowReviews = await seedSearchVenue({
      name: 'RatingLowReviews',
      weighted: 4.5,
      reviews: 2,
    });
    const highReviews = await seedSearchVenue({
      name: 'RatingHighReviews',
      weighted: 4.5,
      reviews: 20,
    });
    for (const sort of ['rating', 'best']) {
      const res = await search({ category: 'hotel', sort, limit: 10 });
      expect(res.status).toBe(201);
      // FC113: equal weighted_rating orders by reviews_count descending for both aliases.
      expect(res.body.items.map((item: { venueId: string }) => item.venueId)).toEqual([
        highReviews,
        lowReviews,
      ]);
    }
  });

  it('FC114 rejects malformed and sort-mismatched cursors', async () => {
    await seedSearchVenue({ name: 'CursorSource', price: 100 });
    await seedSearchVenue({ name: 'CursorMore', price: 200 });
    const first = await search({ category: 'hotel', sort: 'cheapest', limit: 1 });
    expect(first.status).toBe(201);
    expect(first.body.nextCursor).toBeTruthy();
    const malformed = await search({ category: 'hotel', sort: 'cheapest', cursor: 'not-json' });
    const mismatch = await search({
      category: 'hotel',
      sort: 'newest',
      cursor: first.body.nextCursor,
    });
    // FC114: cursor integrity includes shape and originating sort.
    expect(malformed.status).toBeGreaterThanOrEqual(400);
    expect(mismatch.status).toBeGreaterThanOrEqual(400);
  });
});
