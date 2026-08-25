import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { pool, seedProvider, seedVenue } from '../helpers/seed';
import { ReceivableEligibilityService } from '../../src/modules/settlements/application/receivable-eligibility.service';

/**
 * Gate 3D.1 — Settlement Ledger Attribution (OPTION A)
 * AL–AP
 */
describe('Gate 3D.1 AL–AP Settlement Ledger Attribution', () => {
  let app: INestApplication;

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  function sig(body: string): string {
    return createHmac('sha256', process.env.STUB_WEBHOOK_SECRET as string).update(body).digest('hex');
  }

  async function book(opts: {
    providerId: string;
    venueId: string;
    typeId: string;
    uid: string;
    checkIn: string;
    checkOut: string;
    tag: string;
  }) {
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(opts.uid))
      .send({
        venueId: opts.venueId,
        inventoryTypeId: opts.typeId,
        checkIn: opts.checkIn,
        checkOut: opts.checkOut,
        quantity: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `al-h-${opts.tag}`)
      .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `al-p-${opts.tag}`)
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: `al-evt-${opts.tag}`,
      type: 'payment.succeeded',
      pspIntentId: `stub_pi_${intent.body.paymentId}`,
    });
    await request(app.getHttpServer())
      .post('/v1/webhooks/psp/stub')
      .set('X-Stub-Signature', sig(body))
      .set('Content-Type', 'application/json')
      .send(body)
      .expect(201);
    return {
      bookingId: hold.body.bookingId as string,
      providerNet: q.body.providerNet as string,
      gross: q.body.grossTotal as string,
    };
  }

  it('AL MULTI_BOOKING_SETTLEMENT_ATTRIBUTION — settlement/payout booking_id NULL', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'al-owner', 'ALCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'AL',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 10,
          nights: {
            '2026-09-01': '1000',
            '2026-09-02': '0',
            '2026-09-05': '555.56',
            '2026-09-06': '0',
          },
        },
      ],
    });
    await db.end();

    const a = await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'al-a',
      checkIn: '2026-09-01',
      checkOut: '2026-09-02',
      tag: 'a',
    });
    const b = await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'al-b',
      checkIn: '2026-09-05',
      checkOut: '2026-09-06',
      tag: 'b',
    });

    await app.get(ReceivableEligibilityService).promoteDue('2026-09-10');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-al', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(2);
    expect(draft.body.net).toBe('1400.00');

    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-al', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    const items = await db2.query<{ booking_id: string; amount_snapshot: string }>(
      `SELECT booking_id, amount_snapshot::text FROM settlement_items WHERE settlement_id = $1 ORDER BY amount_snapshot DESC`,
      [draft.body.settlementId],
    );
    expect(items.rows.map((r) => r.booking_id).sort()).toEqual([a.bookingId, b.bookingId].sort());
    expect(items.rows.find((r) => r.booking_id === a.bookingId)?.amount_snapshot).toBe('900.00');
    expect(items.rows.find((r) => r.booking_id === b.bookingId)?.amount_snapshot).toBe('500.00');

    const led = await db2.query<{
      type: string;
      amount: string;
      booking_id: string | null;
      reference: string;
      provider_id: string;
    }>(
      `SELECT type, amount::text, booking_id, reference, provider_id
       FROM ledger_entries
       WHERE reference = $1 AND type IN ('settlement','payout')
       ORDER BY type`,
      [`settlement:${draft.body.settlementId}`],
    );
    await db2.end();

    expect(led.rows).toHaveLength(2);
    const settlement = led.rows.find((r) => r.type === 'settlement');
    const payout = led.rows.find((r) => r.type === 'payout');
    expect(settlement?.amount).toBe('1400.00');
    expect(payout?.amount).toBe('1400.00');
    expect(settlement?.booking_id).toBeNull();
    expect(payout?.booking_id).toBeNull();
    expect(settlement?.provider_id).toBe(providerId);
    expect(payout?.provider_id).toBe(providerId);
    expect(settlement?.reference).toBe(`settlement:${draft.body.settlementId}`);
  });

  it('AM SINGLE_BOOKING_SETTLEMENT — still booking_id NULL (no special case)', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'am-owner', 'AMCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'AM',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 5, nights: { '2026-09-10': '200', '2026-09-11': '0' } }],
    });
    await db.end();

    await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'am-u',
      checkIn: '2026-09-10',
      checkOut: '2026-09-11',
      tag: 'am1',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-15');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-am', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(1);
    expect(draft.body.net).toBe('180.00');

    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-am', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    const led = await db2.query<{ booking_id: string | null; type: string; amount: string }>(
      `SELECT booking_id, type, amount::text FROM ledger_entries
       WHERE reference = $1 AND type IN ('settlement','payout')`,
      [`settlement:${draft.body.settlementId}`],
    );
    await db2.end();
    expect(led.rows).toHaveLength(2);
    for (const row of led.rows) {
      expect(row.booking_id).toBeNull();
      expect(row.amount).toBe('180.00');
    }
  });

  it('AN BOOKING_FINANCIAL_HISTORY_ISOLATION — no full settlement on booking_id', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'an-owner', 'ANCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'AN',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 10,
          nights: {
            '2026-09-01': '1000',
            '2026-09-02': '0',
            '2026-09-05': '555.56',
            '2026-09-06': '0',
          },
        },
      ],
    });
    await db.end();

    const a = await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'an-a',
      checkIn: '2026-09-01',
      checkOut: '2026-09-02',
      tag: 'an-a',
    });
    const b = await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'an-b',
      checkIn: '2026-09-05',
      checkOut: '2026-09-06',
      tag: 'an-b',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-10');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-an', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-an', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    for (const bookingId of [a.bookingId, b.bookingId]) {
      const hist = await db2.query<{ type: string; amount: string }>(
        `SELECT type, amount::text FROM ledger_entries WHERE booking_id = $1 AND type IN ('settlement','payout')`,
        [bookingId],
      );
      expect(hist.rows).toHaveLength(0);

      const misattr = await db2.query<{ c: number }>(
        `SELECT count(*)::int AS c FROM ledger_entries
         WHERE booking_id = $1 AND type IN ('settlement','payout') AND amount = 1400`,
        [bookingId],
      );
      expect(misattr.rows[0].c).toBe(0);
    }
    await db2.end();
  });

  it('AO SETTLEMENT_TRACEABILITY — settlement → items → bookings → ledger', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'ao-owner', 'AOCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'AO',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 10,
          nights: {
            '2026-09-01': '1000',
            '2026-09-02': '0',
            '2026-09-05': '555.56',
            '2026-09-06': '0',
          },
        },
      ],
    });
    await db.end();

    const a = await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'ao-a',
      checkIn: '2026-09-01',
      checkOut: '2026-09-02',
      tag: 'ao-a',
    });
    const b = await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'ao-b',
      checkIn: '2026-09-05',
      checkOut: '2026-09-06',
      tag: 'ao-b',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-10');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ao', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    const settlementId = draft.body.settlementId as string;
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${settlementId}/pay`)
      .set('Authorization', auth('fin-ao', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    const s = await db2.query<{ net: string; provider_id: string; status: string }>(
      `SELECT net::text, provider_id, status FROM settlements WHERE id = $1`,
      [settlementId],
    );
    expect(s.rows[0].net).toBe('1400.00');
    expect(s.rows[0].provider_id).toBe(providerId);
    expect(s.rows[0].status).toBe('paid');

    const items = await db2.query<{ booking_id: string }>(
      `SELECT booking_id FROM settlement_items WHERE settlement_id = $1`,
      [settlementId],
    );
    expect(items.rows.map((r) => r.booking_id).sort()).toEqual([a.bookingId, b.bookingId].sort());

    const led = await db2.query<{ type: string; booking_id: string | null }>(
      `SELECT type, booking_id FROM ledger_entries WHERE reference = $1 ORDER BY type`,
      [`settlement:${settlementId}`],
    );
    const payout = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payouts WHERE settlement_id = $1`,
      [settlementId],
    );
    await db2.end();

    expect(led.rows.map((r) => r.type).sort()).toEqual(['payout', 'settlement']);
    expect(led.rows.every((r) => r.booking_id === null)).toBe(true);
    expect(payout.rows[0].c).toBe(1);
  });

  it('AP LEDGER_BALANCE_AFTER_ATTRIBUTION — balanced pair, no duplicates', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'ap-owner', 'APCo');
    const seeded = await seedVenue(db, providerId, {
      name: 'AP',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 10,
          nights: {
            '2026-09-01': '1000',
            '2026-09-02': '0',
            '2026-09-05': '555.56',
            '2026-09-06': '0',
          },
        },
      ],
    });
    await db.end();

    await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'ap-a',
      checkIn: '2026-09-01',
      checkOut: '2026-09-02',
      tag: 'ap-a',
    });
    await book({
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Std,
      uid: 'ap-b',
      checkIn: '2026-09-05',
      checkOut: '2026-09-06',
      tag: 'ap-b',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-10');

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ap', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-ap', 'placesAdmin,placesFinance'))
      .expect(201);
    // idempotent second pay
    await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-ap', 'placesAdmin,placesFinance'))
      .expect(201);

    const db2 = pool();
    const bal = await db2.query<{ direction: string; total: string }>(
      `SELECT direction, sum(amount)::text AS total
       FROM ledger_entries
       WHERE reference = $1 AND type IN ('settlement','payout')
       GROUP BY direction`,
      [`settlement:${draft.body.settlementId}`],
    );
    const counts = await db2.query<{ type: string; c: number }>(
      `SELECT type, count(*)::int AS c FROM ledger_entries
       WHERE reference = $1 AND type IN ('settlement','payout')
       GROUP BY type`,
      [`settlement:${draft.body.settlementId}`],
    );
    const imm = await db2.query<{ id: string }>(
      `SELECT id FROM ledger_entries WHERE reference = $1 LIMIT 1`,
      [`settlement:${draft.body.settlementId}`],
    );
    await expect(
      db2.query(`UPDATE ledger_entries SET amount = amount WHERE id = $1`, [imm.rows[0].id]),
    ).rejects.toThrow(/append-only|ledger_entries/);
    await expect(db2.query(`DELETE FROM ledger_entries WHERE id = $1`, [imm.rows[0].id])).rejects.toThrow(
      /append-only|ledger_entries/,
    );
    await db2.end();

    const byDir = Object.fromEntries(bal.rows.map((r) => [r.direction, r.total]));
    expect(byDir.debit).toBe('1400.00');
    expect(byDir.credit).toBe('1400.00');
    const byType = Object.fromEntries(counts.rows.map((r) => [r.type, r.c]));
    expect(byType.settlement).toBe(1);
    expect(byType.payout).toBe(1);
  });
});
