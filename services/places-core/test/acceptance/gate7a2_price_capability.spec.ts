import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { newId } from '../../src/shared/ids/ids';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue, SeededVenue } from '../helpers/seed';

describe('Gate 7A.2 — Price Option A and capability policy FC54–FC70', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-fc7a2-price';

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

  async function seedPricedVenue(options: {
    name: string;
    venueType?: string;
    types?: { name: string; qty: number; base: number; maxOccupancy?: number }[];
    media?: { hint: number | null; moderation?: 'approved' | 'pending'; kind?: 'video' | 'image' }[];
  }): Promise<SeededVenue> {
    const providerId = await seedProvider(pool, `price-${options.name}-${newId()}`, options.name);
    const venue = await seedVenue(pool, providerId, {
      name: options.name,
      venueType: options.venueType ?? 'hotel',
      types: (options.types ?? [{ name: 'standard', qty: 4, base: 300 }]).map((type) => ({
        name: type.name,
        qty: type.qty,
        nights: { '2033-01-01': String(type.base) },
      })),
    });
    for (const type of options.types ?? []) {
      if (type.maxOccupancy != null) {
        await pool.query('UPDATE inventory_types SET max_occupancy=$2, base_occupancy=LEAST(base_occupancy,$2) WHERE id=$1', [
          venue.types[type.name],
          type.maxOccupancy,
        ]);
      }
    }
    for (const [index, media] of (options.media ?? []).entries()) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
         VALUES ($1,$2,$3,$4,$5,'https://example.test/cover.jpg',$6,$7,$8,$9)`,
        [
          newId(),
          venue.venueId,
          providerId,
          media.kind ?? 'video',
          `https://example.test/${options.name}-${index}.mp4`,
          media.moderation ?? 'approved',
          index,
          options.venueType ?? 'hotel',
          media.hint,
        ],
      );
    }
    return venue;
  }

  async function blockNight(inventoryTypeId: string, date: string, capacity: number): Promise<void> {
    await pool.query(
      `INSERT INTO inventory_daily_capacity
         (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,$3,$4,0,$4,0)`,
      [newId(), inventoryTypeId, date, capacity],
    );
  }

  it('FC54–FC56 returns MIN base rate from the same dated-eligible inventory set', async () => {
    const venue = await seedPricedVenue({
      name: 'OptionA',
      types: [
        { name: 'cheap-blocked', qty: 1, base: 100 },
        { name: 'eligible-mid', qty: 3, base: 250 },
        { name: 'eligible-high', qty: 3, base: 400 },
      ],
      media: [{ hint: 50 }],
    });
    await blockNight(venue.types['cheap-blocked'], '2033-02-01', 1);
    const res = await search({
      category: 'hotel',
      checkIn: '2033-02-01',
      checkOut: '2033-02-02',
      quantity: 1,
    });
    expect(res.status).toBe(201);
    const item = res.body.items.find((candidate: { venueId: string }) => candidate.venueId === venue.venueId);
    expect(item).toBeDefined();
    // FC54: dated responses identify Option A semantics.
    expect(res.body.applied.priceSemantics).toBe('AVAILABILITY_FILTERED_INDICATIVE_PRICE');
    // FC55: the projection uses MIN(base rate_rules) among eligible inventory types.
    expect(item.startingPriceHint).toBe(250);
    // FC56: a cheaper unavailable type cannot leak into the displayed price.
    expect(item.startingPriceHint).not.toBe(100);
  });

  it('FC57–FC60 applies occupancy, quantity, status, and every night to price eligibility', async () => {
    const venue = await seedPricedVenue({
      name: 'EligibilityDimensions',
      types: [
        { name: 'low-occupancy', qty: 5, base: 90, maxOccupancy: 1 },
        { name: 'low-quantity', qty: 1, base: 110, maxOccupancy: 8 },
        { name: 'inactive', qty: 5, base: 130, maxOccupancy: 8 },
        { name: 'second-night-blocked', qty: 5, base: 150, maxOccupancy: 8 },
        { name: 'eligible', qty: 5, base: 300, maxOccupancy: 8 },
      ],
    });
    await pool.query("UPDATE inventory_types SET status='inactive' WHERE id=$1", [venue.types.inactive]);
    await blockNight(venue.types['second-night-blocked'], '2033-03-02', 5);
    const res = await search({
      category: 'hotel',
      checkIn: '2033-03-01',
      checkOut: '2033-03-03',
      guests: 8,
      quantity: 2,
    });
    expect(res.status).toBe(201);
    const item = res.body.items.find((candidate: { venueId: string }) => candidate.venueId === venue.venueId);
    expect(item).toBeDefined();
    // FC57: insufficient max_occupancy excludes the 90 rate.
    expect(item.startingPriceHint).not.toBe(90);
    // FC58: insufficient quantity_total excludes the 110 rate.
    expect(item.startingPriceHint).not.toBe(110);
    // FC59: inactive inventory excludes the 130 rate.
    expect(item.startingPriceHint).not.toBe(130);
    // FC60: failure on any requested night excludes the 150 rate.
    expect(item.startingPriceHint).toBe(300);
  });

  it('FC61–FC62 dated price filters use the projected Option A expression', async () => {
    const venue = await seedPricedVenue({
      name: 'DatedFilter',
      types: [{ name: 'eligible', qty: 3, base: 275 }],
      media: [{ hint: 25 }],
    });
    const common = {
      category: 'hotel',
      checkIn: '2033-04-01',
      checkOut: '2033-04-02',
    };
    const minimum = await search({ ...common, minPrice: 200 });
    expect(minimum.status).toBe(201);
    // FC61: minPrice compares the availability-filtered base rate, not media hint.
    expect(minimum.body.items.some((item: { venueId: string }) => item.venueId === venue.venueId)).toBe(
      true,
    );
    const maximum = await search({ ...common, maxPrice: 200 });
    expect(maximum.status).toBe(201);
    // FC62: maxPrice uses that same displayed expression.
    expect(maximum.body.items.some((item: { venueId: string }) => item.venueId === venue.venueId)).toBe(
      false,
    );
  });

  it('FC63–FC65 without dates uses approved-media indicative starting price', async () => {
    const venue = await seedPricedVenue({
      name: 'MediaHint',
      types: [{ name: 'base', qty: 2, base: 900 }],
      media: [
        { hint: 80, moderation: 'pending' },
        { hint: 240, moderation: 'approved' },
        { hint: 180, moderation: 'approved', kind: 'image' },
      ],
    });
    const noMedia = await seedPricedVenue({ name: 'NoMedia' });
    const res = await search({ category: 'hotel', limit: 50 });
    expect(res.status).toBe(201);
    // FC63: undated responses advertise indicative starting-price semantics.
    expect(res.body.applied.priceSemantics).toBe('INDICATIVE_STARTING_PRICE');
    const priced = res.body.items.find((item: { venueId: string }) => item.venueId === venue.venueId);
    expect(priced).toBeDefined();
    // FC64: only approved media participate and MIN approved hint is selected.
    expect(priced.startingPriceHint).toBe(180);
    const absent = res.body.items.find((item: { venueId: string }) => item.venueId === noMedia.venueId);
    expect(absent).toBeDefined();
    // FC65: no approved media hint is represented honestly as null.
    expect(absent.startingPriceHint).toBeNull();
  });

  it('FC66 undated price filtering uses approved media rather than base rates', async () => {
    const venue = await seedPricedVenue({
      name: 'UndatedFilter',
      types: [{ name: 'base', qty: 2, base: 50 }],
      media: [{ hint: 600, moderation: 'approved' }],
    });
    const res = await search({ category: 'hotel', maxPrice: 100 });
    expect(res.status).toBe(201);
    // FC66: the cheap inventory base does not satisfy an undated media-hint filter.
    expect(res.body.items.some((item: { venueId: string }) => item.venueId === venue.venueId)).toBe(
      false,
    );
  });

  it('FC67 rejects an explicitly disabled discovery category', async () => {
    await pool.query(
      "UPDATE venue_type_capabilities SET enabled_for_discovery=FALSE WHERE venue_type='hotel'",
    );
    const res = await search({ category: 'hotel' });
    // FC67: explicit category capability policy rejects rather than returning candidates.
    expect(res.status).toBeGreaterThanOrEqual(400);
    await pool.query(
      "UPDATE venue_type_capabilities SET enabled_for_discovery=TRUE WHERE venue_type='hotel'",
    );
  });

  it('FC68–FC69 fails closed when a venue type capability row is missing', async () => {
    const venue = await seedPricedVenue({
      name: 'MissingCapability',
      venueType: 'unregistered_type',
      media: [{ hint: 100 }],
    });
    const explicit = await search({ category: 'unregistered_type' });
    // FC68: an explicit unknown capability row is rejected.
    expect(explicit.status).toBeGreaterThanOrEqual(400);
    const unscoped = await search({ limit: 50 });
    expect(unscoped.status).toBe(201);
    // FC69: unscoped discovery also hides missing-capability venues via EXISTS.
    expect(unscoped.body.items.some((item: { venueId: string }) => item.venueId === venue.venueId)).toBe(
      false,
    );
  });

  it('FC70 fails closed at booking entry when capability is missing', async () => {
    const venue = await seedPricedVenue({
      name: 'MissingBookingCapability',
      venueType: 'unregistered_booking_type',
    });
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumer))
      .send({
        venueId: venue.venueId,
        inventoryTypeId: venue.types.standard,
        checkIn: '2033-05-01',
        checkOut: '2033-05-02',
        quantity: 1,
        guestsAdults: 1,
        guestsChildren: 0,
        extraIds: [],
      });
    // FC70: absent booking capability never inherits an allow default.
    expect(quote.status).toBeGreaterThanOrEqual(400);
  });
});
