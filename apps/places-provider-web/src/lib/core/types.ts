export type VenueRow = {
  id: string;
  name?: string;
  venueType?: string;
  venue_type?: string;
  bookingMode?: string;
  booking_mode?: string;
  status?: string;
  city?: string | null;
  cityId?: string | null;
  city_id?: string | null;
  district?: string | null;
  districtId?: string | null;
  district_id?: string | null;
  street?: string | null;
  buildingNo?: string | null;
  landmark?: string | null;
  accessNotes?: string | null;
  mapsUrl?: string | null;
  locationSource?: string | null;
  lat?: number | null;
  lng?: number | null;
  providerId?: string;
  provider_id?: string;
};

export type LocationCity = {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
};

export type LocationDistrict = {
  id: string;
  cityId: string;
  code: string;
  nameAr: string;
  nameEn: string;
};

export type AmenityCatalogRow = {
  code: string;
  label_ar?: string;
  labelAr?: string;
  icon_key?: string;
  applicable_venue_types?: string[];
};

export type VenueAmenityRow = {
  code: string;
  id?: string;
  inventoryTypeId?: string | null;
  scope?: string;
  state?: string;
  labelAr?: string;
  label_ar?: string;
};

export type InventoryTypeRow = {
  id: string;
  venueId?: string;
  code?: string;
  labelAr?: string;
  inventoryModel?: string;
  quantityTotal?: number;
  baseOccupancy?: number;
  maxOccupancy?: number;
  status?: string;
};

export type MediaRow = {
  id: string;
  url?: string;
  kind?: string;
  /** Unified contract status (alias of moderationStatus). */
  status?: string;
  moderationStatus?: string;
  moderation_status?: string;
  /** venue | inventory_type */
  scope?: 'venue' | 'inventory_type';
  /** Unified contract order (alias of sortOrder). */
  order?: number;
  isCover?: boolean;
  is_cover?: boolean;
  cover?: boolean;
  sortOrder?: number;
  sort_order?: number;
  casVersion?: number;
  cas_version?: number;
  inventoryTypeId?: string | null;
  inventory_type_id?: string | null;
};

/** Mirrors Core MEDIA_LIMITS (services/places-core/.../media-contract.ts). */
export const MEDIA_LIMITS = {
  maxImagesPerScope: 30,
  maxVideosPerScope: 3,
} as const;

export type BookingRow = {
  id: string;
  human_code?: string;
  humanCode?: string;
  status?: string;
  check_in?: string;
  check_out?: string;
  checkIn?: string;
  checkOut?: string;
  gross_total?: string | number;
  grossTotal?: string | number;
  consumer_firebase_uid?: string;
  venue_id?: string;
  venueId?: string;
};

export function venueIdOf(v: VenueRow): string {
  return v.id;
}

export function venueNameOf(v: VenueRow): string {
  return v.name ?? "—";
}

export function venueTypeOf(v: VenueRow): string {
  return v.venueType ?? v.venue_type ?? "";
}

export function mediaModerationOf(m: MediaRow): string {
  return m.moderationStatus ?? m.moderation_status ?? "unknown";
}

export function mediaCasOf(m: MediaRow): number {
  return m.casVersion ?? m.cas_version ?? 0;
}

export function bookingCodeOf(b: BookingRow): string {
  return b.humanCode ?? b.human_code ?? b.id.slice(0, 8);
}
