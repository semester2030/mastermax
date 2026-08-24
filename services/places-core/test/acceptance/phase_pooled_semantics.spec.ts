/**
 * Pooled inventory semantics — legacy physical categories become pooled.
 * Does not invent unit names. Real physical units stay independent.
 */
import { INestApplication } from "@nestjs/common";
import { Pool } from "pg";
import request from "supertest";
import { readFileSync } from "fs";
import path from "path";
import { auth, createTestApp, resetDb, testEnv } from "../helpers/test-app";
import { seedProvider, seedVenue } from "../helpers/seed";
import { newId } from "../../src/shared/ids/ids";
import { VenuePublicationService } from "../../src/modules/venues/application/venue-publication.service";

const CONVERT_SQL = `
WITH candidates AS (
  SELECT t.id
  FROM inventory_types t
  WHERE t.inventory_model = 'physical'
    AND t.quantity_total > 1
    AND NOT EXISTS (SELECT 1 FROM inventory_units u WHERE u.inventory_type_id = t.id)
    AND NOT EXISTS (
      SELECT 1 FROM inventory_unit_occupancy o
      JOIN inventory_units u ON u.id = o.inventory_unit_id
      WHERE u.inventory_type_id = t.id
    )
)
UPDATE inventory_types t
SET inventory_model = 'pooled'
FROM candidates c
WHERE t.id = c.id AND t.inventory_model = 'physical'
RETURNING t.id
`;

