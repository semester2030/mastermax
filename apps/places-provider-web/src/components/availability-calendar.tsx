"use client";

import { useMemo, useState } from "react";
import { useActionState } from "react";
import { CalendarDays, Check, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import { putAvailabilityAction, type ActionResult } from "@/lib/core/actions";
import {
  dayKind,
  monthGrid,
  type CalendarDay,
} from "@/lib/calendar-range";

const WEEK = ["أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"];

export function AvailabilityCalendar({
  venueId,
  inventoryOptions,
  days,
}: {
  venueId: string;
  inventoryOptions: { id: string; label: string }[];
  days: CalendarDay[];
}) {
  const bound = putAvailabilityAction.bind(null, venueId);
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    bound,
    null,
  );
  const today = new Date();
  const [cursor, setCursor] = useState({
    y: today.getUTCFullYear(),
    m: today.getUTCMonth(),
  });
  const [unitId, setUnitId] = useState(inventoryOptions[0]?.id ?? "");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const cells = useMemo(() => monthGrid(cursor.y, cursor.m), [cursor]);
  const monthLabel = new Intl.DateTimeFormat("ar-SA", {
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(cursor.y, cursor.m, 1)));

  function pick(iso: string) {
    if (!from || (from && to)) {
      setFrom(iso);
      setTo("");
      return;
    }
    if (iso < from) {
      setTo(from);
      setFrom(iso);
      return;
    }
    setTo(iso);
  }

  const empty = inventoryOptions.length === 0;

  return (
    <form action={action} className="space-y-5">
      <input type="hidden" name="inventoryTypeId" value={unitId} />
      <input type="hidden" name="dateFrom" value={from} />
      <input type="hidden" name="dateTo" value={to || from} />

      {empty ? (
        <p className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_10%,white)] px-3 py-2 text-sm">
          أضف وحدة واحدة على الأقل من «خيارات متقدمة → الوحدات» قبل تحديد الإتاحة.
        </p>
      ) : (
        <div>
          <Label htmlFor="unit">الوحدة</Label>
          <Select
            id="unit"
            value={unitId}
            onChange={(e) => setUnitId(e.target.value)}
          >
            {inventoryOptions.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </Select>
        </div>
      )}

      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="flex items-center gap-2 text-base font-bold">
          <CalendarDays className="h-4 w-4" aria-hidden />
          التقويم
        </h2>
        <div className="flex gap-2">
          <Button
            type="button"
            size="sm"
            variant="secondary"
            onClick={() =>
              setCursor((c) =>
                c.m === 0 ? { y: c.y - 1, m: 11 } : { y: c.y, m: c.m - 1 },
              )
            }
          >
            الشهر السابق
          </Button>
          <p className="grid min-w-32 place-items-center text-sm font-semibold">
            {monthLabel}
          </p>
          <Button
            type="button"
            size="sm"
            variant="secondary"
            onClick={() =>
              setCursor((c) =>
                c.m === 11 ? { y: c.y + 1, m: 0 } : { y: c.y, m: c.m + 1 },
              )
            }
          >
            الشهر التالي
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-1 text-center text-xs text-[var(--color-on-surface-muted)]">
        {WEEK.map((d) => (
          <div key={d} className="py-1 font-semibold">
            {d}
          </div>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-1">
        {cells.map((iso, i) => {
          if (!iso) return <div key={`e-${i}`} />;
          const kind = dayKind(days, iso, unitId);
          const selected =
            iso === from || iso === to || (from && to && iso >= from && iso <= to);
          const tone =
            kind === "block"
              ? "border-[var(--color-error)]/40 bg-[color-mix(in_srgb,var(--color-error)_10%,white)]"
              : kind === "open"
                ? "border-[#22C063]/40 bg-[#22C063]/10"
                : kind === "busy"
                  ? "border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_12%,white)]"
                  : "border-[var(--color-border)] bg-white";
          return (
            <button
              key={iso}
              type="button"
              onClick={() => pick(iso)}
              aria-pressed={Boolean(selected)}
              className={`min-h-11 rounded-[var(--radius-sm)] border text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)] ${tone} ${
                selected ? "ring-2 ring-[var(--color-primary)]" : ""
              }`}
            >
              {Number(iso.slice(8, 10))}
            </button>
          );
        })}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor="dateFromUi">من يوم</Label>
          <Input
            id="dateFromUi"
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            required
          />
        </div>
        <div>
          <Label htmlFor="dateToUi">إلى يوم (اختياري)</Label>
          <Input
            id="dateToUi"
            type="date"
            value={to}
            onChange={(e) => setTo(e.target.value)}
          />
        </div>
      </div>

      <fieldset className="space-y-2">
        <legend className="mb-1.5 text-xs font-semibold text-[var(--color-text-secondary)]">
          الحالة
        </legend>
        <div className="flex flex-wrap gap-2">
          <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-[var(--radius-md)] border border-[#22C063]/40 bg-[#22C063]/10 px-3 text-sm">
            <input type="radio" name="kind" value="open" defaultChecked />
            <Check className="h-4 w-4" aria-hidden />
            متاح
          </label>
          <label className="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-error)]/35 bg-[color-mix(in_srgb,var(--color-error)_8%,white)] px-3 text-sm">
            <input type="radio" name="kind" value="block" />
            <X className="h-4 w-4" aria-hidden />
            غير متاح
          </label>
        </div>
      </fieldset>

      <details className="rounded-[var(--radius-md)] border border-[var(--color-border)] px-3 py-2">
        <summary className="cursor-pointer text-sm font-semibold text-[var(--color-text-secondary)]">
          خيارات متقدمة
        </summary>
        <div className="mt-3 space-y-3">
          <div>
            <Label htmlFor="reason">سبب الإغلاق (اختياري)</Label>
            <Input id="reason" name="reason" />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input type="radio" name="kind" value="maintenance" />
            صيانة
          </label>
        </div>
      </details>

      {state && !state.ok ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {state.error}
        </p>
      ) : null}
      {state?.ok ? (
        <p className="text-sm text-[#22C063]" role="status">
          تم حفظ الإتاحة
        </p>
      ) : null}

      <Button type="submit" disabled={pending || empty || !from}>
        {pending ? "جارٍ الحفظ…" : "حفظ الإتاحة"}
      </Button>
    </form>
  );
}
