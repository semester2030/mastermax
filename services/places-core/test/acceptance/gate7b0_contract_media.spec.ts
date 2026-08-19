import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { newId } from '../../src/shared/ids/ids';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7B.0 — playable media + NULL cursor multi-page', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-g7b0';
  const providerUid = 'provider-g7b0-media';

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

  async function seedHotel(name: string): Promise<{ venueId: string; providerId: string }> {
    const providerId = await seedProvider(pool, `${providerUid}-${name}`, name);
    const venue = await seedVenue(pool, providerId, {
      name,
      venueType: 'hotel',
      types: [{ name: 'standard', qty: 2, nights: { '2027-01-01': '200' } }],
    });
    return { venueId: venue.venueId, providerId };
  }

  it('G7B0-MEDIA-01 provider upload-session → approve → Discovery Feed returns playable streamUid', async () => {
    const owner = `${providerUid}-playable-uid`;
    const { venueId, providerId } = await seedHotel('playable-uid');
    const session = await request(app.getHttpServer())
      .post('/v1/provider/media/videos/upload-session')
      .set('Authorization', auth(owner, 'placesProvider'))
      .set('Idempotency-Key', `unique-${Date.now()}-${Math.random()}`)
      .send({ venueId });
    expect(session.status).toBe(201);

    expect(session.body.uploadSessionId).toBeTruthy();
    expect(session.body.streamUid).toBeTruthy();

    const complete = await request(app.getHttpServer())
      .post('/v1/provider/media/videos/complete')
      .set('Authorization', auth(owner, 'placesProvider'))
      .send({
        uploadSessionId: session.body.uploadSessionId,
        purpose: 'spotlight',
        coverUrl: 'https://example.test/cover.jpg',
      });
    expect(complete.status).toBe(201);
    expect(complete.body.mediaId).toBeTruthy();
    expect(complete.body.streamUid).toBe(session.body.streamUid);

    // Admin moderation path is out of scope; Core stores pending then approve in DB.
    await pool.query(
      `UPDATE venue_media SET moderation_status = 'approved' WHERE id = $1`,
      [complete.body.mediaId],
    );
    const row = await pool.query(
      `SELECT url, stream_uid FROM venue_media WHERE id = $1`,
      [complete.body.mediaId],
    );
    expect(row.rows[0].stream_uid).toBe(session.body.streamUid);
    expect(row.rows[0].url).toMatch(/cloudflarestream\.com/);

    const res = await search({ surface: 'feed', category: 'hotel', limit: 10 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(1);
    const item = res.body.items[0];
    expect(item.venueId).toBe(venueId);
    expect(item.streamUid).toBe(session.body.streamUid);
    expect(item.streamUrl).toMatch(/cloudflarestream\.com/);

    const feed = await request(app.getHttpServer())
      .get('/v1/feed')
      .query({ category: 'hotel' })
      .set('Authorization', auth(consumer));
    expect(feed.status).toBe(200);
    expect(feed.body.items[0].streamUid).toBe(session.body.streamUid);
    expect(feed.body.items[0].streamUrl).toMatch(/cloudflarestream\.com/);
    void providerId;
  });

  it('G7B0-MEDIA-01b https url remains streamUrl; streamUid separate', async () => {
    const { venueId, providerId } = await seedHotel('playable-https');
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, stream_uid, cover_url, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video','https://customer-abc.cloudflarestream.com/uid/manifest/video.m3u8','cf-uid-2','https://example.test/c.jpg','approved',0)`,
      [newId(), venueId, providerId],
    );
    const res = await search({ surface: 'feed', category: 'hotel', limit: 10 });
    expect(res.status).toBe(201);
    expect(res.body.items[0].streamUid).toBe('cf-uid-2');
    expect(res.body.items[0].streamUrl).toBe(
      'https://customer-abc.cloudflarestream.com/uid/manifest/video.m3u8',
    );
  });

  it('G7B0-MEDIA-02 approved video without stream_uid/url is not feed-eligible', async () => {
    const { venueId, providerId } = await seedHotel('unplayable');
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, stream_uid, cover_url, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video',NULL,NULL,'https://example.test/c.jpg','approved',0)`,
      [newId(), venueId, providerId],
    );
    const res = await search({ surface: 'feed', category: 'hotel', limit: 10 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(0);
  });

  it('G7B0-CUR-NULL-01 cheapest multi-page with NULL prices: no dupes / full coverage', async () => {
    const priced: string[] = [];
    const unpriced: string[] = [];
    for (let i = 0; i < 3; i++) {
      const { venueId, providerId } = await seedHotel(`priced-${i}`);
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, starting_price_hint)
         VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,$5)`,
        [newId(), venueId, providerId, `https://example.test/p${i}.mp4`, 100 + i * 10],
      );
      priced.push(venueId);
    }
    for (let i = 0; i < 4; i++) {
      const { venueId, providerId } = await seedHotel(`nullprice-${i}`);
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, starting_price_hint)
         VALUES ($1,$2,$3,'video',$4,'https://example.test/c.jpg','approved',0,NULL)`,
        [newId(), venueId, providerId, `https://example.test/n${i}.mp4`],
      );
      unpriced.push(venueId);
    }

    const seen: string[] = [];
    let cursor: string | null = null;
    let pages = 0;
    for (;;) {
      const res = await search({
        surface: 'map',
        category: 'hotel',
        sort: 'cheapest',
        limit: 2,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      pages += 1;
      for (const item of res.body.items) {
        seen.push(item.venueId);
      }
      cursor = res.body.nextCursor;
      if (!cursor) break;
      expect(pages).toBeLessThan(20);
    }
    expect(pages).toBeGreaterThan(1);
    expect(seen).toHaveLength(7);
    expect(new Set(seen).size).toBe(7);
    expect(new Set(seen)).toEqual(new Set([...priced, ...unpriced]));
  });

  it('G7B0-CUR-NULL-02 near_me multi-page with NULL distance: no dupes / full coverage', async () => {
    const withGeo: string[] = [];
    const noGeo: string[] = [];
    for (let i = 0; i < 3; i++) {
      const { venueId, providerId } = await seedHotel(`geo-${i}`);
      await pool.query(`UPDATE venues SET lat=$2, lng=$3 WHERE id=$1`, [
        venueId,
        24.7 + i * 0.01,
        46.7,
      ]);
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order)
         VALUES ($1,$2,$3,'image','https://example.test/i.jpg','https://example.test/c.jpg','approved',0)`,
        [newId(), venueId, providerId],
      );
      withGeo.push(venueId);
    }
    for (let i = 0; i < 3; i++) {
      const { venueId, providerId } = await seedHotel(`nogeo-${i}`);
      // lat/lng remain NULL
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order)
         VALUES ($1,$2,$3,'image','https://example.test/i.jpg','https://example.test/c.jpg','approved',0)`,
        [newId(), venueId, providerId],
      );
      noGeo.push(venueId);
    }

    const seen: string[] = [];
    let cursor: string | null = null;
    let pages = 0;
    for (;;) {
      const res = await search({
        surface: 'map',
        category: 'hotel',
        sort: 'near_me',
        lat: 24.7,
        lng: 46.7,
        limit: 2,
        ...(cursor ? { cursor } : {}),
      });
      expect(res.status).toBe(201);
      pages += 1;
      for (const item of res.body.items) {
        seen.push(item.venueId);
      }
      cursor = res.body.nextCursor;
      if (!cursor) break;
      expect(pages).toBeLessThan(20);
    }
    expect(pages).toBeGreaterThan(1);
    expect(seen).toHaveLength(6);
    expect(new Set(seen).size).toBe(6);
    expect(new Set(seen)).toEqual(new Set([...withGeo, ...noGeo]));
  });
});
