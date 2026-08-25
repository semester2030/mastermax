import { asArray, getCalendar, listInventoryTypes, listMedia, listRatePlans } from "@/lib/core/client";
import {
  countApprovedVenueImages,
  hasApprovedVenueCover,
  hasApprovedVenueVideo,
  unitHasApprovedImageAndVideo,
} from "@/lib/core/publish-readiness";
import type { InventoryTypeRow, MediaRow, VenueRow } from "@/lib/core/types";
import { venueTypeOf } from "@/lib/core/types";
import { asCalendarDays } from "@/lib/calendar-range";
import { buildPrepareSnapshot, type PrepareEvidence } from "@/lib/prepare-path";
import { isContentOnlyVenueType } from "@/lib/venue-types";
import { venueHasCoordinates } from "@/lib/location/venue-location";

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export async function loadPrepareEvidence(
  providerId: string,
  venue: VenueRow,
): Promise<PrepareEvidence> {
  let media: MediaRow[] = [];
  let approvedVenueImages: number | null = null;
  try {
    media = asArray(await listMedia(providerId, venue.id)) as MediaRow[];
    approvedVenueImages = countApprovedVenueImages(media);
  } catch {
    approvedVenueImages = null;
  }

  let unitCount = 0;
  let units: InventoryTypeRow[] = [];
  try {
    units = asArray(await listInventoryTypes(providerId, venue.id)) as InventoryTypeRow[];
    unitCount = units.length;
  } catch {
    unitCount = 0;
  }

  let ratePlanCount = 0;
  let hasBasePrice = false;
  try {
    const plans = asArray(await listRatePlans(providerId, venue.id)) as Array<{
      id?: string;
      hasBase?: boolean;
      has_base?: boolean;
    }>;
    ratePlanCount = plans.length;
    hasBasePrice = plans.length > 0;
  } catch {
    ratePlanCount = 0;
  }

  let availabilityMarked = false;
  try {
    const from = isoDate(new Date());
    const toDate = new Date();
    toDate.setDate(toDate.getDate() + 60);
    const days = asCalendarDays(await getCalendar(providerId, from, isoDate(toDate)));
    availabilityMarked = days.length > 0;
  } catch {
    availabilityMarked = false;
  }

  const images = media.filter((m) => (m.kind ?? "image") === "image");
  const videos = media.filter((m) => m.kind === "video");
  const allActiveUnitsHaveMedia =
    units.length === 0 ||
    units.every((u) => unitHasApprovedImageAndVideo(media, u.id));
  return {
    hasName: Boolean(venue.name?.trim()),
    hasCity: Boolean((venue.cityId ?? venue.city_id ?? venue.city)?.toString().trim()),
    hasDistrict: Boolean((venue.districtId ?? venue.district_id ?? venue.district)?.toString().trim()),
    hasStreet: Boolean(venue.street?.trim()),
    hasCoordinates: venueHasCoordinates(venue),
    imageCount: images.length,
    approvedVenueImages,
    hasCover: hasApprovedVenueCover(media),
    hasVenueVideo: hasApprovedVenueVideo(media),
    videoCount: videos.length,
    unitCount,
    allActiveUnitsHaveMedia,
    ratePlanCount,
    availabilityMarked,
    hasBasePrice,
    status: venue.status ?? "draft",
    contentOnly: isContentOnlyVenueType(venueTypeOf(venue)),
  };
}

export async function loadPrepareSnapshot(providerId: string, venue: VenueRow) {
  return buildPrepareSnapshot(await loadPrepareEvidence(providerId, venue));
}
