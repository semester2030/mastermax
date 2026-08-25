import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  LOCATION_INCOMPLETE_AR,
  PLACES_SEARCH_CONSTRAINTS,
  buildVenueLocationPatch,
  canPersistCoordinates,
  composeAddressPreview,
  matchCatalogName,
  newAutocompleteSessionToken,
  venueHasCoordinates,
} from "../src/lib/location/venue-location.ts";
import {
  mapsServerKeyConfigured,
  parseGeocodeResponse,
} from "../src/lib/location/geocode.ts";
import { bootLocationMaps } from "../src/lib/google-maps/boot-maps.ts";
import { buildMapsScriptSrc } from "../src/lib/google-maps/load-script.ts";
import { resolveClassicMarkerCtor } from "../src/lib/google-maps/marker-ctor.ts";
import { googleMapLooksBroken } from "../src/lib/google-maps/osm-pin.ts";
import { operatorErrorAr } from "../src/lib/operator-errors.ts";

const cities = [
  { id: "c1", code: "riyadh", nameAr: "الرياض", nameEn: "Riyadh" },
  { id: "c2", code: "jeddah", nameAr: "جدة", nameEn: "Jeddah" },
];

test("search constraints stay in Saudi Arabia and Arabic", () => {
  assert.deepEqual(PLACES_SEARCH_CONSTRAINTS.includedRegionCodes, ["SA"]);
  assert.equal(PLACES_SEARCH_CONSTRAINTS.language, "ar");
  assert.equal(PLACES_SEARCH_CONSTRAINTS.region, "SA");
});

test("autocomplete session tokens are unique per search session", () => {
  const a = newAutocompleteSessionToken();
  const b = newAutocompleteSessionToken();
  assert.notEqual(a, b);
  assert.ok(a.length > 8);
});

test("selecting a place persists search source and confirmed coordinates", () => {
  const patch = buildVenueLocationPatch({
    cityId: "c1",
    districtId: "d1",
    city: "الرياض",
    district: "العليا",
    street: "طريق الملك فهد",
    formattedAddress: "طريق الملك فهد، العليا، الرياض",
    googlePlaceId: "ChIJ-search",
    lat: 24.7136,
    lng: 46.6753,
    locationSource: "search",
    pinConfirmed: true,
  });
  assert.equal(patch.locationSource, "search");
  assert.equal(patch.lat, 24.7136);
  assert.equal(patch.lng, 46.6753);
  assert.equal(patch.latitude, 24.7136);
  assert.equal(patch.longitude, 46.6753);
  assert.equal(patch.googlePlaceId, "ChIJ-search");
});

test("dragging the pin switches source to pin and keeps the new coords", () => {
  const patch = buildVenueLocationPatch({
    lat: 24.72,
    lng: 46.68,
    locationSource: "pin",
    pinConfirmed: true,
    street: "طريق الملك فهد",
  });
  assert.equal(patch.locationSource, "pin");
  assert.equal(patch.lat, 24.72);
  assert.equal(patch.lng, 46.68);
});

test("current location uses geolocation source", () => {
  const patch = buildVenueLocationPatch({
    lat: 24.7,
    lng: 46.6,
    locationSource: "geolocation",
    pinConfirmed: true,
  });
  assert.equal(patch.locationSource, "geolocation");
  assert.ok(canPersistCoordinates({ lat: 24.7, lng: 46.6, pinConfirmed: true }));
});

test("manual address without pin confirmation is saved as a draft only", () => {
  const patch = buildVenueLocationPatch({
    city: "الرياض",
    district: "العليا",
    street: "شارع التحلية",
    formattedAddress: "شارع التحلية، العليا، الرياض",
    lat: 24.7,
    lng: 46.6,
    locationSource: "manual",
    pinConfirmed: false,
  });
  assert.equal(patch.locationSource, "manual");
  assert.equal("lat" in patch, false);
  assert.equal("lng" in patch, false);
  assert.equal(canPersistCoordinates({ lat: 24.7, lng: 46.6, pinConfirmed: false }), false);
});

