"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import {
  createRatePlanAction,
  putPricingAction,
  type ActionResult,
} from "@/lib/core/actions";

export function PricingForm({
  venueId,
  inventoryOptions,
  ratePlanOptions,
  simple = false,
}: {
  venueId: string;
  inventoryOptions: { id: string; label: string }[];
  ratePlanOptions: { id: string; label: string }[];
  simple?: boolean;
}) {
  const boundPrice = putPricingAction.bind(null, venueId);
  const boundPlan = createRatePlanAction.bind(null, venueId);
  const [priceState, priceAction, pricePending] = useActionState<
    ActionResult | null,
    FormData
  >(boundPrice, null);
  const [planState, planAction, planPending] = useActionState<
    ActionResult | null,
    FormData
  >(boundPlan, null);
  const defaultPlan = ratePlanOptions[0]?.id ?? "";

  return (
    <div className="space-y-8">
      {ratePlanOptions.length === 0 ? (
        <form action={planAction} className="max-w-xl space-y-4">
          <h2 className="text-lg font-bold">خطة السعر</h2>
          <p className="text-sm text-[var(--color-on-surface-muted)]">
            أنشئ خطة سعر للوحدة ثم أدخل السعر الأساسي.
          </p>
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
          <input type="hidden" name="name" value="افتراضي" />
          {planState && !planState.ok ? (
            <p className="text-sm text-[var(--color-error)]" role="alert">
              {planState.error}
            </p>
          ) : null}
          {planState?.ok ? (
            <p className="text-sm text-[#22C063]" role="status">
              تم إنشاء خطة السعر
            </p>
          ) : null}
          <Button
            type="submit"
            disabled={planPending || inventoryOptions.length === 0}
          >
            {planPending ? "جارٍ الإنشاء…" : "إنشاء خطة السعر"}
          </Button>
        </form>
      ) : null}

      <form action={priceAction} className="max-w-xl space-y-4">
        <h2 className="text-lg font-bold">السعر الأساسي</h2>
        {ratePlanOptions.length > 1 ? (
          <div>
            <Label htmlFor="ratePlanId">خطة السعر</Label>
            <Select
              id="ratePlanId"
              name="ratePlanId"
              required
              defaultValue={defaultPlan}
            >
              {ratePlanOptions.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.label}
                </option>
              ))}
            </Select>
          </div>
        ) : (
          <input type="hidden" name="ratePlanId" value={defaultPlan} />
        )}
        <input type="hidden" name="kind" value="base" />
        <div>
          <Label htmlFor="amount">المبلغ (ريال)</Label>
          <Input
            id="amount"
            name="amount"
            required
            inputMode="decimal"
            placeholder="250"
          />
        </div>
        {priceState && !priceState.ok ? (
          <p className="text-sm text-[var(--color-error)]" role="alert">
            {priceState.error}
          </p>
        ) : null}
        {priceState?.ok ? (
          <p className="text-sm text-[#22C063]" role="status">
            تم حفظ السعر الأساسي
          </p>
        ) : null}
        <Button type="submit" disabled={pricePending || !defaultPlan}>
          {pricePending ? "جارٍ الحفظ…" : "حفظ السعر الأساسي"}
        </Button>
      </form>

      {simple ? null : (
        <details className="max-w-xl rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white/70 px-4 py-3">
          <summary className="cursor-pointer text-sm font-semibold text-[var(--color-text-secondary)]">
            خيارات متقدمة — خصومات وأسعار موسمية
          </summary>
          <form action={priceAction} className="mt-4 space-y-4">
            {ratePlanOptions.length > 0 ? (
              <div>
                <Label htmlFor="advRatePlan">خطة السعر</Label>
                <Select
                  id="advRatePlan"
                  name="ratePlanId"
                  required
                  defaultValue={defaultPlan}
                >
                  {ratePlanOptions.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.label}
                    </option>
                  ))}
                </Select>
              </div>
            ) : (
              <p className="text-sm text-[var(--color-warning)]">
                أنشئ خطة سعر أولًا.
              </p>
            )}
            <div>
              <Label htmlFor="kind">النوع</Label>
              <Select id="kind" name="kind" defaultValue="seasonal">
                <option value="seasonal">سعر موسمي</option>
                <option value="discount">خصم</option>
              </Select>
            </div>
            <div>
              <Label htmlFor="advAmount">المبلغ (ريال)</Label>
              <Input id="advAmount" name="amount" required inputMode="decimal" />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <Label htmlFor="dateFrom">من تاريخ</Label>
                <Input id="dateFrom" name="dateFrom" type="date" />
              </div>
              <div>
                <Label htmlFor="dateTo">إلى تاريخ</Label>
                <Input id="dateTo" name="dateTo" type="date" />
              </div>
            </div>
            <Button type="submit" disabled={pricePending || !defaultPlan}>
              حفظ الخيار المتقدم
            </Button>
          </form>
        </details>
      )}
    </div>
  );
}
