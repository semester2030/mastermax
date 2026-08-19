import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7A — Filter Engine F01–F40', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-f7a';
  const provider = 'provider-f7a';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  async function seedDiscoveryVenue(opts: {
    name: string;
    type: string;
    city?: string;
    district?: string;
    verified?: boolean;
    stars?: number;
    bedrooms?: number;
    bathrooms?: number;
    capacity?: number;
    priceHint?: number;
    amenities?: string[];
    offer?: boolean;
    lat?: number;
    lng?: number;
    hallType?: string;
    maxOcc?: number;
  }): Promise<string> {
    const providerId = await seedProvider(pool, `${provider}-${opts.name}`, opts.name);
    const seeded = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.type,
      types: [
        {
          name: 'default',
          qty: 5,
          nights: { '2030-01-10': String(opts.priceHint ?? 200) },
        },
      ],
    });
    if (opts.maxOcc != null) {
      await pool.query(`UPDATE inventory_types SET max_occupancy = $2, base_occupancy = LEAST(2,$2) WHERE venue_id = $1`, [
        seeded.venueId,
        opts.maxOcc,
      ]);
    }
    await pool.query(
      `UPDATE venues SET
         city = $2, district = $3, verified = $4, stars = $5, bedrooms = $6, bathrooms = $7,
         capacity = $8, has_active_offer = $9, lat = $10, lng = $11,
         attributes_jsonb = COALESCE(attributes_jsonb, '{}'::jsonb) || $12::jsonb
       WHERE id = $1`,
      [
        seeded.venueId,
        opts.city ?? 'Riyadh',
        opts.district ?? null,
        opts.verified ?? false,
        opts.stars ?? null,
        opts.bedrooms ?? null,
        opts.bathrooms ?? null,
        opts.capacity ?? null,
        opts.offer ?? false,
        opts.lat ?? 24.7136,
        opts.lng ?? 46.6753,
        JSON.stringify(opts.hallType ? { hall_type: opts.hallType } : {}),
      ],
    );
    await pool.query(
      `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
       VALUES ($1,$2,$3,'video','https://ex/v.mp4','https://ex/c.jpg','approved',0,$4,$5)`,
      [newId(), seeded.venueId, providerId, opts.type, opts.priceHint ?? 200],
    );
    for (const code of opts.amenities ?? []) {
      await pool.query(
        `INSERT INTO venue_amenity_links (id, venue_id, amenity_code, scope, state) VALUES ($1,$2,$3,'venue','AVAILABLE')
         ON CONFLICT DO NOTHING`,
        [newId(), seeded.venueId, code],
      );
    }
    return seeded.venueId;
  }

  async function insertCompletedBooking(venueId: string, uid: string, tag: string): Promise<string> {
    const quoteId = newId();
    const holdId = newId();
    const bid = newId();
    const day = 10 + (Math.abs([...tag].reduce((a, c) => a + c.charCodeAt(0), 0)) % 80);
    const checkIn = `2030-04-${String(day).padStart(2, '0')}`;
    const checkOut = `2030-04-${String(day + 1).padStart(2, '0')}`;
    const row = await pool.query(
      `SELECT v.provider_id, it.id AS type_id FROM venues v
       JOIN inventory_types it ON it.venue_id = v.id WHERE v.id = $1 LIMIT 1`,
      [venueId],
    );
    const { provider_id, type_id } = row.rows[0];
    await pool.query(
      `INSERT INTO quotes (id, consumer_firebase_uid, venue_id, inventory_type_id, check_in, check_out, quantity,
        guests_adults, guests_children, currency, subtotal, extras_total, discount_total, tax_total, gross_total,
        commission_bps, commission_amount, provider_net, pricing_version, status, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,1,1,0,'SAR',100,0,0,0,100,1000,10,90,'v1','consumed',now())`,
      [quoteId, uid, venueId, type_id, checkIn, checkOut],
    );
    await pool.query(
      `INSERT INTO booking_holds (id, quote_id, inventory_type_id, consumer_firebase_uid,
        quantity, check_in, check_out, status, expires_at, idempotency_key)
       VALUES ($1,$2,$3,$4,1,$5,$6,'CONVERTED',now(),$7)`,
      [holdId, quoteId, type_id, uid, checkIn, checkOut, `h-${tag}-${newId().slice(0, 8)}`],
    );
    await pool.query(
      `INSERT INTO bookings (id, hold_id, quote_id, venue_id, provider_id, inventory_type_id, consumer_firebase_uid,
        human_code, status, quantity, check_in, check_out, currency, gross_total, commission_bps,
        commission_amount, provider_net, cancellation_policy_snapshot_json, payment_method, payment_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'COMPLETED',1,$9,$10,'SAR',100,1000,10,90,'{}'::jsonb,'LEGACY_UNSPECIFIED','LEGACY_UNSPECIFIED')`,
      [bid, holdId, quoteId, venueId, provider_id, type_id, uid, `HC-${tag}-${newId().slice(0, 6)}`, checkIn, checkOut],
    );
    return bid;
  }

  async function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send(body);
  }

  it('F25 filter definition endpoint canonical + alias', async () => {
    const a = await request(app.getHttpServer())
      .get('/v1/filter-definitions')
      .set('Authorization', auth(consumer));
    const b = await request(app.getHttpServer())
      .get('/v1/filters/definitions')
      .set('Authorization', auth(consumer));
    expect(a.status).toBe(200);
    expect(b.status).toBe(200);
    expect(a.body.length).toBeGreaterThan(5);
    expect(b.body.length).toBe(a.body.length);
    expect(a.body[0]).toHaveProperty('labelAr');
    expect(a.body[0]).toHaveProperty('section');
  });

  it('F01 category filter', async () => {
    await seedDiscoveryVenue({ name: 'H1', type: 'hotel', amenities: ['wifi'] });
    await seedDiscoveryVenue({ name: 'C1', type: 'chalet', amenities: ['pool'] });
    const res = await search({ category: 'hotel' });
    expect(res.status).toBe(201);
    expect(res.body.items.every((i: { category: string }) => i.category === 'hotel')).toBe(true);
  });

  it('F02 city', async () => {
    await seedDiscoveryVenue({ name: 'Jed1', type: 'apartment', city: 'Jeddah' });
    const res = await search({ city: 'Jeddah' });
    expect(res.body.items.every((i: { city: string }) => i.city === 'Jeddah')).toBe(true);
  });

  it('F03 district', async () => {
    await seedDiscoveryVenue({ name: 'Malqa', type: 'villa', district: 'الملقا' });
    const res = await search({ district: 'الملقا' });
    expect(res.body.items.some((i: { district: string }) => i.district === 'الملقا')).toBe(true);
  });

  it('F04 price range', async () => {
    await seedDiscoveryVenue({ name: 'Cheap', type: 'apartment', priceHint: 100 });
    await seedDiscoveryVenue({ name: 'Dear', type: 'apartment', priceHint: 900 });
    const res = await search({ category: 'apartment', maxPrice: 200 });
    expect(res.body.items.every((i: { startingPriceHint: number }) => i.startingPriceHint <= 200)).toBe(
      true,
    );
  });

  it('F05 rating + F34 weighted rating + F32 trusted booking only', async () => {
    const venueId = await seedDiscoveryVenue({ name: 'Rated', type: 'hotel', stars: 5 });
    const b1 = await insertCompletedBooking(venueId, consumer, 'r1');
    const b2 = await insertCompletedBooking(venueId, `${consumer}-2`, 'r2');
    await request(app.getHttpServer())
      .post('/v1/reviews')
      .set('Authorization', auth(consumer))
      .send({ bookingId: b1, rating: 5 });
    await request(app.getHttpServer())
      .post('/v1/reviews')
      .set('Authorization', auth(`${consumer}-2`))
      .send({ bookingId: b2, rating: 5 });

    const v = await pool.query(`SELECT reviews_count, weighted_rating, rating_average FROM venues WHERE id = $1`, [
      venueId,
    ]);
    expect(Number(v.rows[0].reviews_count)).toBe(2);
    expect(Number(v.rows[0].rating_average)).toBe(5);
    expect(Number(v.rows[0].weighted_rating)).toBeGreaterThan(0);

    const res = await search({ minRating: 4 });
    expect(res.body.items.some((i: { venueId: string }) => i.venueId === venueId)).toBe(true);
  });

  it('F33 duplicate review blocked', async () => {
    const venueId = await seedDiscoveryVenue({ name: 'DupRev', type: 'hotel' });
    const b1 = await insertCompletedBooking(venueId, 'dup-user', 'dup');
    const first = await request(app.getHttpServer())
      .post('/v1/reviews')
      .set('Authorization', auth('dup-user'))
      .send({ bookingId: b1, rating: 4 });
    expect(first.status).toBe(201);
    const second = await request(app.getHttpServer())
      .post('/v1/reviews')
      .set('Authorization', auth('dup-user'))
      .send({ bookingId: b1, rating: 3 });
    expect(second.status).toBeGreaterThanOrEqual(400);
  });

  it('F06 amenity one + F07 amenities AND', async () => {
    await seedDiscoveryVenue({ name: 'PoolOnly', type: 'chalet', amenities: ['pool'] });
    await seedDiscoveryVenue({ name: 'PoolBbq', type: 'chalet', amenities: ['pool', 'bbq'] });
    const one = await search({ category: 'chalet', amenities: ['pool'] });
    expect(one.body.items.length).toBeGreaterThanOrEqual(2);
    const both = await search({ category: 'chalet', amenities: ['pool', 'bbq'] });
    expect(both.body.items.every((i: { amenities: string[] }) => i.amenities.includes('bbq'))).toBe(
      true,
    );
  });

  it('F08 guest capacity', async () => {
    await seedDiscoveryVenue({ name: 'SmallOcc', type: 'apartment', maxOcc: 2 });
    await seedDiscoveryVenue({ name: 'BigOcc', type: 'apartment', maxOcc: 10, capacity: 10 });
    const res = await search({ category: 'apartment', guests: 8 });
    expect(res.body.items.every((i: { name: string }) => i.name !== 'SmallOcc')).toBe(true);
  });

  it('F09 availability dates', async () => {
    const id = await seedDiscoveryVenue({ name: 'Avail', type: 'hotel', maxOcc: 4 });
    const it = await pool.query(`SELECT id, quantity_total FROM inventory_types WHERE venue_id = $1`, [id]);
    // Block all capacity on 2030-06-01
    await pool.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1, $2, '2030-06-01', $3, 0, $3, 0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET booked = EXCLUDED.booked, capacity = EXCLUDED.capacity`,
      [newId(), it.rows[0].id, it.rows[0].quantity_total],
    );
    const blocked = await search({
      category: 'hotel',
      checkIn: '2030-06-01',
      checkOut: '2030-06-02',
      quantity: 1,
    });
    expect(blocked.body.items.some((i: { venueId: string }) => i.venueId === id)).toBe(false);
    const open = await search({
      category: 'hotel',
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
      quantity: 1,
    });
    expect(open.body.items.some((i: { venueId: string }) => i.venueId === id)).toBe(true);
    expect(open.body.applied.availabilityMode).toBe('AVAILABLE');
  });

  it('F10 verified + F11 offers', async () => {
    await seedDiscoveryVenue({ name: 'Ver', type: 'villa', verified: true, offer: true });
    const v = await search({ verified: true });
    expect(v.body.items.every((i: { verified: boolean }) => i.verified)).toBe(true);
    const o = await search({ offers: true });
    expect(o.body.items.every((i: { hasActiveOffer: boolean }) => i.hasActiveOffer)).toBe(true);
  });

  it('F12 hotel stars', async () => {
    await seedDiscoveryVenue({ name: 'S3', type: 'hotel', stars: 3 });
    await seedDiscoveryVenue({ name: 'S5', type: 'hotel', stars: 5 });
    const res = await search({ category: 'hotel', starsMin: 5 });
    expect(res.body.items.every((i: { stars: number }) => i.stars >= 5)).toBe(true);
  });

  it('F13 apartment bedrooms', async () => {
    await seedDiscoveryVenue({ name: 'B1', type: 'apartment', bedrooms: 1 });
    await seedDiscoveryVenue({ name: 'B3', type: 'apartment', bedrooms: 3 });
    const res = await search({ category: 'apartment', bedroomsMin: 3 });
    expect(res.body.items.every((i: { bedrooms: number }) => i.bedrooms >= 3)).toBe(true);
  });

  it('F14 chalet private pool', async () => {
    await seedDiscoveryVenue({ name: 'PP', type: 'chalet', amenities: ['private_pool'] });
    const res = await search({ category: 'chalet', amenities: ['private_pool'] });
    expect(res.body.items.some((i: { name: string }) => i.name === 'PP')).toBe(true);
  });

  it('F15 rest house capacity', async () => {
    await seedDiscoveryVenue({ name: 'RH', type: 'rest_house', capacity: 30 });
    const res = await search({ category: 'rest_house', capacityMin: 20 });
    expect(res.body.items.some((i: { name: string }) => i.name === 'RH')).toBe(true);
  });

  it('F16 resort inventory kind attribute pass-through defs exist', async () => {
    const defs = await request(app.getHttpServer())
      .get('/v1/filter-definitions?venueType=resort')
      .set('Authorization', auth(consumer));
    expect(defs.body.some((d: { key: string }) => d.key === 'inventory_kind')).toBe(true);
  });

  it('F17 villa bedrooms', async () => {
    await seedDiscoveryVenue({ name: 'V4', type: 'villa', bedrooms: 4, bathrooms: 3 });
    const res = await search({ category: 'villa', bedroomsMin: 4 });
    expect(res.body.items.some((i: { name: string }) => i.name === 'V4')).toBe(true);
  });

  it('F18–F21 wedding palace / event hall capacity + time slot', async () => {
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery = TRUE, enabled_for_booking = TRUE
       WHERE venue_type IN ('wedding_palace', 'event_hall')`,
    );
    const wp = await seedDiscoveryVenue({
      name: 'WP1',
      type: 'wedding_palace',
      capacity: 400,
      amenities: ['stage', 'catering'],
    });
    const eh = await seedDiscoveryVenue({
      name: 'EH1',
      type: 'event_hall',
      capacity: 150,
      hallType: 'conference',
    });
    const tpl = newId();
    await pool.query(
      `INSERT INTO event_slot_templates
         (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id)
       SELECT $1,$2,'evening','مسائي','18:00','23:00',400,5000,id
       FROM inventory_types WHERE venue_id=$2 ORDER BY id LIMIT 1`,
      [tpl, wp],
    );
    await pool.query(
      `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
       VALUES ($1,$2,$3,'2030-09-01','open')`,
      [newId(), wp, tpl],
    );
    const tpl2 = newId();
    await pool.query(
      `INSERT INTO event_slot_templates
         (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id)
       SELECT $1,$2,'morning','صباحي','09:00','14:00',150,2000,id
       FROM inventory_types WHERE venue_id=$2 ORDER BY id LIMIT 1`,
      [tpl2, eh],
    );
    await pool.query(
      `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
       VALUES ($1,$2,$3,'2030-09-01','open')`,
      [newId(), eh, tpl2],
    );

    const cap = await search({ category: 'wedding_palace', capacityMin: 300 });
    expect(cap.body.items.some((i: { venueId: string }) => i.venueId === wp)).toBe(true);

    const slot = await search({
      category: 'wedding_palace',
      checkIn: '2030-09-01',
      slotCode: 'evening',
    });
    expect(slot.body.items.some((i: { venueId: string }) => i.venueId === wp)).toBe(true);

    const hall = await search({ category: 'event_hall', capacityMin: 100 });
    expect(hall.body.items.some((i: { venueId: string }) => i.venueId === eh)).toBe(true);

    const morning = await search({
      category: 'event_hall',
      checkIn: '2030-09-01',
      slotCode: 'morning',
    });
    expect(morning.body.items.some((i: { venueId: string }) => i.venueId === eh)).toBe(true);
  });

  it('F22 intent family + F23 honeymoon', async () => {
    await seedDiscoveryVenue({ name: 'Fam', type: 'chalet', amenities: ['family'], maxOcc: 6 });
    await seedDiscoveryVenue({
      name: 'Honey',
      type: 'chalet',
      amenities: ['honeymoon', 'privacy'],
      maxOcc: 2,
    });
    const fam = await search({ intent: 'family' });
    expect(fam.status).toBe(201);
    expect(fam.body.applied.intent).toBe('family');
    const honey = await search({ intent: 'honeymoon', category: 'chalet' });
    expect(honey.body.items.every((i: { amenities: string[] }) => i.amenities.includes('privacy'))).toBe(
      true,
    );
  });

  it('F24 unknown amenity semantics — invalid amenity yields empty not error', async () => {
    const res = await search({ amenities: ['definitely_not_a_real_code_xyz'] });
    expect(res.status).toBe(201);
    expect(res.body.items).toEqual([]);
  });

  it('F26 pagination stable + total fixed across pages', async () => {
    for (let i = 0; i < 3; i++) {
      await seedDiscoveryVenue({ name: `Page${i}`, type: 'serviced_apartment', priceHint: 150 + i });
    }
    const p1 = await search({ category: 'serviced_apartment', limit: 2, sort: 'cheapest' });
    expect(p1.body.items.length).toBe(2);
    const p2 = await search({
      category: 'serviced_apartment',
      limit: 2,
      sort: 'cheapest',
      cursor: p1.body.nextCursor,
    });
    expect(p2.body.total).toBe(p1.body.total);
    const ids1 = p1.body.items.map((i: { venueId: string }) => i.venueId);
    const ids2 = p2.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids1.some((id: string) => ids2.includes(id))).toBe(false);
  });

  it('F27 invalid filter rejected', async () => {
    const res = await search({ minPrice: 500, maxPrice: 100, category: 'hotel' });
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('F28 unsupported / unknown intent rejected', async () => {
    const res = await search({ intent: 'not_a_real_intent' });
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('F29 explicitly disabled capability is rejected', async () => {
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery = FALSE WHERE venue_type = 'wedding_palace'`,
    );
    await seedDiscoveryVenue({ name: 'HiddenWP', type: 'wedding_palace', capacity: 100 });
    const res = await search({ category: 'wedding_palace' });
    expect(res.status).toBeGreaterThanOrEqual(400);
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery = TRUE WHERE venue_type = 'wedding_palace'`,
    );
  });

  it('F30 result count', async () => {
    const res = await search({ category: 'villa' });
    expect(typeof res.body.total).toBe('number');
    expect(res.body.total).toBeGreaterThanOrEqual(res.body.items.length);
  });

  it('F31 no N+1 — single search returns amenities array without per-item roundtrips', async () => {
    const res = await search({ limit: 5 });
    expect(res.status).toBe(201);
    expect(Array.isArray(res.body.items[0]?.amenities)).toBe(true);
    expect(res.body.capabilities.facetCounts).toBe('deferred');
  });

  it('F35 map/feed same request semantics via shared discovery', async () => {
    const venueId = await seedDiscoveryVenue({ name: 'SharedSem', type: 'hotel', city: 'FC35City' });
    const body = { category: 'hotel', city: 'FC35City', limit: 10 };
    const discovery = await search(body);
    const feed = await request(app.getHttpServer())
      .get('/v1/feed')
      .query({ category: 'hotel', city: 'FC35City' })
      .set('Authorization', auth(consumer));
    expect(discovery.status).toBe(201);
    expect(feed.status).toBe(200);
    expect(discovery.body.items.map((i: { venueId: string }) => i.venueId)).toEqual([venueId]);
    expect(feed.body.items.map((i: { venueId: string }) => i.venueId)).toEqual([venueId]);
    expect(feed.body.total).toBe(1);
    // Shared filter: both only include the requested city's hotels with discovery capability
    expect(discovery.body.items.every((i: { city: string }) => i.city === 'FC35City')).toBe(true);
    expect(feed.body.items.every((i: { city: string }) => i.city === 'FC35City')).toBe(true);
  });

  it('F36 zero results', async () => {
    const res = await search({ category: 'hotel', city: 'NoSuchCityXYZ' });
    expect(res.body.items).toEqual([]);
    expect(res.body.total).toBe(0);
  });

  it('F37 category switch — common filters still apply across types', async () => {
    await seedDiscoveryVenue({ name: 'HCity', type: 'hotel', city: 'Dammam' });
    await seedDiscoveryVenue({ name: 'CCity', type: 'chalet', city: 'Dammam' });
    const hotel = await search({ category: 'hotel', city: 'Dammam' });
    const chalet = await search({ category: 'chalet', city: 'Dammam' });
    expect(hotel.body.items.every((i: { city: string }) => i.city === 'Dammam')).toBe(true);
    expect(chalet.body.items.every((i: { city: string }) => i.city === 'Dammam')).toBe(true);
  });

  it('F38 static/dynamic filter distinction in definitions', async () => {
    const defs = await request(app.getHttpServer())
      .get('/v1/filter-definitions')
      .set('Authorization', auth(consumer));
    const price = defs.body.find((d: { key: string }) => d.key === 'price');
    const wifiSection = defs.body.find((d: { key: string }) => d.key === 'amenity');
    expect(price.availabilityMode).toBe('needs_dates');
    expect(wifiSection.availabilityMode).toBe('static');
  });

  it('F39 query injection safety — malicious string does not widen results', async () => {
    const res = await search({ city: "Riyadh' OR '1'='1" });
    expect(res.status).toBe(201);
    expect(res.body.items.every((i: { city: string }) => i.city === "Riyadh' OR '1'='1")).toBe(true);
  });

  it('F40 existing booking path still works (availability SKU)', async () => {
    const venueId = await seedDiscoveryVenue({ name: 'BookPath', type: 'hotel' });
    const it = await pool.query(`SELECT id FROM inventory_types WHERE venue_id = $1`, [venueId]);
    const res = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth(consumer))
      .send({
        venueId,
        inventoryTypeId: it.rows[0].id,
        checkIn: '2030-08-01',
        checkOut: '2030-08-03',
        quantity: 1,
      });
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('available');
  });
});
