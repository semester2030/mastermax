"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { saveAmenitiesAction } from "@/lib/core/actions";
import type { AmenityCatalogRow, VenueAmenityRow } from "@/lib/core/types";

export function AmenityPicker({
  venueId,
  catalog,
  selected,
  inventoryTypeId,
  title = "خدمات المكان",
}: {
  venueId: string;
  catalog: AmenityCatalogRow[];
  selected: VenueAmenityRow[];
  inventoryTypeId?: string;
  title?: string;
}) {
  const scoped = selected.filter((s) =>
    inventoryTypeId
      ? s.inventoryTypeId === inventoryTypeId
      : !s.inventoryTypeId,
  );
  const [codes, setCodes] = useState(
    scoped.map((s) => s.code || s.id || "").filter(Boolean),
  );
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [pending, startTransition] = useTransition();

  if (catalog.length === 0) return null;

  return (
    <div className="space-y-3">
      <h2 className="text-lg font-semibold">{title}</h2>
      <p className="text-sm text-[var(--color-text-secondary)]">
        اختر الموجود فقط من الكتالوج. نفس المعرّفات تظهر في تفاصيل التطبيق
        وفلاتر البحث.
      </p>
      <div className="flex flex-wrap gap-2">
        {catalog.map((a) => {
          const code = a.code;
          const label = a.labelAr ?? a.label_ar ?? code;
          const on = codes.includes(code);
          return (
            <button
              key={code}
              type="button"
              className={`rounded-full border px-3 py-1 text-sm ${
                on
                  ? "border-[var(--color-primary)] bg-[var(--color-primary-light)]"
                  : "border-[var(--color-border)] bg-white"
              }`}
              onClick={() => {
                setOk(false);
                setCodes((prev) =>
                  prev.includes(code)
                    ? prev.filter((c) => c !== code)
                    : [...prev, code],
                );
              }}
            >
              {label}
            </button>
          );
        })}
      </div>
      {error ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {error}
        </p>
      ) : null}
      {ok ? (
        <p className="text-sm text-[#22C063]" role="status">
          تم حفظ الخدمات
        </p>
      ) : null}
      <Button
        type="button"
        disabled={pending}
        onClick={() => {
          startTransition(async () => {
            const res = await saveAmenitiesAction(
              venueId,
              codes,
              inventoryTypeId,
            );
            if (!res.ok) {
              setError(res.error);
              setOk(false);
            } else {
              setError(null);
              setOk(true);
            }
          });
        }}
      >
        {pending ? "جارٍ الحفظ…" : "حفظ الخدمات"}
      </Button>
    </div>
  );
}
