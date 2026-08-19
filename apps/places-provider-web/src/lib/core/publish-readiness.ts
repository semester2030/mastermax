/**
 * Publish gating mirrored from Places Core Phase 8B.
 * Core remains the sole authority.
 */

import type { MediaRow } from "./types";

export const PUBLISH_REQUIRES_IMAGE_AR =
  "يلزم مدينة وحي وشارع، وفيديو رئيسي معتمد، وصورة غلاف، وسعر وإتاحة، ووسائط معتمدة لكل وحدة نشطة.";

function isVenueLevel(m: MediaRow): boolean {
  const id = m.inventoryTypeId ?? m.inventory_type_id;
  return id == null || id === "";
}

function isImage(m: MediaRow): boolean {
  return (m.kind ?? "").toLowerCase() === "image";
}

function isVideo(m: MediaRow): boolean {
  return (m.kind ?? "").toLowerCase() === "video";
}

function isApproved(m: MediaRow): boolean {
  return (m.moderationStatus ?? m.moderation_status) === "approved";
}

export function countApprovedVenueImages(media: readonly MediaRow[]): number {
  return media.filter((m) => isImage(m) && isVenueLevel(m) && isApproved(m))
    .length;
}

export function hasApprovedVenueCover(media: readonly MediaRow[]): boolean {
  return media.some(
    (m) =>
      isImage(m) &&
      isVenueLevel(m) &&
      isApproved(m) &&
      (m.isCover ?? m.is_cover ?? m.cover) === true,
  );
}

export function hasApprovedVenueVideo(media: readonly MediaRow[]): boolean {
  return media.some((m) => isVideo(m) && isVenueLevel(m) && isApproved(m));
}

export function unitHasApprovedImageAndVideo(
  media: readonly MediaRow[],
  inventoryTypeId: string,
): boolean {
  const scoped = media.filter(
    (m) => (m.inventoryTypeId ?? m.inventory_type_id) === inventoryTypeId,
  );
  return (
    scoped.some((m) => isImage(m) && isApproved(m)) &&
    scoped.some((m) => isVideo(m) && isApproved(m))
  );
}

export type PublishUiEvidence = {
  hasCityId: boolean;
  hasDistrictId: boolean;
  hasStreet: boolean;
  approvedVenueImages: number | null;
  hasCover: boolean;
  hasVenueVideo: boolean;
  hasPrice: boolean;
  hasAvailability: boolean;
  allActiveUnitsHaveMedia: boolean;
};

export function canPublish(approvedVenueImages: number | null): boolean {
  return approvedVenueImages == null || approvedVenueImages > 0;
}

export function canPublishFromEvidence(e: PublishUiEvidence): boolean {
  if (e.approvedVenueImages == null) return true;
  return (
    e.hasCityId &&
    e.hasDistrictId &&
    e.hasStreet &&
    e.hasCover &&
    e.hasVenueVideo &&
    e.hasPrice &&
    e.hasAvailability &&
    e.allActiveUnitsHaveMedia
  );
}

export function describeVenuePublishError(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const envelope = body as { code?: string; message?: string };
  if (envelope.code !== "VALIDATION_ERROR") return null;
  const msg = envelope.message ?? "";
  if (
    /cityId|districtId|street|cover image|hero video|price|availability|unit type/i.test(
      msg,
    ) ||
    /approved venue-level image/i.test(msg)
  ) {
    return `تعذّر النشر — ${PUBLISH_REQUIRES_IMAGE_AR}`;
  }
  return null;
}
