"use client";

import { useActionState, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/field";
import { createUnitAction, type ActionResult } from "@/lib/core/actions";

export function UnitCreateForm({ venueId }: { venueId: string }) {
  const bound = createUnitAction.bind(null, venueId);
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    bound,
    null,
  );
  const [independent, setIndependent] = useState(false);

  return (
    <form action={action} className="max-w-xl space-y-4">
      <input
        type="hidden"
        name="inventoryModel"
        value={independent ? "physical" : "pooled"}
      />
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor="code">الرمز الداخلي</Label>
          <Input id="code" name="code" required dir="ltr" />
          <p className="mt-1 text-xs text-[var(--color-on-surface-muted)]">
            للمرجعية عند المزود فقط. لا يظهر للضيف.
          </p>
        </div>
        <div>
          <Label htmlFor="labelAr">اسم النوع</Label>
          <Input
            id="labelAr"
            name="labelAr"
            required
            placeholder="مثل: غرف أو جناح ملكي"
          />
        </div>
        {independent ? (
          <input type="hidden" name="quantityTotal" value="0" />
        ) : (
          <div>
            <Label htmlFor="quantityTotal">العدد</Label>
            <Input
              id="quantityTotal"
              name="quantityTotal"
              type="number"
              min={1}
              defaultValue={1}
              required
            />
            <p className="mt-1 text-xs text-[var(--color-on-surface-muted)]">
              عدد الوحدات المتشابهة من هذا النوع.
            </p>
          </div>
        )}
        <div>
          <Label htmlFor="baseOccupancy">السعة الأساسية</Label>
          <Input
            id="baseOccupancy"
            name="baseOccupancy"
            type="number"
            min={1}
            defaultValue={2}
            required
          />
        </div>
        <div>
          <Label htmlFor="maxOccupancy">أقصى سعة</Label>
          <Input
            id="maxOccupancy"
            name="maxOccupancy"
            type="number"
            min={1}
            defaultValue={2}
            required
          />
        </div>
        <div>
          <Label htmlFor="nightlyAmount">السعر لليلة (ريال)</Label>
          <Input
            id="nightlyAmount"
            name="nightlyAmount"
            type="number"
            min={0}
            step="0.01"
            placeholder="اختياري — من سعرك الفعلي"
          />
        </div>
      </div>
      <label className="flex items-start gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3 text-sm">
        <input
          type="checkbox"
          className="mt-1"
          checked={independent}
          onChange={(e) => setIndependent(e.target.checked)}
        />
        <span>
          <span className="font-semibold">وحدات مستقلة (اختياري)</span>
          <span className="mt-1 block text-xs text-[var(--color-on-surface-muted)]">
            فقط إذا كانت كل وحدة مختلفة فعلًا ولها اسم خاص، مثل شاليه 1 أو فيلا
            A أو قاعة الماسة. الغرف المتشابهة تبقى «نوع بعدد» ولا تحتاج اسمًا
            لكل غرفة.
          </span>
        </span>
      </label>
      {state && !state.ok ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {state.error}
        </p>
      ) : null}
      {state?.ok ? (
        <p className="text-sm text-[var(--color-success)]">تمت إضافة النوع</p>
      ) : null}
      <Button type="submit" disabled={pending}>
        {pending ? "جارٍ الإضافة…" : "إضافة نوع"}
      </Button>
    </form>
  );
}
