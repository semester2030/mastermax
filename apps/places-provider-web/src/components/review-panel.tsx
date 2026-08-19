import Link from "next/link";
import { CircleAlert, CircleCheck } from "lucide-react";
import type { PrepareSnapshot } from "@/lib/prepare-path";
import { venueHref } from "@/lib/prepare-path";

export function ReviewPanel({
  venueId,
  snapshot,
}: {
  venueId: string;
  snapshot: PrepareSnapshot;
}) {
  const missing = snapshot.gaps;
  const ready = snapshot.canPublish && snapshot.status !== "published";

  return (
    <section
      id="review"
      className="space-y-4 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/80 p-5"
      aria-labelledby="review-title"
    >
      <div>
        <h2 id="review-title" className="text-lg font-bold">
          المراجعة قبل النشر
        </h2>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          الحالة الآن: {snapshot.statusLabelAr} · الاكتمال {snapshot.percent}٪
        </p>
      </div>

      {missing.length === 0 ? (
        <p
          className="flex items-start gap-2 text-sm text-[#22C063]"
          role="status"
        >
          <CircleCheck className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
          لا يوجد نقص ظاهر من البيانات الحالية. يمكنك النشر من النموذج أعلاه.
        </p>
      ) : (
        <ul className="space-y-2" aria-label="العناصر الناقصة">
          {missing.map((gap) => (
            <li key={`${gap.step}-${gap.labelAr}`}>
              <Link
                href={venueHref(venueId, gap.hrefSuffix)}
                className={`flex min-h-11 items-center justify-between gap-3 rounded-[var(--radius-md)] border px-3 py-2 text-sm ${
                  gap.blocksPublish
                    ? "border-[color-mix(in_srgb,var(--color-error)_35%,white)] bg-[color-mix(in_srgb,var(--color-error)_8%,white)]"
                    : "border-[color-mix(in_srgb,var(--color-warning)_40%,white)] bg-[color-mix(in_srgb,var(--color-warning)_10%,white)]"
                }`}
              >
                <span className="flex items-center gap-2">
                  <CircleAlert className="h-4 w-4 shrink-0" aria-hidden />
                  {gap.labelAr}
                </span>
                <span className="text-xs font-semibold">
                  {gap.blocksPublish ? "يمنع النشر" : "مستحسن"}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}

      {ready ? (
        <p className="text-sm text-[#22C063]" role="status">
          جاهز للنشر — اختر «منشور» في الحالة ثم احفظ.
        </p>
      ) : null}
    </section>
  );
}
