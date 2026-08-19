/** Exact Core venue_type strings used by Wave1 Provider Web. */

export const FULL_BOOKING_VENUE_TYPES = [
  "hotel",
  "apartment",
  "chalet",
  "rest_house",
  "farm",
] as const;

export const CONTENT_ONLY_VENUE_TYPES = [
  "wedding_palace",
  "event_hall",
] as const;

export type FullBookingVenueType = (typeof FULL_BOOKING_VENUE_TYPES)[number];
export type ContentOnlyVenueType = (typeof CONTENT_ONLY_VENUE_TYPES)[number];
export type Wave1VenueType = FullBookingVenueType | ContentOnlyVenueType;

export const VENUE_TYPE_LABELS_AR: Record<Wave1VenueType, string> = {
  hotel: "فندق",
  apartment: "شقة",
  chalet: "شاليه",
  rest_house: "استراحة",
  farm: "مزرعة",
  wedding_palace: "قصر أفراح",
  event_hall: "قاعة مناسبات",
};

export const CONTENT_ONLY_BANNER_AR = "محتوى ووسائط فقط — الحجز مغلق";

export function isContentOnlyVenueType(venueType: string): boolean {
  return (CONTENT_ONLY_VENUE_TYPES as readonly string[]).includes(venueType);
}

export function isFullBookingVenueType(venueType: string): boolean {
  return (FULL_BOOKING_VENUE_TYPES as readonly string[]).includes(venueType);
}

export function venueTypeLabelAr(venueType: string): string {
  return (
    VENUE_TYPE_LABELS_AR[venueType as Wave1VenueType] ?? venueType
  );
}
