/**
 * Gate 7B.3.4 — filter composition + NFC/literals + bestScore evidence (acceptance).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import { normalizeSearchText } from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.3.4 acceptance — composition / evidence', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b34-user';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_discovery=true
       WHERE venue_type IN ('wedding_palace','event_hall')`,
    );
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

  it('G7B34-COMP undated: max(guests,capacityMin); qty forbids v.capacity bypass; cross-type false', async () => {
    const p = await seedProvider(pool, `${uid}-c-${newId().slice(0, 6)}`, 'Comp');

    const venueCap = await seedVenue(pool, p, {
      name: 'VenueCapOnly',
      venueType: 'hotel',
      types: [{ name: 'tiny', qty: 1, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET capacity=50, lat=24.7, lng=46.7, weighted_rating=4, reviews_count=5 WHERE id=$1`,
      [venueCap.venueId],
    );
    await pool.query(`UPDATE inventory_types SET max_occupancy=2 WHERE venue_id=$1`, [
      venueCap.venueId,
    ]);
    await ensureMedia(venueCap.venueId, p, 'vcap');

    const invOnly = await seedVenue(pool, p, {
      name: 'InvOccOnly',
      venueType: 'hotel',
      types: [{ name: 'suite', qty: 3, nights: { '2030-01-10': '200' } }],
    });
    await pool.query(
      `UPDATE venues SET capacity=NULL, lat=24.71, lng=46.71, weighted_rating=4, reviews_count=5 WHERE id=$1`,
      [invOnly.venueId],
    );
    await pool.query(`UPDATE inventory_types SET max_occupancy=12 WHERE venue_id=$1`, [
      invOnly.venueId,
    ]);
    await ensureMedia(invOnly.venueId, p, 'inv');

    // No qty: need=max(4,10)=10 — venueCap matches via v.capacity; invOnly via max_occupancy
    const undated = await search({
      category: 'hotel',
      guests: 4,
      capacityMin: 10,
      limit: 50,
    });
    expect(undated.status).toBe(201);
    const undatedIds = (undated.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(undatedIds).toContain(venueCap.venueId);
    expect(undatedIds).toContain(invOnly.venueId);

    // Explicit qty=2 + guests=8: venueCap has qty_total=1 → excluded; invOnly 3×12 OK
    const withQty = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      limit: 50,
    });
    expect(withQty.status).toBe(201);
    const qtyIds = (withQty.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(qtyIds).not.toContain(venueCap.venueId);
    expect(qtyIds).toContain(invOnly.venueId);

    // Cross-type false positive: two types that only together satisfy guests+qty
    const cross = await seedVenue(pool, p, {
      name: 'CrossTypeHotel',
      venueType: 'hotel',
      types: [
        { name: 'a', qty: 1, nights: { '2030-08-01': '100' } },
        { name: 'b', qty: 5, nights: { '2030-08-01': '90' } },
      ],
    });
    const types = await pool.query(
      `SELECT id, name FROM inventory_types WHERE venue_id=$1 ORDER BY name`,
      [cross.venueId],
    );
    const a = types.rows.find((r) => r.name === 'a')!;
    const b = types.rows.find((r) => r.name === 'b')!;
    await pool.query(`UPDATE inventory_types SET max_occupancy=8, quantity_total=1 WHERE id=$1`, [
      a.id,
    ]);
    await pool.query(`UPDATE inventory_types SET max_occupancy=2, quantity_total=5 WHERE id=$1`, [
      b.id,
    ]);
    await pool.query(
      `UPDATE venues SET capacity=100, lat=24.72, lng=46.72, weighted_rating=4, reviews_count=5 WHERE id=$1`,
      [cross.venueId],
    );
    await ensureMedia(cross.venueId, p, 'cross');

    const falsePos = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      limit: 50,
    });
    expect(falsePos.status).toBe(201);
    expect(
      (falsePos.body.items as { venueId: string }[]).some((i) => i.venueId === cross.venueId),
    ).toBe(false);

    // Same type after fix: type b with occ=4 qty=5
    await pool.query(`UPDATE inventory_types SET max_occupancy=4 WHERE id=$1`, [b.id]);
    const ok = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      limit: 50,
    });
    expect(ok.status).toBe(201);
    expect((ok.body.items as { venueId: string }[]).some((i) => i.venueId === cross.venueId)).toBe(
      true,
    );
  });

  it('G7B34-NIGHTLY same-type qty+capacity+nights; qty0 / no-inventory', async () => {
    const p = await seedProvider(pool, `${uid}-n-${newId().slice(0, 6)}`, 'Night');
    const seeded = await seedVenue(pool, p, {
      name: 'NightHotel',
      venueType: 'hotel',
      types: [
        { name: 'suite', qty: 1, nights: { '2030-07-01': '500' } },
        { name: 'std', qty: 5, nights: { '2030-07-01': '200' } },
      ],
    });
    const types = await pool.query(
      `SELECT id, name FROM inventory_types WHERE venue_id=$1`,
      [seeded.venueId],
    );
    const suite = types.rows.find((r) => r.name === 'suite')!;
    const std = types.rows.find((r) => r.name === 'std')!;
    await pool.query(`UPDATE inventory_types SET max_occupancy=8 WHERE id=$1`, [suite.id]);
    await pool.query(`UPDATE inventory_types SET max_occupancy=4 WHERE id=$1`, [std.id]);
    await pool.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,'2030-07-01',1,0,1,0), ($3,$4,'2030-07-01',5,0,0,0)`,
      [newId(), suite.id, newId(), std.id],
    );
    await pool.query(
      `UPDATE venues SET lat=24.8, lng=46.8, weighted_rating=4.2, reviews_count=12 WHERE id=$1`,
      [seeded.venueId],
    );
    await ensureMedia(seeded.venueId, p, 'night');

    const blocked = await search({
      category: 'hotel',
      guests: 8,
      quantity: 1,
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
    });
    expect(blocked.status).toBe(201);
    expect(
      (blocked.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(false);

    const ok = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
    });
    expect(ok.status).toBe(201);
    expect((ok.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId)).toBe(
      true,
    );

    await pool.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,'2030-07-02',5,0,5,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET booked=5, capacity=5`,
      [newId(), std.id],
    );
    const multi = await search({
      category: 'hotel',
      guests: 8,
      quantity: 2,
      checkIn: '2030-07-01',
      checkOut: '2030-07-03',
    });
    expect(multi.status).toBe(201);
    expect(
      (multi.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(false);

    const pNo = await seedProvider(pool, `${uid}-no-${newId().slice(0, 6)}`, 'NoInv');
    const noInv = await seedVenue(pool, pNo, {
      name: 'Wedding NoInv34',
      venueType: 'wedding_palace',
      types: [],
    });
    await pool.query(
      `UPDATE venues SET capacity=400, lat=24.9, lng=46.9, weighted_rating=4, reviews_count=3 WHERE id=$1`,
      [noInv.venueId],
    );
    await ensureMedia(noInv.venueId, pNo, 'noinv34');

    const open = await search({
      category: 'wedding_palace',
      sort: 'best',
      limit: 50,
      surface: 'search',
    });
    expect(open.status).toBe(201);
    expect((open.body.items as { venueId: string }[]).some((i) => i.venueId === noInv.venueId)).toBe(
      true,
    );

    const qty1 = await search({
      category: 'wedding_palace',
      quantity: 1,
      limit: 50,
      surface: 'search',
    });
    expect(qty1.status).toBe(201);
    expect((qty1.body.items as { venueId: string }[]).some((i) => i.venueId === noInv.venueId)).toBe(
      false,
    );

    const zero = await seedVenue(pool, p, {
      name: 'ZeroQtyHotel',
      venueType: 'hotel',
      types: [{ name: 'z', qty: 0, nights: { '2030-01-10': '50' } }],
    });
    await ensureMedia(zero.venueId, p, 'zq');
    const zFiltered = await search({ quantity: 1, category: 'hotel', limit: 50 });
    expect(zFiltered.status).toBe(201);
    expect(
      (zFiltered.body.items as { venueId: string }[]).some((i) => i.venueId === zero.venueId),
    ).toBe(false);
  });

  it('G7B34-SLOT capacity + date/qty rejects before SQL', async () => {
    const p = await seedProvider(pool, `${uid}-s-${newId().slice(0, 6)}`, 'Slot');
    const seeded = await seedVenue(pool, p, {
      name: 'SlotPalace',
      venueType: 'wedding_palace',
      types: [{ name: 'Hall', qty: 1, nights: { '2030-09-01': '5000' } }],
    });
    await pool.query(
      `UPDATE venues SET capacity=500, lat=25, lng=47, weighted_rating=4.5, reviews_count=8 WHERE id=$1`,
      [seeded.venueId],
    );
    await ensureMedia(seeded.venueId, p, 'slot');

    const tpl = await pool.query(
      `INSERT INTO event_slot_templates
         (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id)
       VALUES ($1,$2,'evening','مسائي','18:00','23:00',200,5000,$3) RETURNING id`,
      [newId(), seeded.venueId, seeded.types.Hall],
    );
    await pool.query(
      `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
       VALUES ($1,$2,$3,'2030-09-01','open')`,
      [newId(), seeded.venueId, tpl.rows[0].id],
    );

    const ok = await search({
      category: 'wedding_palace',
      checkIn: '2030-09-01',
      slotCode: 'evening',
      guests: 100,
      capacityMin: 150,
    });
    expect(ok.status).toBe(201);
    expect((ok.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId)).toBe(
      true,
    );

    const tooBig = await search({
      category: 'wedding_palace',
      checkIn: '2030-09-01',
      slotCode: 'evening',
      capacityMin: 300,
    });
    expect(tooBig.status).toBe(201);
    expect(
      (tooBig.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(false);

    expect((await search({ slotCode: 'evening' })).status).toBe(400);
    expect(
      (await search({ checkIn: '2030-09-01', checkOut: '2030-09-02', slotCode: 'evening' })).status,
    ).toBe(400);
    expect((await search({ checkIn: '2030-09-01' })).status).toBe(400);
    expect((await search({ checkOut: '2030-09-02' })).status).toBe(400);
    expect(
      (
        await search({
          checkIn: '2030-09-01',
          slotCode: 'evening',
          quantity: 1,
        })
      ).status,
    ).toBe(400);
  });

  it('G7B34-NFC composed/decomposed + literals % _ \\ hard asserts', async () => {
    const p = await seedProvider(pool, `${uid}-nfc-${newId().slice(0, 6)}`, 'Nfc');
    const seeded = await seedVenue(pool, p, {
      name: 'فندق الملقا 100%_deal \\slash UniqueNFC',
      venueType: 'hotel',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET lat=24.75, lng=46.75, city='Riyadh', district='Malqa',
        weighted_rating=4.5, reviews_count=40 WHERE id=$1`,
      [seeded.venueId],
    );
    await ensureMedia(seeded.venueId, p, 'nfc');

    const nfd = 'ف\u064Eندق';
    const nfcTs = normalizeSearchText(nfd);
    expect(nfcTs.length).toBeGreaterThan(0);
    const pgN = await pool.query<{ n: string }>(`SELECT places_normalize_search($1) AS n`, [nfd]);
    expect(pgN.rows[0].n).toBe(nfcTs);
    const composed = await search({ q: nfd, limit: 20 });
    expect(composed.status).toBe(201);
    expect(
      (composed.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(true);
    const nfcForm = normalizeSearchText('فندق');
    const deco = await search({ q: nfcForm, limit: 20 });
    expect(deco.status).toBe(201);
    expect((deco.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId)).toBe(
      true,
    );

    const litPct = await search({ q: '100%_deal', limit: 20 });
    expect(litPct.status).toBe(201);
    expect(
      (litPct.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(true);

    const litUnder = await search({ q: '100_deal', limit: 20 });
    expect(litUnder.status).toBe(201);
    expect(
      (litUnder.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(false);

    const litSlash = await search({ q: '\\slash', limit: 20 });
    expect(litSlash.status).toBe(201);
    expect(
      (litSlash.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(true);

    const wildPct = await search({ q: '%', limit: 20 });
    expect(wildPct.status).toBe(400);
  });

  it('G7B34-RANK bestScore cap500 + media + freshness + ties + full pagination', async () => {
    const p = await seedProvider(pool, `${uid}-r-${newId().slice(0, 6)}`, 'Rank34');
    const ids: string[] = [];
    const specs = [
      { reviews: 500, rating: 4.5, days: 5, media: true },
      { reviews: 800, rating: 4.5, days: 5, media: true },
      { reviews: 500, rating: 4.5, days: 5, media: false },
      { reviews: 10, rating: 4.5, days: 5, media: true },
      { reviews: 500, rating: 4.5, days: 200, media: true },
    ];
    for (let i = 0; i < specs.length; i++) {
      const s = specs[i];
      const seeded = await seedVenue(pool, p, {
        name: `Rank34 Hotel ${i}`,
        venueType: 'hotel',
        types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
      });
      await pool.query(
        `UPDATE venues SET lat=$2, lng=$3, weighted_rating=$4, reviews_count=$5,
          rating_average=$4, created_at=now() - ($6 || ' days')::interval WHERE id=$1`,
        [seeded.venueId, 26 + i * 0.01, 46 + i * 0.01, s.rating, s.reviews, String(s.days)],
      );
      if (s.media) await ensureMedia(seeded.venueId, p, `r34-${i}`);
      ids.push(seeded.venueId);
    }

    const asOf = new Date().toISOString();
    const expr = bestScoreSqlExpr(1);
    const scores = await pool.query<{ id: string; reviews_count: number; score: string }>(
      `SELECT v.id, v.reviews_count, ${expr}::text AS score
       FROM venues v WHERE v.id = ANY($2::uuid[])
       ORDER BY ${expr} DESC, v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC`,
      [asOf, ids],
    );
    expect(scores.rows).toHaveLength(ids.length);
    const byReviews = (n: number) => scores.rows.filter((r) => Number(r.reviews_count) === n);
    const s500 = byReviews(500);
    const s800 = byReviews(800);
    expect(s500.length).toBeGreaterThanOrEqual(2);
    expect(s800).toHaveLength(1);
    // Cap 500: reviews 500 and 800 share identical reviews component when other terms equal
    const freshMedia500 = scores.rows.find(
      (r) => r.id === ids[0],
    )!;
    const freshMedia800 = scores.rows.find(
      (r) => r.id === ids[1],
    )!;
    expect(freshMedia500.score).toBe(freshMedia800.score);

    const noMedia = scores.rows.find((r) => r.id === ids[2])!;
    expect(Number(noMedia.score)).toBeLessThan(Number(freshMedia500.score));

    const stale = scores.rows.find((r) => r.id === ids[4])!;
    expect(Number(stale.score)).toBeLessThan(Number(freshMedia500.score));

    const first = await search({ sort: 'best', limit: 2, surface: 'search' });
    expect(first.status).toBe(201);
    const total = first.body.total as number;
    const seen = new Set<string>();
    let cursor: string | null = null;
    let rankingAsOf: string | null = null;
    for (let page = 0; page < 80; page++) {
      const body: Record<string, unknown> = { sort: 'best', limit: 2, surface: 'search' };
      if (cursor) body.cursor = cursor;
      const res = await search(body);
      expect(res.status).toBe(201);
      expect(res.body.total).toBe(total);
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
    for (const id of ids) expect(seen.has(id)).toBe(true);
  });
});
