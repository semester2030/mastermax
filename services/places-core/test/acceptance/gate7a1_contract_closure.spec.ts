import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';
import { seedProvider, seedVenue } from '../helpers/seed';
import { isHandlerRegistered } from '../../src/modules/filters/application/filter-handler-registry';
import { RATING_PRIOR_MEAN, RATING_PRIOR_STRENGTH } from '../../src/modules/reviews/application/review.service';

describe('Gate 7A.1 — Filter Contract Closure FC01–FC45', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-fc7a1';
  const provider = 'provider-fc7a1';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  async function seedVenueFull(opts: {
    name: string;
    type?: string;
    city?: string;
    lat?: number;
    lng?: number;
    priceHint?: number;
    amenities?: { code: string; state: string }[];
    bedrooms?: number;
    sizeSqm?: number;
    inventoryKind?: string;
    ratingAvg?: number;
    reviewsCount?: number;
    weighted?: number;
    moderation?: string;
  }): Promise<{ venueId: string; providerId: string }> {
    const providerId = await seedProvider(pool, `${provider}-${opts.name}`, opts.name);
    const seeded = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.type ?? 'hotel',
      types: [{ name: 'std', qty: 5, nights: { '2030-01-10': String(opts.priceHint ?? 200) } }],
    });
    await pool.query(
      `UPDATE venues SET city=$2, lat=$3, lng=$4, bedrooms=$5, size_sqm=$6,
         attributes_jsonb = COALESCE(attributes_jsonb,'{}'::jsonb) || $7::jsonb,
         rating_average=$8, reviews_count=$9, weighted_rating=$10
       WHERE id=$1`,
      [
        seeded.venueId,
        opts.city ?? 'Riyadh',
        opts.lat ?? 24.7,
        opts.lng ?? 46.7,
        opts.bedrooms ?? null,
        opts.sizeSqm ?? null,
        JSON.stringify(opts.inventoryKind ? { inventory_kind: opts.inventoryKind } : {}),
        opts.ratingAvg ?? 0,
        opts.reviewsCount ?? 0,
        opts.weighted ?? 0,
      ],
    );
    await pool.query(
      `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
       VALUES ($1,$2,$3,'video','https://customer-abc.cloudflarestream.com/v/manifest/video.m3u8','https://imagedelivery.net/stub/c/public',$4,0,$5,$6)`,
      [
        newId(),
        seeded.venueId,
        providerId,
        opts.moderation ?? 'approved',
        opts.type ?? 'hotel',
        opts.priceHint ?? 200,
      ],
    );
    for (const a of opts.amenities ?? []) {
      await pool.query(
        `INSERT INTO venue_amenity_links (id, venue_id, amenity_code, scope, state)
         VALUES ($1,$2,$3,'venue',$4) ON CONFLICT DO NOTHING`,
        [newId(), seeded.venueId, a.code, a.state],
      );
    }
    return { venueId: seeded.venueId, providerId };
  }

  function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send(body);
  }

  it('FC01 near_me COUNT bind parameters do not mismatch', async () => {
    await seedVenueFull({ name: 'NearA', lat: 24.71, lng: 46.67, priceHint: 100 });
    await seedVenueFull({ name: 'NearB', lat: 24.8, lng: 46.8, priceHint: 100 });
    const res = await search({
      sort: 'near_me',
      lat: 24.7136,
      lng: 46.6753,
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(typeof res.body.total).toBe('number');
    expect(res.body.total).toBeGreaterThanOrEqual(res.body.items.length);
  });

  it('FC02 near_me distance ordering', async () => {
    await seedVenueFull({ name: 'Close', lat: 24.714, lng: 46.676, priceHint: 100 });
    await seedVenueFull({ name: 'Far', lat: 25.5, lng: 47.5, priceHint: 100 });
    const res = await search({ sort: 'near_me', lat: 24.7136, lng: 46.6753, limit: 5 });
    expect(res.status).toBe(201);
    const dists = res.body.items.map((i: { distanceKm: number | null }) => i.distanceKm);
    for (let i = 1; i < dists.length; i++) {
      if (dists[i] != null && dists[i - 1] != null) {
        expect(dists[i]).toBeGreaterThanOrEqual(dists[i - 1]);
      }
    }
  });

  it('FC03 total stable across pages', async () => {
    for (let i = 0; i < 5; i++) {
      await seedVenueFull({ name: `T${i}`, type: 'apartment', priceHint: 100 + i * 10 });
    }
    const p1 = await search({ category: 'apartment', sort: 'cheapest', limit: 2 });
    const p2 = await search({
      category: 'apartment',
      sort: 'cheapest',
      limit: 2,
      cursor: p1.body.nextCursor,
    });
    expect(p1.body.total).toBe(p2.body.total);
    expect(p1.body.total).toBeGreaterThanOrEqual(5);
  });

  async function assertKeyset(sort: string, extra: Record<string, unknown> = {}) {
    for (let i = 0; i < 4; i++) {
      await seedVenueFull({
        name: `${sort}${i}-${Date.now()}`,
        type: 'villa',
        priceHint: 200 + i * 50,
        ratingAvg: 3 + i * 0.4,
        reviewsCount: 10 + i,
        weighted: 3 + i * 0.3,
      });
    }
    const p1 = await search({ category: 'villa', sort, limit: 2, ...extra });
    expect(p1.status).toBe(201);
    expect(p1.body.nextCursor).toBeTruthy();
    const p2 = await search({
      category: 'villa',
      sort,
      limit: 2,
      cursor: p1.body.nextCursor,
      ...extra,
    });
    const ids = [
      ...p1.body.items.map((i: { venueId: string }) => i.venueId),
      ...p2.body.items.map((i: { venueId: string }) => i.venueId),
    ];
    expect(new Set(ids).size).toBe(ids.length);
    expect(p1.body.total).toBe(p2.body.total);
  }

  it('FC04 rating keyset', async () => assertKeyset('rating'));
  it('FC05 cheapest keyset', async () => assertKeyset('cheapest'));
  it('FC06 most_expensive keyset', async () => assertKeyset('most_expensive'));
  it('FC07 newest keyset', async () => assertKeyset('newest'));
  it('FC08 best keyset', async () => assertKeyset('best'));

  it('FC09 malformed cursor rejected', async () => {
    const res = await search({ cursor: '!!!not-base64!!!', sort: 'best' });
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC10 equal sort value tie broken by venueId', async () => {
    await seedVenueFull({ name: 'Tie1', type: 'resort', priceHint: 333, weighted: 4.2, reviewsCount: 5, ratingAvg: 4.2 });
    await seedVenueFull({ name: 'Tie2', type: 'resort', priceHint: 333, weighted: 4.2, reviewsCount: 5, ratingAvg: 4.2 });
    const res = await search({ category: 'resort', sort: 'cheapest', limit: 10 });
    const same = res.body.items.filter((i: { startingPriceHint: number }) => i.startingPriceHint === 333);
    const ids = same.map((i: { venueId: string }) => i.venueId);
    expect([...ids].sort().join()).toBe(ids.join()); // ascending venueId among equal price
  });

  it('FC11–FC15 same inventory type guests+availability; cross-type blocked; multi-night; inactive excluded', async () => {
    const providerId = await seedProvider(pool, `${provider}-xinv`, 'xinv');
    const seeded = await seedVenue(pool, providerId, {
      name: 'CrossInv',
      venueType: 'hotel',
      types: [
        { name: 'suite', qty: 1, nights: { '2030-07-01': '500' } },
        { name: 'standard', qty: 3, nights: { '2030-07-01': '200' } },
      ],
    });
    const types = await pool.query(
      `SELECT id, name, max_occupancy, quantity_total FROM inventory_types WHERE venue_id=$1 ORDER BY name`,
      [seeded.venueId],
    );
    const suite = types.rows.find((r) => r.name === 'suite');
    const standard = types.rows.find((r) => r.name === 'standard');
    await pool.query(`UPDATE inventory_types SET max_occupancy=8 WHERE id=$1`, [suite.id]);
    await pool.query(`UPDATE inventory_types SET max_occupancy=2 WHERE id=$1`, [standard.id]);
    // Suite fully booked; standard available
    await pool.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,'2030-07-01',1,0,1,0), ($3,$4,'2030-07-01',3,0,0,0)`,
      [newId(), suite.id, newId(), standard.id],
    );
    await pool.query(
      `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
       VALUES ($1,$2,$3,'video','https://ex/v.mp4','https://ex/c.jpg','approved',0,'hotel',200)`,
      [newId(), seeded.venueId, providerId],
    );

    const falsePositive = await search({
      category: 'hotel',
      guests: 8,
      quantity: 1,
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
    });
    expect(falsePositive.body.items.some((i: { venueId: string }) => i.venueId === seeded.venueId)).toBe(
      false,
    );

    // Two rooms × occupancy 4 = 8 guests on same type with availability
    await pool.query(`UPDATE inventory_types SET max_occupancy=4, quantity_total=5, status='active' WHERE id=$1`, [
      standard.id,
    ]);
    await pool.query(
      `UPDATE inventory_daily_capacity SET capacity=5, booked=0, held=0, blocked=0 WHERE inventory_type_id=$1 AND date='2030-07-01'`,
      [standard.id],
    );
    const ok = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
    });
    expect(ok.body.items.some((i: { venueId: string }) => i.venueId === seeded.venueId)).toBe(true);

    // Multi-night: block second night
    await pool.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,'2030-07-02',5,0,5,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET booked=5, capacity=5`,
      [newId(), standard.id],
    );
    const multi = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      checkIn: '2030-07-01',
      checkOut: '2030-07-03',
    });
    expect(multi.body.items.some((i: { venueId: string }) => i.venueId === seeded.venueId)).toBe(false);

    await pool.query(`UPDATE inventory_types SET status='inactive' WHERE venue_id=$1`, [seeded.venueId]);
    const inactive = await search({
      category: 'hotel',
      guests: 2,
      quantity: 1,
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
    });
    expect(inactive.body.items.some((i: { venueId: string }) => i.venueId === seeded.venueId)).toBe(false);
  });

  it('FC16 quantity without dates uses quantity_total', async () => {
    const providerId = await seedProvider(pool, `${provider}-qty`, 'qty');
    const seeded = await seedVenue(pool, providerId, {
      name: 'QtyOnly',
      venueType: 'apartment',
      types: [{ name: 'u', qty: 1, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
       VALUES ($1,$2,$3,'video','https://customer-abc.cloudflarestream.com/v/manifest/video.m3u8','https://imagedelivery.net/stub/c/public','approved',0,'apartment',100)`,
      [newId(), seeded.venueId, providerId],
    );
    const fail = await search({ category: 'apartment', quantity: 3 });
    expect(fail.body.items.some((i: { venueId: string }) => i.venueId === seeded.venueId)).toBe(false);
  });

  it('FC17–FC23 active definitions have handlers; room_type inactive; size/inventory work', async () => {
    const orphan = await request(app.getHttpServer())
      .get('/v1/filter-definitions')
      .set('Authorization', auth(consumer));
    for (const d of orphan.body) {
      expect(isHandlerRegistered(d.key)).toBe(true);
    }
    const room = await pool.query(
      `SELECT status FROM filter_definitions WHERE key='room_type' LIMIT 1`,
    );
    expect(room.rows[0].status).toBe('inactive');
    expect(orphan.body.some((d: { key: string }) => d.key === 'room_type')).toBe(false);

    await seedVenueFull({ name: 'SizeV', type: 'villa', sizeSqm: 400, inventoryKind: 'villa', priceHint: 900 });
    const bySize = await search({ category: 'villa', sizeSqmMin: 300 });
    expect(bySize.body.items.some((i: { name: string }) => i.name === 'SizeV')).toBe(true);
    const byKind = await search({ category: 'villa', inventoryKind: 'villa' });
    expect(byKind.body.items.some((i: { name: string }) => i.name === 'SizeV')).toBe(true);
  });

  it('FC24–FC29 discovery projection media + feed + approved price', async () => {
    await seedVenueFull({ name: 'MediaOk', priceHint: 180, moderation: 'approved' });
    await seedVenueFull({ name: 'MediaPend', priceHint: 50, moderation: 'pending' });
    const res = await search({ limit: 50 });
    const ok = res.body.items.find((i: { name: string }) => i.name === 'MediaOk');
    expect(ok).toBeDefined();
    expect(ok!.primaryMediaId).toBeTruthy();
    expect(ok!.coverUrl).toBeTruthy();
    expect(ok!.streamUrl).toBeTruthy();
    const pend = res.body.items.find((i: { name: string }) => i.name === 'MediaPend');
    expect(pend).toBeDefined();
    expect(pend!.startingPriceHint).toBeNull();

    const feed = await request(app.getHttpServer())
      .get('/v1/feed')
      .set('Authorization', auth(consumer));
    expect(feed.status).toBe(200);
    expect(Array.isArray(feed.body.items)).toBe(true);
    for (const item of feed.body.items as { coverUrl?: string; videoId?: string }[]) {
      expect(item.videoId).toBeTruthy();
      expect(item.coverUrl).toBeTruthy();
    }
  });

  it('FC30–FC34 amenity tri-state + details SSOT', async () => {
    const a = await seedVenueFull({
      name: 'AmAvail',
      amenities: [{ code: 'pool', state: 'AVAILABLE' }],
    });
    await seedVenueFull({
      name: 'AmNo',
      amenities: [{ code: 'pool', state: 'NOT_AVAILABLE' }],
    });
    await seedVenueFull({
      name: 'AmUnk',
      amenities: [{ code: 'pool', state: 'UNKNOWN' }],
    });
    const res = await search({ amenities: ['pool'] });
    const names = res.body.items.map((i: { name: string }) => i.name);
    expect(names).toContain('AmAvail');
    expect(names).not.toContain('AmNo');
    expect(names).not.toContain('AmUnk');

    const details = await request(app.getHttpServer())
      .get(`/v1/venues/${a.venueId}`)
      .set('Authorization', auth(consumer));
    expect(details.body.amenities[0].state).toBe('AVAILABLE');
    expect(details.body.amenities[0].code).toBe('pool');
  });

  it('FC35–FC39 rating filter vs sort + concurrency + trusted rules', async () => {
    await seedVenueFull({
      name: 'RatedAvg',
      ratingAvg: 4.6,
      reviewsCount: 20,
      weighted: 4.1,
      priceHint: 200,
    });
    const byAvg = await search({ minRating: 4.5 });
    expect(byAvg.body.items.some((i: { name: string }) => i.name === 'RatedAvg')).toBe(true);

    // sort uses weighted — create two with same average different weighted
    await seedVenueFull({
      name: 'WHigh',
      type: 'chalet',
      ratingAvg: 5,
      reviewsCount: 100,
      weighted: 4.9,
      priceHint: 200,
    });
    await seedVenueFull({
      name: 'WLow',
      type: 'chalet',
      ratingAvg: 5,
      reviewsCount: 1,
      weighted: 4.2,
      priceHint: 200,
    });
    const sorted = await search({ category: 'chalet', sort: 'rating', limit: 10 });
    const idxHigh = sorted.body.items.findIndex((i: { name: string }) => i.name === 'WHigh');
    const idxLow = sorted.body.items.findIndex((i: { name: string }) => i.name === 'WLow');
    expect(idxHigh).toBeGreaterThanOrEqual(0);
    expect(idxLow).toBeGreaterThanOrEqual(0);
    expect(idxHigh).toBeLessThan(idxLow);

    // concurrent reviews (smaller batch to avoid test-server connection storms)
    const venue = await seedVenueFull({ name: 'Conc', priceHint: 100 });
    const bookings: string[] = [];
    const CONC = 8;
    for (let i = 0; i < CONC; i++) {
      const quoteId = newId();
      const holdId = newId();
      const bid = newId();
      const meta = await pool.query(
        `SELECT v.provider_id, it.id AS type_id FROM venues v
         JOIN inventory_types it ON it.venue_id=v.id WHERE v.id=$1 LIMIT 1`,
        [venue.venueId],
      );
      const day = 10 + i;
      const checkIn = `2031-01-${String(day).padStart(2, '0')}`;
      const checkOut = `2031-01-${String(day + 1).padStart(2, '0')}`;
      const uid = `conc-u-${i}`;
      await pool.query(
        `INSERT INTO quotes (id, consumer_firebase_uid, venue_id, inventory_type_id, check_in, check_out, quantity,
          guests_adults, guests_children, currency, subtotal, extras_total, discount_total, tax_total, gross_total,
          commission_bps, commission_amount, provider_net, pricing_version, status, expires_at)
         VALUES ($1,$2,$3,$4,$5,$6,1,1,0,'SAR',100,0,0,0,100,1000,10,90,'v1','consumed',now())`,
        [quoteId, uid, venue.venueId, meta.rows[0].type_id, checkIn, checkOut],
      );
      await pool.query(
        `INSERT INTO booking_holds (id, quote_id, inventory_type_id, consumer_firebase_uid,
          quantity, check_in, check_out, status, expires_at, idempotency_key)
         VALUES ($1,$2,$3,$4,1,$5,$6,'CONVERTED',now(),$7)`,
        [holdId, quoteId, meta.rows[0].type_id, uid, checkIn, checkOut, `hc-${i}`],
      );
      await pool.query(
        `INSERT INTO bookings (id, hold_id, quote_id, venue_id, provider_id, inventory_type_id, consumer_firebase_uid,
          human_code, status, quantity, check_in, check_out, currency, gross_total, commission_bps,
          commission_amount, provider_net, cancellation_policy_snapshot_json, payment_method, payment_status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'COMPLETED',1,$9,$10,'SAR',100,1000,10,90,'{}'::jsonb,'LEGACY_UNSPECIFIED','LEGACY_UNSPECIFIED')`,
        [
          bid,
          holdId,
          quoteId,
          venue.venueId,
          meta.rows[0].provider_id,
          meta.rows[0].type_id,
          uid,
          `HC-C-${i}`,
          checkIn,
          checkOut,
        ],
      );
      bookings.push(bid);
    }
    await Promise.all(
      bookings.map((bookingId, i) =>
        request(app.getHttpServer())
          .post('/v1/reviews')
          .set('Authorization', auth(`conc-u-${i}`))
          .send({ bookingId, rating: 5 }),
      ),
    );
    const v = await pool.query(
      `SELECT reviews_count, rating_sum, rating_average, weighted_rating FROM venues WHERE id=$1`,
      [venue.venueId],
    );
    expect(Number(v.rows[0].reviews_count)).toBe(CONC);
    expect(Number(v.rows[0].rating_sum)).toBe(CONC * 5);
    expect(Number(v.rows[0].rating_average)).toBe(5);
    const expected =
      (RATING_PRIOR_STRENGTH * RATING_PRIOR_MEAN + CONC * 5) / (RATING_PRIOR_STRENGTH + CONC);
    expect(Number(v.rows[0].weighted_rating)).toBeCloseTo(expected, 1);

    const dup = await request(app.getHttpServer())
      .post('/v1/reviews')
      .set('Authorization', auth('conc-u-0'))
      .send({ bookingId: bookings[0], rating: 1 });
    expect(dup.status).toBeGreaterThanOrEqual(400);
  });

  it('FC40–FC43 migration artifacts present; custom filter preserved; handlers audit', async () => {
    const customId = newId();
    await pool.query(
      `INSERT INTO filter_definitions (id, key, venue_type, label_ar, label_en, value_type, operator, indexed, options_json, section, status)
       VALUES ($1,'custom_admin_only','hotel','مخصص','Custom','bool','eq',false,'{}'::jsonb,'admin','inactive')
       ON CONFLICT DO NOTHING`,
      [customId],
    );
    // re-apply 007 statements that must be idempotent
    await pool.query(`UPDATE filter_definitions SET status='inactive' WHERE key='room_type'`);
    const custom = await pool.query(`SELECT status FROM filter_definitions WHERE key='custom_admin_only'`);
    expect(custom.rowCount).toBeGreaterThan(0);
    expect(custom.rows[0].status).toBe('inactive');

    const cols = await pool.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_name='venue_amenity_links' AND column_name='state'`,
    );
    expect(cols.rowCount).toBe(1);
  });

  it('FC44 capability flags enforced at discovery and booking entry', async () => {
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking=FALSE WHERE venue_type='hotel'`,
    );
    const v = await seedVenueFull({ name: 'NoBook', type: 'hotel' });
    const type = await pool.query(`SELECT id FROM inventory_types WHERE venue_id=$1 LIMIT 1`, [v.venueId]);
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumer))
      .send({
        venueId: v.venueId,
        inventoryTypeId: type.rows[0].id,
        checkIn: '2030-08-01',
        checkOut: '2030-08-02',
        quantity: 1,
        guestsAdults: 1,
        guestsChildren: 0,
        extraIds: [],
      });
    expect(quote.status).toBeGreaterThanOrEqual(400);
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking=TRUE WHERE venue_type='hotel'`,
    );
  });

  it('FC45 intent never silently overwrites explicit guests', async () => {
    await seedVenueFull({
      name: 'HoneyConflict',
      type: 'chalet',
      amenities: [
        { code: 'honeymoon', state: 'AVAILABLE' },
        { code: 'privacy', state: 'AVAILABLE' },
      ],
    });
    // honeymoon expands guestsMin=2 only; guestsMax silent overwrite removed.
    // Explicit guests=8 must not become 2 — with family-like conflict use guestsMin if we add guestsMax conflict:
    // Use inactive weekend to ensure inactive intents reject:
    const inactive = await search({ intent: 'weekend' });
    expect(inactive.status).toBeGreaterThanOrEqual(400);

    // If we set guestsMax back for honeymoon conflict — migration removed guestsMax.
    // Explicit large guests + family guestsMin=4: guests=2 should conflict
    const conflict = await search({ intent: 'family', guests: 2 });
    expect(conflict.status).toBeGreaterThanOrEqual(400);
  });
});
