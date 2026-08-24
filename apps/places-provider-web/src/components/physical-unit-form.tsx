"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/field";
import {
  createPhysicalUnitAction,
  type ActionResult,
} from "@/lib/core/actions";

export function PhysicalUnitForm({
  venueId,
  inventoryTypeId,
  typeLabel,
}: {
  venueId: string;
  inventoryTypeId: string;
  typeLabel: string;
}) {
  const bound = createPhysicalUnitAction.bind(null, venueId, inventoryTypeId);
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    bound,
    null,
  );

  return (
    <form action={action} className="space-y-3 rounded-[var(--radius-md)] border border-[var(--color-border)] p-3">
      <p className="text-sm font-semibold">إضافة وحدة إلى {typeLabel}</p>
      <p className="text-xs text-[var(--color-on-surface-muted)]">
        اسم مفهوم يظهر للضيف. لا يُقبل حجز وحدة محجوزة في نفس التواريخ.
      </p>
      <div>
        <Label htmlFor={`label-${inventoryTypeId}`}>اسم الوحدة</Label>
        <Input
          id={`label-${inventoryTypeId}`}
          name="labelAr"
          required
          placeholder="مثل: جناح الواجهة"
        />
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
        {pending ? "جارٍ الإضافة…" : "إضافة وحدة مستقلة"}
      </Button>
    </form>
  );
}
