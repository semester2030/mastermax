import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { haversineKm } from '../../src/modules/filters/application/discovery-geo';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7B.0.4 — G7B04-GEO-02 DB/API radius inclusion', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-g7b04-geo';

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

  it('G7B04-GEO-02 origin=(0,0) radius=200 venue=(1.797,0) appears in discovery', async () => {
    expect(haversineKm(0, 0, 1.797, 0)).toBeLessThanOrEqual(200);

    const providerId = await seedProvider(pool, 'prov-g7b04-geo', 'G');
    const venue = await seedVenue(pool, providerId, {
      name: 'edge-radius',
      venueType: 'hotel',
      types: [{ name: 'standard', qty: 2, nights: { '2032-01-01': '200' } }],
    });
    await pool.query(`UPDATE venues SET lat=$2, lng=$3 WHERE id=$1`, [venue.venueId, 1.797, 0]);

    const res = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({
        surface: 'map',
        category: 'hotel',
        lat: 0,
        lng: 0,
        radiusKm: 200,
        limit: 10,
      });
    expect(res.status).toBe(201);
    expect(res.body.total).toBeGreaterThanOrEqual(1);
    expect(res.body.items.some((i: { venueId: string }) => i.venueId === venue.venueId)).toBe(true);
  });
});
