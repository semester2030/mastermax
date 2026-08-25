function isValidLatitude(lat: unknown): lat is number {
  return typeof lat === "number" && Number.isFinite(lat) && lat >= -90 && lat <= 90;
}

function isValidLongitude(lng: unknown): lng is number {
  return typeof lng === "number" && Number.isFinite(lng) && lng >= -180 && lng <= 180;
}

export type GeocodeOk = {
  ok: true;
  lat: number;
  lng: number;
  formattedAddress: string;
  googlePlaceId: string | null;
  city: string | null;
  district: string | null;
  street: string | null;
};

export type GeocodeFail = {
  ok: false;
  reason: "unavailable" | "not_found" | "invalid";
};

export type GeocodeResult = GeocodeOk | GeocodeFail;

type GeocodeJson = {
  status?: string;
  results?: Array<{
    formatted_address?: string;
    place_id?: string;
    geometry?: { location?: { lat?: number; lng?: number } };
    address_components?: Array<{
      long_name?: string;
      types?: string[];
    }>;
  }>;
};

export function mapsServerKeyConfigured(env: NodeJS.ProcessEnv = process.env): boolean {
  return Boolean(env.GOOGLE_MAPS_SERVER_API_KEY?.trim());
}

export function parseGeocodeResponse(payload: GeocodeJson): GeocodeResult {
  const first = payload.results?.[0];
  const lat = first?.geometry?.location?.lat;
  const lng = first?.geometry?.location?.lng;
  if (payload.status !== "OK" || !first || !isValidLatitude(lat) || !isValidLongitude(lng)) {
    return { ok: false, reason: payload.status === "ZERO_RESULTS" ? "not_found" : "invalid" };
  }
  const components = first.address_components ?? [];
  const pick = (...types: string[]) =>
    components.find((c) => (c.types ?? []).some((t) => types.includes(t)))?.long_name ??
    null;
  return {
    ok: true,
    lat,
    lng,
    formattedAddress: first.formatted_address?.trim() || "",
    googlePlaceId: first.place_id ?? null,
    city: pick("locality", "administrative_area_level_1"),
    district: pick("sublocality", "sublocality_level_1", "neighborhood"),
    street: pick("route", "street_address"),
  };
}

export async function geocodeSaudiAddress(input: {
  address: string;
  fetchImpl?: typeof fetch;
  env?: NodeJS.ProcessEnv;
}): Promise<GeocodeResult> {
  const key = (input.env ?? process.env).GOOGLE_MAPS_SERVER_API_KEY?.trim();
  if (!key) return { ok: false, reason: "unavailable" };
  const address = input.address.trim();
  if (!address) return { ok: false, reason: "invalid" };
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("address", address);
  url.searchParams.set("components", "country:SA");
  url.searchParams.set("language", "ar");
  url.searchParams.set("region", "SA");
  url.searchParams.set("key", key);
  const fetchImpl = input.fetchImpl ?? fetch;
  const res = await fetchImpl(url);
  if (!res.ok) return { ok: false, reason: "unavailable" };
  return parseGeocodeResponse((await res.json()) as GeocodeJson);
}

export async function reverseGeocodeSaudi(input: {
  lat: number;
  lng: number;
  fetchImpl?: typeof fetch;
  env?: NodeJS.ProcessEnv;
}): Promise<GeocodeResult> {
  if (!isValidLatitude(input.lat) || !isValidLongitude(input.lng)) {
    return { ok: false, reason: "invalid" };
  }
  const key = (input.env ?? process.env).GOOGLE_MAPS_SERVER_API_KEY?.trim();
  if (!key) return { ok: false, reason: "unavailable" };
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("latlng", `${input.lat},${input.lng}`);
  url.searchParams.set("language", "ar");
  url.searchParams.set("region", "SA");
  url.searchParams.set("key", key);
  const fetchImpl = input.fetchImpl ?? fetch;
  const res = await fetchImpl(url);
  if (!res.ok) return { ok: false, reason: "unavailable" };
  return parseGeocodeResponse((await res.json()) as GeocodeJson);
}
