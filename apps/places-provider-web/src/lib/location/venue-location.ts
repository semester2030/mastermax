export const LOCATION_INCOMPLETE_AR = "الموقع غير مكتمل";
export const LOCATION_PIN_CONFIRM_AR = "أكد موقع الدبوس على الخريطة قبل الحفظ بالإحداثيات.";
export const LOCATION_GEOCODE_FAILED_AR =
  "تعذّر تحويل العنوان إلى إحداثيات. يمكن حفظه كمسودة فقط ولن يُنشر للاكتشاف.";
export const LOCATION_GEO_DENIED_AR =
  "رُفض الوصول إلى الموقع الحالي. يمكنك البحث أو إدخال العنوان يدويًا.";
export const LOCATION_API_UNAVAILABLE_AR =
  "خرائط Google غير متاحة الآن. الإدخال اليدوي للمدينة والحي والشارع ما زال متاحًا.";

export const SAUDI_DEFAULT_CENTER = { lat: 24.7136, lng: 46.6753 } as const;

export const PLACES_SEARCH_CONSTRAINTS = {
  includedRegionCodes: ["SA"],
  language: "ar",
  region: "SA",
} as const;

export type LocationSource = "manual" | "geolocation" | "search" | "pin";

export type VenueLocationDraft = {
  city?: string | null;
  cityId?: string | null;
  district?: string | null;
  districtId?: string | null;
  street?: string | null;
  formattedAddress?: string | null;
  googlePlaceId?: string | null;
  lat?: number | null;
  lng?: number | null;
  locationSource?: LocationSource | null;
  pinConfirmed?: boolean;
};

export function isValidLatitude(lat: unknown): lat is number {
  return typeof lat === "number" && Number.isFinite(lat) && lat >= -90 && lat <= 90;
}

export function isValidLongitude(lng: unknown): lng is number {
  return typeof lng === "number" && Number.isFinite(lng) && lng >= -180 && lng <= 180;
}

export function isValidLatLng(lat: unknown, lng: unknown): boolean {
  return isValidLatitude(lat) && isValidLongitude(lng);
}

export function venueHasCoordinates(row: {
  lat?: unknown;
  lng?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  locationComplete?: unknown;
}): boolean {
  if (row.locationComplete === true) return true;
  const lat = row.lat ?? row.latitude;
  const lng = row.lng ?? row.longitude;
  return isValidLatLng(
    typeof lat === "string" ? Number(lat) : lat,
    typeof lng === "string" ? Number(lng) : lng,
  );
}

export function composeAddressPreview(parts: {
  street?: string | null;
  district?: string | null;
  city?: string | null;
  formattedAddress?: string | null;
}): string {
  const stored = parts.formattedAddress?.trim();
  if (stored) return stored;
  return [parts.street, parts.district, parts.city]
    .filter((p): p is string => typeof p === "string" && p.trim().length > 0)
    .map((p) => p.trim())
    .join("، ");
}

export function matchCatalogName<T extends { nameAr: string; nameEn: string }>(
  rows: readonly T[],
  raw: string | null | undefined,
): T | undefined {
  const needle = raw?.trim().toLowerCase();
  if (!needle) return undefined;
  return rows.find(
    (row) =>
      row.nameAr.trim().toLowerCase() === needle ||
      row.nameEn.trim().toLowerCase() === needle,
  );
}

export function canPersistCoordinates(draft: VenueLocationDraft): boolean {
  return isValidLatLng(draft.lat, draft.lng) && draft.pinConfirmed === true;
}

export function buildVenueLocationPatch(draft: VenueLocationDraft): Record<string, unknown> {
  const body: Record<string, unknown> = {
    locationSource: draft.locationSource ?? "manual",
  };
  if (draft.cityId) body.cityId = draft.cityId;
  if (draft.districtId) body.districtId = draft.districtId;
  if (typeof draft.city === "string" && draft.city.trim()) body.city = draft.city.trim();
  if (typeof draft.district === "string" && draft.district.trim()) {
    body.district = draft.district.trim();
  }
  if (typeof draft.street === "string" && draft.street.trim()) {
    body.street = draft.street.trim();
  }
  if (typeof draft.formattedAddress === "string" && draft.formattedAddress.trim()) {
    body.formattedAddress = draft.formattedAddress.trim();
  }
  if (typeof draft.googlePlaceId === "string" && draft.googlePlaceId.trim()) {
    body.googlePlaceId = draft.googlePlaceId.trim();
  }
  if (canPersistCoordinates(draft)) {
    body.lat = draft.lat;
    body.lng = draft.lng;
    body.latitude = draft.lat;
    body.longitude = draft.lng;
  }
  return body;
}

export function newAutocompleteSessionToken(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `sa-places-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