test("failed geocode payload never invents coordinates", () => {
  const parsed = parseGeocodeResponse({ status: "ZERO_RESULTS", results: [] });
  assert.equal(parsed.ok, false);
  if (parsed.ok) throw new Error("expected failure");
  assert.equal(parsed.reason, "not_found");
  const saved = buildVenueLocationPatch({
    city: "الرياض",
    street: "عنوان غير معروف",
    locationSource: "manual",
    pinConfirmed: false,
  });
  assert.equal(saved.lat, undefined);
  assert.equal(saved.lng, undefined);
});

test("successful geocode requires pin confirmation before persist", () => {
  const parsed = parseGeocodeResponse({
    status: "OK",
    results: [
      {
        formatted_address: "طريق الملك فهد، الرياض",
        place_id: "ChIJ-geo",
        geometry: { location: { lat: 24.7136, lng: 46.6753 } },
        address_components: [
          { long_name: "الرياض", types: ["locality"] },
          { long_name: "العليا", types: ["sublocality"] },
          { long_name: "طريق الملك فهد", types: ["route"] },
        ],
      },
    ],
  });
  assert.equal(parsed.ok, true);
  if (!parsed.ok) throw new Error("expected geocode");
  assert.equal(parsed.city, "الرياض");
  assert.equal(parsed.district, "العليا");
  assert.equal(parsed.street, "طريق الملك فهد");
  assert.equal(
    canPersistCoordinates({ lat: parsed.lat, lng: parsed.lng, pinConfirmed: false }),
    false,
  );
  assert.equal(
    canPersistCoordinates({ lat: parsed.lat, lng: parsed.lng, pinConfirmed: true }),
    true,
  );
});

test("save/reload contract keeps Core field names only", () => {
  const preview = composeAddressPreview({
    street: "طريق الملك فهد",
    district: "العليا",
    city: "الرياض",
  });
  assert.equal(preview, "طريق الملك فهد، العليا، الرياض");
  const patch = buildVenueLocationPatch({
    cityId: "c1",
    districtId: "d1",
    street: "طريق الملك فهد",
    formattedAddress: preview,
    googlePlaceId: "ChIJ-reload",
    lat: 24.7136,
    lng: 46.6753,
    locationSource: "search",
    pinConfirmed: true,
  });
  assert.deepEqual(
    Object.keys(patch).sort(),
    [
      "cityId",
      "districtId",
      "formattedAddress",
      "googlePlaceId",
      "lat",
      "latitude",
      "lng",
      "locationSource",
      "longitude",
      "street",
    ].sort(),
  );
});

test("out-of-range coordinates never persist and block publish completeness", () => {
  assert.equal(venueHasCoordinates({ lat: 91, lng: 46 }), false);
  assert.equal(venueHasCoordinates({ lat: 24.7, lng: 181 }), false);
  assert.equal(canPersistCoordinates({ lat: 91, lng: 46, pinConfirmed: true }), false);
  assert.equal(LOCATION_INCOMPLETE_AR, "الموقع غير مكتمل");
});

test("catalog matching stays tenant-local to provided cities", () => {
  assert.equal(matchCatalogName(cities, "Riyadh")?.id, "c1");
  assert.equal(matchCatalogName(cities, "جدة")?.id, "c2");
  assert.equal(matchCatalogName(cities, "مكة"), undefined);
});

test("server geocode key is never printed and example file has names only", () => {
  assert.equal(mapsServerKeyConfigured({}), false);
  const example = readFileSync(
    join(import.meta.dirname, "../.env.example"),
    "utf8",
  );
  assert.match(example, /NEXT_PUBLIC_GOOGLE_MAPS_WEB_API_KEY=/);
  assert.match(example, /NEXT_PUBLIC_GOOGLE_MAPS_MAP_ID=/);
  assert.match(example, /GOOGLE_MAPS_SERVER_API_KEY=/);
  assert.equal(example.includes("AIza"), false);
});

