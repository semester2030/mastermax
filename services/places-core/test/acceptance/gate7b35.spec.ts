/**
 * Gate 7B.3.5 acceptance — input/slot integrity + NFC + capability + bestScore evidence.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import { normalizeSearchText } from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.3.5 acceptance — input / slot / evidence', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b35-user';

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

  it('G7B35-API rejects fractional ints and timestamps with 400', async () => {
    expect((await search({ quantity: 1.5, limit: 5 })).status).toBe(400);
    expect((await search({ guests: 2.5, limit: 5 })).status).toBe(400);
    expect((await search({ capacityMin: 10.5, limit: 5 })).status).toBe(400);
    expect((await search({ starsMin: 3.5, limit: 5 })).status).toBe(400);
    expect((await search({ limit: 10.5 })).status).toBe(400);
    expect(
      (
        await search({
          checkIn: '2030-07-01T00:00:00.000Z',
          checkOut: '2030-07-02',
          limit: 5,
        })
      ).status,
    ).toBe(400);
    expect(
      (await search({ checkIn: '2030-07-01', checkOut: '2030-07-01', limit: 5 })).status,
    ).toBe(201);
    expect((await search({ checkIn: '2030-02-30', checkOut: '2030-03-01', limit: 5 })).status).toBe(
      400,
    );
    expect((await search({ minPrice: 99.5, limit: 5 })).status).toBe(201);
  });

  it('G7B35-SLOT cross-venue inventory blocked by FK; discovery matches same-venue only', async () => {
    const p = await seedProvider(pool, `${uid}-slot-${newId().slice(0, 6)}`, 'Slot35');
    const a = await seedVenue(pool, p, {
      name: 'Palace A',
      venueType: 'wedding_palace',
      types: [{ name: 'Hall', qty: 1, nights: { '2030-09-01': '100' } }],
    });
    const b = await seedVenue(pool, p, {
      name: 'Palace B',
      venueType: 'wedding_palace',
      types: [{ name: 'Hall', qty: 1, nights: { '2030-09-01': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET capacity=400, lat=24.5, lng=46.5, weighted_rating=4.5, reviews_count=9 WHERE id=$1`,
      [a.venueId],
    );
    await pool.query(
      `UPDATE venues SET capacity=400, lat=24.51, lng=46.51, weighted_rating=4.4, reviews_count=8 WHERE id=$1`,
      [b.venueId],
    );
    await ensureMedia(a.venueId, p, 'sa');
    await ensureMedia(b.venueId, p, 'sb');

    const tplA = newId();
    const invA = await pool.query<{ id: string }>(
      `SELECT id::text AS id FROM inventory_types WHERE venue_id=$1 ORDER BY id LIMIT 1`,
      [a.venueId],
    );
    await pool.query(
      `INSERT INTO event_slot_templates
         (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id)
       VALUES ($1,$2,'evening','مسائي','18:00','23:00',300,100.00,$3)`,
      [tplA, a.venueId, invA.rows[0].id],
    );
    let crossInsertBlocked = false;
    try {
      await pool.query(
        `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
         VALUES ($1,$2,$3,'2030-09-01','open')`,
        [newId(), b.venueId, tplA],
      );
    } catch {
      crossInsertBlocked = true;
    }
    expect(crossInsertBlocked).toBe(true);

    await pool.query(
      `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
       VALUES ($1,$2,$3,'2030-09-01','open')`,
      [newId(), a.venueId, tplA],
    );

    const ok = await search({
      category: 'wedding_palace',
      checkIn: '2030-09-01',
      slotCode: 'evening',
      capacityMin: 200,
    });
    expect(ok.status).toBe(201);
    const ids = (ok.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(ids).toContain(a.venueId);
    expect(ids).not.toContain(b.venueId);
  });

  it('G7B35A-API multi-word capability label: document OR venue_type then token AND', async () => {
    // Multi-word label_ar for hotel_apartment = "شقق فندقية"
    const labels = await pool.query<{ phrase: string }>(
      `SELECT label_ar AS phrase FROM venue_type_capabilities WHERE venue_type='hotel_apartment'`,
    );
    const multi = labels.rows[0].phrase;
    expect(multi.split(/\s+/).length).toBeGreaterThanOrEqual(2);

    const p = await seedProvider(pool, `${uid}-mw-${newId().slice(0, 6)}`, 'MultiCap');
    const apt = await seedVenue(pool, p, {
      name: 'Silent Apt UniqueTokenMW',
      venueType: 'hotel_apartment',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '120' } }],
    });
    const hotel = await seedVenue(pool, p, {
      name: 'Silent Hotel UniqueTokenMW',
      venueType: 'hotel',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET lat=24.3, lng=46.3, weighted_rating=4.3, reviews_count=11 WHERE id=$1`,
      [apt.venueId],
    );
    await pool.query(
      `UPDATE venues SET lat=24.31, lng=46.31, weighted_rating=4.3, reviews_count=11 WHERE id=$1`,
      [hotel.venueId],
    );
    await ensureMedia(apt.venueId, p, 'apt');
    await ensureMedia(hotel.venueId, p, 'ht');

    // Phrase alone resolves via venue_type OR (document does not contain label words)
    const byLabel = await search({ q: multi, limit: 30 });
    expect(byLabel.status).toBe(201);
    const byLabelIds = (byLabel.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(byLabelIds).toContain(apt.venueId);
    expect(byLabelIds).not.toContain(hotel.venueId);

    // Phrase AND UniqueTokenMW — both venues have token; type OR still filters to apartment
    const andTok = await search({ q: `${multi} UniqueTokenMW`, limit: 30 });
    expect(andTok.status).toBe(201);
    const andIds = (andTok.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(andIds).toContain(apt.venueId);
    expect(andIds).not.toContain(hotel.venueId);

    // Impossible AND
    const miss = await search({ q: `${multi} NoSuchTokenMWZZZ`, limit: 10 });
    expect(miss.status).toBe(201);
    expect(miss.body.total).toBe(0);
  });


  it('G7B35-NFC Café vs Cafe\\u0301 via TS + PG + search_document + API', async () => {
    const composed = 'Café UniqueNfc35';
    const decomposed = 'Cafe\u0301 UniqueNfc35';
    expect(composed).not.toBe(decomposed);
    const nfcTs = normalizeSearchText(decomposed);
    expect(nfcTs).toBe(normalizeSearchText(composed));
    const pg = await pool.query<{ n: string }>(`SELECT places_normalize_search($1) AS n`, [
      decomposed,
    ]);
    expect(pg.rows[0].n).toBe(nfcTs);

    const p = await seedProvider(pool, `${uid}-nfc-${newId().slice(0, 6)}`, 'Nfc35');
    const seeded = await seedVenue(pool, p, {
      name: composed,
      venueType: 'hotel',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET lat=24.6, lng=46.6, weighted_rating=4.5, reviews_count=20 WHERE id=$1`,
      [seeded.venueId],
    );
    await ensureMedia(seeded.venueId, p, 'nfc35');
    const doc = await pool.query<{ d: string }>(
      `SELECT search_document AS d FROM venues WHERE id=$1`,
      [seeded.venueId],
    );
    expect(doc.rows[0].d).toContain(nfcTs.split(' ')[0]);

    const byDecomp = await search({ q: decomposed, limit: 20 });
    expect(byDecomp.status).toBe(201);
    expect(
      (byDecomp.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(true);
    const byComp = await search({ q: composed, limit: 20 });
    expect(byComp.status).toBe(201);
    expect(
      (byComp.body.items as { venueId: string }[]).some((i) => i.venueId === seeded.venueId),
    ).toBe(true);
  });

  it('G7B35-CAPABILITY label → venue_type OR with phrase AND', async () => {
    // label_ar for hotel is "فنادق" — searching that should match hotels via venue_type OR
    // even when search_document does not contain the label text.
    const p = await seedProvider(pool, `${uid}-cap-${newId().slice(0, 6)}`, 'Cap35');
    const hotel = await seedVenue(pool, p, {
      name: 'Silent Doc Venue Alpha',
      venueType: 'hotel',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
    });
    const villa = await seedVenue(pool, p, {
      name: 'Silent Doc Venue Beta',
      venueType: 'villa',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET lat=24.4, lng=46.4, weighted_rating=4.2, reviews_count=15 WHERE id=$1`,
      [hotel.venueId],
    );
    await pool.query(
      `UPDATE venues SET lat=24.41, lng=46.41, weighted_rating=4.2, reviews_count=15 WHERE id=$1`,
      [villa.venueId],
    );
    await ensureMedia(hotel.venueId, p, 'h');
    await ensureMedia(villa.venueId, p, 'v');

    const labels = await pool.query<{ phrase: string; vt: string }>(
      `SELECT label_ar AS phrase, venue_type AS vt FROM venue_type_capabilities WHERE venue_type='hotel'`,
    );
    const hotelLabel = labels.rows[0].phrase;
    expect(hotelLabel.length).toBeGreaterThan(1);

    // Direct SQL path: capability-label token expands to venue_type ANY
    const n = normalizeSearchText(hotelLabel);
    const sqlHit = await pool.query<{ id: string }>(
      `SELECT v.id FROM venues v
       WHERE v.id = ANY($1::uuid[])
         AND (
           v.search_document ILIKE '%' || $2 || '%' ESCAPE '\\'
           OR similarity(v.search_document, $3) >= 0.25
           OR v.venue_type = ANY($4::text[])
         )`,
      [[hotel.venueId, villa.venueId], n, n, ['hotel']],
    );
    expect(sqlHit.rows.map((r) => r.id)).toContain(hotel.venueId);
    expect(sqlHit.rows.map((r) => r.id)).not.toContain(villa.venueId);

    // Phrase AND: hotel label + unique token present only on hotel name fails on villa path
    const phrase = await search({ q: `${hotelLabel} Alpha`, limit: 20 });
    expect(phrase.status).toBe(201);
    const phraseIds = (phrase.body.items as { venueId: string }[]).map((i) => i.venueId);
    expect(phraseIds).toContain(hotel.venueId);
    expect(phraseIds).not.toContain(villa.venueId);

    // Impossible AND → empty
    const miss = await search({ q: `${hotelLabel} NoSuchTokenZZZ`, limit: 10 });
    expect(miss.status).toBe(201);
    expect(miss.body.total).toBe(0);
  });

  it('G7B35-RANK expected numeric bestScore + full tuple tie by id + pagination', async () => {
    const p = await seedProvider(pool, `${uid}-rank-${newId().slice(0, 6)}`, 'Rank35');
    const asOf = '2030-01-01T00:00:00.000Z';
    // Controlled: rating=5, reviews=500, created_at=asOf, media=yes → score 0.900000
    // Formula: 0.45 + 0.20 + 0.15 + 0.10 = 0.90
    const ids: string[] = [];
    for (let i = 0; i < 3; i++) {
      const seeded = await seedVenue(pool, p, {
        name: `Rank35 Tie ${i}`,
        venueType: 'hotel',
        types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
      });
      await pool.query(
        `UPDATE venues SET lat=$2, lng=$3, weighted_rating=5, reviews_count=500,
          rating_average=5, created_at=$4::timestamptz WHERE id=$1`,
        [seeded.venueId, 27 + i * 0.001, 47 + i * 0.001, asOf],
      );
      await ensureMedia(seeded.venueId, p, `tie${i}`);
      ids.push(seeded.venueId);
    }
    // Cap proof: reviews 800 equals 500 component
    const high = await seedVenue(pool, p, {
      name: 'Rank35 Cap800',
      venueType: 'hotel',
      types: [{ name: 'u', qty: 2, nights: { '2030-01-10': '100' } }],
    });
    await pool.query(
      `UPDATE venues SET lat=27.1, lng=47.1, weighted_rating=5, reviews_count=800,
        rating_average=5, created_at=$2::timestamptz WHERE id=$1`,
      [high.venueId, asOf],
    );
    await ensureMedia(high.venueId, p, 'cap');
    ids.push(high.venueId);

    const expr = bestScoreSqlExpr(1);
    const scores = await pool.query<{ id: string; score: string }>(
      `SELECT v.id, ${expr}::text AS score FROM venues v
       WHERE v.id = ANY($2::uuid[])
       ORDER BY ${expr} DESC, v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC`,
      [asOf, ids],
    );
    expect(scores.rows).toHaveLength(4);
    for (const row of scores.rows) {
      expect(Number(row.score)).toBeCloseTo(0.9, 5);
      expect(row.score).toMatch(/^0\.900000/);
    }
    // Full tuple tie → id ASC
    const tiedOnly = scores.rows.filter((r) => ids.slice(0, 3).includes(r.id));
    const sortedIds = [...ids.slice(0, 3)].sort();
    expect(tiedOnly.map((r) => r.id)).toEqual(sortedIds);

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
