"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/field";
import { cancelBookingAction, type ActionResult } from "@/lib/core/actions";

export function CancelBookingForm({ bookingId }: { bookingId: string }) {
  const bound = cancelBookingAction.bind(null, bookingId);
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    bound,
    null,
  );

  return (
    <form action={action} className="max-w-md space-y-3">
      <div>
        <Label htmlFor="reason">سبب الإلغاء</Label>
        <Input id="reason" name="reason" required />
      </div>
      {state && !state.ok ? (
        <p className="text-sm text-[var(--color-error)]">{state.error}</p>
      ) : null}
      {state?.ok ? (
        <p className="text-sm text-[var(--color-success)]">تم إلغاء الحجز</p>
      ) : null}
      <Button type="submit" variant="danger" disabled={pending}>
        {pending ? "جارٍ الإلغاء…" : "إلغاء الحجز"}
      </Button>
    </form>
  );
}
