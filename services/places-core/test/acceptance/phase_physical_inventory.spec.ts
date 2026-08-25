/**
 * Physical inventory closure — targeted acceptance.
 * Two units same dates · same unit concurrency · non-overlap · cancel/expiry · PAV · pooled.
 */
import { INestApplication } from "@nestjs/common";
import { Pool } from "pg";
import request from "supertest";
import { auth, createTestApp, resetDb, testEnv } from "../helpers/test-app";
import { seedProvider, seedVenue } from "../helpers/seed";
import { newId } from "../../src/shared/ids/ids";

async function quoteHold(
  app: INestApplication,
  uid: string,
  body: {
    venueId: string;
    inventoryTypeId: string;
    inventoryUnitId: string;
    checkIn: string;
    checkOut: string;
    key: string;
  },
) {
  const quote = await request(app.getHttpServer())
    .post("/v1/quotes")
    .set("Authorization", auth(uid))
    .send({
      venueId: body.venueId,
      inventoryTypeId: body.inventoryTypeId,
      inventoryUnitId: body.inventoryUnitId,
      checkIn: body.checkIn,
      checkOut: body.checkOut,
      quantity: 1,
      guestsAdults: 1,
    });
  if (quote.status !== 201 && quote.status !== 200) {
    return { quote, hold: quote };
  }
  const hold = await request(app.getHttpServer())
    .post("/v1/holds")
    .set("Authorization", auth(uid))
    .set("Idempotency-Key", body.key)
    .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
  return { quote, hold };
}

