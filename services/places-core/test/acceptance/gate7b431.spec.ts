/**
 * Gate 7B.4.3.1 — Honest PG metrics + Same-Type negative evidence (algorithm unchanged).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';

type DivMetrics = {
  resolverQueryCount: number;
  countQueryCount: number;
  distinctQueryCount: number;
  candidateQueryCount: number;
  observedPgQueryCount?: number;
  totalRequestQueryCount: number;
  queryCount: number;
};

describe('Gate 7B.4.3.1 — metrics + Same-Type evidence closure', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b431-user';

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

  async function seedFeedVenue(opts: {
    name: string;
    venueType: string;
    createdAt?: string;
    mediaModeration?: 'approved' | 'pending' | 'rejected';
    mediaKind?: 'video' | 'image';
    noMedia?: boolean;
    lat?: number;
    lng?: number;
    qty?: number;
    nights?: Record<string, string>;
    maxOccupancy?: number;
  }): Promise<{ venueId: string; providerId: string }> {
    const providerId = await seedProvider(pool, `${uid}-${newId()}`, opts.name);
    const venue = await seedVenue(pool, providerId, {
      name: opts.name,
      venueType: opts.venueType,
      types: [
        {
          name: 'std',
          qty: opts.qty ?? 4,
          nights: opts.nights ?? { '2032-01-01': '180', '2032-01-02': '180' },
        },
      ],
    });
    if (opts.maxOccupancy != null) {
      await pool.query(`UPDATE inventory_types SET max_occupancy=$2 WHERE venue_id=$1`, [
        venue.venueId,
        opts.maxOccupancy,
      ]);
    }
    if (opts.createdAt) {
      await pool.query(`UPDATE venues SET created_at=$2::timestamptz WHERE id=$1`, [
        venue.venueId,
        opts.createdAt,
      ]);
    }
    if (opts.lat != null && opts.lng != null) {
      await pool.query(`UPDATE venues SET lat=$2, lng=$3 WHERE id=$1`, [
        venue.venueId,
        opts.lat,
        opts.lng,
      ]);
    }
    if (!opts.noMedia) {
      const moderation = opts.mediaModeration ?? 'approved';
      const kind = opts.mediaKind ?? 'video';
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
         VALUES ($1,$2,$3,$4,$5,'https://example.test/c.jpg',$6,0,$7)`,
        [
          newId(),
          venue.venueId,
          providerId,
          kind,
          kind === 'video'
            ? `https://example.test/${opts.name}.mp4`
            : `https://example.test/${opts.name}.jpg`,
          moderation,
          opts.venueType,
        ],
      );
    }
    return { venueId: venue.venueId, providerId };
  }

  function lastMetrics(engine: FilterEngineService): DivMetrics {
    const m = (engine as { lastDiversityMetrics?: DivMetrics }).lastDiversityMetrics;
    expect(m).toBeDefined();
    return m!;
  }

  it('G7B431-METRICS plain feed: total=observed; buckets sum', async () => {
    for (let i = 0; i < 6; i++) {
      await seedFeedVenue({
        name: `P${i}`,
        venueType: i % 2 === 0 ? 'hotel' : 'chalet',
      });
    }
    const engine = app.get(FilterEngineService);
    await engine.search({ surface: 'feed', sort: 'newest', limit: 20 } as never);
    const m = lastMetrics(engine);
    expect(m.observedPgQueryCount).toBeDefined();
    expect(m.totalRequestQueryCount).toBe(m.observedPgQueryCount);
    expect(m.countQueryCount).toBe(1);
    expect(m.distinctQueryCount).toBe(1);
    expect(m.candidateQueryCount).toBeGreaterThan(0);
    expect(m.totalRequestQueryCount).toBe(
      m.resolverQueryCount + m.countQueryCount + m.distinctQueryCount + m.candidateQueryCount,
    );
    // Plain feed (no intent/q/anchor): resolvers may be 0 — total must still equal observed.
    console.log('G7B431_PLAIN_METRICS', JSON.stringify(m));
  });

  it('G7B431-METRICS feed+intent (+labels path) resolvers > plain', async () => {
    for (let i = 0; i < 4; i++) {
      await seedFeedVenue({ name: `Q${i}`, venueType: 'hotel' });
    }
    const engine = app.get(FilterEngineService);
    await engine.search({ surface: 'feed', sort: 'newest', limit: 20 } as never);
    const plain = lastMetrics(engine);
    await engine.search({
      surface: 'feed',
      sort: 'best',
      intent: 'family',
      limit: 20,
    } as never);
    const withIntent = lastMetrics(engine);
    expect(withIntent.totalRequestQueryCount).toBe(withIntent.observedPgQueryCount);
    expect(withIntent.resolverQueryCount).toBeGreaterThan(plain.resolverQueryCount);
    expect(withIntent.resolverQueryCount).toBeGreaterThanOrEqual(1);
    expect(withIntent.totalRequestQueryCount).toBe(
      withIntent.resolverQueryCount +
        withIntent.countQueryCount +
        withIntent.distinctQueryCount +
        withIntent.candidateQueryCount,
    );
    console.log(
      'G7B431_INTENT_METRICS',
      JSON.stringify({
        plainResolvers: plain.resolverQueryCount,
        intentResolvers: withIntent.resolverQueryCount,
        withIntent,
      }),
    );
  });

  it('G7B431-SAME-DATES peer with zero nightly capacity excluded', async () => {
    const anchor = await seedFeedVenue({
      name: 'A',
      venueType: 'hotel',
      lat: 24.6,
      lng: 46.6,
      mediaKind: 'image',
    });
    const avail = await seedFeedVenue({
      name: 'Avail',
      venueType: 'hotel',
      lat: 24.61,
      lng: 46.61,
      mediaKind: 'image',
    });
    const blocked = await seedFeedVenue({
      name: 'Blocked',
      venueType: 'hotel',
      lat: 24.605,
      lng: 46.605,
      mediaKind: 'image',
    });
    const it = await pool.query<{ id: string }>(
      `SELECT id FROM inventory_types WHERE venue_id=$1`,
      [blocked.venueId],
    );
    for (const day of ['2032-01-01', '2032-01-02']) {
      await pool.query(
        `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
         VALUES ($1,$2,$3::date,0,0,0,0)`,
        [newId(), it.rows[0].id, day],
      );
    }
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      checkIn: '2032-01-01',
      checkOut: '2032-01-03',
      limit: 20,
    });
    expect(res.status).toBe(201);
    expect(res.body.applied.availabilityMode).toBe('AVAILABLE');
    const ids = res.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids).toContain(avail.venueId);
    expect(ids).not.toContain(blocked.venueId);
    expect(ids).not.toContain(anchor.venueId);
    expect(res.body.total).toBe(1);
  });

  it('G7B431-SAME-GUESTS over capacity excluded', async () => {
    const anchor = await seedFeedVenue({
      name: 'Ag',
      venueType: 'hotel',
      lat: 24.7,
      lng: 46.7,
      mediaKind: 'image',
      maxOccupancy: 4,
    });
    const ok = await seedFeedVenue({
      name: 'CapOk',
      venueType: 'hotel',
      lat: 24.71,
      lng: 46.71,
      mediaKind: 'image',
      maxOccupancy: 4,
    });
    const tiny = await seedFeedVenue({
      name: 'CapTiny',
      venueType: 'hotel',
      lat: 24.705,
      lng: 46.705,
      mediaKind: 'image',
      maxOccupancy: 2,
    });
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      guests: 4,
      limit: 20,
    });
    expect(res.status).toBe(201);
    const ids = res.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids).toContain(ok.venueId);
    expect(ids).not.toContain(tiny.venueId);
    expect(res.body.total).toBe(1);
  });

  it('G7B431-SAME-QTY over inventory excluded', async () => {
    const anchor = await seedFeedVenue({
      name: 'Aq',
      venueType: 'hotel',
      lat: 24.8,
      lng: 46.8,
      mediaKind: 'image',
      qty: 5,
    });
    const ok = await seedFeedVenue({
      name: 'QtyOk',
      venueType: 'hotel',
      lat: 24.81,
      lng: 46.81,
      mediaKind: 'image',
      qty: 5,
    });
    const low = await seedFeedVenue({
      name: 'QtyLow',
      venueType: 'hotel',
      lat: 24.805,
      lng: 46.805,
      mediaKind: 'image',
      qty: 1,
    });
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      quantity: 3,
      checkIn: '2032-01-01',
      checkOut: '2032-01-03',
      limit: 20,
    });
    expect(res.status).toBe(201);
    const ids = res.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids).toContain(ok.venueId);
    expect(ids).not.toContain(low.venueId);
    expect(res.body.total).toBe(1);
  });

  it('G7B431-SAME-RADIUS far peer excluded', async () => {
    const anchor = await seedFeedVenue({
      name: 'Ar',
      venueType: 'hotel',
      lat: 24.9,
      lng: 46.9,
      mediaKind: 'image',
    });
    const near = await seedFeedVenue({
      name: 'Near',
      venueType: 'hotel',
      lat: 24.901,
      lng: 46.901,
      mediaKind: 'image',
    });
    const far = await seedFeedVenue({
      name: 'Far',
      venueType: 'hotel',
      lat: 25.5,
      lng: 47.5,
      mediaKind: 'image',
    });
    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      radiusKm: 2,
      limit: 20,
    });
    expect(res.status).toBe(201);
    const ids = res.body.items.map((i: { venueId: string }) => i.venueId);
    expect(ids).toContain(near.venueId);
    expect(ids).not.toContain(far.venueId);
    expect(res.body.total).toBe(1);
  });

  it('G7B431-SAME-MEDIA pending/rejected not projected; circle keeps no-media fallback', async () => {
    const anchor = await seedFeedVenue({
      name: 'Am',
      venueType: 'hotel',
      lat: 25.0,
      lng: 47.0,
      mediaKind: 'image',
    });
    const approved = await seedFeedVenue({
      name: 'Approved',
      venueType: 'hotel',
      lat: 25.01,
      lng: 47.01,
      mediaKind: 'image',
    });
    const pending = await seedFeedVenue({
      name: 'Pending',
      venueType: 'hotel',
      lat: 25.005,
      lng: 47.005,
      mediaModeration: 'pending',
      mediaKind: 'image',
    });
    const rejected = await seedFeedVenue({
      name: 'Rejected',
      venueType: 'hotel',
      lat: 25.002,
      lng: 47.002,
      mediaModeration: 'rejected',
      mediaKind: 'image',
    });
    const noMedia = await seedFeedVenue({
      name: 'NoMedia',
      venueType: 'hotel',
      lat: 25.008,
      lng: 47.008,
      noMedia: true,
    });

    const res = await search({
      surface: 'circle',
      sort: 'near_place',
      anchorVenueId: anchor.venueId,
      radiusKm: 50,
      limit: 20,
    });
    expect(res.status).toBe(201);
    const byId = new Map(
      res.body.items.map((i: { venueId: string }) => [i.venueId, i]),
    );
    // Circle does not drop venues solely for missing approved media.
    expect(byId.has(approved.venueId)).toBe(true);
    expect(byId.has(noMedia.venueId)).toBe(true);
    expect(byId.has(pending.venueId)).toBe(true);
    expect(byId.has(rejected.venueId)).toBe(true);

    const okItem = byId.get(approved.venueId) as {
      primaryMediaId?: string | null;
      coverUrl?: string | null;
      categoryFallbackKey?: string | null;
    };
    expect(okItem.primaryMediaId).toBeTruthy();
    expect(okItem.coverUrl).toBeTruthy();

    for (const id of [pending.venueId, rejected.venueId, noMedia.venueId]) {
      const item = byId.get(id) as {
        primaryMediaId?: string | null;
        streamUrl?: string | null;
        coverUrl?: string | null;
        categoryFallbackKey?: string | null;
      };
      // Pending/rejected media must not appear as projected primary media.
      expect(item.primaryMediaId == null || item.primaryMediaId === '').toBe(true);
      expect(item.streamUrl == null || item.streamUrl === '').toBe(true);
      expect(item.categoryFallbackKey).toBeTruthy();
    }
  });
});
