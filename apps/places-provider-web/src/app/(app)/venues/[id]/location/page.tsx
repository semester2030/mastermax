import Link from "next/link";
import { VenueLocationForm } from "@/components/venue-location-form";
import { VenueNav } from "@/components/venue-nav";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  getVenue,
  listLocationCities,
  listLocationDistricts,
  requireProviderId,
} from "@/lib/core/client";
import { loadPrepareEvidence } from "@/lib/load-prepare";
import { LOCATION_INCOMPLETE_AR, venueHasCoordinates } from "@/lib/location/venue-location";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { LocationCity, LocationDistrict, VenueRow } from "@/lib/core/types";
import { venueNameOf } from "@/lib/core/types";

export default async function VenueLocationPage({
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
  try {
    venue = (await getVenue(id, providerId)) as VenueRow;
    cities = asArray(await listLocationCities()) as LocationCity[];
    const cityId = venue.cityId ?? venue.city_id;
    if (cityId) {
      districts = asArray(await listLocationDistricts(cityId)) as LocationDistrict[];
    }
  } catch (e) {
    error =
      e instanceof CoreApiError
        ? operatorErrorAr(e.message)
        : "تعذّر جلب موقع المكان. حدّث الصفحة ثم أعد المحاولة.";
  }

  const evidence = venue ? await loadPrepareEvidence(providerId, venue) : null;
  const incomplete = venue ? !venueHasCoordinates(venue) : false;

  return (
    <div className="space-y-6">
      <div>
        <Link
          href={`/venues/${id}`}
          className="text-sm text-[var(--color-text-secondary)] hover:text-[var(--color-primary)]"
        >
          بيانات المكان
        </Link>
        <h1 className="mt-2 text-2xl font-bold">موقع المكان</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          {venue ? venueNameOf(venue) : "حدد الموقع على الخريطة أو أدخله يدويًا"}
        </p>
      </div>

      {evidence ? (
        <VenueStepper venueId={id} current="basics" evidence={evidence} />
      ) : null}
      <VenueNav venueId={id} />

      {incomplete ? (
        <p
          className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_12%,white)] px-3 py-2 text-sm"
          role="status"
        >
          {LOCATION_INCOMPLETE_AR}. لا تُخترع إحداثيات للأماكن القديمة — أكملها هنا.
        </p>
      ) : null}

      {error ? (
        <ErrorState title="تعذّر فتح الموقع" description={error} />
      ) : venue ? (
        <VenueLocationForm
          venueId={id}
          initial={{
            city: venue.city,
            cityId: venue.cityId ?? venue.city_id,
            district: venue.district,
            districtId: venue.districtId ?? venue.district_id,
            street: venue.street,
            formattedAddress: venue.formattedAddress,
            googlePlaceId: venue.googlePlaceId,
            lat: venue.lat ?? venue.latitude,
            lng: venue.lng ?? venue.longitude,
            locationSource: venue.locationSource,
            locationComplete: venue.locationComplete,
          }}
          cities={cities}
          initialDistricts={districts}
        />
      ) : null}

      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
