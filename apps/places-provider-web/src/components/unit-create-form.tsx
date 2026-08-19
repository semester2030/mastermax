"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import { createUnitAction, type ActionResult } from "@/lib/core/actions";

export function UnitCreateForm({ venueId }: { venueId: string }) {
  const bound = createUnitAction.bind(null, venueId);
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    bound,
    null,
  );

  return (
    <form action={action} className="max-w-xl space-y-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor="code">الرمز</Label>
          <Input id="code" name="code" required dir="ltr" />
        </div>
        <div>
          <Label htmlFor="labelAr">الاسم بالعربية</Label>
          <Input id="labelAr" name="labelAr" required />
        </div>
        <div>
          <Label htmlFor="inventoryModel">نوع الوحدة</Label>
          <Select id="inventoryModel" name="inventoryModel" defaultValue="pooled">
            <option value="pooled">مشتركة</option>
            <option value="physical">مستقلة</option>
          </Select>
        </div>
        <div>
          <Label htmlFor="quantityTotal">الكمية</Label>
          <Input
            id="quantityTotal"
            name="quantityTotal"
            type="number"
            min={0}
            defaultValue={1}
            required
          />
        </div>
        <div>
          <Label htmlFor="baseOccupancy">الإشغال الأساسي</Label>
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
          <Label htmlFor="maxOccupancy">أقصى إشغال</Label>
          <Input
            id="maxOccupancy"
            name="maxOccupancy"
            type="number"
            min={1}
            defaultValue={2}
            required
          />
        </div>
      </div>
      {state && !state.ok ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {state.error}
        </p>
      ) : null}
      {state?.ok ? (
        <p className="text-sm text-[var(--color-success)]">تمت إضافة الوحدة</p>
      ) : null}
      <Button type="submit" disabled={pending}>
        {pending ? "جارٍ الإضافة…" : "إضافة وحدة"}
      </Button>
    </form>
  );
}
