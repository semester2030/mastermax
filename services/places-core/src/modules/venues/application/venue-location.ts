export function isValidLatitude(lat: unknown): lat is number {
  return typeof lat === "number" && Number.isFinite(lat) && lat >= -90 && lat <= 90;
}

export function isValidLongitude(lng: unknown): lng is number {
  return typeof lng === "number" && Number.isFinite(lng) && lng >= -180 && lng <= 180;
}

export function isValidLatLng(lat: unknown, lng: unknown): boolean {
  return isValidLatitude(lat) && isValidLongitude(lng);
}

export function composeFormattedAddress(parts: {
  street?: string | null;
  buildingNo?: string | null;
  district?: string | null;
  city?: string | null;
  formattedAddress?: string | null;
}): string | null {
  const stored = parts.formattedAddress?.trim();
  if (stored) return stored;
  const joined = [
    parts.street,
    parts.buildingNo,
    parts.district,
    parts.city,
  ]
    .filter((p): p is string => typeof p === "string" && p.trim().length > 0)
    .map((p) => p.trim())
    .join("، ");
  return joined || null;
}

export function venueHasPublishableCoordinates(row: {
  lat?: unknown;
  lng?: unknown;
  latitude?: unknown;
  longitude?: unknown;
}): boolean {
  const lat = row.lat ?? row.latitude;
  const lng = row.lng ?? row.longitude;
  return isValidLatLng(
    typeof lat === "string" ? Number(lat) : lat,
    typeof lng === "string" ? Number(lng) : lng,
  );
}

export function projectVenueLocation(row: {
  lat?: unknown;
  lng?: unknown;
  city?: string | null;
  district?: string | null;
  street?: string | null;
  building_no?: string | null;
  formatted_address?: string | null;
  google_place_id?: string | null;
  location_source?: string | null;
}): {
  lat: number | null;
  lng: number | null;
  latitude: number | null;
  longitude: number | null;
  formattedAddress: string | null;
  googlePlaceId: string | null;
  locationSource: string | null;
  locationComplete: boolean;
} {
  const latNum =
    typeof row.lat === "number"
      ? row.lat
      : typeof row.lat === "string"
        ? Number(row.lat)
        : null;
  const lngNum =
    typeof row.lng === "number"
      ? row.lng
      : typeof row.lng === "string"
        ? Number(row.lng)
        : null;
  const lat = isValidLatitude(latNum) ? latNum : null;
  const lng = isValidLongitude(lngNum) ? lngNum : null;
  return {
    lat,
    lng,
    latitude: lat,
    longitude: lng,
    formattedAddress: composeFormattedAddress({
      street: row.street,
      buildingNo: row.building_no,
      district: row.district,
      city: row.city,
      formattedAddress: row.formatted_address,
    }),
    googlePlaceId: row.google_place_id ?? null,
    locationSource: row.location_source ?? null,
    locationComplete: lat != null && lng != null,
  };
}
