"use client";

import Link from "next/link";
import {
  buildPrepareSnapshot,
  type PrepareEvidence,
  type PrepareStepId,
  venueHref,
} from "@/lib/prepare-path";
import { markStepVisited } from "@/lib/step-persist";

export function VenueStepper({
  venueId,
  current,
  evidence,
}: {
  venueId: string;
  current: PrepareStepId;
  evidence: PrepareEvidence;
}) {
  const snapshot = buildPrepareSnapshot(evidence);

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm font-semibold text-[var(--color-text-primary)]">
          اكتمال التجهيز {snapshot.percent}٪
        </p>
        <p className="text-xs text-[var(--color-on-surface-muted)]">
          {snapshot.statusLabelAr}
        </p>
      </div>
      <div
        className="h-2 overflow-hidden rounded-full bg-[var(--color-primary-light)]"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={snapshot.percent}
        aria-label="نسبة اكتمال تجهيز المكان"
      >
        <div
          className="h-full rounded-full bg-[#22C063] transition-[width]"
          style={{ width: `${snapshot.percent}%` }}
        />
      </div>
      <ol
        className="grid gap-2 sm:grid-cols-4"
        aria-label="خطوات تجهيز المكان"
      >
        {snapshot.steps.map((step, index) => {
          const active = step.id === current;
          const done = step.complete;
          return (
            <li key={step.id}>
              <Link
                href={venueHref(venueId, step.hrefSuffix)}
                onClick={() => markStepVisited(venueId, step.id)}
                aria-current={active ? "step" : undefined}
                className={`flex min-h-11 items-center gap-2 rounded-[var(--radius-md)] border px-3 py-2 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)] ${
                  active
                    ? "border-[var(--color-primary)] bg-[var(--color-primary-light)] text-[var(--color-text-primary)]"
                    : done
                      ? "border-[#22C063]/40 bg-[#22C063]/10 text-[var(--color-text-primary)]"
                      : "border-[var(--color-border)] bg-white/80 text-[var(--color-text-secondary)]"
                }`}
              >
                <span
                  className={`grid h-6 w-6 shrink-0 place-items-center rounded-full text-xs font-bold ${
                    done
                      ? "bg-[#22C063] text-white"
                      : active
                        ? "bg-[var(--color-primary)] text-white"
                        : "bg-[var(--color-primary-light)] text-[var(--color-text-secondary)]"
                  }`}
                >
                  {done ? "✓" : index + 1}
                </span>
                <span className="leading-tight">{step.titleAr}</span>
              </Link>
            </li>
          );
        })}
      </ol>
    </div>
  );
}

export function AdvancedVenueLinks({ venueId }: { venueId: string }) {
  return (
    <details className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white/70 px-4 py-3">
      <summary className="cursor-pointer text-sm font-semibold text-[var(--color-text-secondary)]">
        خيارات متقدمة
      </summary>
      <div className="mt-3 flex flex-wrap gap-2">
        <Link
          href={`/venues/${venueId}/location`}
          className="rounded-[var(--radius-sm)] bg-[var(--color-primary-light)] px-3 py-2 text-sm"
        >
          الموقع
        </Link>
        <Link
          href={`/venues/${venueId}/units`}
          className="rounded-[var(--radius-sm)] bg-[var(--color-primary-light)] px-3 py-2 text-sm"
        >
          الوحدات
        </Link>
        <Link
          href={`/venues/${venueId}/pricing`}
          className="rounded-[var(--radius-sm)] bg-[var(--color-primary-light)] px-3 py-2 text-sm"
        >
          الخصومات والأسعار الموسمية
        </Link>
      </div>
    </details>
  );
}
