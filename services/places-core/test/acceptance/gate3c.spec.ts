import { INestApplication } from '@nestjs/common';
import { createHmac } from 'crypto';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { pool, seedProvider, seedVenue } from '../helpers/seed';
import { ReceivableEligibilityService } from '../../src/modules/settlements/application/receivable-eligibility.service';
import {
  REFUND_STALE_SECONDS,
  RefundService,
} from '../../src/modules/booking/application/refund.service';
import { PAYMENT_PORT, PaymentPort, RefundInput } from '../../src/modules/payments/domain/payment.port';
import { newId } from '../../src/shared/ids/ids';
import { PgService } from '../../src/shared/database/pg.service';

describe('Gate 3C AD–AK Financial Integrity', () => {
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

  async function confirmStay(opts: {
    owner: string;
    uid: string;
    nights: Record<string, string>;
    checkIn: string;
    checkOut: string;
    eventId: string;
    providerId?: string;
    venueId?: string;
    typeId?: string;
  }) {
    let providerId = opts.providerId;
    let venueId = opts.venueId;
    let typeId = opts.typeId;
    if (!providerId || !venueId || !typeId) {
      const db = pool();
      providerId = await seedProvider(db, opts.owner, opts.owner);
      const seeded = await seedVenue(db, providerId, {
        name: `V-${opts.owner}`,
        venueType: 'hotel',
        types: [{ name: 'Std', qty: 20, nights: opts.nights }],
      });
      await db.end();
      venueId = seeded.venueId;
      typeId = seeded.types.Std;
    }
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(opts.uid))
      .send({
        venueId,
        inventoryTypeId: typeId,
        checkIn: opts.checkIn,
        checkOut: opts.checkOut,
        quantity: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `h-${opts.eventId}`)
      .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const intent = await request(app.getHttpServer())
      .post('/v1/payments/intents')
      .set('Authorization', auth(opts.uid))
      .set('Idempotency-Key', `p-${opts.eventId}`)
      .send({ holdId: hold.body.holdId })
      .expect(201);
    const body = JSON.stringify({
      eventId: opts.eventId,
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
      providerId: providerId!,
      venueId: venueId!,
      typeId: typeId!,
      bookingId: hold.body.bookingId as string,
      paymentId: intent.body.paymentId as string,
    };
  }

  it('AD settlement stale snapshot rejected after refund/adjustment', async () => {
    const c = await confirmStay({
      owner: 'ad-owner',
      uid: 'ad-user',
      nights: { '2026-09-10': '1000', '2026-09-11': '0' },
      checkIn: '2026-09-10',
      checkOut: '2026-09-11',
      eventId: 'ad-evt',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-12');
    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ad', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(1);
    expect(draft.body.net).toBe('900.00');

    // Simulate post-draft adjustment (refund path also valid; SQL keeps test focused on revalidation)
    const dbAdj = pool();
    await dbAdj.query(
      `UPDATE provider_receivables SET amount = 400, status = 'adjusted', updated_at = now()
       WHERE booking_id = $1`,
      [c.bookingId],
    );
    await dbAdj.end();

    const pay = await request(app.getHttpServer())
      .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
      .set('Authorization', auth('fin-ad', 'placesAdmin,placesFinance'));
    expect(pay.status).toBe(409);
    expect(pay.body.code).toMatch(/SETTLEMENT_STALE|SETTLEMENT_REVALIDATION_FAILED/);

    const db = pool();
    const s = await db.query<{ status: string }>(`SELECT status FROM settlements WHERE id = $1`, [
      draft.body.settlementId,
    ]);
    const pays = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payouts WHERE settlement_id = $1`,
      [draft.body.settlementId],
    );
    const ledger = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE reference = $1`,
      [`settlement:${draft.body.settlementId}`],
    );
    await db.end();
    expect(s.rows[0].status).toBe('stale');
    expect(pays.rows[0].c).toBe(0);
    expect(ledger.rows[0].c).toBe(0);
  });

  it('AE concurrent settlement pay — one payout only', async () => {
    const c = await confirmStay({
      owner: 'ae-owner',
      uid: 'ae-user',
      nights: { '2026-09-12': '200', '2026-09-13': '0' },
      checkIn: '2026-09-12',
      checkOut: '2026-09-13',
      eventId: 'ae-evt',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-09-14');
    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ae', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);

    const results = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
        .set('Authorization', auth('fin-ae', 'placesAdmin,placesFinance')),
      request(app.getHttpServer())
        .post(`/v1/admin/settlements/${draft.body.settlementId}/pay`)
        .set('Authorization', auth('fin-ae', 'placesAdmin,placesFinance')),
    ]);
    expect(results.every((r) => r.status === 201)).toBe(true);

    const db = pool();
    const pays = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM payouts WHERE settlement_id = $1`,
      [draft.body.settlementId],
    );
    const ledger = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE reference = $1`,
      [`settlement:${draft.body.settlementId}`],
    );
    const st = await db.query<{ status: string }>(`SELECT status FROM settlements WHERE id = $1`, [
      draft.body.settlementId,
    ]);
    await db.end();
    expect(pays.rows[0].c).toBe(1);
    expect(ledger.rows[0].c).toBe(2);
    expect(st.rows[0].status).toBe('paid');
  });

  it('AF eligible_at cross-month — Jul check-in / Aug eligible in August only', async () => {
    const c = await confirmStay({
      owner: 'af-owner',
      uid: 'af-user',
      nights: { '2026-09-30': '100', '2026-10-01': '100' },
      checkIn: '2026-09-30',
      checkOut: '2026-10-02',
      eventId: 'af-evt',
    });
    await app.get(ReceivableEligibilityService).promoteDue('2026-10-02');
    const db = pool();
    const el = await db.query<{ eligible_at: Date; status: string }>(
      `SELECT eligible_at, status FROM provider_receivables WHERE booking_id = $1`,
      [c.bookingId],
    );
    await db.end();
    expect(el.rows[0].status).toBe('eligible');
    expect(el.rows[0].eligible_at).toBeTruthy();

    const july = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-af', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-09-01', periodEnd: '2026-10-01' })
      .expect(201);
    expect(july.body.itemCount).toBe(0);

    const aug = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-af', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-10-01', periodEnd: '2026-11-01' })
      .expect(201);
    expect(aug.body.itemCount).toBe(1);
  });

  it('AG eligible_at boundary [start, end)', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'ag-owner', 'AG');
    const seeded = await seedVenue(db, providerId, {
      name: 'AG',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 5, nights: { '2026-08-15': '100', '2026-08-16': '0' } }],
    });
    // Two synthetic eligible receivables with exact boundary timestamps
    const bookingStart = newId();
    const bookingEnd = newId();
    for (const [bid, tag] of [
      [bookingStart, 's'],
      [bookingEnd, 'e'],
    ] as const) {
      const holdId = newId();
      const quoteId = newId();
      await db.query(
        `INSERT INTO quotes (id, consumer_firebase_uid, venue_id, inventory_type_id, check_in, check_out,
          quantity, guests_adults, guests_children, currency, subtotal, extras_total, discount_total,
          tax_total, gross_total, commission_bps, commission_amount, provider_net, pricing_version, status, expires_at)
         VALUES ($1,'ag',$2,$3,'2026-08-15','2026-08-16',1,1,0,'SAR',100,0,0,0,100,1000,10,90,'v1','consumed',now())`,
        [quoteId, seeded.venueId, seeded.types.Std],
      );
      await db.query(
        `INSERT INTO booking_holds (id, quote_id, inventory_type_id, consumer_firebase_uid,
          quantity, check_in, check_out, status, expires_at, idempotency_key)
         VALUES ($1,$2,$3,'ag',1,'2026-08-15','2026-08-16','CONVERTED',now(),$4)`,
        [holdId, quoteId, seeded.types.Std, `ag-${tag}`],
      );
      await db.query(
        `INSERT INTO bookings (id, hold_id, quote_id, venue_id, provider_id, inventory_type_id, consumer_firebase_uid,
          human_code, status, quantity, check_in, check_out, currency, gross_total, commission_bps,
          commission_amount, provider_net, cancellation_policy_snapshot_json, payment_method, payment_status)
         VALUES ($1,$2,$3,$4,$5,$6,'ag',$7,'COMPLETED',1,'2026-08-15','2026-08-16','SAR',100,1000,10,90,'{}'::jsonb,'LEGACY_UNSPECIFIED','LEGACY_UNSPECIFIED')`,
        [bid, holdId, quoteId, seeded.venueId, providerId, seeded.types.Std, `AG-${tag}`],
      );
    }
    const startTs = `2026-08-01 00:00:00+03`;
    const endTs = `2026-09-01 00:00:00+03`;
    await db.query(
      `INSERT INTO provider_receivables (id, booking_id, provider_id, amount, status, eligible_at)
       VALUES ($1,$2,$3,90,'eligible',$4::timestamptz)`,
      [newId(), bookingStart, providerId, startTs],
    );
    await db.query(
      `INSERT INTO provider_receivables (id, booking_id, provider_id, amount, status, eligible_at)
       VALUES ($1,$2,$3,90,'eligible',$4::timestamptz)`,
      [newId(), bookingEnd, providerId, endTs],
    );
    await db.end();

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ag', 'placesAdmin,placesFinance'))
      .send({ providerId, periodStart: '2026-08-01', periodEnd: '2026-09-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(1);
    expect(draft.body.net).toBe('90.00');
  });

  it('AH pending receivable excluded regardless of booking dates', async () => {
    const c = await confirmStay({
      owner: 'ah-owner',
      uid: 'ah-user',
      nights: { '2026-08-20': '100', '2026-08-21': '0' },
      checkIn: '2026-08-20',
      checkOut: '2026-08-21',
      eventId: 'ah-evt',
    });
    const db = pool();
    const st = await db.query<{ status: string; eligible_at: Date | null }>(
      `SELECT status, eligible_at FROM provider_receivables WHERE booking_id = $1`,
      [c.bookingId],
    );
    await db.end();
    expect(st.rows[0].status).toBe('pending');
    expect(st.rows[0].eligible_at).toBeNull();

    const draft = await request(app.getHttpServer())
      .post('/v1/admin/settlements')
      .set('Authorization', auth('fin-ah', 'placesAdmin,placesFinance'))
      .send({ providerId: c.providerId, periodStart: '2026-08-01', periodEnd: '2026-09-01' })
      .expect(201);
    expect(draft.body.itemCount).toBe(0);
  });

  it('AI multi-worker refund claim — 50 refunds / 3 workers', async () => {
    const db = pool();
    const providerId = await seedProvider(db, 'ai-owner', 'AI');
    const seeded = await seedVenue(db, providerId, {
      name: 'AI',
      venueType: 'hotel',
      types: [{ name: 'Std', qty: 100, nights: { '2026-08-15': '50', '2026-08-16': '0' } }],
    });
    const refundIds: string[] = [];
    const calls: string[] = [];
    for (let i = 0; i < 50; i += 1) {
      const quoteId = newId();
      const holdId = newId();
      const bookingId = newId();
      const paymentId = newId();
      const refundId = newId();
      refundIds.push(refundId);
      await db.query(
        `INSERT INTO quotes (id, consumer_firebase_uid, venue_id, inventory_type_id, check_in, check_out,
          quantity, guests_adults, guests_children, currency, subtotal, extras_total, discount_total,
          tax_total, gross_total, commission_bps, commission_amount, provider_net, pricing_version, status, expires_at)
         VALUES ($1,$2,$3,$4,'2026-08-15','2026-08-16',1,1,0,'SAR',50,0,0,0,50,1000,5,45,'v1','consumed',now())`,
        [quoteId, `ai-${i}`, seeded.venueId, seeded.types.Std],
      );
      await db.query(
        `INSERT INTO booking_holds (id, quote_id, inventory_type_id, consumer_firebase_uid,
          quantity, check_in, check_out, status, expires_at, idempotency_key)
         VALUES ($1,$2,$3,$4,1,'2026-08-15','2026-08-16','CONVERTED',now(),$5)`,
        [holdId, quoteId, seeded.types.Std, `ai-${i}`, `ai-h-${i}`],
      );
      await db.query(
        `INSERT INTO bookings (id, hold_id, quote_id, venue_id, provider_id, inventory_type_id, consumer_firebase_uid,
          human_code, status, quantity, check_in, check_out, currency, gross_total, commission_bps,
          commission_amount, provider_net, cancellation_policy_snapshot_json, payment_method, payment_status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'REFUND_PENDING',1,'2026-08-15','2026-08-16','SAR',50,1000,5,45,'{}'::jsonb,'LEGACY_UNSPECIFIED','LEGACY_UNSPECIFIED')`,
        [bookingId, holdId, quoteId, seeded.venueId, providerId, seeded.types.Std, `ai-${i}`, `AI${i}`],
      );
      await db.query(
        `INSERT INTO payments (id, booking_id, hold_id, quote_id, status, amount, currency, psp_name, psp_intent_id)
         VALUES ($1,$2,$3,$4,'succeeded',50,'SAR','stub',$5)`,
        [paymentId, bookingId, holdId, quoteId, `stub_pi_${paymentId}`],
      );
      await db.query(
        `INSERT INTO provider_receivables (id, booking_id, provider_id, amount, status)
         VALUES ($1,$2,$3,45,'pending')`,
        [newId(), bookingId, providerId],
      );
      await db.query(
        `INSERT INTO refunds (id, payment_id, booking_id, amount, reason, kind, status)
         VALUES ($1,$2,$3,50,'bulk','operational','pending')`,
        [refundId, paymentId, bookingId],
      );
    }
    await db.end();

    const real = app.get<PaymentPort>(PAYMENT_PORT);
    const wrapped: PaymentPort = {
      pspName: real.pspName,
      createIntent: (i) => real.createIntent(i),
      verifySignature: (b, s) => real.verifySignature(b, s),
      parseWebhook: (b) => real.parseWebhook(b),
      refund: async (input: RefundInput) => {
        calls.push(input.operationId);
        return real.refund(input);
      },
    };
    const svc = app.get(RefundService);
    (svc as unknown as { psp: PaymentPort }).psp = wrapped;

    const [a, b, c] = await Promise.all([
      svc.claimBatch(25, 'w1'),
      svc.claimBatch(25, 'w2'),
      svc.claimBatch(25, 'w3'),
    ]);
    const claimed = [...a, ...b, ...c];
    expect(claimed.length).toBe(50);
    expect(new Set(claimed.map((x) => x.id)).size).toBe(50);

    await Promise.all(claimed.map((row) => svc.processClaimed(row, `ai:${row.id}`)));

    const db2 = pool();
    const done = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM refunds WHERE id = ANY($1::uuid[]) AND status = 'completed'`,
      [refundIds],
    );
    const ledger = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE idempotency_key LIKE 'ledger:%:refund'
         AND idempotency_key = ANY(SELECT 'ledger:' || x || ':refund' FROM unnest($1::uuid[]) x)`,
      [refundIds],
    );
    await db2.end();
    expect(done.rows[0].c).toBe(50);
    expect(ledger.rows[0].c).toBe(50);
    expect(calls.length).toBe(50);
    expect(new Set(calls).size).toBe(50);
  });

  it('AJ refund worker crash recovery', async () => {
    const c = await confirmStay({
      owner: 'aj-owner',
      uid: 'aj-user',
      nights: { '2026-08-25': '80', '2026-08-26': '0' },
      checkIn: '2026-08-25',
      checkOut: '2026-08-26',
      eventId: 'aj-evt',
    });
    const requested = await app.get(RefundService).requestRefund({
      bookingId: c.bookingId,
      actorUid: 'admin-aj',
      actorRole: 'placesAdmin',
      kind: 'full',
      reason: 'crash-test',
      correlationId: 'aj',
    });
    const claimed = await app.get(RefundService).claimOne(requested.refundId, 'crasher');
    expect(claimed).toBeTruthy();

    const db = pool();
    await db.query(
      `UPDATE refunds SET locked_at = now() - interval '2 minutes' WHERE id = $1`,
      [requested.refundId],
    );
    await db.end();

    const reaped = await app.get(RefundService).reapStale(REFUND_STALE_SECONDS);
    expect(reaped).toBeGreaterThanOrEqual(1);

    const calls: string[] = [];
    const real = app.get<PaymentPort>(PAYMENT_PORT);
    const wrapped: PaymentPort = {
      pspName: real.pspName,
      createIntent: (i) => real.createIntent(i),
      verifySignature: (b, s) => real.verifySignature(b, s),
      parseWebhook: (b) => real.parseWebhook(b),
      refund: async (input: RefundInput) => {
        calls.push(input.operationId);
        return real.refund(input);
      },
    };
    const svc = app.get(RefundService);
    (svc as unknown as { psp: PaymentPort }).psp = wrapped;

    await svc.dispatchRefund(requested.refundId, 'aj-recover');
    await svc.dispatchRefund(requested.refundId, 'aj-recover-2');

    const db2 = pool();
    const row = await db2.query<{ status: string; psp_refund_id: string }>(
      `SELECT status, psp_refund_id FROM refunds WHERE id = $1`,
      [requested.refundId],
    );
    const ledger = await db2.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE idempotency_key = $1`,
      [`ledger:${requested.refundId}:refund`],
    );
    await db2.end();
    expect(row.rows[0].status).toBe('completed');
    expect(ledger.rows[0].c).toBe(1);
    expect(calls.every((id) => id === requested.refundId)).toBe(true);
  });

  it('AK refund stable operation id / no duplicate financial effect', async () => {
    const c = await confirmStay({
      owner: 'ak-owner',
      uid: 'ak-user',
      nights: { '2026-08-27': '120', '2026-08-28': '0' },
      checkIn: '2026-08-27',
      checkOut: '2026-08-28',
      eventId: 'ak-evt',
    });
    const calls: string[] = [];
    const real = app.get<PaymentPort>(PAYMENT_PORT);
    const wrapped: PaymentPort = {
      pspName: real.pspName,
      createIntent: (i) => real.createIntent(i),
      verifySignature: (b, s) => real.verifySignature(b, s),
      parseWebhook: (b) => real.parseWebhook(b),
      refund: async (input: RefundInput) => {
        calls.push(input.operationId);
        return { pspRefundId: `stub_re_${input.operationId}` };
      },
    };
    const svc = app.get(RefundService);
    (svc as unknown as { psp: PaymentPort }).psp = wrapped;

    const requested = await svc.requestRefund({
      bookingId: c.bookingId,
      actorUid: 'admin-ak',
      actorRole: 'placesAdmin',
      kind: 'full',
      reason: 'op-id',
      correlationId: 'ak',
    });
    await svc.dispatchRefund(requested.refundId, 'ak-1');
    await svc.dispatchRefund(requested.refundId, 'ak-2');
    await svc.dispatchRefund(requested.refundId, 'ak-3');

    const db = pool();
    const ledger = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM ledger_entries WHERE idempotency_key = $1`,
      [`ledger:${requested.refundId}:refund`],
    );
    const refunds = await db.query<{ c: number }>(
      `SELECT count(*)::int AS c FROM refunds WHERE booking_id = $1 AND status = 'completed'`,
      [c.bookingId],
    );
    await db.end();
    expect(refunds.rows[0].c).toBe(1);
    expect(ledger.rows[0].c).toBe(1);
    expect(new Set(calls).size).toBe(1);
    expect(calls[0]).toBe(requested.refundId);
  });

  it('ledger immutability still holds after Gate 3C', async () => {
    const pg = app.get(PgService);
    const row = await pg.query<{ id: string }>(`SELECT id FROM ledger_entries LIMIT 1`);
    if (!row.rowCount) {
      return;
    }
    await expect(
      pg.query(`UPDATE ledger_entries SET amount = amount WHERE id = $1`, [row.rows[0].id]),
    ).rejects.toThrow(/append-only|ledger/i);
  });
});
