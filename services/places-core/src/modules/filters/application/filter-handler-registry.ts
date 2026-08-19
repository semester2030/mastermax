/**
 * Allowlisted filter handlers — ACTIVE definitions must map here.
 * Never build SQL from DB source_field strings.
 */
export const ACTIVE_FILTER_HANDLERS = {
  category: { requestFields: ['category'], implemented: true },
  city: { requestFields: ['city'], implemented: true },
  district: { requestFields: ['district'], implemented: true },
  price: { requestFields: ['minPrice', 'maxPrice'], implemented: true },
  guests: { requestFields: ['guests'], implemented: true },
  quantity: { requestFields: ['quantity'], implemented: true },
  rating: { requestFields: ['minRating'], implemented: true },
  verified: { requestFields: ['verified'], implemented: true },
  offers: { requestFields: ['offers'], implemented: true },
  distance_km: { requestFields: ['lat', 'lng', 'radiusKm'], implemented: true },
  cancellation: { requestFields: ['cancellation'], implemented: true },
  amenity: { requestFields: ['amenities'], implemented: true },
  stars: { requestFields: ['starsMin'], implemented: true },
  bedrooms: { requestFields: ['bedroomsMin'], implemented: true },
  bathrooms: { requestFields: ['bathroomsMin'], implemented: true },
  capacity: { requestFields: ['capacityMin', 'guests'], implemented: true },
  slot: { requestFields: ['slotCode', 'checkIn'], implemented: true },
  hall_type: { requestFields: ['hallType'], implemented: true },
  inventory_kind: { requestFields: ['inventoryKind'], implemented: true },
  size_sqm: { requestFields: ['sizeSqmMin', 'sizeSqmMax'], implemented: true },
  // dates are trip constraints, not a definition key but used by engine
  check_in: { requestFields: ['checkIn', 'checkOut'], implemented: true },
} as const;

export type FilterHandlerKey = keyof typeof ACTIVE_FILTER_HANDLERS;

export const IMPLEMENTED_DEFINITION_KEYS = new Set<string>(
  Object.entries(ACTIVE_FILTER_HANDLERS)
    .filter(([, v]) => v.implemented)
    .map(([k]) => k),
);

/** Keys that may appear ACTIVE in DB only if listed here. */
export function isHandlerRegistered(key: string): boolean {
  return IMPLEMENTED_DEFINITION_KEYS.has(key);
}
