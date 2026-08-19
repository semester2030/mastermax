"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import {
  createVenueAction,
  type ActionResult,
} from "@/lib/core/actions";
import {
  CONTENT_ONLY_BANNER_AR,
  CONTENT_ONLY_VENUE_TYPES,
  FULL_BOOKING_VENUE_TYPES,
  VENUE_TYPE_LABELS_AR,
  isContentOnlyVenueType,
  type Wave1VenueType,
} from "@/lib/venue-types";
import { useState } from "react";

const allTypes = [
  ...FULL_BOOKING_VENUE_TYPES,
  ...CONTENT_ONLY_VENUE_TYPES,
] as Wave1VenueType[];

export function VenueCreateForm() {
  const [venueType, setVenueType] = useState<string>("hotel");
  const [state, action, pending] = useActionState<ActionResult | null, FormData>(
    createVenueAction,
    null,
  );

  return (
    <form action={action} className="max-w-xl space-y-4">
      <div>
        <Label htmlFor="name">اسم المكان</Label>
        <Input id="name" name="name" required />
      </div>
      <div>
        <Label htmlFor="venueType">نوع المكان</Label>
        <Select
          id="venueType"
          name="venueType"
          value={venueType}
          onChange={(e) => setVenueType(e.target.value)}
        >
          {allTypes.map((t) => (
            <option key={t} value={t}>
              {VENUE_TYPE_LABELS_AR[t]}
            </option>
          ))}
        </Select>
      </div>
      {isContentOnlyVenueType(venueType) ? (
        <p
          className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_12%,white)] px-3 py-2 text-sm text-[var(--color-text-primary)]"
          role="status"
        >
          {CONTENT_ONLY_BANNER_AR}
        </p>
      ) : null}
      <div>
        <Label htmlFor="bookingMode">وضع الحجز</Label>
        <Select id="bookingMode" name="bookingMode" defaultValue="nightly">
          <option value="nightly">ليلي</option>
          <option value="daily">يومي</option>
        </Select>
      </div>
      <div>
        <Label htmlFor="city">المدينة</Label>
        <Input id="city" name="city" />
      </div>
      {state && !state.ok ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" disabled={pending}>
        {pending ? "جارٍ الإنشاء…" : "إنشاء المكان"}
      </Button>
    </form>
  );
}
