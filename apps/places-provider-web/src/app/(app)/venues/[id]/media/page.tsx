import { MediaManager } from "@/components/media-manager";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  getVenue,
  listInventoryTypes,
  listMedia,
  requireProviderId,
} from "@/lib/core/client";
import { loadPrepareEvidence } from "@/lib/load-prepare";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { InventoryTypeRow, MediaRow, VenueRow } from "@/lib/core/types";

function isVenueLevel(m: MediaRow): boolean {
  const id = m.inventoryTypeId ?? m.inventory_type_id;
  return id == null || id === "";
}

export default async function VenueMediaPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const providerId = await requireProviderId();
  let items: MediaRow[] = [];
  let units: InventoryTypeRow[] = [];
  let error: string | null = null;
  let venue: VenueRow | null = null;
  try {
    venue = (await getVenue(id, providerId)) as VenueRow;
    items = asArray(await listMedia(providerId, id)) as MediaRow[];
    items.sort(
      (a, b) =>
        (a.sortOrder ?? a.sort_order ?? a.order ?? 0) -
        (b.sortOrder ?? b.sort_order ?? b.order ?? 0),
    );
    units = asArray(await listInventoryTypes(providerId, id)) as InventoryTypeRow[];
  } catch (e) {
    error =
      e instanceof CoreApiError
        ? operatorErrorAr(e.message)
        : "تعذّر جلب الصور والفيديو. حدّث الصفحة ثم أعد المحاولة.";
  }

  const evidence = venue
    ? await loadPrepareEvidence(providerId, venue)
    : null;
  const venueItems = items.filter(isVenueLevel);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold">الصور والفيديو</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          وسائط المكان مستقلة عن وسائط كل وحدة. النشر يحتاج فيديو رئيسيًا وغلافًا
          معتمدين، وكل وحدة نشطة تحتاج فيديو وصورة معتمدين.
        </p>
      </div>
      {evidence ? (
        <VenueStepper venueId={id} current="media" evidence={evidence} />
      ) : null}
      {error ? (
        <ErrorState title="تعذّر تحميل الوسائط" description={error} />
      ) : (
        <>
          <section className="space-y-3">
            <h2 className="text-xl font-bold">وسائط المكان</h2>
            <MediaManager venueId={id} items={venueItems} />
          </section>
          <section className="space-y-4">
            <h2 className="text-xl font-bold">وسائط الوحدات</h2>
            {units.length === 0 ? (
              <p className="text-sm text-[var(--color-text-secondary)]">
                لا توجد وحدات بعد. أضف وحدة من الخيارات المتقدمة ثم ارفع وسائطها
                هنا.
              </p>
            ) : (
              units.map((unit) => {
                const unitId = unit.id;
                const unitItems = items.filter(
                  (m) =>
                    (m.inventoryTypeId ?? m.inventory_type_id) === unitId,
                );
                return (
                  <div
                    key={unitId}
                    className="rounded-[var(--radius-md)] border border-[var(--color-border)] p-4"
                  >
                    <MediaManager
                      venueId={id}
                      items={unitItems}
                      inventoryTypeId={unitId}
                      heading={unit.labelAr ?? unit.code ?? "وحدة"}
                    />
                  </div>
                );
              })
            )}
          </section>
        </>
      )}
      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
