import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';
import { seedProvider, seedVenue } from '../helpers/seed';
import { encodeCursor } from '../../src/modules/filters/application/discovery-cursor';
import { encodeTestCursorV2 } from '../helpers/cursor-v2';
import { applyMigrationsThrough, applyRemainingMigrations } from '../helpers/migrate-partial';
import { testEnv } from '../helpers/test-app';
import { dropPublicSchemaForCi } from '../helpers/db-safety';

describe('Gate 7A.3.1 — Final evidence closure', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7a31-consumer';
  const providerUid = 'g7a31-provider';

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  async function paySucceed(holdId: string, user: string, key: string) {
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(user))
      .set('Idempotency-Key', key)
      .send({ holdId })
      .expect(201);
    const paymentId = intent.body.paymentId as string;
    const body = JSON.stringify({
      eventId: `evt-${paymentId}`,
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${paymentId}`,
    });
    const sig = createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string)
      .update(body)
      .digest('hex');
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig)
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    return paymentId;
  }

  it('A — provider publish rejected when provider=false and when capability missing; venue stays draft', async () => {
    const providerId = await seedProvider(pool, providerUid, 'PubCo');
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_provider=TRUE WHERE venue_type='villa'`,
    );

    const created = await request(app.getHttpServer())
      .post('/v1/provider/venues')
      .set('Authorization', auth(providerUid, 'placesProvider'))
      .send({
        providerId,
        name: 'Draft Villa',
        venueType: 'villa',
        bookingMode: 'nightly',
        city: 'Riyadh',
      })
      .expect(201);
    const venueId = created.body.venueId as string;
    expect(venueId).toBeTruthy();

    const before = await pool.query<{ status: string }>(`SELECT status FROM venues WHERE id=$1`, [
      venueId,
    ]);
    expect(before.rows[0].status).toBe('draft');

    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_provider=FALSE WHERE venue_type='villa'`,
    );

    const nameBeforeOff = await pool.query<{ name: string; updated_at: Date }>(
      `SELECT name, updated_at FROM venues WHERE id=$1`,
      [venueId],
    );

    const publishOff = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId}`)
      .set('Authorization', auth(providerUid, 'placesProvider'))
      .send({ status: 'published' });
    expect(publishOff.status).toBe(400);
    expect(publishOff.body.code).toBe('VALIDATION_ERROR');
    expect(publishOff.status).not.toBe(500);

    const afterOff = await pool.query<{ status: string; name: string; updated_at: Date }>(
      `SELECT status, name, updated_at FROM venues WHERE id=$1`,
      [venueId],
    );
    expect(afterOff.rows[0].status).toBe('draft');
    expect(afterOff.rows[0].name).toBe(nameBeforeOff.rows[0].name);
    expect(new Date(afterOff.rows[0].updated_at).getTime()).toBe(
      new Date(nameBeforeOff.rows[0].updated_at).getTime(),
    );

    // Missing capability row → fail-closed on another draft venue
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_provider=TRUE WHERE venue_type='resort'`,
    );
    const created2 = await request(app.getHttpServer())
      .post('/v1/provider/venues')
      .set('Authorization', auth(providerUid, 'placesProvider'))
      .send({
        providerId,
        name: 'Draft Resort',
        venueType: 'resort',
        bookingMode: 'nightly',
        city: 'Jeddah',
      })
      .expect(201);
    const venueId2 = created2.body.venueId as string;
    const beforeMissing = await pool.query<{ status: string; name: string; updated_at: Date }>(
      `SELECT status, name, updated_at FROM venues WHERE id=$1`,
      [venueId2],
    );
    expect(beforeMissing.rows[0].status).toBe('draft');
    await pool.query(`DELETE FROM venue_type_capabilities WHERE venue_type='resort'`);

    const publishMissing = await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId2}`)
      .set('Authorization', auth(providerUid, 'placesProvider'))
      .send({ status: 'published' });
    expect(publishMissing.status).toBe(400);
    expect(publishMissing.body.code).toBe('VALIDATION_ERROR');
    expect(publishMissing.status).not.toBe(500);
    const afterMissing = await pool.query<{ status: string; name: string; updated_at: Date }>(
      `SELECT status, name, updated_at FROM venues WHERE id=$1`,
      [venueId2],
    );
    expect(afterMissing.rows[0].status).toBe('draft');
    expect(afterMissing.rows[0].name).toBe(beforeMissing.rows[0].name);
    expect(new Date(afterMissing.rows[0].updated_at).getTime()).toBe(
      new Date(beforeMissing.rows[0].updated_at).getTime(),
    );

    // Regression: create also denied when provider=false
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_provider=FALSE WHERE venue_type='villa'`,
    );
    const createDenied = await request(app.getHttpServer())
      .post('/v1/provider/venues')
      .set('Authorization', auth(providerUid, 'placesProvider'))
      .send({
        providerId,
        name: 'Should Fail',
        venueType: 'villa',
        bookingMode: 'nightly',
        city: 'Riyadh',
      });
    expect(createDenied.status).toBe(400);
    expect(createDenied.body.code).toBe('VALIDATION_ERROR');
    expect(createDenied.status).not.toBe(500);

    // restore
    await pool.query(
      `INSERT INTO venue_type_capabilities (venue_type, label_ar, label_en, enabled_for_discovery, enabled_for_booking, enabled_for_provider, enabled_for_admin, booking_semantics, sort_order)
       VALUES ('resort','منتجع','Resort',TRUE,TRUE,TRUE,TRUE,'accommodation',70)
       ON CONFLICT (venue_type) DO UPDATE SET enabled_for_provider=TRUE, enabled_for_booking=TRUE`,
    );
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_provider=TRUE WHERE venue_type='villa'`,
    );
  });

  it('B — existing CONFIRMED booking remains readable/cancellable after booking capability OFF', async () => {
    const providerId = await seedProvider(pool, `${providerUid}-b`, 'BookCo');
    const seeded = await seedVenue(pool, providerId, {
      name: 'Bookable Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 5,
          nights: { '2027-03-10': '150', '2027-03-11': '150' },
        },
      ],
    });
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking=TRUE, enabled_for_discovery=TRUE WHERE venue_type='hotel'`,
    );

    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2027-03-10',
        checkOut: '2027-03-12',
        quantity: 1,
        guestsAdults: 1,
        guestsChildren: 0,
        extraIds: [],
      })
      .expect(201);

    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `h-${newId()}`)
      .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);

    await paySucceed(hold.body.holdId, uid, `pay-${newId()}`);

    const bookingRow = await pool.query<{ id: string; status: string }>(
      `SELECT id, status FROM bookings WHERE hold_id=$1`,
      [hold.body.holdId],
    );
    expect(bookingRow.rows[0].status).toBe('CONFIRMED');
    const bookingId = bookingRow.rows[0].id;

    // Turn booking capability OFF — new booking blocked, existing remains
    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking=FALSE WHERE venue_type='hotel'`,
    );

    const newQuote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.Std,
        checkIn: '2027-04-01',
        checkOut: '2027-04-02',
        quantity: 1,
        guestsAdults: 1,
        guestsChildren: 0,
        extraIds: [],
      });
    expect(newQuote.status).toBeGreaterThanOrEqual(400);

    const list = await request(app.getHttpServer())
      .get('/v1/bookings')
      .set('Authorization', auth(uid))
      .expect(200);
    expect(Array.isArray(list.body)).toBe(true);
    const listed = list.body.find((b: { id: string }) => b.id === bookingId);
    expect(listed).toBeDefined();
    expect(listed.id).toBe(bookingId);

    const details = await request(app.getHttpServer())
      .get(`/v1/bookings/${bookingId}`)
      .set('Authorization', auth(uid))
      .expect(200);
    expect(details.body.id).toBe(bookingId);
    expect(details.body.status).toBe('CONFIRMED');

    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${bookingId}/cancel`)
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `cancel-${newId()}`)
      .send({ reason: 'guest cancel after capability off' })
      .expect(200);
    expect(cancel.body.refundId).toBeTruthy();
    expect(cancel.body.status).toBeTruthy();

    const after = await pool.query<{ status: string; cancelled_at: Date | null }>(
      `SELECT status, cancelled_at FROM bookings WHERE id=$1`,
      [bookingId],
    );
    expect(['CANCELLED', 'REFUNDED']).toContain(after.rows[0].status);
    expect(after.rows[0].cancelled_at).toBeTruthy();

    const refund = await pool.query<{ id: string; status: string; amount: string }>(
      `SELECT id, status, amount::text FROM refunds WHERE booking_id=$1`,
      [bookingId],
    );
    expect(refund.rows).toHaveLength(1);
    expect(refund.rows[0].id).toBe(cancel.body.refundId);
    expect(['pending', 'succeeded', 'completed', 'processing']).toContain(refund.rows[0].status);

    const ledger = await pool.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE booking_id=$1`,
      [bookingId],
    );
    expect(Number(ledger.rows[0].c)).toBeGreaterThan(0);

    const receivable = await pool.query<{ status: string }>(
      `SELECT status FROM provider_receivables WHERE booking_id=$1`,
      [bookingId],
    );
    if (receivable.rowCount) {
      expect(['adjusted', 'void', 'cancelled', 'pending', 'eligible']).toContain(
        receivable.rows[0].status,
      );
    }

    await pool.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking=TRUE WHERE venue_type='hotel'`,
    );
  });

  it('C — newest cursor rejects impossible ISO dates before SQL; accepts valid', async () => {
    const validId = newId();
    const newestBody = { sort: 'newest', limit: 5 };
    const valid = encodeTestCursorV2(newestBody, {
      sv: '2031-06-15T12:30:00.000Z',
      id: validId,
    });
    // empty result is fine; must not 500
    const ok = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(uid))
      .send({ ...newestBody, cursor: valid });
    expect(ok.status).toBe(201);

    const impossible = encodeCursor({
      v: 1,
      sort: 'newest',
      sv: '2035-99-99T99:99:99Z',
      id: newId(),
    });
    const bad = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(uid))
      .send({ sort: 'newest', cursor: impossible });
    expect(bad.status).toBeGreaterThanOrEqual(400);

    const badMonth = encodeCursor({
      v: 1,
      sort: 'newest',
      sv: '2031-13-01T00:00:00Z',
      id: newId(),
    });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'newest', cursor: badMonth })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const badDay = encodeCursor({
      v: 1,
      sort: 'newest',
      sv: '2031-02-31T00:00:00Z',
      id: newId(),
    });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'newest', cursor: badDay })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const badHour = encodeCursor({
      v: 1,
      sort: 'newest',
      sv: '2031-01-01T25:00:00Z',
      id: newId(),
    });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'newest', cursor: badHour })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const badSv = encodeCursor({ v: 1, sort: 'cheapest', sv: 'abc', id: newId() });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'cheapest', cursor: badSv })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const badSv2 = encodeCursor({
      v: 1,
      sort: 'rating',
      sv: '4.5',
      sv2: 'x',
      id: newId(),
    });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'rating', cursor: badSv2 })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const badUuid = encodeCursor({
      v: 1,
      sort: 'best',
      sv: '4',
      sv2: '1',
      id: 'not-a-uuid',
    });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'best', cursor: badUuid })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    const mismatch = encodeCursor({
      v: 1,
      sort: 'cheapest',
      sv: '10',
      id: newId(),
    });
    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'newest', cursor: mismatch })
      ).status,
    ).toBeGreaterThanOrEqual(400);

    expect(
      (
        await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(uid))
          .send({ sort: 'newest', cursor: '!!!' })
      ).status,
    ).toBeGreaterThanOrEqual(400);
  });
});

describe('Gate 7A.3.1 — migration evidence (clean + upgrade)', () => {
  it('clean 001→009 and upgrade from 006 with duplicates', async () => {
    testEnv();
    const pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await dropPublicSchemaForCi(pool);
    await applyMigrationsThrough(pool, '009_gate7a3_final_closure.sql');
    const clean = await pool.query(`SELECT id FROM schema_migrations ORDER BY id`);
    expect(clean.rows.some((r) => String(r.id).includes('009'))).toBe(true);

    await dropPublicSchemaForCi(pool);
    await applyMigrationsThrough(pool, '006_gate7a_filter_engine.sql');
    const customId = newId();
    const d1 = newId();
    const d2 = newId();
    await pool.query(
      `INSERT INTO filter_definitions (id, key, venue_type, label_ar, value_type, operator, indexed, options_json, status)
       VALUES
         ($1,'city',NULL,'c1','enum','eq',true,'[]'::jsonb,'inactive'),
         ($2,'city',NULL,'c2','enum','eq',true,'[]'::jsonb,'inactive'),
         ($3,'custom_admin_only','hotel','مخصص','bool','eq',false,'{}'::jsonb,'inactive')`,
      [d1, d2, customId],
    );
    await applyRemainingMigrations(pool);
    const custom = await pool.query(`SELECT key FROM filter_definitions WHERE id=$1`, [customId]);
    expect(custom.rows[0].key).toBe('custom_admin_only');
    await pool.end();
  }, 120_000);
});
