"use client";

import { useActionState, useState, useTransition } from "react";
import Link from "next/link";
import { Save } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import { loadDistrictsAction, patchVenueAction, type VenueSaveResult } from "@/lib/core/actions";
import {
  canPublishFromEvidence,
  type PublishUiEvidence,
  PUBLISH_REQUIRES_IMAGE_AR,
} from "@/lib/core/publish-readiness";
import { VENUE_STATUS_LABEL_AR } from "@/lib/prepare-path";
import type { LocationCity, LocationDistrict } from "@/lib/core/types";
import { LOCATION_INCOMPLETE_AR } from "@/lib/location/venue-location";

export function VenueEditForm({
  venueId,
  initial,
  cities,
  initialDistricts,
  publishEvidence,
}: {
  venueId: string;
  initial: {
    name?: string;
    cityId?: string | null;
    districtId?: string | null;
    street?: string | null;
    buildingNo?: string | null;
    landmark?: string | null;
    accessNotes?: string | null;
    status?: string;
  };
  cities: LocationCity[];
  initialDistricts: LocationDistrict[];
  publishEvidence: PublishUiEvidence;
}) {
  const bound = patchVenueAction.bind(null, venueId);
  const [state, action, pending] = useActionState<
    VenueSaveResult | null,
    FormData
  >(bound, null);
  const [dirty, setDirty] = useState(false);
  const [cityId, setCityId] = useState(initial.cityId ?? "");
  const [districts, setDistricts] = useState(initialDistricts);
  const [districtId, setDistrictId] = useState(initial.districtId ?? "");
  const [, startTransition] = useTransition();
  const publishAllowed = canPublishFromEvidence(publishEvidence);
  const result = dirty ? null : state;
  const storedStatus =
    (state?.ok ? state.status : undefined) ?? initial.status ?? "draft";

  function onCityChange(next: string) {
    setCityId(next);
    setDistrictId("");
    if (!next) {
      setDistricts([]);
      return;
    }
    startTransition(async () => {
      const res = await loadDistrictsAction(next);
      if (res.ok) {
        setDistricts(res.districts as LocationDistrict[]);
      }
    });
  }

  return (
    <form
      action={action}
      onChange={() => setDirty(true)}
      onSubmit={() => setDirty(false)}
      className="max-w-xl space-y-4"
    >
      <input type="hidden" name="locationSource" value="manual" />
      <div>
        <Label htmlFor="name">اسم المكان</Label>
        <Input id="name" name="name" defaultValue={initial.name ?? ""} required />
      </div>
      <div>
        <Label htmlFor="cityId">المدينة</Label>
        <Select
          id="cityId"
          name="cityId"
          required
          value={cityId}
          onChange={(e) => onCityChange(e.target.value)}
        >
          <option value="">اختر المدينة</option>
          {cities.map((c) => (
            <option key={c.id} value={c.id}>
              {c.nameAr}
            </option>
          ))}
        </Select>
      </div>
      <div>
        <Label htmlFor="districtId">الحي</Label>
        <Select
          id="districtId"
          name="districtId"
          required
          value={districtId}
          onChange={(e) => setDistrictId(e.target.value)}
          disabled={!cityId}
        >
          <option value="">اختر الحي</option>
          {districts.map((d) => (
            <option key={d.id} value={d.id}>
              {d.nameAr}
            </option>
          ))}
        </Select>
      </div>
      <div>
        <Label htmlFor="street">الشارع</Label>
        <Input
          id="street"
          name="street"
          defaultValue={initial.street ?? ""}
          required
        />
      </div>
      <div>
        <Label htmlFor="buildingNo">رقم المبنى (اختياري)</Label>
        <Input
          id="buildingNo"
          name="buildingNo"
          defaultValue={initial.buildingNo ?? ""}
        />
      </div>
      <div>
        <Label htmlFor="landmark">أقرب معلم (اختياري)</Label>
        <Input
          id="landmark"
          name="landmark"
          defaultValue={initial.landmark ?? ""}
        />
      </div>
      <div>
        <Label htmlFor="accessNotes">وصف الوصول (اختياري)</Label>
        <Input
          id="accessNotes"
          name="accessNotes"
          defaultValue={initial.accessNotes ?? ""}
        />
      </div>
      {!publishEvidence.hasCoordinates ? (
        <p
          className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_12%,white)] px-3 py-2 text-sm"
          role="status"
        >
          {LOCATION_INCOMPLETE_AR}.{" "}
          <Link
            href={`/venues/${venueId}/location`}
            className="font-semibold text-[var(--color-primary)] underline"
          >
            أكمل الموقع على الخريطة
          </Link>
        </p>
      ) : (
        <p className="text-sm text-[var(--color-text-secondary)]">
          <Link
            href={`/venues/${venueId}/location`}
            className="font-semibold text-[var(--color-primary)] underline"
          >
            تعديل الموقع على الخريطة
          </Link>
        </p>
      )}
      <div>
        <Label htmlFor="status">الحالة</Label>
        <Select
          key={storedStatus}
          id="status"
          name="status"
          defaultValue={storedStatus}
          aria-describedby={publishAllowed ? undefined : "publish-blocked"}
        >
          <option value="draft">مسودة</option>
          <option value="published" disabled={!publishAllowed}>
            منشور
          </option>
          <option value="suspended">موقوف</option>
        </Select>
        {publishAllowed ? null : (
          <p
            id="publish-blocked"
            className="mt-1 text-sm text-[var(--color-warning)]"
            role="status"
          >
            {PUBLISH_REQUIRES_IMAGE_AR} أكمل المدينة والحي والشارع، والفيديو
            الرئيسي المعتمد، والغلاف، والسعر والإتاحة، ووسائط كل وحدة نشطة.
          </p>
        )}
      </div>
      {result && !result.ok ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {result.error}
        </p>
      ) : null}
      {result?.ok ? (
        <p className="text-sm text-[#22C063]" role="status">
          {result.status
            ? `تم الحفظ — الحالة الآن: ${VENUE_STATUS_LABEL_AR[result.status] ?? result.status}`
            : "تم الحفظ"}
        </p>
      ) : null}
      <Button type="submit" disabled={pending}>
        <Save className="h-4 w-4" aria-hidden />
        {pending ? "جارٍ الحفظ…" : "حفظ البيانات"}
      </Button>
    </form>
  );
}
