import { UnitCreateForm } from "@/components/unit-create-form";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import { PhysicalUnitForm } from "@/components/physical-unit-form";
import {
  asArray,
  CoreApiError,
  getVenue,
  listInventoryTypes,
  listInventoryUnits,
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
  const physicalUnits: Record<string, Array<{ id: string; label: string }>> = {};
  let error: string | null = null;
  try {
    venue = (await getVenue(id, providerId)) as VenueRow;
    units = asArray(
      await listInventoryTypes(providerId, id),
    ) as InventoryTypeRow[];
    for (const t of units) {
      if (t.inventoryModel === "physical" && t.id) {
        const listed = await listInventoryUnits(providerId, t.id);
        physicalUnits[t.id] = asArray(listed.items).map((u) => ({
          id: String((u as { id?: string }).id ?? ""),
          label: String((u as { label?: string }).label ?? ""),
        }));
      }
    }
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
                {u.inventoryModel === "physical" ? "مستقلة" : "مشتركة"} · الكمية{" "}
                {u.quantityTotal ?? "—"} ·{" "}
                {u.status === "active" || !u.status ? "نشطة" : "غير نشطة"}
              </p>
              {u.inventoryModel === "physical" && u.id ? (
                <div className="mt-3 space-y-2">
                  {(physicalUnits[u.id] ?? []).length === 0 ? (
                    <p className="text-xs text-[var(--color-on-surface-muted)]">
                      لا توجد وحدات مستقلة بعد — أضف اسمًا مفهومًا لكل وحدة.
                    </p>
                  ) : (
                    <ul className="list-disc pr-5 text-xs">
                      {(physicalUnits[u.id] ?? []).map((pu) => (
                        <li key={pu.id}>{pu.label}</li>
                      ))}
                    </ul>
                  )}
                  <PhysicalUnitForm
                    venueId={id}
                    inventoryTypeId={u.id}
                    typeLabel={u.labelAr ?? `وحدة ${i + 1}`}
                  />
                </div>
              ) : null}
            </li>
          ))}
        </ul>
      )}

      <UnitCreateForm venueId={id} />
      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
