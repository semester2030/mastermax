import { UnitCreateForm } from "@/components/unit-create-form";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  getVenue,
  listInventoryTypes,
  requireProviderId,
} from "@/lib/core/client";
import { loadPrepareEvidence } from "@/lib/load-prepare";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { InventoryTypeRow, VenueRow } from "@/lib/core/types";

export default async function VenueUnitsPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const providerId = await requireProviderId();
  let venue: VenueRow | null = null;
  let units: InventoryTypeRow[] = [];
  let error: string | null = null;
  try {
    venue = (await getVenue(id, providerId)) as VenueRow;
    units = asArray(
      await listInventoryTypes(providerId, id),
    ) as InventoryTypeRow[];
  } catch (e) {
    error =
      e instanceof CoreApiError
        ? operatorErrorAr(e.message)
        : "تعذّر جلب الوحدات. حدّث الصفحة ثم أعد المحاولة.";
  }

  const evidence = venue
    ? await loadPrepareEvidence(providerId, venue)
    : null;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">الوحدات</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          الوحدات التي تُعرض للحجز في هذا المكان.
        </p>
      </div>
      {evidence ? (
        <VenueStepper venueId={id} current="availability" evidence={evidence} />
      ) : null}

      {error ? (
        <ErrorState title="تعذّر تحميل الوحدات" description={error} />
      ) : units.length === 0 ? (
        <EmptyState
          title="لا توجد وحدات بعد"
          description="أضف وحدة واحدة على الأقل حتى يمكن تحديد الإتاحة والسعر."
        />
      ) : (
        <ul className="divide-y divide-[var(--color-border)] rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/80">
          {units.map((u, i) => (
            <li key={u.id} className="px-4 py-3 text-sm">
              <p className="font-semibold">{u.labelAr ?? `وحدة ${i + 1}`}</p>
              <p className="text-xs text-[var(--color-on-surface-muted)]">
                الكمية {u.quantityTotal ?? "—"} ·{" "}
                {u.status === "active" || !u.status ? "نشطة" : "غير نشطة"}
              </p>
            </li>
          ))}
        </ul>
      )}

      <UnitCreateForm venueId={id} />
      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
