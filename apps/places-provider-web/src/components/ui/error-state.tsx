"use client";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type ErrorStateProps = {
  title?: string;
  description?: string;
  onRetry?: () => void;
  className?: string;
};

export function ErrorState({
  title = "تعذّر تحميل المحتوى",
  description = "حدث خطأ غير متوقع. أعد المحاولة بعد لحظات.",
  onRetry,
  className,
}: ErrorStateProps) {
  return (
    <div
      role="alert"
      className={cn(
        "flex flex-col items-start gap-4 rounded-[var(--radius-lg)] border border-[color-mix(in_srgb,var(--color-error)_22%,transparent)] bg-[color-mix(in_srgb,var(--color-error)_6%,white)] px-6 py-8",
        className,
      )}
    >
      <div className="space-y-2">
        <p className="text-xs font-semibold tracking-wide text-[var(--color-error)]">
          خطأ
        </p>
        <h2 className="text-xl font-bold text-[var(--color-text-primary)]">
          {title}
        </h2>
        <p className="max-w-md text-sm leading-7 text-[var(--color-on-surface-muted)]">
          {description}
        </p>
      </div>
      {onRetry ? (
        <Button type="button" onClick={onRetry}>
          إعادة المحاولة
        </Button>
      ) : null}
    </div>
  );
}
