import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { newId } from '../../src/shared/ids/ids';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7B.0.2 — G7B02-MEDIA-01 primary playable selection', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-g7b02-media';

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

  it('G7B02-MEDIA-01 http video must not hide playable streamUid/HTTPS video', async () => {
    const providerId = await seedProvider(pool, 'prov-g7b02-media', 'M');
    const venue = await seedVenue(pool, providerId, {
      name: 'media-priority',
      venueType: 'hotel',
      types: [{ name: 'standard', qty: 2, nights: { '2032-01-01': '200' } }],
    });
    // Unplayable http video with better sort_order — must NOT become primary
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, stream_uid, cover_url, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video','http://insecure.example/v.mp4',NULL,'https://example.test/c.jpg','approved',0)`,
      [newId(), venue.venueId, providerId],
    );
    // Playable uid-only
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, stream_uid, cover_url, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video',NULL,'cf-good-uid','https://example.test/c2.jpg','approved',9)`,
      [newId(), venue.venueId, providerId],
    );

    const res = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({ surface: 'feed', category: 'hotel', limit: 10 });
    expect(res.status).toBe(201);
    expect(res.body.total).toBe(1);
    expect(res.body.items[0].streamUid).toBe('cf-good-uid');
    expect(res.body.items[0].streamUrl).toBeNull();
  });
});
