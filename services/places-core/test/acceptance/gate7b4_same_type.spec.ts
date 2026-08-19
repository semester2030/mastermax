/**
 * Gate 7B.4 — Same-Type canonical discovery profile (circle + near_place + sameTypeOnly).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';

describe('Gate 7B.4 — Same-Type canonical profile', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b4-same';

  beforeAll(async () => {
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

  async function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(uid))
      .send(body);
  }

  async function seedGeoVenue(opts: {
    name: string;
    venueType: string;
    lat: number;
    lng: number;
    status?: string;
    withVideo?: boolean;
    withImage?: boolean;
    discoveryOff?: boolean;
  }): Promise<{ venueId: string; providerId: string }> {
    const providerId = await seedProvider(pool, `${uid}-${newId()}`, opts.name);
    const venue = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.venueType,
      types: [{ name: 'std', qty: 2, nights: { '2032-01-01': '200' } }],
    });
    await pool.query(`UPDATE venues SET lat=$2, lng=$3, status=$4 WHERE id=$1`, [
      venue.venueId,
      opts.lat,
      opts.lng,
      opts.status ?? 'published',
    ]);
    if (opts.discoveryOff) {
      await pool.query(
        `UPDATE venue_type_capabilities SET enabled_for_discovery=false WHERE venue_type=$1`,
        [opts.venueType],
      );
    }
    if (opts.withVideo) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,'video','https://example.test/v.mp4','https://example.test/c.jpg','approved',0,$4)`,
        [newId(), venue.venueId, providerId, opts.venueType],
      );
    }
    if (opts.withImage) {
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,'image','https://example.test/i.jpg','https://example.test/c.jpg','approved',0,$4)`,
        [newId(), venue.venueId, providerId, opts.venueType],
      );
    }
    return { venueId: venue.venueId, providerId };
  }

  it('G7B4-SAME-01 circle near_place defaults radius=50 sameTypeOnly=true + profile', async () => {
    const anchor = await seedGeoVenue({
      name: 'Anchor',
      venueType: 'hotel',
      lat: 24.7,
      lng: 46.7,
      withImage: true,
    });
    await seedGeoVenue({
      name: 'NearHotel',
      venueType: 'hotel',
      lat: 24.71,
      lng: 46.71,
      withImage: true,
    });
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(res.body.applied.radiusKm).toBe(50);
    expect(res.body.applied.sameTypeOnly).toBe(true);
    expect(res.body.applied.profile).toBe('same_type_near_place');
    expect(res.body.applied.diversity.applied).toBe(false);
  });

  it('G7B4-SAME-02 same type only; anchor excluded; distance pagination', async () => {
    const anchor = await seedGeoVenue({
      name: 'A',
      venueType: 'hotel',
      lat: 24.0,
      lng: 46.0,
      withImage: true,
    });
    const near = await seedGeoVenue({
      name: 'Near',
      venueType: 'hotel',
      lat: 24.01,
      lng: 46.01,
      withImage: true,
    });
    const far = await seedGeoVenue({
      name: 'Far',
      venueType: 'hotel',
      lat: 24.05,
      lng: 46.05,
      withImage: true,
    });
    await seedGeoVenue({
      name: 'Chalet',
      venueType: 'chalet',
      lat: 24.005,
      lng: 46.005,
      withImage: true,
    });
    const seen: string[] = [];
    let cursor: string | undefined;
    for (;;) {
      const res = await search({
        surface: 'circle',
        sort: 'near_place',
        anchorVenueId: anchor.venueId,
        limit: 1,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      for (const item of res.body.items) {
        expect(item.venueId).not.toBe(anchor.venueId);
        expect(item.category).toBe('hotel');
        seen.push(item.venueId);
      }
      if (!res.body.nextCursor) break;
      cursor = res.body.nextCursor;
    }
    expect(seen).toEqual([near.venueId, far.venueId]);
  });

  it('G7B4-SAME-03 missing/draft/invalid geo anchor rejected', async () => {
    expect(
      (await search({ surface: 'circle', sort: 'near_place', limit: 5 })).status,
    ).toBe(400);
    const draft = await seedGeoVenue({
      name: 'DraftA',
      venueType: 'hotel',
      lat: 24.7,
      lng: 46.7,
      status: 'draft',
    });
    expect(
      (
        await search({
          surface: 'circle',
          sort: 'near_place',
          anchorVenueId: draft.venueId,
          limit: 5,
        })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const noGeo = await seedVenue(
      pool,
      await seedProvider(pool, `${uid}-nogeo`, 'NoGeo'),
      {
        name: 'NoGeo',
        venueType: 'hotel',
        types: [{ name: 'std', qty: 1, nights: { '2032-01-01': '100' } }],
      },
    );
    expect(
      (
        await search({
          surface: 'circle',
          sort: 'near_place',
          anchorVenueId: noGeo.venueId,
          limit: 5,
        })
      ).status,
    ).toBeGreaterThanOrEqual(400);
  });

  it('G7B4-SAME-04 circle allows venue without video; approved media/fallback', async () => {
    const anchor = await seedGeoVenue({
      name: 'AnchImg',
      venueType: 'hotel',
      lat: 24.5,
      lng: 46.5,
      withImage: true,
    });
    const peer = await seedGeoVenue({
      name: 'PeerImg',
      venueType: 'hotel',
      lat: 24.51,
      lng: 46.51,
      withImage: true,
    });
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(res.body.items.some((i: { venueId: string }) => i.venueId === peer.venueId)).toBe(
      true,
    );
    const item = res.body.items.find((i: { venueId: string }) => i.venueId === peer.venueId);
    expect(item.categoryFallbackKey).toBeTruthy();
  });

  it('G7B4-SAME-05 amenities/radius apply before ranking', async () => {
    const anchor = await seedGeoVenue({
      name: 'A5',
      venueType: 'hotel',
      lat: 25.0,
      lng: 47.0,
      withImage: true,
    });
    const withAmen = await seedGeoVenue({
      name: 'Amen',
      venueType: 'hotel',
      lat: 25.01,
      lng: 47.01,
      withImage: true,
    });
    await seedGeoVenue({
      name: 'NoAmen',
      venueType: 'hotel',
      lat: 25.005,
      lng: 47.005,
      withImage: true,
    });
    await pool.query(
      `INSERT INTO venue_amenity_links (id, venue_id, amenity_code, state)
       VALUES ($1,$2,'wifi','AVAILABLE')
       ON CONFLICT DO NOTHING`,
      [newId(), withAmen.venueId],
    );
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      amenities: ['wifi'],
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(res.body.items.map((i: { venueId: string }) => i.venueId)).toEqual([
      withAmen.venueId,
    ]);
  });

  it('G7B4-SAME-06 sameTypeOnly=false is not Same-Type profile; no diversity', async () => {
    const anchor = await seedGeoVenue({
      name: 'A6',
      venueType: 'hotel',
      lat: 26.0,
      lng: 48.0,
      withImage: true,
    });
    await seedGeoVenue({
      name: 'H6',
      venueType: 'hotel',
      lat: 26.01,
      lng: 48.01,
      withImage: true,
    });
    await seedGeoVenue({
      name: 'C6',
      venueType: 'chalet',
      lat: 26.005,
      lng: 48.005,
      withImage: true,
    });
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      sameTypeOnly: false,
      limit: 10,
    });
    expect(res.status).toBe(201);
    expect(res.body.applied.profile).toBeNull();
    expect(res.body.applied.sameTypeOnly).toBe(false);
    expect(res.body.applied.diversity.applied).toBe(false);
    const types = new Set(res.body.items.map((i: { category: string }) => i.category));
    expect(types.has('chalet')).toBe(true);
    expect(types.has('hotel')).toBe(true);
  });
});