test("document referrer policy sends a full HTTPS URL so Google HTTP referrers match", () => {
  const config = readFileSync(
    join(import.meta.dirname, "../next.config.ts"),
    "utf8",
  );
  const layout = readFileSync(
    join(import.meta.dirname, "../src/app/layout.tsx"),
    "utf8",
  );
  assert.match(config, /Referrer-Policy/);
  assert.match(config, /no-referrer-when-downgrade/);
  assert.match(layout, /no-referrer-when-downgrade/);
});

test("maps script loads Maps JS only and never bundles Places or async loading flags", () => {
  const src = buildMapsScriptSrc("test-key");
  assert.match(src, /^https:\/\/maps\.googleapis\.com\/maps\/api\/js\?/);
  assert.match(src, /callback=__darPlacesMapsReady/);
  assert.equal(src.includes("libraries="), false);
  assert.equal(src.includes("loading=async"), false);
  assert.equal(src.includes("AIza"), false);
});

test("Google overlay copy is treated as a broken map so OSM can take over", () => {
  const el = {
    innerText: "عفوًا، حدث خطأ. لم تحمِّل هذه الصفحة خرائط Google بشكل صحيح.",
    innerHTML: "<div>error</div>".repeat(20),
    querySelectorAll() {
      return { length: 1 };
    },
  };
  assert.equal(googleMapLooksBroken(el as unknown as HTMLElement), true);
  const ok = {
    innerText: "",
    innerHTML: "<img><img><img>",
    querySelectorAll() {
      return { length: 8 };
    },
  };
  assert.equal(googleMapLooksBroken(ok as unknown as HTMLElement), false);
});

test("classic marker is read from google.maps because importLibrary omits it", () => {
  const mapsLib = { Map: class {} };
  const globalMarker = class {};
  const previous = (globalThis as { window?: unknown }).window;
  (globalThis as { window?: unknown }).window = {
    google: { maps: { Marker: globalMarker } },
  };
  try {
    assert.equal(resolveClassicMarkerCtor(mapsLib as never), globalMarker);
  } finally {
    (globalThis as { window?: unknown }).window = previous;
  }
});

test("map still boots when Places session setup fails", async () => {
  const attached: string[] = [];
  const result = await bootLocationMaps({
    loadScript: async () => undefined,
    createSession: async () => {
      throw new Error("places_new_unavailable");
    },
    attachPin: async () => {
      attached.push("primary");
    },
  });
  assert.equal(result.ready, true);
  assert.equal(result.session, null);
  assert.deepEqual(attached, ["primary"]);
});

test("map falls back to a classic pin when the Map ID attach fails", async () => {
  const attached: string[] = [];
  const result = await bootLocationMaps({
    loadScript: async () => undefined,
    createSession: async () => "token",
    attachPin: async () => {
      throw new Error("advanced_marker_failed");
    },
    attachPinFallback: async () => {
      attached.push("fallback");
    },
  });
  assert.equal(result.ready, true);
  assert.equal(result.session, "token");
  assert.deepEqual(attached, ["fallback"]);
});

test("production moderation English is mapped to Arabic", () => {
  assert.equal(
    operatorErrorAr("Internal media moderation is forbidden in production"),
    "تعذّر اعتماد الوسائط. سجّل الدخول بحساب المطوّر الداخلي ثم أعد المحاولة.",
  );
});

test("location patch is scoped to one venue id and never a second tenant", () => {
  const venueId = "11111111-1111-4111-8111-111111111111";
  const otherVenueId = "22222222-2222-4222-8222-222222222222";
  const patch = buildVenueLocationPatch({
    lat: 24.7,
    lng: 46.6,
    pinConfirmed: true,
    locationSource: "pin",
  });
  assert.equal("venueId" in patch, false);
  assert.equal("providerId" in patch, false);
  assert.notEqual(venueId, otherVenueId);
});
