/**
 * Phase 7 — event_slot / palace / hall E2E without PSP (RC2, deterministic).
 *
 * Capabilities remain OFF by default; this suite enables booking caps only in CI.
 * RC2 corrections proven here:
 *  - pricing comes from event_slot_templates.base_price (inventory_type_id + status=active);
 *  - event_slot does NOT consume inventory_daily_capacity;
 *  - availability / hold / cancel / expiry / overlap are exercised deterministically;
 *  - no-show is rejected before the slot start time and allowed only after it;
 *  - no assertion accepts HTTP 400 as success.
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import request from 'supertest';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';
import { newId } from '../../src/shared/ids/ids';
import { VenuePublicationService } from '../../src/modules/venues/application/venue-publication.service';
import { HoldService } from '../../src/modules/booking/application/hold.service';
import { armHoldBarrier } from '../../src/modules/booking/application/hold-barrier';
import { riyadhTodayIso } from '../../src/shared/time/stay-dates';

describe('phase7_event_slot_e2e', () => {
  let app: INestApplication;
  let db: Pool;
  const slotDate = '2026-12-20';

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = 'stub';
    process.env.PLACES_PAY_AT_VENUE_ENABLED = 'true';
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = '';
    process.env.PLACES_EVENT_SLOT_ENABLED = 'true';
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
    // Test-only: enable booking for palace/hall. Production defaults stay OFF (024/026).
    await db.query(
      `UPDATE venue_type_capabilities
       SET enabled_for_booking = TRUE, enabled_for_discovery = TRUE
       WHERE venue_type IN ('wedding_palace', 'event_hall')`,
    );
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  async function seedPalace(tag: string) {
    const owner = `p7-owner-${tag}`;
    const consumer = `p7-consumer-${tag}`;
    const providerId = await seedProvider(db, owner, `P7-${tag}`);
    const seeded = await seedVenue(db, providerId, {
      name: `P7 Palace ${tag}`,
      venueType: 'wedding_palace',
      mode: 'event_slot',
      types: [{ name: 'Hall', qty: 1, nights: { [slotDate]: '2500.00' } }],
    });
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, provider_id, kind, url, cloudflare_image_id, moderation_status, sort_order)
       VALUES ($1,$2,$3,'image',$4,$5,'approved',0)`,
      [
        newId(),
        seeded.venueId,
        providerId,
        'https://imagedelivery.net/stub/p7/public',
        `img-p7-${newId()}`,
      ],
    );
    await app.get(VenuePublicationService).publishVenue({
      venueId: seeded.venueId,
      actorUid: owner,
      actorRole: 'provider',
      correlationId: `p7-pub-${tag}`,
    });

    // Seed a daily-capacity row on purpose: event_slot must NOT touch it.
    await db.query(
      `INSERT INTO inventory_daily_capacity
         (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1,$2,$3::date,1,0,0,0)
       ON CONFLICT (inventory_type_id, date) DO UPDATE SET capacity = 1`,
      [newId(), seeded.types.Hall, slotDate],
    );

    return {
      owner,
      consumer,
      providerId,
      venueId: seeded.venueId,
      typeId: seeded.types.Hall,
    };
  }

  async function createTemplate(
    s: { owner: string; venueId: string; typeId: string },
    opts: {
      code: string;
      startTime: string;
      endTime: string;
      basePrice?: string;
      date?: string;
    },
  ): Promise<string> {
    const day = opts.date ?? slotDate;
    const tpl = await request(app.getHttpServer())
      .post('/v1/provider/event-slots/templates')
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        code: opts.code,
        labelAr: 'مسائية',
        startTime: opts.startTime,
        endTime: opts.endTime,
        capacity: 1,
        basePrice: opts.basePrice ?? '2500.00',
      })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/provider/event-slots/generate')
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .send({
        venueId: s.venueId,
        templateId: tpl.body.templateId,
        dateFrom: day,
        dateTo: day,
      })
      .expect(201);
    return tpl.body.templateId as string;
  }

  function quote(
    s: { venueId: string; typeId: string },
    consumerUid: string,
    slotCode: string,
    day = slotDate,
  ) {
    return request(app.getHttpServer())
      .post('/v1/quotes')
      .set('Authorization', auth(consumerUid))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: day,
        checkOut: day,
        quantity: 1,
        guestsAdults: 1,
        slotCode,
      });
  }

  async function dailyCapacity(
    typeId: string,
  ): Promise<{ held: number; booked: number }> {
    const r = await db.query<{ held: number; booked: number }>(
      `SELECT held, booked FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = $2::date`,
      [typeId, slotDate],
    );
    return { held: Number(r.rows[0]?.held ?? 0), booked: Number(r.rows[0]?.booked ?? 0) };
  }

  it('T-MIG-031-01 migration 031 applied; caps OFF in migration defaults', async () => {
    const row = await db.query<{ checksum: string | null }>(
      `SELECT checksum FROM schema_migrations WHERE id = '031_phase7_event_slot.sql'`,
    );
    expect(row.rowCount).toBe(1);
    const sql = await fs.readFile(
      path.resolve(__dirname, '../../db/migrations/031_phase7_event_slot.sql'),
      'utf8',
    );
    expect(row.rows[0].checksum).toBe(
      createHash('sha256').update(sql, 'utf8').digest('hex'),
    );
    expect(sql).toMatch(/remain OFF|stay false|OFF by default/i);
    expect(sql).not.toMatch(/enabled_for_booking\s*=\s*TRUE/i);
  });

  it('T-SLOT-PRICE-01 quote price equals template base_price (not rate_rules)', async () => {
    const s = await seedPalace('price');
    await createTemplate(s, {
      code: 'evening',
      startTime: '18:00',
      endTime: '23:00',
      basePrice: '2500.00',
    });
    // Deliberately corrupt the nightly rate_rules so a rate_rules-based price
    // would differ from the template base_price.
    await db.query(
      `UPDATE rate_rules SET amount = 9999 WHERE rate_plan_id = ANY(
         SELECT id FROM rate_plans WHERE inventory_type_id = $1)`,
      [s.typeId],
    );
    const q = await quote(s, s.consumer, 'evening').expect(201);
    // Price must reflect base_price 2500, never the poisoned 9999 rate_rule.
    expect(String(q.body.subtotal)).toBe('2500.00');
    expect(String(q.body.grossTotal)).toContain('2500');
  });

  it('T-SLOT-PRICE-02 quote rejected when inventory_type_id != template', async () => {
    const s = await seedPalace('price2');
    await createTemplate(s, {
      code: 'evening',
      startTime: '18:00',
      endTime: '23:00',
    });
    // A second inventory type not linked to the template.
    const otherType = newId();
    await db.query(
      `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total, base_occupancy, max_occupancy)
       VALUES ($1,$2,'Other','pooled',1,2,4)`,
      [otherType, s.venueId],
    );
    await db.query(
      `INSERT INTO rate_plans (id, inventory_type_id, name, is_default, status)
       VALUES ($1,$2,'default',true,'active')`,
      [newId(), otherType],
    );
    const res = await quote(
      { venueId: s.venueId, typeId: otherType },
      s.consumer,
      'evening',
    );
    expect(res.status).toBe(400);
    expect(res.body.code).toBe('VALIDATION_ERROR');
  });

  it('T-SLOT-CRUD-01 template + generate idempotent + block rejects quote (409) + reopen + discovery', async () => {
    const s = await seedPalace('crud');
    const templateId = await createTemplate(s, {
      code: 'evening',
      startTime: '18:00',
      endTime: '23:00',
    });

    // Idempotent generate.
    const gen2 = await request(app.getHttpServer())
      .post('/v1/provider/event-slots/generate')
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .send({ venueId: s.venueId, templateId, dateFrom: slotDate, dateTo: slotDate })
      .expect(201);
    expect(gen2.body.skipped).toBe(1);

    const list = await request(app.getHttpServer())
      .get('/v1/provider/event-slots/inventory')
      .query({ venueId: s.venueId, dateFrom: slotDate, dateTo: slotDate })
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .expect(200);
    expect(list.body[0].status).toBe('open');
    const invId = list.body[0].id as string;

    await request(app.getHttpServer())
      .patch(`/v1/provider/event-slots/inventory/${invId}`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .send({ venueId: s.venueId, status: 'blocked', reason: 'maintenance' })
      .expect(200);

    // Blocked slot => quote deterministically 409 AVAILABILITY_CHANGED.
    const blocked = await quote(s, s.consumer, 'evening');
    expect(blocked.status).toBe(409);
    expect(blocked.body.code).toBe('AVAILABILITY_CHANGED');

    await request(app.getHttpServer())
      .patch(`/v1/provider/event-slots/inventory/${invId}`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .send({ venueId: s.venueId, status: 'open', reason: 'reopen' })
      .expect(200);

    // After reopen, quote succeeds.
    await quote(s, s.consumer, 'evening').expect(201);

    const disc = await request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(s.consumer))
      .send({
        category: 'wedding_palace',
        city: 'Riyadh',
        sort: 'best',
        checkIn: slotDate,
        slotCode: 'evening',
        limit: 20,
      });
    // Discovery must not error for a valid event_slot search (slotCode + checkIn;
    // event_slot forbids checkOut and explicit quantity).
    expect([200, 201]).toContain(disc.status);
    const items = (disc.body.items ?? []) as { venueId: string }[];
    expect(items.some((i) => i.venueId === s.venueId)).toBe(true);
  });

  it('T-SLOT-E2E-01 Quote→Hold→PAV→collect→check-in→complete; concurrency CAS; daily capacity untouched', async () => {
    const s = await seedPalace('e2e');
    await createTemplate(s, { code: 'evening', startTime: '18:00', endTime: '23:00' });

    const quoteA = await quote(s, s.consumer, 'evening').expect(201);
    const quoteB = await quote(s, `${s.consumer}-b`, 'evening').expect(201);

    // Concurrent holds — rendezvous barrier so both observe the same lock set.
    process.env.PLACES_HOLD_BARRIER = '1';
    armHoldBarrier(2);
    const [h1, h2] = await Promise.all([
      request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(s.consumer))
        .set('Idempotency-Key', `p7-hold-a-${newId()}`)
        .send({ quoteId:quoteA.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } }),
      request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(`${s.consumer}-b`))
        .set('Idempotency-Key', `p7-hold-b-${newId()}`)
        .send({ quoteId:quoteB.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } }),
    ]);
    delete process.env.PLACES_HOLD_BARRIER;
    const ok = [h1, h2].filter((r) => r.status === 201);
    const bad = [h1, h2].filter((r) => r.status !== 201);
    expect(ok.length).toBe(1);
    expect(bad.length).toBe(1);
    expect(bad[0].status).toBe(409);
    const holdId = ok[0].body.holdId as string;
    const winConsumer = ok[0] === h1 ? s.consumer : `${s.consumer}-b`;

    // event_slot must NOT consume daily capacity on hold.
    expect(await dailyCapacity(s.typeId)).toEqual({ held: 0, booked: 0 });

    const conf = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(winConsumer))
      .set('Idempotency-Key', `p7-pav-${newId()}`)
      .send({ holdId })
      .expect(201);
    const bookingId = conf.body.bookingId as string;

    const slot = await db.query<{ status: string }>(
      `SELECT status FROM event_slot_inventory WHERE booking_id = $1`,
      [bookingId],
    );
    expect(slot.rows[0]?.status).toBe('booked');
    // Still no daily-capacity consumption after confirm.
    expect(await dailyCapacity(s.typeId)).toEqual({ held: 0, booked: 0 });

    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${bookingId}/collect-at-venue`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .set('Idempotency-Key', `p7-collect-${newId()}`)
      .send({ amount: String(quoteA.body.grossTotal), currency: 'SAR' })
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${bookingId}/check-in`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .set('Idempotency-Key', `p7-checkin-${newId()}`)
      .send({})
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${bookingId}/complete`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .set('Idempotency-Key', `p7-complete-${newId()}`)
      .send({})
      .expect(200);

    const b = await db.query(`SELECT status FROM bookings WHERE id = $1`, [bookingId]);
    expect(b.rows[0].status).toBe('COMPLETED');
  });

  it('T-SLOT-CANCEL-01 hold then cancel frees slot → open; daily capacity untouched', async () => {
    const s = await seedPalace('cancel');
    await createTemplate(s, { code: 'evening', startTime: '18:00', endTime: '23:00' });
    const q = await quote(s, s.consumer, 'evening').expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-cxl-hold-${newId()}`)
      .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);

    const held = await db.query<{ status: string }>(
      `SELECT status FROM event_slot_inventory WHERE hold_id = $1`,
      [hold.body.holdId],
    );
    expect(held.rows[0].status).toBe('held');

    // Cancel the HOLDING booking bound to this hold.
    const booking = await db.query<{ id: string }>(
      `SELECT id FROM bookings WHERE hold_id = $1`,
      [hold.body.holdId],
    );
    await request(app.getHttpServer())
      .post(`/v1/bookings/${booking.rows[0].id}/cancel`)
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-cxl-${newId()}`)
      .send({ reason: 'changed_plans' })
      .expect(200);

    const after = await db.query<{ status: string; hold_id: string | null; booking_id: string | null }>(
      `SELECT status, hold_id, booking_id FROM event_slot_inventory
       WHERE venue_id = $1 AND slot_date = $2::date`,
      [s.venueId, slotDate],
    );
    expect(after.rows[0].status).toBe('open');
    expect(after.rows[0].hold_id).toBeNull();
    expect(after.rows[0].booking_id).toBeNull();
    expect(await dailyCapacity(s.typeId)).toEqual({ held: 0, booked: 0 });
  });

  it('T-SLOT-EXPIRY-01 expired hold frees slot → open (hold-expiry path)', async () => {
    const s = await seedPalace('expiry');
    await createTemplate(s, { code: 'evening', startTime: '18:00', endTime: '23:00' });
    const q = await quote(s, s.consumer, 'evening').expect(201);
    const hold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-exp-hold-${newId()}`)
      .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);

    // Force expiry then run the expiry sweep the worker uses.
    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`,
      [hold.body.holdId],
    );
    const expired = await app.get(HoldService).expireDue();
    expect(expired).toBeGreaterThanOrEqual(1);

    const after = await db.query<{ status: string }>(
      `SELECT status FROM event_slot_inventory WHERE venue_id = $1 AND slot_date = $2::date`,
      [s.venueId, slotDate],
    );
    expect(after.rows[0].status).toBe('open');
    expect(await dailyCapacity(s.typeId)).toEqual({ held: 0, booked: 0 });
  });

  it('T-SLOT-OVERLAP-01 overlapping windows conflict; non-overlapping coexist; cross-midnight rejected', async () => {
    const s = await seedPalace('overlap');
    // Two overlapping templates (18-23 and 22-23:30 overlap) + one disjoint (09-12).
    await createTemplate(s, { code: 'evening', startTime: '18:00', endTime: '23:00' });
    await createTemplate(s, { code: 'late', startTime: '22:00', endTime: '23:30' });
    await createTemplate(s, { code: 'morning', startTime: '09:00', endTime: '12:00' });

    // Hold the evening slot.
    const q1 = await quote(s, s.consumer, 'evening').expect(201);
    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-ovl-hold-${newId()}`)
      .send({ quoteId:q1.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);

    // Overlapping 'late' hold must conflict (409).
    const q2 = await quote(s, `${s.consumer}-late`, 'late').expect(201);
    const lateHold = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(`${s.consumer}-late`))
      .set('Idempotency-Key', `p7-ovl-late-${newId()}`)
      .send({ quoteId:q2.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
    expect(lateHold.status).toBe(409);
    expect(lateHold.body.code).toBe('SLOT_OR_CAPACITY_CONFLICT');

    // Non-overlapping 'morning' hold succeeds concurrently.
    const q3 = await quote(s, `${s.consumer}-am`, 'morning').expect(201);
    await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(`${s.consumer}-am`))
      .set('Idempotency-Key', `p7-ovl-am-${newId()}`)
      .send({ quoteId:q3.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);

    // Cross-midnight template rejected at creation (deterministic 400).
    const bad = await request(app.getHttpServer())
      .post('/v1/provider/event-slots/templates')
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        code: 'overnight',
        startTime: '22:00',
        endTime: '02:00',
        basePrice: '3000.00',
      });
    expect(bad.status).toBe(400);
  });

  it('T-SLOT-TPL-STATUS-01 Hold refuses inactive template and inventory_type mismatch', async () => {
    const s = await seedPalace('tplstat');
    const tplId = await createTemplate(s, {
      code: 'evening',
      startTime: '18:00',
      endTime: '23:00',
    });
    const qInactive = await quote(s, s.consumer, 'evening').expect(201);
    await db.query(
      `UPDATE event_slot_templates SET status = 'inactive' WHERE id = $1`,
      [tplId],
    );
    const holdInactive = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-tpl-hold-${newId()}`)
      .send({ quoteId:qInactive.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
    expect(holdInactive.status).toBe(400);
    expect(holdInactive.body.message).toMatch(/not active/i);
    await db.query(
      `UPDATE event_slot_templates SET status = 'active' WHERE id = $1`,
      [tplId],
    );

    const otherType = newId();
    await db.query(
      `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total, base_occupancy, max_occupancy)
       VALUES ($1,$2,'Other','pooled',1,2,4)`,
      [otherType, s.venueId],
    );
    const qMismatch = await quote(s, `${s.consumer}-mm`, 'evening').expect(201);
    await db.query(
      `UPDATE quotes SET inventory_type_id = $2 WHERE id = $1`,
      [qMismatch.body.quoteId, otherType],
    );
    const holdMismatch = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(`${s.consumer}-mm`))
      .set('Idempotency-Key', `p7-tpl-mm-${newId()}`)
      .send({ quoteId:qMismatch.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
    expect(holdMismatch.status).toBe(400);
    expect(holdMismatch.body.message).toMatch(/inventory_type/i);
  });

  it('T-SLOT-NOSHOW-01 no-show uses frozen snapshot; before/after without template edit', async () => {
    const today = riyadhTodayIso();
    const s = await seedPalace('noshow');
    await db.query(
      `INSERT INTO inventory_daily_capacity (id, inventory_type_id, date, capacity, held, booked, blocked)
       VALUES ($1, $2, $3::date, 1, 0, 0, 0)
       ON CONFLICT (inventory_type_id, date) DO NOTHING`,
      [newId(), s.typeId, today],
    );

    await createTemplate(s, {
      code: 'late',
      startTime: '23:50',
      endTime: '23:59',
      date: today,
    });
    const qLate = await quote(s, s.consumer, 'late', today).expect(201);
    const holdLate = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-ns-hold-${newId()}`)
      .send({ quoteId:qLate.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const confLate = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(s.consumer))
      .set('Idempotency-Key', `p7-ns-pav-${newId()}`)
      .send({ holdId: holdLate.body.holdId })
      .expect(201);
    const lateId = confLate.body.bookingId as string;
    const snap = await db.query<{
      slot_start_time: string | null;
      slot_timezone: string | null;
    }>(
      `SELECT to_char(slot_start_time, 'HH24:MI') AS slot_start_time, slot_timezone
       FROM bookings WHERE id = $1`,
      [lateId],
    );
    expect(snap.rows[0].slot_start_time).toBe('23:50');
    expect(snap.rows[0].slot_timezone).toBeTruthy();

    const early = await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${lateId}/no-show`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .set('Idempotency-Key', `p7-ns-early-${newId()}`)
      .send({});
    expect(early.status).toBe(400);
    expect(early.body.code).toBe('VALIDATION_ERROR');

    // Mutating the live template must not unlock no-show — snapshot is frozen.
    await db.query(
      `UPDATE event_slot_templates SET start_time = TIME '00:00'
       WHERE venue_id = $1 AND code = 'late'`,
      [s.venueId],
    );
    const stillEarly = await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${lateId}/no-show`)
      .set('Authorization', auth(s.owner, 'placesProvider'))
      .set('Idempotency-Key', `p7-ns-tpl-${newId()}`)
      .send({});
    expect(stillEarly.status).toBe(400);

    const sAfter = await seedPalace('ns-after');
    await createTemplate(sAfter, {
      code: 'dawn',
      startTime: '00:00',
      endTime: '00:30',
      date: today,
    });
    const qAfter = await quote(sAfter, sAfter.consumer, 'dawn', today).expect(201);
    const holdAfter = await request(app.getHttpServer())
      .post('/v1/holds')
      .set('Authorization', auth(sAfter.consumer))
      .set('Idempotency-Key', `p7-ns-after-hold-${newId()}`)
      .send({ quoteId:qAfter.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
      .expect(201);
    const confAfter = await request(app.getHttpServer())
      .post('/v1/bookings/confirm-pay-at-venue')
      .set('Authorization', auth(sAfter.consumer))
      .set('Idempotency-Key', `p7-ns-after-pav-${newId()}`)
      .send({ holdId: holdAfter.body.holdId })
      .expect(201);
    const afterId = confAfter.body.bookingId as string;
    const slotId = (
      await db.query<{ id: string }>(
        `SELECT id FROM event_slot_inventory WHERE booking_id = $1`,
        [afterId],
      )
    ).rows[0].id;
    await request(app.getHttpServer())
      .post(`/v1/provider/bookings/${afterId}/no-show`)
      .set('Authorization', auth(sAfter.owner, 'placesProvider'))
      .set('Idempotency-Key', `p7-ns-ok-${newId()}`)
      .send({})
      .expect(200);
    const slot = await db.query<{ status: string; booking_id: string | null }>(
      `SELECT status, booking_id FROM event_slot_inventory WHERE id = $1`,
      [slotId],
    );
    expect(slot.rows[0].status).toBe('open');
    expect(slot.rows[0].booking_id).toBeNull();
  });

  it('T-HOLD-LOCK-WAITER-01 hold blocks on venue FOR UPDATE taken before the in-TX barrier', async () => {
    const s = await seedPalace('waiter');
    await createTemplate(s, { code: 'evening', startTime: '18:00', endTime: '23:00' });
    const q = await quote(s, s.consumer, 'evening').expect(201);

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

    const gate = await db.connect();
    let committed = false;
    try {
      await gate.query('BEGIN');
      await gate.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [s.venueId]);
      const holdP = request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(s.consumer))
        .set('Idempotency-Key', `p7-wait-${newId()}`)
        .send({ quoteId:q.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } })
        .then((r) => r);
      await waitForLockWaiters(1);
      await gate.query('COMMIT');
      committed = true;
      const hold = await holdP;
      expect(hold.status).toBe(201);
    } finally {
      if (!committed) await gate.query('ROLLBACK').catch(() => undefined);
      gate.release();
    }
  });

  it('T-SLOT-CAPS-01 event_slot kill switch: disabling env blocks quote (403)', async () => {
    const s = await seedPalace('caps');
    await createTemplate(s, { code: 'evening', startTime: '18:00', endTime: '23:00' });
    process.env.PLACES_EVENT_SLOT_ENABLED = 'false';
    try {
      const res = await quote(s, s.consumer, 'evening');
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('EVENT_SLOT_DISABLED');
    } finally {
      process.env.PLACES_EVENT_SLOT_ENABLED = 'true';
    }
  });
});
