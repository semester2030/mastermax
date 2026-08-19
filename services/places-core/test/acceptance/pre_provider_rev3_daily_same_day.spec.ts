/**
 * REV3: daily same-day quote → hold → confirm; catalog returns bookingMode.
 */
import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

function sig(body: string): string {
  return createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string)
    .update(body)
    .digest('hex');
}

describe('pre_provider_rev3 — daily same-day + bookingMode', () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await db.end();
  });

  it('daily same-day quote/hold/confirm + catalog bookingMode', async () => {
    const uid = 'rev3-daily-same';
    const providerId = await seedProvider(db, 'owner-daily-same', 'DailySame');
    const day = '2026-11-15';
    const seeded = await seedVenue(db, providerId, {
      name: 'Daily Farm',
      venueType: 'farm',
      mode: 'daily',
      types: [{ name: 'Unit', qty: 3, nights: { [day]: '250.00' } }],
    });
    const typeId = seeded.types.Unit;

    const details = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}`)
      .set('Authorization', auth(uid))
      .expect(200);
    expect(details.body.bookingMode).toBe('daily');
    expect(details.body.booking_mode).toBe('daily');

    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: day,
        checkOut: day,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `daily-same-${Date.now()}`)
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);
    expect(hold.body.bookingId).toBeTruthy();

    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `daily-pay-${Date.now()}`)
      .send({ holdId: hold.body.holdId })
      .expect(201);

    const paymentId = intent.body.paymentId as string;
    const payload = JSON.stringify({
      eventId: `evt-daily-${paymentId}`,
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(payload))
      .set('Content-Type', 'application/json')
      .send(payload)
      .expect(201);

    const booking = await request(app.getHttpServer())
      .get(`/v1/bookings/${hold.body.bookingId}`)
      .set('Authorization', auth(uid))
      .expect(200);
    expect(booking.body.status).toBe('CONFIRMED');
    expect(booking.body.commission_bps).toBeUndefined();
    expect(booking.body.provider_net).toBeUndefined();
  });

  it('nightly rejects same-day quote', async () => {
    const uid = 'rev3-nightly-same';
    const providerId = await seedProvider(db, 'owner-nightly-same', 'NightSame');
    const day = '2026-11-20';
    const seeded = await seedVenue(db, providerId, {
      name: 'Night Hotel',
      venueType: 'hotel',
      mode: 'nightly',
      types: [{ name: 'Std', qty: 2, nights: { [day]: '100.00' } }],
    });
    await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: day,
        checkOut: day,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(400);
  });
});
