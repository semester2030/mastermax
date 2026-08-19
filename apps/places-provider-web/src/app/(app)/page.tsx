import Link from "next/link";
import { ArrowLeft, Building2, CircleAlert } from "lucide-react";
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
import { nextStepHref, VENUE_STATUS_LABEL_AR } from "@/lib/prepare-path";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { VenueRow } from "@/lib/core/types";
import { venueNameOf } from "@/lib/core/types";

export default async function DashboardPage() {
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

  const cards = await Promise.all(
    venues.slice(0, 8).map(async (venue) => {
      const snapshot = await loadPrepareSnapshot(providerId, venue);
      return { venue, snapshot };
    }),
  );
  const primary = cards[0];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">
          لوحة التحكم
        </h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          جهّز المكان ثم انشره بأقل خطوات. حساب المطوّر الداخلي فقط.
        </p>
      </div>

      {error ? (
        <ErrorState title="تعذّر تحميل اللوحة" description={error} />
      ) : null}

      {!error && venues.length === 0 ? (
        <EmptyState
          title="لا يوجد مكان بعد"
          description="ابدأ بإنشاء المكان ثم أكمل الصور والإتاحة والمراجعة."
        />
      ) : null}

      {!error && venues.length === 0 ? (
        <Button asChild>
          <Link href="/venues/new">
            <Building2 className="h-4 w-4" aria-hidden />
            إنشاء مكان
          </Link>
        </Button>
      ) : null}

      {primary ? (
        <section className="rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/85 p-5 shadow-[0_12px_28px_var(--color-shadow)]">
          <p className="text-xs font-semibold text-[var(--color-text-secondary)]">
            المكان الحالي
          </p>
          <h2 className="mt-1 text-xl font-bold">
            {venueNameOf(primary.venue)}
          </h2>
          <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
            الحالة: {primary.snapshot.statusLabelAr} · الاكتمال{" "}
            {primary.snapshot.percent}٪
          </p>
          <div
            className="mt-3 h-2 overflow-hidden rounded-full bg-[var(--color-primary-light)]"
            role="progressbar"
            aria-valuenow={primary.snapshot.percent}
            aria-valuemin={0}
            aria-valuemax={100}
          >
            <div
              className="h-full bg-[#22C063]"
              style={{ width: `${primary.snapshot.percent}%` }}
            />
          </div>
          {primary.snapshot.nextStep ? (
            <p className="mt-3 flex items-start gap-2 text-sm">
              <CircleAlert
                className="mt-0.5 h-4 w-4 text-[var(--color-warning)]"
                aria-hidden
              />
              الخطوة التالية: {primary.snapshot.nextStep.titleAr}
            </p>
          ) : (
            <p className="mt-3 text-sm text-[#22C063]">المكان منشور</p>
          )}
          <div className="mt-4 flex flex-wrap gap-2">
            <Button asChild>
              <Link href={nextStepHref(primary.venue.id, primary.snapshot)}>
                <ArrowLeft className="h-4 w-4" aria-hidden />
                {primary.snapshot.nextStep
                  ? `متابعة: ${primary.snapshot.nextStep.titleAr}`
                  : "فتح المراجعة"}
              </Link>
            </Button>
            <Button asChild variant="secondary">
              <Link href={`/venues/${primary.venue.id}`}>بيانات المكان</Link>
            </Button>
          </div>
        </section>
      ) : null}

      {cards.length > 1 ? (
        <ul className="grid gap-3 sm:grid-cols-2">
          {cards.slice(1).map(({ venue, snapshot }) => (
            <li key={venue.id}>
              <Link
                href={nextStepHref(venue.id, snapshot)}
                className="block rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/80 p-4"
              >
                <p className="font-semibold">{venueNameOf(venue)}</p>
                <p className="mt-1 text-xs text-[var(--color-on-surface-muted)]">
                  {VENUE_STATUS_LABEL_AR[venue.status ?? "draft"] ?? "مسودة"} ·{" "}
                  {snapshot.percent}٪ ·{" "}
                  {snapshot.nextStep?.titleAr ?? "مكتمل"}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
