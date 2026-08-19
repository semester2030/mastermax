import { PricingForm } from "@/components/pricing-form";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  getVenue,
  listInventoryTypes,
  listRatePlans,
  requireProviderId,
} from "@/lib/core/client";
import { loadPrepareEvidence } from "@/lib/load-prepare";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { InventoryTypeRow, VenueRow } from "@/lib/core/types";

export default async function VenuePricingPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const providerId = await requireProviderId();
  let venue: VenueRow | null = null;
  let units: InventoryTypeRow[] = [];
  let error: string | null = null;
  let ratePlanOptions: { id: string; label: string }[] = [];
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

  try {
    const plans = asArray(await listRatePlans(providerId, id)) as {
      id: string;
      name?: string;
    }[];
    ratePlanOptions = plans.map((p, index) => ({
      id: p.id,
      label: p.name?.trim() || `خطة السعر ${index + 1}`,
    }));
  } catch (e) {
    if (!error) {
      error =
        e instanceof CoreApiError
          ? operatorErrorAr(e.message)
          : "تعذّر جلب خطط السعر. يمكنك إنشاء خطة جديدة.";
    }
  }

  const evidence = venue
    ? await loadPrepareEvidence(providerId, venue)
    : null;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">الخصومات والأسعار الموسمية</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          السعر الأساسي في خطوة الإتاحة. هنا الخيارات المتقدمة فقط.
        </p>
      </div>
      {evidence ? (
        <VenueStepper venueId={id} current="availability" evidence={evidence} />
      ) : null}
      {error ? (
        <ErrorState title="تعذّر تحميل بعض بيانات السعر" description={error} />
      ) : null}
      <PricingForm
        venueId={id}
        inventoryOptions={units.map((u, i) => ({
          id: u.id,
          label: u.labelAr ?? u.code ?? `وحدة ${i + 1}`,
        }))}
        ratePlanOptions={ratePlanOptions}
      />
      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
