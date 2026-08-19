import { AvailabilityCalendar } from "@/components/availability-calendar";
import { PricingForm } from "@/components/pricing-form";
import { AdvancedVenueLinks, VenueStepper } from "@/components/venue-stepper";
import { ErrorState } from "@/components/ui/error-state";
import {
  asArray,
  CoreApiError,
  getCalendar,
  getVenue,
  listInventoryTypes,
  listRatePlans,
  requireProviderId,
} from "@/lib/core/client";
import { asCalendarDays } from "@/lib/calendar-range";
import { loadPrepareEvidence } from "@/lib/load-prepare";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { InventoryTypeRow, VenueRow } from "@/lib/core/types";

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export default async function VenueAvailabilityPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const providerId = await requireProviderId();
  const from = isoDate(new Date());
  const toDate = new Date();
  toDate.setDate(toDate.getDate() + 60);
  const to = isoDate(toDate);

  let venue: VenueRow | null = null;
  let units: InventoryTypeRow[] = [];
  let days = asCalendarDays([]);
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
    days = asCalendarDays(await getCalendar(providerId, from, to));
  } catch (e) {
    if (!error) {
      error =
        e instanceof CoreApiError
          ? operatorErrorAr(e.message)
          : "تعذّر جلب التقويم. يمكنك مع ذلك تحديد يوم أو نطاق.";
    }
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
  } catch {
    ratePlanOptions = [];
  }

  const evidence = venue
    ? await loadPrepareEvidence(providerId, venue)
    : null;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">الإتاحة والسعر</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          حدّد يومًا أو نطاق أيام، ثم اختر متاح أو غير متاح، وأدخل السعر الأساسي.
        </p>
      </div>
      {evidence ? (
        <VenueStepper venueId={id} current="availability" evidence={evidence} />
      ) : null}
      {error ? (
        <ErrorState title="تعذّر تحميل بعض بيانات الإتاحة" description={error} />
      ) : null}
      <AvailabilityCalendar
        venueId={id}
        days={days}
        inventoryOptions={units.map((u) => ({
          id: u.id,
          label: u.labelAr ?? u.code ?? `وحدة ${units.indexOf(u) + 1}`,
        }))}
      />
      <PricingForm
        venueId={id}
        simple
        inventoryOptions={units.map((u) => ({
          id: u.id,
          label: u.labelAr ?? u.code ?? `وحدة ${units.indexOf(u) + 1}`,
        }))}
        ratePlanOptions={ratePlanOptions}
      />
      <AdvancedVenueLinks venueId={id} />
    </div>
  );
}
