"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import { putAvailabilityAction, type ActionResult } from "@/lib/core/actions";

export function AvailabilityForm({
  venueId,
  inventoryOptions,
}: {
  venueId: string;
  inventoryOptions: { id: string; label: string }[];
}) {
  const bound = putAvailabilityAction.bind(null, venueId);
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    bound,
    null,
  );

  return (
    <form action={action} className="max-w-xl space-y-4">
      <div>
        <Label htmlFor="inventoryTypeId">الوحدة</Label>
        <Select id="inventoryTypeId" name="inventoryTypeId" required>
          {inventoryOptions.map((o) => (
            <option key={o.id} value={o.id}>
              {o.label}
            </option>
          ))}
        </Select>
      </div>
      <div>
        <Label htmlFor="date">التاريخ</Label>
        <Input id="date" name="date" type="date" required />
      </div>
      <div>
        <Label htmlFor="kind">الحالة</Label>
        <Select id="kind" name="kind" defaultValue="block">
          <option value="block">إغلاق (block)</option>
          <option value="open">فتح (open)</option>
          <option value="maintenance">صيانة (maintenance)</option>
        </Select>
      </div>
      <div>
        <Label htmlFor="reason">السبب</Label>
        <Input id="reason" name="reason" />
      </div>
      {state && !state.ok ? (
        <p className="text-sm text-[var(--color-error)]">{state.error}</p>
      ) : null}
      {state?.ok ? (
        <p className="text-sm text-[var(--color-success)]">تم التحديث</p>
      ) : null}
      <Button type="submit" disabled={pending || inventoryOptions.length === 0}>
        حفظ التوفر
      </Button>
    </form>
  );
}
