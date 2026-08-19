import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { pool, seedProvider, seedVenue } from '../helpers/seed';

describe('wave1_rate_plans', () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    db = pool();
  });

  afterAll(async () => {
    await app.close();
    await db.end();
  });

  it('T-W1-RP-01 create/list/patch rate plans', async () => {
    const owner = 'w1-rp-owner';
    const providerId = await seedProvider(db, owner, 'W1RP');
    const seeded = await seedVenue(db, providerId, {
      name: 'W1 Hotel',
      venueType: 'hotel',
      types: [{ name: 'STD', qty: 2, nights: { '2026-12-20': '120' } }],
    });
    const invId = seeded.types.STD!;

    const created = await request(app.getHttpServer())
      .post('/v1/provider/rate-plans')
      .set('Authorization', auth(owner, 'placesProvider'))
      .set('Idempotency-Key', 'w1-rp-create-1')
      .send({
        providerId,
        venueId: seeded.venueId,
        inventoryTypeId: invId,
        name: 'موسمي',
        currency: 'SAR',
        isDefault: true,
      })
      .expect(201);

    expect(created.body.id).toBeTruthy();
    expect(created.body.inventoryTypeId).toBe(invId);
    expect(created.body.isDefault).toBe(true);

    const listed = await request(app.getHttpServer())
      .get(`/v1/provider/rate-plans?providerId=${providerId}&venueId=${seeded.venueId}`)
      .set('Authorization', auth(owner, 'placesProvider'))
      .expect(200);
    expect(listed.body.items.length).toBeGreaterThanOrEqual(2);

    const patched = await request(app.getHttpServer())
      .patch(`/v1/provider/rate-plans/${created.body.id}`)
      .set('Authorization', auth(owner, 'placesProvider'))
      .send({ name: 'موسمي محدث', status: 'active' })
      .expect(200);
    expect(patched.body.name).toBe('موسمي محدث');
  });
});
