/**
 * Phase 3 — availability / inventory / concurrent hold truth
 * Findings: F-V2-007, F-V2-008, F-V3-009, F-V3-010 (+ partials)
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';
import { seedProvider, seedVenue } from '../helpers/seed';
import { stayDates } from '../../src/shared/time/stay-dates';
import { HoldService } from '../../src/modules/booking/application/hold.service';

describe('phase3_inventory_truth', () => {
  let app: INestApplication;
  let db: Pool;
  const consumer = 'p3-consumer';
  const owner = 'p3-owner';

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    delete process.env.PLACES_EVENT_SLOT_ENABLED;
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 180_000);

  afterAll(async () => {
    await app.close();
    await db.end();
  });

  async function ensureDiscoverable(venueId: string, providerId: string) {
    await db.query(
      `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category)
       VALUES ($1,$2,$3,'video','https://ex/v.mp4','https://ex/c.jpg','approved',0,'hotel')
       ON CONFLICT DO NOTHING`,
      [newId(), venueId, providerId],
    );
  }

  /**
   * Dispatch a SuperTest request immediately (superagent only sends on
   * `.then`/await) and return a real Promise. This lets a request actually reach
   * — and block on — a lock BEFORE the barrier polls, so the race is genuine.
   */
  function fire(t: request.Test): Promise<request.Response> {
    return t.then((r) => r);
  }

  /**
   * Deterministic, timer-free barrier. Resolves once at least `expected` app
   * backends are blocked waiting on a heavyweight (row) lock. Uses only awaited
   * queries — no sleep / setTimeout — so ordering is driven purely by the real
   * PostgreSQL lock queue, not by wall-clock guesses.
   */
  async function waitForLockWaiters(expected: number): Promise<void> {
    for (let i = 0; i < 5000; i++) {
      const r = await db.query<{ n: number }>(
        `SELECT count(*)::int AS n
           FROM pg_stat_activity
          WHERE datname = current_database()
            AND wait_event_type = 'Lock'
            AND state = 'active'`,
      );
      if (Number(r.rows[0].n) >= expected) return;
    }
    throw new Error(`timed out waiting for ${expected} lock waiter(s)`);
  }

  it('T-DAILY-PARITY-01 stayDates nightly exclusive vs daily inclusive', () => {
    expect(stayDates('nightly', '2026-10-01', '2026-10-03')).toEqual([
      '2026-10-01',
      '2026-10-02',
    ]);
    expect(stayDates('daily', '2026-10-01', '2026-10-03')).toEqual([
      '2026-10-01',
      '2026-10-02',
      '2026-10-03',
    ]);
    expect(stayDates('daily', '2026-10-01', '2026-10-01')).toEqual([
      '2026-10-01',
    ]);
  });

  it('T-DAILY-PARITY-01 / T-AVAIL-PARITY-01 Discovery↔availability for daily + rules', async () => {
    const providerId = await seedProvider(db, owner, 'P3Daily');
    const checkIn = '2027-03-01';
    const checkOut = '2027-03-03';
    const seeded = await seedVenue(db, providerId, {
      name: 'Daily Parity Farm',
      venueType: 'farm',
      mode: 'daily',
      types: [
        {
          name: 'Unit',
          qty: 2,
          nights: {
            [checkIn]: '100',
            '2027-03-02': '100',
            [checkOut]: '100',
          },
        },
      ],
    });
    await ensureDiscoverable(seeded.venueId, providerId);
    const typeId = seeded.types.Unit;

    // Ensure capacity rows for inclusive daily dates.
    for (const d of stayDates('daily', checkIn, checkOut)) {
      await db.query(
        `INSERT INTO inventory_daily_capacity
           (id, inventory_type_id, date, capacity, held, booked, blocked)
         VALUES ($1,$2,$3::date,2,0,0,0)
         ON CONFLICT (inventory_type_id, date) DO UPDATE SET capacity = 2`,
        [newId(), typeId, d],
      );
    }

    const discOk = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({
        category: 'farm',
        sort: 'best',
        checkIn,
        checkOut,
        quantity: 1,
        limit: 20,
      });
    expect(discOk.status).toBe(201);
    expect(
      (discOk.body.items as { venueId: string }[]).some(
        (i) => i.venueId === seeded.venueId,
      ),
    ).toBe(true);

    const avail = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth(consumer))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn,
        checkOut,
        quantity: 1,
      })
      .expect(201);
    expect(avail.body.available).toBe(true);

    // Block middle day via override → discovery + availability closed.
    await db.query(
      `INSERT INTO availability_overrides
         (id, inventory_type_id, date, kind)
       VALUES ($1,$2,'2027-03-02'::date,'block')`,
      [newId(), typeId],
    );

    const discBlocked = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({
        category: 'farm',
        sort: 'best',
        checkIn,
        checkOut,
        quantity: 1,
        limit: 20,
      });
    expect(discBlocked.status).toBe(201);
    expect(
      (discBlocked.body.items as { venueId: string }[]).some(
        (i) => i.venueId === seeded.venueId,
      ),
    ).toBe(false);

    const availBlocked = await request(app.getHttpServer())
      .post('/v1/availability/search')
      .set('Authorization', auth(consumer))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn,
        checkOut,
        quantity: 1,
      })
      .expect(201);
    expect(availBlocked.body.available).toBe(false);
  });

  it('T-HOLD-RACE-01 Quote→suspend/unpublish/capability→Hold rejected', async () => {
    const providerId = await seedProvider(db, `${owner}-race`, 'P3Race');
    const seeded = await seedVenue(db, providerId, {
      name: 'Race Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 2,
          nights: { '2027-04-01': '150', '2027-04-02': '150' },
        },
      ],
    });
    const typeId = seeded.types.Std;

    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumer))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: '2027-04-01',
        checkOut: '2027-04-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    await db.query(`UPDATE providers SET status = 'suspended' WHERE id = $1`, [
      providerId,
    ]);
    const holdSusp = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(consumer))
      .set('Idempotency-Key', `p3-susp-${Date.now()}`)
      .send({ quoteId: quote.body.quoteId, quantity: 1 });
    expect(holdSusp.status).toBeGreaterThanOrEqual(400);
    await db.query(`UPDATE providers SET status = 'active' WHERE id = $1`, [
      providerId,
    ]);

    const quote2 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(`${consumer}-2`))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: '2027-04-01',
        checkOut: '2027-04-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    await db.query(`UPDATE venues SET status = 'draft' WHERE id = $1`, [
      seeded.venueId,
    ]);
    const holdUnpub = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(`${consumer}-2`))
      .set('Idempotency-Key', `p3-unpub-${Date.now()}`)
      .send({ quoteId: quote2.body.quoteId, quantity: 1 });
    expect(holdUnpub.status).toBeGreaterThanOrEqual(400);
    await db.query(`UPDATE venues SET status = 'published' WHERE id = $1`, [
      seeded.venueId,
    ]);

    const quote3 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(`${consumer}-3`))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: '2027-04-01',
        checkOut: '2027-04-03',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    await db.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking = FALSE
       WHERE venue_type = 'hotel'`,
    );
    const holdCap = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(`${consumer}-3`))
      .set('Idempotency-Key', `p3-cap-${Date.now()}`)
      .send({ quoteId: quote3.body.quoteId, quantity: 1 });
    expect(holdCap.status).toBeGreaterThanOrEqual(400);
    await db.query(
      `UPDATE venue_type_capabilities SET enabled_for_booking = TRUE
       WHERE venue_type = 'hotel'`,
    );
  });

  it('T-HOLD-RACE dual Hold on last unit → one winner', async () => {
    const providerId = await seedProvider(db, `${owner}-dual`, 'P3Dual');
    const seeded = await seedVenue(db, providerId, {
      name: 'Last Unit',
      venueType: 'chalet',
      types: [
        {
          name: 'Only',
          qty: 1,
          nights: { '2027-05-10': '200', '2027-05-11': '200' },
        },
      ],
    });
    const typeId = seeded.types.Only;
    const qA = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('dual-a'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: '2027-05-10',
        checkOut: '2027-05-12',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const qB = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth('dual-b'))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn: '2027-05-10',
        checkOut: '2027-05-12',
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    const [a, b] = await Promise.all([
      request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth('dual-a'))
        .set('Idempotency-Key', `dual-a-${Date.now()}`)
        .send({ quoteId: qA.body.quoteId, quantity: 1 }),
      request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth('dual-b'))
        .set('Idempotency-Key', `dual-b-${Date.now()}`)
        .send({ quoteId: qB.body.quoteId, quantity: 1 }),
    ]);
    const statuses = [a.status, b.status].sort();
    expect(statuses).toEqual([201, 409]);
  });

  it('T-QTY-RECON-01 increase/decrease quantity_total', async () => {
    const { CapacityService } = await import(
      '../../src/modules/inventory/application/capacity.service'
    );
    const providerId = await seedProvider(db, `${owner}-qty`, 'P3Qty');
    const seeded = await seedVenue(db, providerId, {
      name: 'Qty Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Room',
          qty: 2,
          nights: { '2027-06-01': '90', '2027-06-02': '90' },
        },
      ],
    });
    const typeId = seeded.types.Room;
    const future = '2027-06-01';
    await db.query(
      `INSERT INTO inventory_daily_capacity
         (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,$3::date,2,1,0,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE
         SET capacity = 2, held = 1, booked = 0, blocked = 0`,
      [newId(), typeId, future],
    );

    const svc = new CapacityService({} as never);
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      await svc.reconcileQuantityTotal(typeId, 5, client, future);
      await client.query(
        `UPDATE inventory_types SET quantity_total = 5 WHERE id = $1`,
        [typeId],
      );
      const row = await client.query<{ capacity: number; held: number }>(
        `SELECT capacity, held FROM inventory_daily_capacity
         WHERE inventory_type_id = $1 AND date = $2::date`,
        [typeId, future],
      );
      expect(Number(row.rows[0].capacity)).toBe(5);
      expect(Number(row.rows[0].held)).toBe(1);

      await expect(
        svc.reconcileQuantityTotal(typeId, 0, client, future),
      ).rejects.toMatchObject({
        message: expect.stringContaining('Cannot reduce'),
      });
      await client.query('ROLLBACK');
    } finally {
      client.release();
    }
  });

  it('T-FIN-HARDEN-01 partial: SAR only + default rate-plan uniqueness', async () => {
    const providerId = await seedProvider(db, `${owner}-rp`, 'P3RP');
    const seeded = await seedVenue(db, providerId, {
      name: 'RP Hotel',
      venueType: 'hotel',
      types: [{ name: 'R', qty: 1, nights: { '2027-07-01': '50' } }],
    });
    const typeId = seeded.types.R;

    // Concurrent second defaults should not leave two active defaults.
    const a = newId();
    const b = newId();
    await db.query('BEGIN');
    await db.query(`SELECT id FROM inventory_types WHERE id = $1 FOR UPDATE`, [
      typeId,
    ]);
    await db.query(
      `UPDATE rate_plans SET is_default = FALSE WHERE inventory_type_id = $1`,
      [typeId],
    );
    await db.query(
      `INSERT INTO rate_plans (id, inventory_type_id, name, currency, is_default, status)
       VALUES ($1,$2,'A','SAR',true,'active')`,
      [a, typeId],
    );
    await db.query('COMMIT');

    let secondFailed = false;
    try {
      await db.query(
        `INSERT INTO rate_plans (id, inventory_type_id, name, currency, is_default, status)
         VALUES ($1,$2,'B','SAR',true,'active')`,
        [b, typeId],
      );
    } catch {
      secondFailed = true;
    }
    expect(secondFailed).toBe(true);
    const defaults = await db.query(
      `SELECT id FROM rate_plans
       WHERE inventory_type_id = $1 AND is_default = TRUE AND status = 'active'`,
      [typeId],
    );
    expect(defaults.rowCount).toBe(1);

    await expect(
      db.query(
        `INSERT INTO rate_plans (id, inventory_type_id, name, currency, is_default, status)
         VALUES ($1,$2,'USD','USD',false,'active')`,
        [newId(), typeId],
      ),
    ).rejects.toBeTruthy();
  });

  it('T-QTY-BARRIER-01 bidirectional quantity_total lock: patch-owns and hold-owns, no stale/overbooking/deadlock', async () => {
    const ownerUid = `${owner}-barrier`;
    const providerId = await seedProvider(db, ownerUid, 'P3Barrier');
    const checkIn = '2027-04-10';
    const checkOut = '2027-04-11';
    const seeded = await seedVenue(db, providerId, {
      name: 'Barrier Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Room',
          qty: 10,
          nights: { [checkIn]: '120', '2027-04-11': '120' },
        },
      ],
    });
    const typeId = seeded.types.Room;

    // ---- Direction 1: Patch OWNS the inventory_types lock, Hold WAITS then
    //      reads the NEW quantity_total (never the stale value). No daily row
    //      may be seeded from the old quantity while the patch holds the lock.
    const preRows = await db.query(
      `SELECT 1 FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = $2::date`,
      [typeId, checkIn],
    );
    expect(preRows.rowCount).toBe(0);

    const quote1 = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(`${consumer}-barrier`))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn,
        checkOut,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);

    const t1 = await db.connect();
    let holdResult: request.Response | undefined;
    let committed1 = false;
    try {
      await t1.query('BEGIN');
      // Same FOR UPDATE gate ProviderInventory.patch / ensureRows use.
      await t1.query(
        `SELECT quantity_total FROM inventory_types WHERE id = $1 FOR UPDATE`,
        [typeId],
      );
      await t1.query(
        `UPDATE inventory_types SET quantity_total = 2 WHERE id = $1`,
        [typeId],
      );

      // Dispatch NOW so the hold actually reaches ensureRows and blocks.
      const holdPromise = fire(
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', auth(`${consumer}-barrier`))
          .set('Idempotency-Key', `barrier-a-${Date.now()}`)
          .send({ quoteId: quote1.body.quoteId, quantity: 1 }),
      );

      // Deterministic barrier: wait until the hold is actually blocked on the
      // inventory_types lock (timer-free) — not a wall-clock sleep.
      await waitForLockWaiters(1);
      // Still no daily row — the hold is blocked, not seeding at the old value.
      const mid = await t1.query(
        `SELECT 1 FROM inventory_daily_capacity WHERE inventory_type_id = $1 AND date = $2::date`,
        [typeId, checkIn],
      );
      expect(mid.rowCount).toBe(0);

      await t1.query('COMMIT');
      committed1 = true;
      holdResult = await holdPromise;
    } finally {
      if (!committed1) await t1.query('ROLLBACK').catch(() => undefined);
      t1.release();
    }

    expect(holdResult?.status).toBe(201);
    const rowA = await db.query<{ capacity: number; held: number }>(
      `SELECT capacity, held FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [typeId, checkIn],
    );
    // Seeded from the NEW quantity_total (2), never the stale 10; held=1, no overbooking.
    expect(Number(rowA.rows[0].capacity)).toBe(2);
    expect(Number(rowA.rows[0].held)).toBe(1);

    // ---- Direction 2: Hold OWNS the inventory_types lock, real Provider PATCH
    //      WAITS on the same parent row, then applies. A raw client holds the
    //      canonical lockInventoryType gate (exactly what HoldService takes via
    //      ensureRows) while the real PATCH endpoint blocks behind it.
    const t2 = await db.connect();
    let patchResult: request.Response | undefined;
    let committed2 = false;
    try {
      await t2.query('BEGIN');
      await t2.query(
        `SELECT quantity_total FROM inventory_types WHERE id = $1 FOR UPDATE`,
        [typeId],
      );

      const patchPromise = fire(
        request(app.getHttpServer())
          .patch(`/v1/provider/inventory-types/${typeId}`)
          .set('Authorization', auth(ownerUid, 'placesProvider'))
          .send({ quantityTotal: 5 }),
      );

      // PATCH must block on the inventory_types lock held by the hold-like tx.
      await waitForLockWaiters(1);
      const midQty = await t2.query<{ quantity_total: number }>(
        `SELECT quantity_total FROM inventory_types WHERE id = $1`,
        [typeId],
      );
      // From inside the lock-holder, quantity is still the Direction-1 value —
      // the PATCH cannot mutate it until this transaction releases the lock.
      expect(Number(midQty.rows[0].quantity_total)).toBe(2);

      await t2.query('COMMIT');
      committed2 = true;
      patchResult = await patchPromise;
    } finally {
      if (!committed2) await t2.query('ROLLBACK').catch(() => undefined);
      t2.release();
    }

    expect(patchResult?.status).toBe(200);
    const finalQty = await db.query<{ quantity_total: number }>(
      `SELECT quantity_total FROM inventory_types WHERE id = $1`,
      [typeId],
    );
    // PATCH waited for the lock, then applied — increase 2 -> 5 (held preserved).
    expect(Number(finalQty.rows[0].quantity_total)).toBe(5);
    const rowB = await db.query<{ capacity: number; held: number }>(
      `SELECT capacity, held FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [typeId, checkIn],
    );
    expect(Number(rowB.rows[0].capacity)).toBe(5);
    expect(Number(rowB.rows[0].held)).toBe(1);
  });

  it('T-SUSPEND-RACE-01 real Suspend command vs Hold — barrier both orders, no deadlock', async () => {
    const uid = `${consumer}-suspend-race`;
    const adminUid = `${owner}-admin`;
    const providerId = await seedProvider(db, `${owner}-suspend-race`, 'P3SuspRace');
    const seeded = await seedVenue(db, providerId, {
      name: 'Suspend Race Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 3,
          nights: { '2027-04-15': '150', '2027-04-16': '150' },
        },
      ],
    });
    const typeId = seeded.types.Std;

    const makeQuote = async () =>
      (
        await request(app.getHttpServer())
          .post('/v1/quotes')
          .set('Authorization', auth(uid))
          .send({
            venueId: seeded.venueId,
            inventoryTypeId: typeId,
            checkIn: '2027-04-15',
            checkOut: '2027-04-17',
            quantity: 1,
            guestsAdults: 1,
          })
          .expect(201)
      ).body.quoteId as string;

    const suspend = () =>
      fire(
        request(app.getHttpServer())
          .patch(`/v1/admin/providers/${providerId}/status`)
          .set('Authorization', auth(adminUid, 'placesAdmin'))
          .send({ status: 'suspended', reason: 'race test' }),
      );

    const reactivate = () =>
      request(app.getHttpServer())
        .patch(`/v1/admin/providers/${providerId}/status`)
        .set('Authorization', auth(adminUid, 'placesAdmin'))
        .send({ status: 'active', reason: 'race test reset' });

    const hold = (quoteId: string, key: string) =>
      fire(
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', auth(uid))
          .set('Idempotency-Key', key)
          .send({ quoteId, quantity: 1 }),
      );

    // ---- Scenario A: Suspend arrives first (real contention via venue gate).
    //      Both the real Suspend command and the Hold contend on the same venue
    //      row; the FIFO lock queue puts Suspend first → Hold rejected, no effects.
    const quoteA = await makeQuote();
    const gateA = await db.connect();
    let suspendResA: request.Response | undefined;
    let holdResA: request.Response | undefined;
    let committedA = false;
    try {
      await gateA.query('BEGIN');
      await gateA.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
        seeded.venueId,
      ]);

      const suspendPromise = suspend(); // real application command — blocks on venue lock
      await waitForLockWaiters(1);
      const holdPromise = hold(quoteA, `suspend-race-a-${Date.now()}`); // queued after suspend
      await waitForLockWaiters(2);

      await gateA.query('COMMIT');
      committedA = true;
      [suspendResA, holdResA] = await Promise.all([suspendPromise, holdPromise]);
    } finally {
      if (!committedA) await gateA.query('ROLLBACK').catch(() => undefined);
      gateA.release();
    }

    expect(suspendResA?.status).toBe(200);
    expect(suspendResA?.body.status).toBe('suspended');
    expect(holdResA?.status).toBeGreaterThanOrEqual(400);
    const holdsA = await db.query(
      `SELECT status FROM booking_holds WHERE quote_id = $1`,
      [quoteA],
    );
    expect(holdsA.rowCount).toBe(0);
    const bookingsA = await db.query(
      `SELECT id FROM bookings WHERE venue_id = $1`,
      [seeded.venueId],
    );
    expect(bookingsA.rowCount).toBe(0);
    // No capacity consumed for the rejected hold.
    const heldA = await db.query<{ held: number }>(
      `SELECT COALESCE(SUM(held),0)::int AS held FROM inventory_daily_capacity WHERE inventory_type_id = $1`,
      [typeId],
    );
    expect(Number(heldA.rows[0].held)).toBe(0);

    // ---- Scenario B: Hold arrives first → completes; then Suspend blocks new holds.
    await reactivate().expect(200);
    const quoteB = await makeQuote();
    // quoteC is created while the provider is still active; the hold using it is
    // attempted only AFTER suspend, proving the hold boundary (not quote) rejects.
    const quoteC = await makeQuote();
    const gateB = await db.connect();
    let holdResB: request.Response | undefined;
    let suspendResB: request.Response | undefined;
    let committedB = false;
    try {
      await gateB.query('BEGIN');
      await gateB.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
        seeded.venueId,
      ]);

      const holdPromise = hold(quoteB, `suspend-race-b-${Date.now()}`); // blocks on venue lock
      await waitForLockWaiters(1);
      const suspendPromise = suspend(); // queued after the hold
      await waitForLockWaiters(2);

      await gateB.query('COMMIT');
      committedB = true;
      [holdResB, suspendResB] = await Promise.all([holdPromise, suspendPromise]);
    } finally {
      if (!committedB) await gateB.query('ROLLBACK').catch(() => undefined);
      gateB.release();
    }

    // Hold ran while provider still active → succeeds; suspend then applies.
    expect(holdResB?.status).toBe(201);
    expect(suspendResB?.status).toBe(200);
    const heldB = await db.query<{ held: number }>(
      `SELECT COALESCE(SUM(held),0)::int AS held FROM inventory_daily_capacity WHERE inventory_type_id = $1`,
      [typeId],
    );
    // One successful hold of qty=1 over a 2-night stay → held=1 on each of the
    // two nightly rows (sum = 2). Scenario A's hold was rejected (contributes 0).
    expect(Number(heldB.rows[0].held)).toBe(2);

    // A hold on the pre-created quote is now rejected because provider suspended.
    const holdResC = await hold(quoteC, `suspend-race-c-${Date.now()}`);
    expect(holdResC.status).toBeGreaterThanOrEqual(400);
    const holdsC = await db.query(
      `SELECT status FROM booking_holds WHERE quote_id = $1`,
      [quoteC],
    );
    expect(holdsC.rowCount).toBe(0);

    await reactivate().expect(200);
  });

  it('T-HOLD-EXPIRY-RACE-01 create (reused Idempotency-Key) vs expiry — barrier both orders, no deadlock/duplicate', async () => {
    const uid = `${consumer}-expiry-race`;
    const providerId = await seedProvider(db, `${owner}-expiry-race`, 'P3ExpRace');
    const seeded = await seedVenue(db, providerId, {
      name: 'Expiry Race Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Std',
          qty: 3,
          nights: { '2027-05-10': '150', '2027-05-11': '150' },
        },
      ],
    });
    const typeId = seeded.types.Std;
    const holdSvc = app.get(HoldService);

    const makeQuote = async () =>
      (
        await request(app.getHttpServer())
          .post('/v1/quotes')
          .set('Authorization', auth(uid))
          .send({
            venueId: seeded.venueId,
            inventoryTypeId: typeId,
            checkIn: '2027-05-10',
            checkOut: '2027-05-11',
            quantity: 1,
            guestsAdults: 1,
          })
          .expect(201)
      ).body.quoteId as string;

    // Fire the create endpoint (reused Idempotency-Key) so it actually reaches
    // and blocks on the venue lock before the barrier polls.
    const createHold = (quoteId: string, key: string) =>
      fire(
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', auth(uid))
          .set('Idempotency-Key', key)
          .send({ quoteId, quantity: 1 }),
      );

    // Seed one ACTIVE hold, then force it expiry-eligible AND expire the HTTP
    // idempotency record for the key. Expiring the idempotency row is what makes
    // a same-key retry actually re-run the hold command (instead of returning the
    // cached HTTP response) so it genuinely contends on the venue lock with expiry
    // — the exact create-vs-expiry lock-order path under test.
    const armExpiringHold = async (key: string) => {
      const quoteId = await makeQuote();
      const res = await createHold(quoteId, key);
      expect(res.status).toBe(201);
      const holdId = res.body.holdId as string;
      await db.query(
        `UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`,
        [holdId],
      );
      await db.query(
        `UPDATE idempotency_keys SET expires_at = now() - interval '1 hour' WHERE key = $1`,
        [key],
      );
      return { holdId, quoteId };
    };

    // A single successful hold of qty=1 over a single-night stay → held=1.
    const heldSum = async () =>
      Number(
        (
          await db.query<{ held: number }>(
            `SELECT COALESCE(SUM(held),0)::int AS held FROM inventory_daily_capacity WHERE inventory_type_id = $1`,
            [typeId],
          )
        ).rows[0].held,
      );

    // ---- Scenario A: create (reused key) acquires the venue first, expiry waits.
    const keyA = `expiry-race-a-${Date.now()}`;
    const armed = await armExpiringHold(keyA);
    expect(await heldSum()).toBe(1);
    const gateA = await db.connect();
    let createResA: request.Response | undefined;
    let expiredA: boolean | undefined;
    let committedA = false;
    try {
      await gateA.query('BEGIN');
      await gateA.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
        seeded.venueId,
      ]);

      // Reused Idempotency-Key + same quote → idempotent replay (no new effect).
      const createPromise = createHold(armed.quoteId, keyA); // blocks on venue lock
      await waitForLockWaiters(1);
      const expiryPromise = holdSvc.expireOne(armed.holdId); // queued after create
      await waitForLockWaiters(2);

      await gateA.query('COMMIT');
      committedA = true;
      [createResA, expiredA] = await Promise.all([createPromise, expiryPromise]);
    } finally {
      if (!committedA) await gateA.query('ROLLBACK').catch(() => undefined);
      gateA.release();
    }

    // No deadlock: both resolved. Replay returned the SAME hold (no duplicate),
    // expiry then claimed it. Exactly one hold row for the key; held released once.
    expect(createResA?.status).toBe(201);
    expect(createResA?.body.holdId).toBe(armed.holdId);
    expect(expiredA).toBe(true);
    const rowsA = await db.query<{ status: string }>(
      `SELECT status FROM booking_holds WHERE consumer_firebase_uid = $1 AND idempotency_key = $2`,
      [uid, keyA],
    );
    expect(rowsA.rowCount).toBe(1);
    expect(rowsA.rows[0].status).toBe('EXPIRED');
    const bkgA = await db.query<{ status: string }>(
      `SELECT status FROM bookings WHERE hold_id = $1`,
      [armed.holdId],
    );
    expect(bkgA.rowCount).toBe(1);
    expect(bkgA.rows[0].status).toBe('EXPIRED');
    expect(await heldSum()).toBe(0); // released exactly once, no double-release

    // ---- Scenario B: expiry acquires the venue first, create (reused key) waits.
    const keyB = `expiry-race-b-${Date.now()}`;
    const armedB = await armExpiringHold(keyB);
    expect(await heldSum()).toBe(1);
    const gateB = await db.connect();
    let expiredB: boolean | undefined;
    let createResB: request.Response | undefined;
    let committedB = false;
    try {
      await gateB.query('BEGIN');
      await gateB.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
        seeded.venueId,
      ]);

      const expiryPromise = holdSvc.expireOne(armedB.holdId); // blocks on venue lock
      await waitForLockWaiters(1);
      const createPromise = createHold(armedB.quoteId, keyB); // queued after expiry
      await waitForLockWaiters(2);

      await gateB.query('COMMIT');
      committedB = true;
      [expiredB, createResB] = await Promise.all([expiryPromise, createPromise]);
    } finally {
      if (!committedB) await gateB.query('ROLLBACK').catch(() => undefined);
      gateB.release();
    }

    // No deadlock: both resolved. Expiry claimed the hold; the reused-key replay
    // then observed the now-EXPIRED hold and returned it WITHOUT creating a new
    // hold or re-holding capacity.
    expect(expiredB).toBe(true);
    expect(createResB?.status).toBe(201);
    expect(createResB?.body.holdId).toBe(armedB.holdId);
    expect(createResB?.body.status).toBe('EXPIRED');
    const rowsB = await db.query<{ status: string }>(
      `SELECT status FROM booking_holds WHERE consumer_firebase_uid = $1 AND idempotency_key = $2`,
      [uid, keyB],
    );
    expect(rowsB.rowCount).toBe(1);
    expect(rowsB.rows[0].status).toBe('EXPIRED');
    expect(await heldSum()).toBe(0);
  });

  /**
   * Covers the ORIGINAL defect branch of the create-vs-expiry inversion: a reused
   * Idempotency-Key pointing at an old (expiring) hold while the incoming request
   * carries a DIFFERENT quote. That is the only create path that mutates the old
   * hold row (retires its key) AND then creates a new hold + booking + capacity —
   * so before the venues-first lock order it could invert locks against expiry
   * (which locks venue→hold) and deadlock with 40P01.
   */
  it('T-HOLD-EXPIRY-RACE-02 different quote + reused Idempotency-Key', async () => {
    const uid = `${consumer}-expiry-race2`;
    const holdSvc = app.get(HoldService);
    const night = '2027-06-10';
    const checkOut = '2027-06-11';

    // Each direction gets its own venue so capacity sums are unambiguous.
    const setup = async (label: string) => {
      const providerId = await seedProvider(
        db,
        `${owner}-exp2-${label}`,
        `P3Exp2${label}`,
      );
      const seeded = await seedVenue(db, providerId, {
        name: `Expiry Race2 ${label}`,
        venueType: 'hotel',
        types: [
          { name: 'Std', qty: 3, nights: { [night]: '150', [checkOut]: '150' } },
        ],
      });
      return { venueId: seeded.venueId, typeId: seeded.types.Std };
    };

    const makeQuote = async (venueId: string, typeId: string) =>
      (
        await request(app.getHttpServer())
          .post('/v1/quotes')
          .set('Authorization', auth(uid))
          .send({
            venueId,
            inventoryTypeId: typeId,
            checkIn: night,
            checkOut,
            quantity: 1,
            guestsAdults: 1,
          })
          .expect(201)
      ).body.quoteId as string;

    const createHold = (quoteId: string, key: string) =>
      fire(
        request(app.getHttpServer())
          .post('/v1/holds')
          .set('Authorization', auth(uid))
          .set('Idempotency-Key', key)
          .send({ quoteId, quantity: 1 }),
      );

    const heldSum = async (typeId: string) =>
      Number(
        (
          await db.query<{ held: number }>(
            `SELECT COALESCE(SUM(held),0)::int AS held FROM inventory_daily_capacity WHERE inventory_type_id = $1`,
            [typeId],
          )
        ).rows[0].held,
      );

    // Q1 → old hold under key K; then expire BOTH the hold and the HTTP
    // idempotency record so a same-key retry actually re-runs the hold command.
    // Finally mint Q2: a DIFFERENT quote on the SAME venue + inventory type.
    const arm = async (label: string, key: string) => {
      const { venueId, typeId } = await setup(label);
      const q1 = await makeQuote(venueId, typeId);
      const first = await createHold(q1, key);
      expect(first.status).toBe(201);
      const oldHoldId = first.body.holdId as string;
      await db.query(
        `UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`,
        [oldHoldId],
      );
      await db.query(
        `UPDATE idempotency_keys SET expires_at = now() - interval '1 hour' WHERE key = $1`,
        [key],
      );
      const q2 = await makeQuote(venueId, typeId);
      // Old hold still owns exactly one held unit on the single night.
      expect(await heldSum(typeId)).toBe(1);
      return { venueId, typeId, q1, q2, oldHoldId };
    };

    // Shared proof for both directions.
    const assertOutcome = async (
      label: string,
      s: { typeId: string; q2: string; oldHoldId: string },
      key: string,
      createRes: request.Response | undefined,
      expired: boolean | undefined,
    ) => {
      // No deadlock / 40P01 / timeout: both operations resolved normally.
      expect(createRes?.status).toBe(201);
      expect(String(createRes?.text ?? '')).not.toContain('40P01');
      expect(expired).toBe(true);

      // Old hold is EXPIRED and its idempotency key is retired (vacated).
      const oldRow = await db.query<{ status: string; idempotency_key: string }>(
        `SELECT status, idempotency_key FROM booking_holds WHERE id = $1`,
        [s.oldHoldId],
      );
      expect(oldRow.rowCount).toBe(1);
      expect(oldRow.rows[0].status).toBe('EXPIRED');
      expect(oldRow.rows[0].idempotency_key).toBe(
        `${key}#retired#${s.oldHoldId}`,
      );

      // Exactly ONE new hold, tied to Q2 and still owning key K.
      const newRows = await db.query<{ id: string; status: string }>(
        `SELECT id, status FROM booking_holds
         WHERE consumer_firebase_uid = $1 AND idempotency_key = $2`,
        [uid, key],
      );
      expect(newRows.rowCount).toBe(1);
      const newHoldId = newRows.rows[0].id;
      expect(newHoldId).not.toBe(s.oldHoldId);
      expect(newRows.rows[0].status).toBe('ACTIVE');
      expect(createRes?.body.holdId).toBe(newHoldId);
      const byQuote = await db.query(
        `SELECT id FROM booking_holds WHERE quote_id = $1`,
        [s.q2],
      );
      expect(byQuote.rowCount).toBe(1);

      // No duplicate booking effects: one booking per hold, none extra.
      const newBookings = await db.query<{ status: string }>(
        `SELECT status FROM bookings WHERE hold_id = $1`,
        [newHoldId],
      );
      expect(newBookings.rowCount).toBe(1);
      expect(newBookings.rows[0].status).toBe('HOLDING');
      const oldBookings = await db.query<{ status: string }>(
        `SELECT status FROM bookings WHERE hold_id = $1`,
        [s.oldHoldId],
      );
      expect(oldBookings.rowCount).toBe(1);
      expect(oldBookings.rows[0].status).toBe('EXPIRED');
      const q2Bookings = await db.query(
        `SELECT id FROM bookings WHERE quote_id = $1`,
        [s.q2],
      );
      expect(q2Bookings.rowCount).toBe(1);

      // Final capacity counts the NEW hold only; the old one was released once.
      expect(await heldSum(s.typeId)).toBe(1);
      expect(label).toBeTruthy();
    };

    // ---- Direction 1: Create (Q2, reused key K) first, expiry queued behind it.
    const keyA = `exp2-a-${Date.now()}`;
    const sA = await arm('a', keyA);
    const gateA = await db.connect();
    let createResA: request.Response | undefined;
    let expiredA: boolean | undefined;
    let committedA = false;
    try {
      await gateA.query('BEGIN');
      await gateA.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
        sA.venueId,
      ]);

      const createPromise = createHold(sA.q2, keyA); // blocks on venue lock
      await waitForLockWaiters(1);
      const expiryPromise = holdSvc.expireOne(sA.oldHoldId); // queued after create
      await waitForLockWaiters(2);

      await gateA.query('COMMIT');
      committedA = true;
      [createResA, expiredA] = await Promise.all([createPromise, expiryPromise]);
    } finally {
      if (!committedA) await gateA.query('ROLLBACK').catch(() => undefined);
      gateA.release();
    }
    await assertOutcome('create-first', sA, keyA, createResA, expiredA);

    // ---- Direction 2: Expiry first, create (Q2, reused key K) queued behind it.
    const keyB = `exp2-b-${Date.now()}`;
    const sB = await arm('b', keyB);
    const gateB = await db.connect();
    let expiredB: boolean | undefined;
    let createResB: request.Response | undefined;
    let committedB = false;
    try {
      await gateB.query('BEGIN');
      await gateB.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
        sB.venueId,
      ]);

      const expiryPromise = holdSvc.expireOne(sB.oldHoldId); // blocks on venue lock
      await waitForLockWaiters(1);
      const createPromise = createHold(sB.q2, keyB); // queued after expiry
      await waitForLockWaiters(2);

      await gateB.query('COMMIT');
      committedB = true;
      [expiredB, createResB] = await Promise.all([expiryPromise, createPromise]);
    } finally {
      if (!committedB) await gateB.query('ROLLBACK').catch(() => undefined);
      gateB.release();
    }
    await assertOutcome('expiry-first', sB, keyB, createResB, expiredB);
  });

  it('T-NIGHTLY-SAMEDAY-01 nightly hidden when checkIn==checkOut; daily same-day valid', async () => {
    const day = '2027-11-01';
    const nightlyProvider = await seedProvider(db, `${owner}-nsd-n`, 'P3NsdN');
    const nightly = await seedVenue(db, nightlyProvider, {
      name: 'Nightly SameDay Hotel',
      venueType: 'hotel',
      types: [{ name: 'Room', qty: 2, nights: { [day]: '100' } }],
    });
    await ensureDiscoverable(nightly.venueId, nightlyProvider);
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,$3::date,2,0,0,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET capacity = 2`,
      [newId(), nightly.types.Room, day],
    );

    const dailyProvider = await seedProvider(db, `${owner}-nsd-d`, 'P3NsdD');
    const daily = await seedVenue(db, dailyProvider, {
      name: 'Daily SameDay Farm',
      venueType: 'farm',
      mode: 'daily',
      types: [{ name: 'Unit', qty: 2, nights: { [day]: '100' } }],
    });
    await ensureDiscoverable(daily.venueId, dailyProvider);
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,$3::date,2,0,0,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET capacity = 2`,
      [newId(), daily.types.Unit, day],
    );

    const nightlySearch = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({ category: 'hotel', sort: 'best', checkIn: day, checkOut: day, quantity: 1, limit: 50 })
      .expect(201);
    expect(
      (nightlySearch.body.items as { venueId: string }[]).some(
        (i) => i.venueId === nightly.venueId,
      ),
    ).toBe(false);

    const dailySearch = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({ category: 'farm', sort: 'best', checkIn: day, checkOut: day, quantity: 1, limit: 50 })
      .expect(201);
    expect(
      (dailySearch.body.items as { venueId: string }[]).some(
        (i) => i.venueId === daily.venueId,
      ),
    ).toBe(true);
  });

  it('event_slot kill switch remains OFF', async () => {
    expect(process.env.PLACES_EVENT_SLOT_ENABLED).not.toBe('true');
    const providerId = await seedProvider(db, `${owner}-es`, 'P3ES');
    const venueId = newId();
    await db.query(
      `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status, city, min_stay)
       VALUES ($1,$2,'Palace','palace','event_slot','published','Riyadh',1)`,
      [venueId, providerId],
    );
    const typeId = newId();
    await db.query(
      `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total, base_occupancy, max_occupancy)
       VALUES ($1,$2,'Hall','pooled',1,10,100)`,
      [typeId, venueId],
    );
    const q = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumer))
      .send({
        venueId,
        inventoryTypeId: typeId,
        checkIn: '2027-08-01',
        checkOut: '2027-08-01',
        quantity: 1,
        guestsAdults: 1,
        slotCode: 'MORNING',
      });
    expect(q.status).toBeGreaterThanOrEqual(400);
  });

  it('T-CANCEL-RESTORE-01 hold expiry restores future held only', async () => {
    const uid = `${consumer}-exp`;
    const providerId = await seedProvider(db, `${owner}-exp`, 'P3Exp');
    const checkIn = '2027-05-20';
    const checkOut = '2027-05-22';
    const seeded = await seedVenue(db, providerId, {
      name: 'Expiry Hotel',
      venueType: 'hotel',
      types: [
        {
          name: 'Room',
          qty: 1,
          nights: { [checkIn]: '70.00', '2027-05-21': '70.00' },
        },
      ],
    });
    const typeId = seeded.types.Room;
    const quote = await request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: typeId,
        checkIn,
        checkOut,
        quantity: 1,
        guestsAdults: 1,
      })
      .expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(uid))
      .set('Idempotency-Key', `exp-${Date.now()}`)
      .send({ quoteId: quote.body.quoteId, quantity: 1 })
      .expect(201);

    const held = await db.query<{ held: number }>(
      `SELECT held FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [typeId, checkIn],
    );
    expect(Number(held.rows[0].held)).toBe(1);

    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '1 second' WHERE id = $1`,
      [hold.body.holdId],
    );
    const { HoldService } = await import(
      '../../src/modules/booking/application/hold.service'
    );
    const holds = app.get(HoldService);
    const n = await holds.expireDue();
    expect(n).toBeGreaterThanOrEqual(1);

    const after = await db.query<{ held: number; available: number }>(
      `SELECT held, available FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [typeId, checkIn],
    );
    expect(Number(after.rows[0].held)).toBe(0);
    expect(Number(after.rows[0].available)).toBe(1);
  });

  it('F-V2-012 partial: suspended provider hidden from discovery', async () => {
    const providerId = await seedProvider(db, `${owner}-hide`, 'P3Hide');
    const seeded = await seedVenue(db, providerId, {
      name: 'Hidden Soon',
      venueType: 'apartment',
      types: [{ name: 'A', qty: 1, nights: { '2027-09-01': '80' } }],
    });
    await ensureDiscoverable(seeded.venueId, providerId);
    await db.query(`UPDATE providers SET status = 'suspended' WHERE id = $1`, [
      providerId,
    ]);
    const disc = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send({ category: 'apartment', sort: 'best', limit: 50 });
    expect(disc.status).toBe(201);
    expect(
      (disc.body.items as { venueId: string }[]).some(
        (i) => i.venueId === seeded.venueId,
      ),
    ).toBe(false);
  });
});