describe("phase_pooled_semantics", () => {
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

  it("036 is applied and does not invent inventory_units", async () => {
    const mig = await db.query(
      `SELECT 1 FROM schema_migrations WHERE id = '036_pooled_inventory_semantics.sql'`,
    );
    expect(mig.rowCount).toBe(1);
    const sql = readFileSync(
      path.resolve(
        __dirname,
        "../../db/migrations/036_pooled_inventory_semantics.sql",
      ),
      "utf8",
    );
    expect(sql).toMatch(/inventory_model = 'pooled'/);
    expect(sql).not.toMatch(/INSERT INTO inventory_units/i);
  });

  it("غرف ×60 and جناح ×20 convert to pooled and book by count", async () => {
    const owner = `pool-own-${newId()}`;
    const uid = `pool-u-${newId()}`;
    const providerId = await seedProvider(db, owner, "PooledProv");
    const seeded = await seedVenue(db, providerId, {
      name: "فندق البرج",
      venueType: "hotel",
      types: [
        {
          name: "120",
          qty: 60,
          nights: { "2026-12-10": "250.00" },
        },
        {
          name: "150",
          qty: 20,
          nights: { "2026-12-10": "400.00" },
        },
      ],
    });
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical', label_ar = 'غرف' WHERE id = $1`,
      [seeded.types["120"]],
    );
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical', label_ar = 'جناح' WHERE id = $1`,
      [seeded.types["150"]],
    );
    const converted = await db.query(CONVERT_SQL);
    expect(converted.rowCount).toBe(2);
    const models = await db.query<{ inventory_model: string; label_ar: string }>(
      `SELECT inventory_model, label_ar FROM inventory_types WHERE id = ANY($1::uuid[])`,
      [[seeded.types["120"], seeded.types["150"]]],
    );
    expect(models.rows.every((r) => r.inventory_model === "pooled")).toBe(true);

    const catalog = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}`)
      .set("Authorization", auth(uid));
    expect(catalog.status).toBeLessThan(400);
    const names = (
      catalog.body.inventoryTypes as Array<{ name: string; code: string }>
    ).map((t) => t.name);
    expect(names).toEqual(expect.arrayContaining(["غرف", "جناح"]));
    expect(names).not.toContain("120");
    expect(names).not.toContain("150");

    const q = await request(app.getHttpServer())
      .post("/v1/quotes")
      .set("Authorization", auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types["120"],
        checkIn: "2026-12-10",
        checkOut: "2026-12-11",
        quantity: 1,
        guestsAdults: 1,
      });
    expect([200, 201]).toContain(q.status);
    const h = await request(app.getHttpServer())
      .post("/v1/holds")
      .set("Authorization", auth(uid))
      .set("Idempotency-Key", `pool-60-${seeded.types["120"]}`)
      .send({ quoteId: q.body.quoteId, quantity: 1 });
    expect([200, 201]).toContain(h.status);
    expect(h.body.inventoryUnitId ?? null).toBeNull();
  });

  it("does not convert physical types that already have units", async () => {
    const owner = `keep-own-${newId()}`;
    const providerId = await seedProvider(db, owner, "KeepPhys");
    const seeded = await seedVenue(db, providerId, {
      name: "فلل",
      venueType: "villa",
      types: [{ name: "villa-type", qty: 2, nights: { "2026-12-10": "900" } }],
    });
    const typeId = seeded.types["villa-type"];
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical', quantity_total = 2 WHERE id = $1`,
      [typeId],
    );
    await db.query(
      `INSERT INTO inventory_units (id, inventory_type_id, label, status)
       VALUES ($1,$2,'فيلا A','active')`,
      [newId(), typeId],
    );
    const converted = await db.query(CONVERT_SQL);
    const ids = converted.rows.map((r: { id: string }) => r.id);
    expect(ids).not.toContain(typeId);
    const still = await db.query<{ inventory_model: string }>(
      `SELECT inventory_model FROM inventory_types WHERE id = $1`,
      [typeId],
    );
    expect(still.rows[0].inventory_model).toBe("physical");
  });

  it("pooled concurrency cannot exceed quantity; cancel and expiry restore", async () => {
    const owner = `conc-own-${newId()}`;
    const a = `conc-a-${newId()}`;
    const b = `conc-b-${newId()}`;
    const providerId = await seedProvider(db, owner, "ConcProv");
    const seeded = await seedVenue(db, providerId, {
      name: "غرف متزامنة",
      venueType: "hotel",
      types: [{ name: "rooms", qty: 2, nights: { "2026-12-20": "180" } }],
    });
    const typeId = seeded.types.rooms;
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical', label_ar = 'غرف', quantity_total = 2 WHERE id = $1`,
      [typeId],
    );
    await db.query(CONVERT_SQL);

    const quoteHold = async (uid: string, qty: number, key: string) => {
      const q = await request(app.getHttpServer())
        .post("/v1/quotes")
        .set("Authorization", auth(uid))
        .send({
          venueId: seeded.venueId,
          inventoryTypeId: typeId,
          checkIn: "2026-12-20",
          checkOut: "2026-12-21",
          quantity: qty,
          guestsAdults: 1,
        });
      if (q.status >= 400) return q;
      return request(app.getHttpServer())
        .post("/v1/holds")
        .set("Authorization", auth(uid))
        .set("Idempotency-Key", key)
        .send({ quoteId: q.body.quoteId, quantity: qty });
    };

    const first = await quoteHold(a, 2, `conc-ok-${typeId}`);
    expect(first.status).toBeLessThan(400);
    const overflow = await quoteHold(b, 1, `conc-fail-${typeId}`);
    expect(overflow.status).toBeGreaterThanOrEqual(400);

    const cancel = await request(app.getHttpServer())
      .post(`/v1/bookings/${first.body.bookingId}/cancel`)
      .set("Authorization", auth(a))
      .set("Idempotency-Key", `conc-can-${first.body.bookingId}`)
      .send({ reason: "اختبار" });
    expect(cancel.status).toBeLessThan(400);

    const again = await quoteHold(b, 2, `conc-after-can-${typeId}`);
    expect(again.status).toBeLessThan(400);

    await db.query(
      `UPDATE booking_holds SET expires_at = now() - interval '1 minute' WHERE id = $1`,
      [again.body.holdId],
    );
    const { HoldService } = await import(
      "../../src/modules/booking/application/hold.service"
    );
    const n = await app.get(HoldService).expireDue();
    expect(n).toBeGreaterThanOrEqual(1);
    const reuse = await quoteHold(a, 2, `conc-after-exp-${typeId}`);
    expect(reuse.status).toBeLessThan(400);
  });

  it("missing rate plan stays unbookable with rate_plan_missing", async () => {
    const owner = `noprice-${newId()}`;
    const uid = `noprice-u-${newId()}`;
    const providerId = await seedProvider(db, owner, "NoPrice");
    const seeded = await seedVenue(db, providerId, {
      name: "بلا سعر",
      venueType: "hotel",
      types: [{ name: "bare", qty: 5, nights: { "2026-12-10": "100" } }],
    });
    await db.query(`DELETE FROM rate_rules WHERE rate_plan_id = $1`, [
      seeded.plans.bare,
    ]);
    await db.query(`DELETE FROM rate_plans WHERE id = $1`, [seeded.plans.bare]);
    const q = await request(app.getHttpServer())
      .post("/v1/quotes")
      .set("Authorization", auth(uid))
      .send({
        venueId: seeded.venueId,
        inventoryTypeId: seeded.types.bare,
        checkIn: "2026-12-10",
        checkOut: "2026-12-11",
        quantity: 1,
        guestsAdults: 1,
      });
    expect(q.status).toBeGreaterThanOrEqual(400);
    expect(q.body.details?.reason ?? q.body.reason).toBe("rate_plan_missing");
  });

  it("publish refuses physical type with no active unit", async () => {
    const owner = `pub-phys-${newId()}`;
    const providerId = await seedProvider(db, owner, "PubPhys");
    const seeded = await seedVenue(db, providerId, {
      name: "نشر مستقل",
      venueType: "hotel",
      types: [{ name: "chalet", qty: 3, nights: { "2026-12-10": "500" } }],
    });
    await db.query(
      `UPDATE inventory_types SET inventory_model = 'physical', quantity_total = 0 WHERE id = $1`,
      [seeded.types.chalet],
    );
    await db.query(`UPDATE venues SET status = 'draft' WHERE id = $1`, [
      seeded.venueId,
    ]);
    const pub = app.get(VenuePublicationService);
    await expect(
      pub.publishVenue({
        venueId: seeded.venueId,
        actorUid: owner,
        actorRole: "provider",
        correlationId: "pub-phys-fail",
      }),
    ).rejects.toMatchObject({
      code: "VALIDATION_ERROR",
      details: { reason: "physical_unit_required_for_publish" },
    });
  });
});
