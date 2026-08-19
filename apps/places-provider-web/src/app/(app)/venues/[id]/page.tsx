import Link from "next/link";
import { ReviewPanel } from "@/components/review-panel";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { VenueEditForm } from "@/components/venue-edit-form";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  getVenue,
  listAmenityCatalog,
  listLocationCities,
  listLocationDistricts,
  listVenueAmenities,
  requireProviderId,
} from "@/lib/core/client";
import { loadPrepareEvidence } from "@/lib/load-prepare";
import { buildPrepareSnapshot, VENUE_STATUS_LABEL_AR } from "@/lib/prepare-path";
import type {
  AmenityCatalogRow,
  LocationCity,
  LocationDistrict,
  VenueAmenityRow,
  VenueRow,
} from "@/lib/core/types";
import { venueNameOf, venueTypeOf } from "@/lib/core/types";
import { AmenityPicker } from "@/components/amenity-picker";
import {
  CONTENT_ONLY_BANNER_AR,
  isContentOnlyVenueType,
  venueTypeLabelAr,
} from "@/lib/venue-types";
import { operatorErrorAr } from "@/lib/operator-errors";

export default async function VenueDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const providerId = await requireProviderId();
  let venue: VenueRow | null = null;
  let error: string | null = null;
  let cities: LocationCity[] = [];
  let districts: LocationDistrict[] = [];
  let amenityCatalog: AmenityCatalogRow[] = [];
  let venueAmenities: VenueAmenityRow[] = [];
  try {
    venue = (await getVenue(id, providerId)) as VenueRow;
    cities = asArray(await listLocationCities()) as LocationCity[];
    const cityId = venue.cityId ?? venue.city_id;
    if (cityId) {
      districts = asArray(await listLocationDistricts(cityId)) as LocationDistrict[];
    }
    amenityCatalog = asArray(
      await listAmenityCatalog(venueTypeOf(venue)),
    ) as AmenityCatalogRow[];
    venueAmenities = asArray(await listVenueAmenities(id)) as VenueAmenityRow[];
  } catch (e) {
    error =
      e instanceof CoreApiError
        ? operatorErrorAr(e.message)
        : "تعذّر جلب تفاصيل المكان. حدّث الصفحة ثم أعد المحاولة.";
  }

  const evidence = venue
    ? await loadPrepareEvidence(providerId, venue)
    : null;
  const snapshot = evidence ? buildPrepareSnapshot(evidence) : null;
  const type = venue ? venueTypeOf(venue) : "";

  return (
    <div className="space-y-6">
      <div>
        <Link
          href="/venues"
          className="text-sm text-[var(--color-text-secondary)] hover:text-[var(--color-primary)]"
        >
          الأماكن
        </Link>
        <h1 className="mt-2 text-2xl font-bold">
          {venue ? venueNameOf(venue) : "بيانات المكان"}
        </h1>
        {venue ? (
          <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
            {venueTypeLabelAr(type)} ·{" "}
            {VENUE_STATUS_LABEL_AR[venue.status ?? "draft"] ?? "مسودة"}
          </p>
        ) : null}
      </div>

      {evidence ? (
        <VenueStepper venueId={id} current="basics" evidence={evidence} />
      ) : null}

      {isContentOnlyVenueType(type) ? (
        <p
          className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_12%,white)] px-3 py-2 text-sm"
          role="status"
        >
          {CONTENT_ONLY_BANNER_AR}
        </p>
      ) : null}

      {error ? (
        <ErrorState title="تعذّر فتح المكان" description={error} />
      ) : (
        <>
          <VenueEditForm
            venueId={id}
            initial={{
              name: venue?.name,
              cityId: venue?.cityId ?? venue?.city_id,
              districtId: venue?.districtId ?? venue?.district_id,
              street: venue?.street,
              buildingNo: venue?.buildingNo,
              landmark: venue?.landmark,
              accessNotes: venue?.accessNotes,
              mapsUrl: venue?.mapsUrl,
              status: venue?.status,
            }}
            cities={cities}
            initialDistricts={districts}
            publishEvidence={{
              hasCityId: Boolean(venue?.cityId ?? venue?.city_id),
              hasDistrictId: Boolean(venue?.districtId ?? venue?.district_id),
              hasStreet: Boolean(venue?.street?.trim()),
              approvedVenueImages: evidence?.approvedVenueImages ?? null,
              hasCover: evidence?.hasCover ?? false,
              hasVenueVideo: evidence?.hasVenueVideo ?? false,
              hasPrice: evidence?.hasBasePrice ?? false,
              hasAvailability: evidence?.availabilityMarked ?? false,
              allActiveUnitsHaveMedia: evidence?.allActiveUnitsHaveMedia ?? false,
            }}
          />
          <AmenityPicker
            venueId={id}
            catalog={amenityCatalog}
            selected={venueAmenities}
          />
        </>
      )}

      {snapshot ? <ReviewPanel venueId={id} snapshot={snapshot} /> : null}
      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
