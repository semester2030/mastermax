import Link from "next/link";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  listVenues,
  requireProviderId,
} from "@/lib/core/client";
import { loadPrepareSnapshot } from "@/lib/load-prepare";
import { nextStepHref } from "@/lib/prepare-path";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { VenueRow } from "@/lib/core/types";
import { venueNameOf, venueTypeOf } from "@/lib/core/types";
import { LOCATION_INCOMPLETE_AR, venueHasCoordinates } from "@/lib/location/venue-location";
import {
  CONTENT_ONLY_BANNER_AR,
  isContentOnlyVenueType,
  venueTypeLabelAr,
} from "@/lib/venue-types";

export default async function VenuesPage() {
  const providerId = await requireProviderId();
  let venues: VenueRow[] = [];
  let error: string | null = null;
  try {
    venues = asArray(await listVenues(providerId)) as VenueRow[];
  } catch (e) {
    error =
      e instanceof CoreApiError
        ? operatorErrorAr(e.message)
        : "تعذّر جلب الأماكن. حدّث الصفحة ثم أعد المحاولة.";
  }

  const rows = await Promise.all(
    venues.map(async (v) => ({
      venue: v,
      snapshot: await loadPrepareSnapshot(providerId, v),
    })),
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">الأماكن</h1>
          <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
            اختر مكانًا لإكمال التجهيز أو أنشئ مكانًا جديدًا.
          </p>
        </div>
        <Button asChild>
          <Link href="/venues/new">
            <Plus className="h-4 w-4" aria-hidden />
            مكان جديد
          </Link>
        </Button>
      </div>

      {error ? (
        <ErrorState title="تعذّر جلب الأماكن" description={error} />
      ) : null}

      {!error && venues.length === 0 ? (
        <EmptyState
          title="لا توجد أماكن"
          description="أنشئ أول مكان ثم أكمل الصور والإتاحة والمراجعة."
        />
      ) : (
        <ul className="divide-y divide-[var(--color-border)] rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/80">
          {rows.map(({ venue: v, snapshot }) => {
            const type = venueTypeOf(v);
            return (
              <li key={v.id}>
                <Link
                  href={nextStepHref(v.id, snapshot)}
                  className="flex flex-col gap-1 px-4 py-3 transition-colors hover:bg-[var(--color-primary-light)]/50 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div>
                    <p className="font-semibold">{venueNameOf(v)}</p>
                    <p className="text-xs text-[var(--color-on-surface-muted)]">
                      {venueTypeLabelAr(type)} · {snapshot.statusLabelAr}
                      {v.city ? ` · ${v.city}` : ""} · {snapshot.percent}٪
                      {venueHasCoordinates(v) ? "" : ` · ${LOCATION_INCOMPLETE_AR}`}
                    </p>
                  </div>
                  <span className="text-xs font-semibold text-[var(--color-primary)]">
                    {snapshot.nextStep
                      ? `التالي: ${snapshot.nextStep.titleAr}`
                      : "مكتمل"}
                  </span>
                  {isContentOnlyVenueType(type) ? (
                    <span className="text-xs font-medium text-[var(--color-warning)]">
                      {CONTENT_ONLY_BANNER_AR}
                    </span>
                  ) : null}
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
