"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  cancelBooking,
  completeImageUpload,
  completeVideoUpload,
  CoreApiError,
  createImageUploadSession,
  createInventoryType,
  createRatePlan,
  createVenue,
  createVideoUploadSession,
  deleteMedia,
  getVenue,
  moderateMedia,
  patchInventoryType,
  listLocationDistricts,
  patchVenue,
  putAvailability,
  putPricing,
  putVenueAmenities,
  reorderMedia,
  requireProviderId,
  setMediaCover,
} from "@/lib/core/client";
import { describeCoreMediaError } from "@/lib/core/media-errors";
import { describeVenuePublishError } from "@/lib/core/publish-readiness";
import { operatorErrorAr } from "@/lib/operator-errors";
import { eachIsoDate } from "@/lib/calendar-range";
import type { VenueRow } from "@/lib/core/types";
import { isContentOnlyVenueType } from "@/lib/venue-types";

function errMessage(e: unknown): string {
  if (e instanceof CoreApiError) {
    const mapped =
      describeVenuePublishError(e.body) ?? describeCoreMediaError(e.body);
    return operatorErrorAr(mapped ?? e.message);
  }
  if (e instanceof Error) return operatorErrorAr(e.message);
  return "تعذّر إتمام العملية. راجع البيانات ثم أعد المحاولة.";
}

export type ActionResult = { ok: true } | { ok: false; error: string };

/** Venue save reports the status Core actually stored, not the one requested. */
export type VenueSaveResult =
  | { ok: true; status?: string }
  | { ok: false; error: string };

export async function createVenueAction(
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    const providerId = await requireProviderId();
    const name = String(formData.get("name") ?? "").trim();
    const venueType = String(formData.get("venueType") ?? "").trim();
    const bookingMode = String(formData.get("bookingMode") ?? "nightly") as
      | "nightly"
      | "daily";
    const city = String(formData.get("city") ?? "").trim() || undefined;

    if (!name || !venueType) {
      return { ok: false, error: "الاسم ونوع المكان مطلوبان" };
    }

    const result = await createVenue({
      providerId,
      name,
      venueType,
      bookingMode,
      city,
    });
    revalidatePath("/venues");
    redirect(`/venues/${result.venueId}`);
  } catch (e) {
    if (
      e &&
      typeof e === "object" &&
      "digest" in e &&
      typeof (e as { digest: unknown }).digest === "string" &&
      String((e as { digest: string }).digest).startsWith("NEXT_REDIRECT")
    ) {
      throw e;
    }
    const venueType = String(formData.get("venueType") ?? "");
    if (isContentOnlyVenueType(venueType)) {
      return {
        ok: false,
        error: `هذا النوع للمحتوى والوسائط فقط والحجز مغلق. ${errMessage(e)}`,
      };
    }
    return { ok: false, error: errMessage(e) };
  }
}

