/**
 * Unified media contract constants (Phase 6 / F-V3-013).
 * Provider Web and Core must share these limits for kind/status/scope/order/cover.
 */
export const MEDIA_KIND = ['image', 'video'] as const;
export type MediaKind = (typeof MEDIA_KIND)[number];

export const MEDIA_MODERATION_STATUS = [
  'pending',
  'approved',
  'rejected',
] as const;
export type MediaModerationStatus = (typeof MEDIA_MODERATION_STATUS)[number];

/** Venue-level vs inventory-type scoped gallery. */
export const MEDIA_SCOPE = ['venue', 'inventory_type'] as const;
export type MediaScope = (typeof MEDIA_SCOPE)[number];

export const MEDIA_LIMITS = {
  maxImagesPerScope: 30,
  maxVideosPerScope: 3,
  uploadSessionTtlMs: 30 * 60 * 1000,
  /** Rejected media soft-retention before orphan/CF cleanup eligibility (days). */
  rejectedRetentionDays: 30,
  cloudflareFetchTimeoutMs: Number(
    process.env.PLACES_CF_FETCH_TIMEOUT_MS ?? 12_000,
  ),
} as const;

export function mediaScopeFromInventoryTypeId(
  inventoryTypeId: string | null | undefined,
): MediaScope {
  return inventoryTypeId ? 'inventory_type' : 'venue';
}

export type MediaListItemContract = {
  id: string;
  kind: MediaKind | string;
  status: MediaModerationStatus | string;
  scope: MediaScope;
  order: number;
  cover: boolean;
  casVersion: number;
  url?: string | null;
  coverUrl?: string | null;
  inventoryTypeId?: string | null;
};
