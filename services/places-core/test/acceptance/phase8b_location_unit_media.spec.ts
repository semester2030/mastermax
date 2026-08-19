/**
 * Phase 8B — location, unit media isolation, amenity contract.
 * T-LOC-01 · T-UNIT-MEDIA-01 · T-AMENITY-CONTRACT-01
 */
import { INestApplication } from "@nestjs/common";
import { Pool } from "pg";
import request from "supertest";
import { auth, createTestApp, resetDb, testEnv } from "../helpers/test-app";
import { seedProvider, seedVenue } from "../helpers/seed";
import { newId } from "../../src/shared/ids/ids";

const RIYADH = "01400000-0000-7000-8000-000000000001";
const OLAYA = "01400001-0000-7000-8000-000000000001";
const YASMIN = "01400001-0000-7000-8000-000000000004";

describe("phase8b_location_unit_media", () => {
  let app: INestApplication;
  let db: Pool;

  beforeAll(async () => {
    testEnv();
    process.env.PAYMENT_PROVIDER = "stub";
    await resetDb();
    app = await createTestApp();
    db = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await db?.end();
  });

  it("T-LOC-01 manual location save; catalog never empty", async () => {
    const owner = "p8b-loc-owner";
    const providerId = await seedProvider(db, owner, "P8B-Loc");
    const venue = await request(app.getHttpServer())
      .post("/v1/provider/venues")
      .set("Authorization", auth(owner, "placesProvider"))
      .send({
        providerId,
        name: "شاليه الموقع",
        venueType: "chalet",
        bookingMode: "nightly",
      })
    ;
    expect([200, 201]).toContain(venue.status);

    const venueId = venue.body.venueId as string;
    await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${venueId}`)
      .set("Authorization", auth(owner, "placesProvider"))
      .send({
        cityId: RIYADH,
        districtId: OLAYA,
        street: "طريق الملك فهد",
        buildingNo: "12",
        landmark: "برج المملكة",
        accessNotes: "الدخول من البوابة الغربية",
        mapsUrl: "https://maps.google.com/?q=24.7,46.6",
        locationSource: "manual",
      })
      .expect(200);

    const stored = await request(app.getHttpServer())
      .get(`/v1/provider/venues/${venueId}`)
      .set("Authorization", auth(owner, "placesProvider"))
      .expect(200);
    expect(stored.body.cityId).toBe(RIYADH);
    expect(stored.body.districtId).toBe(OLAYA);
    expect(stored.body.street).toBe("طريق الملك فهد");
    expect(stored.body.locationSource).toBe("manual");
    expect(stored.body.city).toBe("الرياض");
    expect(stored.body.district).toBe("العليا");
    expect(stored.body.lat).toBeNull();
    expect(stored.body.lng).toBeNull();

    const cities = await request(app.getHttpServer())
      .get("/v1/provider/location/cities")
      .set("Authorization", auth(owner, "placesProvider"))
      .expect(200);
    expect(cities.body.some((c: { id: string }) => c.id === RIYADH)).toBe(true);

    const districts = await request(app.getHttpServer())
      .get("/v1/provider/location/districts")
      .query({ cityId: RIYADH })
      .set("Authorization", auth(owner, "placesProvider"))
      .expect(200);
    expect(districts.body.some((d: { id: string }) => d.id === YASMIN)).toBe(
      true,
    );

    const published = await seedVenue(db, providerId, {
      name: "منشور للموقع",
      venueType: "chalet",
      types: [{ name: "وحدة", qty: 1, nights: { "2027-09-01": "400" } }],
    });
    await request(app.getHttpServer())
      .patch(`/v1/provider/venues/${published.venueId}`)
      .set("Authorization", auth(owner, "placesProvider"))
      .send({
        cityId: RIYADH,
        districtId: YASMIN,
        street: "شارع التحلية",
        locationSource: "manual",
      })
      .expect(200);

    const catalog = await request(app.getHttpServer())
      .get(`/v1/venues/${published.venueId}`)
      .set("Authorization", auth(owner))
      .expect(200);
    expect(catalog.body.cityId).toBe(RIYADH);
    expect(catalog.body.districtId).toBe(YASMIN);
    expect(catalog.body.street).toBe("شارع التحلية");
    expect(String(catalog.body.formattedAddress)).toContain("شارع التحلية");
    expect(String(catalog.body.formattedAddress).trim().length).toBeGreaterThan(
      0,
    );
    expect(catalog.body.lat == null || catalog.body.lng == null).toBe(true);
  });

  it("T-UNIT-MEDIA-01 unit media does not mix across types", async () => {
    const owner = "p8b-media-owner";
    const providerId = await seedProvider(db, owner, "P8B-Media");
    const seeded = await seedVenue(db, providerId, {
      name: "وسائط الوحدات",
      venueType: "chalet",
      types: [
        { name: "غرفة", qty: 1, nights: { "2027-09-02": "300" } },
        { name: "جناح", qty: 1, nights: { "2027-09-02": "500" } },
      ],
    });
    const roomId = seeded.types["غرفة"];
    const suiteId = seeded.types["جناح"];
    const roomImg = newId();
    const suiteImg = newId();
    await db.query(
      `INSERT INTO venue_media
         (id, venue_id, inventory_type_id, provider_id, kind, url, moderation_status)
       VALUES ($1,$2,$3,$4,'image',$5,'approved'),
              ($6,$2,$7,$4,'image',$8,'approved')`,
      [
        roomImg,
        seeded.venueId,
        roomId,
        providerId,
        "https://imagedelivery.net/stub/room/public",
        suiteImg,
        suiteId,
        "https://imagedelivery.net/stub/suite/public",
      ],
    );

    const listed = await request(app.getHttpServer())
      .get("/v1/provider/media")
      .query({ venueId: seeded.venueId })
      .set("Authorization", auth(owner, "placesProvider"))
      .expect(200);
    const items = Array.isArray(listed.body) ? listed.body : listed.body.items;
    const roomOnly = items.filter(
      (m: { inventoryTypeId?: string }) => m.inventoryTypeId === roomId,
    );
    const suiteOnly = items.filter(
      (m: { inventoryTypeId?: string }) => m.inventoryTypeId === suiteId,
    );
    expect(roomOnly.some((m: { id: string }) => m.id === roomImg)).toBe(true);
    expect(roomOnly.some((m: { id: string }) => m.id === suiteImg)).toBe(false);
    expect(suiteOnly.some((m: { id: string }) => m.id === suiteImg)).toBe(true);
    expect(suiteOnly.some((m: { id: string }) => m.id === roomImg)).toBe(false);

    const catalog = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}`)
      .set("Authorization", auth(owner))
      .expect(200);
    const room = catalog.body.inventoryTypes.find(
      (t: { id: string }) => t.id === roomId,
    );
    const suite = catalog.body.inventoryTypes.find(
      (t: { id: string }) => t.id === suiteId,
    );
    const roomIds = (room.images as { id: string }[]).map((i) => i.id);
    const suiteIds = (suite.images as { id: string }[]).map((i) => i.id);
    expect(roomIds).toContain(roomImg);
    expect(roomIds).not.toContain(suiteImg);
    expect(suiteIds).toContain(suiteImg);
    expect(suiteIds).not.toContain(roomImg);

    const gallery = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}/gallery`)
      .query({ inventoryTypeId: roomId })
      .set("Authorization", auth(owner))
      .expect(200);
    const gIds = (gallery.body.items as { id: string }[]).map((i) => i.id);
    expect(gIds).toContain(roomImg);
    expect(gIds).not.toContain(suiteImg);
  });

  it("T-AMENITY-CONTRACT-01 same codes in details and filters", async () => {
    const owner = "p8b-amenity-owner";
    const providerId = await seedProvider(db, owner, "P8B-Amenity");
    const seeded = await seedVenue(db, providerId, {
      name: "خدمات موحدة",
      venueType: "hotel",
      types: [{ name: "قياسية", qty: 1, nights: { "2027-09-03": "350" } }],
    });

    const catalog = await request(app.getHttpServer())
      .get("/v1/amenities")
      .query({ venueType: "hotel" })
      .set("Authorization", auth(owner))
      .expect(200);
    const codes = (catalog.body as { code: string }[]).map((a) => a.code);
    expect(codes).toEqual(expect.arrayContaining(["pool", "parking", "breakfast"]));

    await request(app.getHttpServer())
      .put("/v1/provider/amenities")
      .set("Authorization", auth(owner, "placesProvider"))
      .send({
        venueId: seeded.venueId,
        codes: ["pool", "parking", "breakfast"],
      })
      .expect(200);

    const details = await request(app.getHttpServer())
      .get(`/v1/venues/${seeded.venueId}`)
      .set("Authorization", auth(owner))
      .expect(200);
    const linked = (details.body.amenities as { code: string; id: string }[]).map(
      (a) => a.code,
    );
    expect(linked).toEqual(
      expect.arrayContaining(["pool", "parking", "breakfast"]),
    );
    expect(
      (details.body.amenities as { id: string }[]).every((a) =>
        ["pool", "parking", "breakfast"].includes(a.id),
      ),
    ).toBe(true);

    const search = await request(app.getHttpServer())
      .post("/v1/discovery/search")
      .set("Authorization", auth(owner))
      .send({
        category: "hotel",
        amenities: ["pool", "parking"],
        limit: 50,
      });
    expect([200, 201]).toContain(search.status);
    const items = (search.body.items ?? []) as { venueId?: string; id?: string }[];
    expect(
      items.some(
        (i) => i.venueId === seeded.venueId || i.id === seeded.venueId,
      ),
    ).toBe(true);
  });
});