export async function patchVenueAction(
  venueId: string,
  _prev: VenueSaveResult | null,
  formData: FormData,
): Promise<VenueSaveResult> {
  try {
    const name = String(formData.get("name") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    const cityId = String(formData.get("cityId") ?? "").trim();
    const districtId = String(formData.get("districtId") ?? "").trim();
    const street = String(formData.get("street") ?? "").trim();
    const buildingNo = String(formData.get("buildingNo") ?? "").trim();
    const landmark = String(formData.get("landmark") ?? "").trim();
    const accessNotes = String(formData.get("accessNotes") ?? "").trim();
    const mapsUrl = String(formData.get("mapsUrl") ?? "").trim();
    const locationSource = String(formData.get("locationSource") ?? "manual").trim();
    const body: Record<string, unknown> = { locationSource };
    if (name) body.name = name;
    if (status) body.status = status;
    if (cityId) body.cityId = cityId;
    if (districtId) body.districtId = districtId;
    if (street) body.street = street;
    if (buildingNo) body.buildingNo = buildingNo;
    if (landmark) body.landmark = landmark;
    if (accessNotes) body.accessNotes = accessNotes;
    if (mapsUrl) body.mapsUrl = mapsUrl;
    await patchVenue(venueId, body);
    revalidatePath(`/venues/${venueId}`);
    revalidatePath("/venues");
    // Re-read so the operator is told the stored status, never the requested one.
    let stored: string | undefined;
    try {
      const providerId = await requireProviderId();
      stored = ((await getVenue(venueId, providerId)) as VenueRow).status;
    } catch {
      stored = undefined;
    }
    return { ok: true, status: stored };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function createUnitAction(
  venueId: string,
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    const providerId = await requireProviderId();
    await createInventoryType({
      providerId,
      venueId,
      code: String(formData.get("code") ?? "").trim(),
      labelAr: String(formData.get("labelAr") ?? "").trim(),
      inventoryModel: String(formData.get("inventoryModel") ?? "pooled") as
        | "pooled"
        | "physical",
      quantityTotal: Number(formData.get("quantityTotal") ?? 1),
      baseOccupancy: Number(formData.get("baseOccupancy") ?? 2),
      maxOccupancy: Number(formData.get("maxOccupancy") ?? 2),
    });
    revalidatePath(`/venues/${venueId}/units`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function patchUnitAction(
  venueId: string,
  unitId: string,
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    await patchInventoryType(unitId, {
      labelAr: String(formData.get("labelAr") ?? "").trim() || undefined,
      quantityTotal: Number(formData.get("quantityTotal") ?? 0) || undefined,
      status: String(formData.get("status") ?? "").trim() || undefined,
    });
    revalidatePath(`/venues/${venueId}/units`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function putPricingAction(
  venueId: string,
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    await putPricing({
      ratePlanId: String(formData.get("ratePlanId") ?? "").trim(),
      kind: String(formData.get("kind") ?? "base").trim(),
      amount: String(formData.get("amount") ?? "").trim(),
      dateFrom: String(formData.get("dateFrom") ?? "").trim() || undefined,
      dateTo: String(formData.get("dateTo") ?? "").trim() || undefined,
    });
    revalidatePath(`/venues/${venueId}/pricing`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function createRatePlanAction(
  venueId: string,
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    const providerId = await requireProviderId();
    await createRatePlan({
      providerId,
      venueId,
      inventoryTypeId: String(formData.get("inventoryTypeId") ?? "").trim(),
      name: String(formData.get("name") ?? "").trim() || "افتراضي",
      currency: "SAR",
      isDefault: true,
    });
    revalidatePath(`/venues/${venueId}/pricing`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function putAvailabilityAction(
  venueId: string,
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    const inventoryTypeId = String(formData.get("inventoryTypeId") ?? "").trim();
    const single = String(formData.get("date") ?? "").trim();
    const from = String(formData.get("dateFrom") ?? "").trim() || single;
    const to = String(formData.get("dateTo") ?? "").trim() || from;
    const kind = String(formData.get("kind") ?? "open") as
      | "block"
      | "open"
      | "maintenance";
    const reason = String(formData.get("reason") ?? "").trim() || undefined;
    if (!inventoryTypeId) {
      return { ok: false, error: "اختر الوحدة ثم حدّد الإتاحة." };
    }
    const dates = eachIsoDate(from, to, 62);
    if (dates.length === 0) {
      return {
        ok: false,
        error: "اختر يومًا واحدًا أو نطاق أيام صحيحًا (حتى ٦٢ يومًا).",
      };
    }
    for (const date of dates) {
      await putAvailability({ inventoryTypeId, date, kind, reason });
    }
    revalidatePath(`/venues/${venueId}/availability`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function startImageUploadAction(
  venueId: string,
  inventoryTypeId?: string,
) {
  try {
    const session = await createImageUploadSession({ venueId, inventoryTypeId });
    return { ok: true as const, session };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function finishImageUploadAction(
  venueId: string,
  input: {
    uploadSessionId: string;
    cloudflareImageId: string;
    isCover?: boolean;
    inventoryTypeId?: string;
  },
) {
  try {
    await completeImageUpload(input);
    revalidatePath(`/venues/${venueId}/media`);
    return { ok: true as const };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function startVideoUploadAction(
  venueId: string,
  title?: string,
  inventoryTypeId?: string,
) {
  try {
    const session = await createVideoUploadSession({
      venueId,
      title,
      inventoryTypeId,
    });
    return { ok: true as const, session };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function loadDistrictsAction(cityId: string) {
  try {
    const rows = await listLocationDistricts(cityId);
    return { ok: true as const, districts: rows };
  } catch (e) {
    return { ok: false as const, error: errMessage(e), districts: [] as unknown[] };
  }
}

export async function saveAmenitiesAction(
  venueId: string,
  codes: string[],
  inventoryTypeId?: string,
): Promise<ActionResult> {
  try {
    await putVenueAmenities({ venueId, codes, inventoryTypeId });
    revalidatePath(`/venues/${venueId}`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function finishVideoUploadAction(
  venueId: string,
  uploadSessionId: string,
) {
  try {
    await completeVideoUpload({ uploadSessionId });
    revalidatePath(`/venues/${venueId}/media`);
    return { ok: true as const };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function setCoverAction(
  venueId: string,
  mediaId: string,
  expectedCasVersion: number,
) {
  try {
    await setMediaCover(mediaId, { expectedCasVersion });
    revalidatePath(`/venues/${venueId}/media`);
    return { ok: true as const };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function deleteMediaAction(
  venueId: string,
  mediaId: string,
  expectedCasVersion: number,
) {
  try {
    await deleteMedia(mediaId, { expectedCasVersion });
    revalidatePath(`/venues/${venueId}/media`);
    return { ok: true as const };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function reorderMediaAction(
  venueId: string,
  orderedMediaIds: string[],
  expectedCasVersions: number[],
  inventoryTypeId?: string,
) {
  try {
    await reorderMedia({
      venueId,
      orderedMediaIds,
      expectedCasVersions,
      inventoryTypeId,
    });
    revalidatePath(`/venues/${venueId}/media`);
    return { ok: true as const };
  } catch (e) {
    return { ok: false as const, error: errMessage(e) };
  }
}

export async function cancelBookingAction(
  bookingId: string,
  _prev: ActionResult | null,
  formData: FormData,
): Promise<ActionResult> {
  try {
    await cancelBooking(bookingId, {
      reason: String(formData.get("reason") ?? "").trim() || "إلغاء من مقدم الخدمة",
    });
    revalidatePath("/bookings");
    revalidatePath(`/bookings/${bookingId}`);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}

export async function moderateMediaAction(
  mediaId: string,
  decision: "approved" | "rejected",
  expectedCasVersion: number,
  reason?: string,
): Promise<ActionResult> {
  try {
    await moderateMedia(mediaId, {
      moderationStatus: decision,
      expectedCasVersion,
      reason,
    });
    revalidatePath("/moderation");
    return { ok: true };
  } catch (e) {
    return { ok: false, error: errMessage(e) };
  }
}