describe("phase_physical_inventory", () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = "stub";
    process.env.PLACES_PAY_AT_VENUE_ENABLED = "true";
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  async function seedPhysical(): Promise<{
    owner: string;
    uidA: string;
    uidB: string;
    venueId: string;
    typeId: string;
    unitA: string;
    unitB: string;
    pooledTypeId: string;
  }> {
    const owner = `phys-owner-${newId()}`;
    const uidA = `phys-a-${newId()}`;
    const uidB = `phys-b-${newId()}`;
    const providerId = await seedProvider(db, owner, "PhysProv");
    const seeded = await seedVenue(db, providerId, {
      name: "فندق الوحدات",
      venueType: "hotel",
      types: [
        {
          name: "suite",
          qty: 2,
          nights: { "2026-11-10": "200.00", "2026-11-12": "200.00" },
        },
        {
          name: "pooled-std",
          qty: 3,
          nights: { "2026-11-10": "150.00" },
        },
      ],
    });
    const typeId = seeded.types.suite;
    const pooledTypeId = seeded.types["pooled-std"];
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical', quantity_total = 0 WHERE id = $1`,
      [typeId],
    );
    const createdA = await request(app.getHttpServer())
      .post(`/v1/provider/inventory-types/${typeId}/units`)
      .set("Authorization", auth(owner, "placesProvider"))
      .set("Idempotency-Key", `u-a-${typeId}`)
      .send({ providerId, labelAr: "جناح الواجهة" });
    const createdB = await request(app.getHttpServer())
      .post(`/v1/provider/inventory-types/${typeId}/units`)
      .set("Authorization", auth(owner, "placesProvider"))
      .set("Idempotency-Key", `u-b-${typeId}`)
      .send({ providerId, labelAr: "جناح الحديقة" });
    expect([200, 201]).toContain(createdA.status);
    expect([200, 201]).toContain(createdB.status);
    return {
      owner,
      uidA,
      uidB,
      venueId: seeded.venueId,
      typeId,
      unitA: createdA.body.id as string,
      unitB: createdB.body.id as string,
      pooledTypeId,
    };
  }

  it("T-PHYS-01 two different units same dates succeed", async () => {
    const s = await seedPhysical();
    const a = await quoteHold(app, s.uidA, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-1a-${s.unitA}`,
    });
    const b = await quoteHold(app, s.uidB, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitB,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-1b-${s.unitB}`,
    });
    expect([200, 201]).toContain(a.hold.status);
    expect([200, 201]).toContain(b.hold.status);
    expect(a.hold.body.inventoryUnitId).toBe(s.unitA);
    expect(b.hold.body.inventoryUnitId).toBe(s.unitB);
  });

  it("T-PHYS-02 same unit same dates — only one concurrent hold", async () => {
    const s = await seedPhysical();
    const results = await Promise.all(
      [s.uidA, s.uidB].map((uid, i) =>
        quoteHold(app, uid, {
          venueId: s.venueId,
          inventoryTypeId: s.typeId,
          inventoryUnitId: s.unitA,
          checkIn: "2026-11-10",
          checkOut: "2026-11-11",
          key: `phys-race-${i}-${s.unitA}`,
        }),
      ),
    );
    const ok = results.filter((r) => r.hold.status < 400);
    const fail = results.filter((r) => r.hold.status >= 400);
    expect(ok).toHaveLength(1);
    expect(fail).toHaveLength(1);
    expect(fail[0].hold.body.code).toBe("AVAILABILITY_CHANGED");
  });

  it("T-PHYS-03 non-overlapping dates on same unit succeed", async () => {
    const s = await seedPhysical();
    const first = await quoteHold(app, s.uidA, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-seq-1-${s.unitA}`,
    });
    expect([200, 201]).toContain(first.hold.status);
    const second = await quoteHold(app, s.uidB, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-12",
      checkOut: "2026-11-13",
      key: `phys-seq-2-${s.unitA}`,
    });
    expect([200, 201]).toContain(second.hold.status);
  });

  it("T-PHYS-04 cancel and hold expiry return the unit", async () => {
    const s = await seedPhysical();
    const held = await quoteHold(app, s.uidA, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-can-${s.unitA}`,
    });
    expect([200, 201]).toContain(held.hold.status);
    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${held.hold.body.bookingId}/cancel`)
      .set("Authorization", auth(s.uidA))
      .set("Idempotency-Key", `phys-cancel-${held.hold.body.bookingId}`)
      .send({ reason: "اختبار إلغاء" });
    expect([200, 201]).toContain(cancel.status);

    const again = await quoteHold(app, s.uidB, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-after-cancel-${s.unitA}`,
    });
    expect([200, 201]).toContain(again.hold.status);

    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`,
      [again.hold.body.holdId],
    );
    const { HoldService } = await import(
      "../../src/modules/booking/application/hold.service"
    );
    const holds = app.get(HoldService);
    const n = await holds.expireDue();
    expect(n).toBeGreaterThanOrEqual(1);

    const reuse = await quoteHold(app, s.uidA, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-after-exp-${s.unitA}`,
    });
    expect([200, 201]).toContain(reuse.hold.status);
  });

  it("T-PHYS-05 PAV confirms the same unit without PaymentIntent", async () => {
    const s = await seedPhysical();
    const held = await quoteHold(app, s.uidA, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitB,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-pav-${s.unitB}`,
    });
    expect(held.hold.body.paymentOptions.payAtVenue).toBe(true);
    const confirm = await request(app.getHttpServer())
      .post("/v1/bookings/confirm-pay-at-venue")
      .set("Authorization", auth(s.uidA))
      .set("Idempotency-Key", `phys-pav-c-${s.unitB}`)
      .send({ holdId: held.hold.body.holdId });
    expect(confirm.status).toBeLessThan(400);
    expect(confirm.body.humanCode).toMatch(/^BKG-/);
    expect(confirm.body.paymentMethod).toBe("PAY_AT_VENUE");
    const occ = await db.query<{ status: string; inventory_unit_id: string }>(
      `SELECT status, inventory_unit_id FROM inventory_unit_occupancy WHERE hold_id = $1`,
      [held.hold.body.holdId],
    );
    expect(occ.rows[0].status).toBe("booked");
    expect(occ.rows[0].inventory_unit_id).toBe(s.unitB);
    const intents = await db.query(
      `SELECT id FROM payments WHERE hold_id = $1`,
      [held.hold.body.holdId],
    );
    expect(intents.rowCount).toBe(0);
  });

  it("T-PHYS-06 pooled path still holds two of three", async () => {
    const s = await seedPhysical();
    const q1 = await request(app.getHttpServer())
      .post("/v1/quotes")
      .set("Authorization", auth(s.uidA))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.pooledTypeId,
        checkIn: "2026-11-10",
        checkOut: "2026-11-11",
        quantity: 2,
        guestsAdults: 1,
      });
    expect([200, 201]).toContain(q1.status);
    const h1 = await request(app.getHttpServer())
      .post("/v1/holds")
      .set("Authorization", auth(s.uidA))
      .set("Idempotency-Key", `pooled-ok-${s.pooledTypeId}`)
      .send({ quoteId:q1.body.quoteId, quantity: 2, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
    expect([200, 201]).toContain(h1.status);
    const q2 = await request(app.getHttpServer())
      .post("/v1/quotes")
      .set("Authorization", auth(s.uidB))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.pooledTypeId,
        checkIn: "2026-11-10",
        checkOut: "2026-11-11",
        quantity: 2,
        guestsAdults: 1,
      });
    const h2 = await request(app.getHttpServer())
      .post("/v1/holds")
      .set("Authorization", auth(s.uidB))
      .set("Idempotency-Key", `pooled-fail-${s.pooledTypeId}`)
      .send({ quoteId:q2.body.quoteId, quantity: 2, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
    expect(h2.status).toBeGreaterThanOrEqual(400);
  });

  it("T-PHYS-07 availability omits booked unit and catalog lists labels", async () => {
    const s = await seedPhysical();
    const first = await quoteHold(app, s.uidA, {
      venueId: s.venueId,
      inventoryTypeId: s.typeId,
      inventoryUnitId: s.unitA,
      checkIn: "2026-11-10",
      checkOut: "2026-11-11",
      key: `phys-av-${s.unitA}`,
    });
    expect([200, 201]).toContain(first.hold.status);
    const av = await request(app.getHttpServer())
      .post("/v1/availability/search")
      .set("Authorization", auth(s.uidB))
      .send({
        venueId: s.venueId,
        inventoryTypeId: s.typeId,
        checkIn: "2026-11-10",
        checkOut: "2026-11-11",
        quantity: 1,
      });
    expect(av.status).toBeLessThan(400);
    const ids = (av.body.units as Array<{ id: string; label: string }>).map(
      (u) => u.id,
    );
    expect(ids).toContain(s.unitB);
    expect(ids).not.toContain(s.unitA);
    expect(av.body.units[0].label).toMatch(/جناح/);
    const listed = await request(app.getHttpServer())
      .get(`/v1/provider/inventory-types/${s.typeId}/units`)
      .set("Authorization", auth(s.owner, "placesProvider"))
      .query({ providerId: (await db.query<{ provider_id: string }>(
        `SELECT provider_id FROM venues WHERE id = $1`,
        [s.venueId],
      )).rows[0].provider_id });
    expect(listed.body.items).toHaveLength(2);
    expect(listed.body.items.map((i: { label: string }) => i.label)).toEqual(
      expect.arrayContaining(["جناح الواجهة", "جناح الحديقة"]),
    );
  });
});
