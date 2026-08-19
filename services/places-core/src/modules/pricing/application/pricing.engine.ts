import { Inject, Injectable } from "@nestjs/common";
import { APP_CONFIG } from "../../../shared/config/app-config";
import { AppEnv } from "../../../shared/config/env";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { Decimal } from "../../../shared/money/decimal";
import {
  commissionOf,
  money,
  providerNetOf,
} from "../../../shared/money/money";
import {
  addDays,
  isWeekend,
  parseIsoDate,
  stayDates,
  toIsoDate,
} from "../../../shared/time/stay-dates";

/** Hard caps aligned with Discovery safety (not business marketing limits). */
const MAX_STAY_NIGHTS_HARD = 90;
const MAX_CHECK_IN_DAYS_AHEAD = 365;

export interface QuoteInput {
  venueId: string;
  inventoryTypeId: string;
  checkIn: string;
  checkOut: string;
  quantity: number;
  guestsAdults: number;
  guestsChildren: number;
  extraIds: string[];
  promoCode?: string;
  /** Required when venue.booking_mode = event_slot. */
  slotCode?: string;
}

export interface QuoteComputation {
  dates: string[];
  items: {
    kind: string;
    date: string | null;
    label: string;
    amount: string;
    qty: number;
  }[];
  subtotal: string;
  extrasTotal: string;
  discountTotal: string;
  taxTotal: string;
  grossTotal: string;
  commissionBps: number;
  commissionAmount: string;
  providerNet: string;
  currency: "SAR";
  pricingVersion: string;
  slotCode: string | null;
  bookingMode: "nightly" | "daily" | "event_slot";
}

interface RateRule {
  kind: string;
  amount: string;
  date_from: string | null;
  date_to: string | null;
  priority: number;
}

@Injectable()
export class PricingEngine {
  constructor(
    private readonly pg: PgService,
    @Inject(APP_CONFIG) private readonly env: AppEnv,
  ) {}

  async compute(input: QuoteInput): Promise<QuoteComputation> {
    if (!Number.isInteger(input.quantity) || input.quantity < 1) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "quantity must be >= 1");
    }
    if (input.guestsAdults < 1 || input.guestsChildren < 0) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Invalid guests");
    }

    const venue = await this.pg.query<{
      booking_mode: "nightly" | "daily" | "event_slot";
      min_stay: number;
      max_stay: number | null;
      provider_id: string;
      status: string;
    }>(
      "SELECT booking_mode, min_stay, max_stay, provider_id, status FROM venues WHERE id = $1",
      [input.venueId],
    );
    if (!venue.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    if (venue.rows[0].status !== "published") {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Venue is not published");
    }
    const mode = venue.rows[0].booking_mode;
    const slotCode = input.slotCode?.trim() || null;
    let eventSlotUnitPrice: Decimal | null = null;
    if (mode === "event_slot") {
      if (!slotCode) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "slotCode required for event_slot booking",
        );
      }
      // Phase 7 RC2: price event_slot from the ACTIVE template base_price that
      // matches the requested inventory_type_id — never from nightly rate_rules.
      const slot = await this.pg.query<{
        code: string;
        base_price: string | null;
        status: string;
        inventory_type_id: string | null;
      }>(
        `SELECT code, base_price::text, status, inventory_type_id
         FROM event_slot_templates
         WHERE venue_id = $1 AND code = $2`,
        [input.venueId, slotCode],
      );
      if (!slot.rowCount) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Unknown slotCode");
      }
      const tpl = slot.rows[0];
      if (tpl.status !== "active") {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Event slot template is not active",
        );
      }
      if (tpl.inventory_type_id !== input.inventoryTypeId) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "inventoryTypeId does not match the event slot template",
        );
      }
      if (tpl.base_price === null) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Event slot template has no base_price",
        );
      }
      eventSlotUnitPrice = money(tpl.base_price);
      const openSlot = await this.pg.query(
        `SELECT 1 FROM event_slot_inventory esi
         JOIN event_slot_templates est ON est.id = esi.slot_template_id
         WHERE esi.venue_id = $1 AND est.code = $2
           AND esi.slot_date = $3::date AND esi.status = 'open'
         LIMIT 1`,
        [input.venueId, slotCode, input.checkIn],
      );
      if (!openSlot.rowCount) {
        throw new AppError(
          ErrorCodes.AVAILABILITY_CHANGED,
          "Event slot not available",
        );
      }
    } else if (slotCode) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "slotCode only allowed for event_slot venues",
      );
    }
    const provider = await this.pg.query<{
      status: string;
      commission_bps_override: number | null;
    }>("SELECT status, commission_bps_override FROM providers WHERE id = $1", [
      venue.rows[0].provider_id,
    ]);
    if (!provider.rowCount || provider.rows[0].status !== "active") {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Provider is not active");
    }

    const type = await this.pg.query<{
      base_occupancy: number;
      max_occupancy: number;
      extra_guest_amount: string;
      status: string;
      inventory_model: string;
    }>(
      `SELECT base_occupancy, max_occupancy, extra_guest_amount::text, status, inventory_model
       FROM inventory_types WHERE id = $1 AND venue_id = $2`,
      [input.inventoryTypeId, input.venueId],
    );
    if (!type.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Inventory type not found");
    }
    if (type.rows[0].status !== "active") {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Inventory type is not active",
      );
    }
    if (type.rows[0].inventory_model !== "pooled") {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Physical inventory model is not bookable in this phase",
      );
    }

    this.assertSafeStayWindow(
      venue.rows[0].booking_mode,
      input.checkIn,
      input.checkOut,
    );

    const dates = stayDates(
      venue.rows[0].booking_mode,
      input.checkIn,
      input.checkOut,
    );
    // event_slot is always one day; min_stay still applies as 1 typically.
    if (dates.length < venue.rows[0].min_stay) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Below min stay");
    }
    if (venue.rows[0].max_stay && dates.length > venue.rows[0].max_stay) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Above max stay");
    }
    if (dates.length > MAX_STAY_NIGHTS_HARD) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Stay exceeds hard maximum",
      );
    }

    // Discovery parity: (max_occupancy × quantity) >= guests
    const guests = input.guestsAdults + input.guestsChildren;
    const capacity = type.rows[0].max_occupancy * input.quantity;
    if (guests > capacity) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Occupancy exceeds max × quantity",
      );
    }

    // event_slot prices from the template base_price (resolved above); nightly/
    // daily continue to price from rate_rules.
    const rules = eventSlotUnitPrice
      ? []
      : await this.loadRules(input.inventoryTypeId);
    const items: QuoteComputation["items"] = [];
    let subtotal = Decimal.zero();
    for (const date of dates) {
      const unit = eventSlotUnitPrice ?? this.priceForNight(date, rules);
      const line = unit.mul(input.quantity);
      subtotal = subtotal.add(line);
      items.push({
        kind: "night",
        date,
        label:
          mode === "event_slot" && slotCode
            ? `Slot ${slotCode} ${date}`
            : `Night ${date}`,
        amount: line.toString(),
        qty: input.quantity,
      });
    }
    let extrasTotal = Decimal.zero();
    if (input.extraIds.length) {
      const extras = await this.pg.query<{
        id: string;
        name: string;
        amount: string;
        per: string;
      }>(
        `SELECT id, name, amount::text, per FROM extras WHERE id = ANY($1::uuid[]) AND venue_id = $2 AND status = 'active'`,
        [input.extraIds, input.venueId],
      );
      for (const ex of extras.rows) {
        const unit = money(ex.amount);
        const qty =
          ex.per === "night" ? dates.length : ex.per === "guest" ? guests : 1;
        const line = unit.mul(qty);
        extrasTotal = extrasTotal.add(line);
        items.push({
          kind: "extra",
          date: null,
          label: ex.name,
          amount: line.toString(),
          qty,
        });
      }
    }
    const extraGuests = Math.max(
      0,
      guests - type.rows[0].base_occupancy * input.quantity,
    );
    const extraGuestAmt = money(type.rows[0].extra_guest_amount);
    if (extraGuests > 0 && extraGuestAmt.toNumber() > 0) {
      const line = extraGuestAmt.mul(extraGuests).mul(dates.length);
      extrasTotal = extrasTotal.add(line);
      items.push({
        kind: "fee",
        date: null,
        label: "Extra guest",
        amount: line.toString(),
        qty: extraGuests,
      });
    }
    let discountTotal = Decimal.zero();
    if (input.promoCode) {
      const promo = await this.pg.query<{ kind: string; value: string }>(
        `SELECT kind, value::text FROM promo_codes
         WHERE code = $1 AND status = 'active'
           AND (provider_id IS NULL OR provider_id = $2)`,
        [input.promoCode, venue.rows[0].provider_id],
      );
      if (!promo.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Promo not valid for this venue/provider",
        );
      }
      const base = subtotal.add(extrasTotal);
      let raw =
        promo.rows[0].kind === "percent"
          ? base.ofBps(Math.min(100, Number(promo.rows[0].value)) * 100)
          : money(promo.rows[0].value);
      // Cap at 100% of base — never negative gross.
      if (raw.gt(base)) {
        raw = base;
      }
      discountTotal = raw;
      items.push({
        kind: "discount",
        date: null,
        label: `Promo ${input.promoCode}`,
        amount: discountTotal.toString(),
        qty: 1,
      });
    }
    const taxTotal = Decimal.zero();
    const gross = subtotal.add(extrasTotal).sub(discountTotal).add(taxTotal);
    if (gross.toNumber() < 0) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Gross cannot be negative",
      );
    }
    const bps =
      provider.rows[0]?.commission_bps_override ??
      this.env.defaultCommissionBps;
    const commission = commissionOf(gross, bps);
    return {
      dates,
      items,
      subtotal: subtotal.toString(),
      extrasTotal: extrasTotal.toString(),
      discountTotal: discountTotal.toString(),
      taxTotal: taxTotal.toString(),
      grossTotal: gross.toString(),
      commissionBps: bps,
      commissionAmount: commission.toString(),
      providerNet: providerNetOf(gross, commission).toString(),
      currency: "SAR",
      pricingVersion: "places-pricing-v1",
      slotCode,
      bookingMode: mode,
    };
  }

  private assertSafeStayWindow(
    mode: "nightly" | "daily" | "event_slot",
    checkIn: string,
    checkOut: string,
  ): void {
    const today = toIsoDate(new Date());
    if (checkIn < today) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "checkIn must not be in the past",
      );
    }
    const maxIn = toIsoDate(
      addDays(parseIsoDate(today), MAX_CHECK_IN_DAYS_AHEAD),
    );
    if (checkIn > maxIn) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "checkIn too far in the future",
      );
    }
    // Daily / event_slot allow same-day (checkIn == checkOut). Nightly requires checkOut > checkIn.
    if (mode === "daily" || mode === "event_slot") {
      if (checkOut < checkIn) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "checkOut must be on/after checkIn",
        );
      }
      return;
    }
    if (checkOut <= checkIn) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "checkOut must be after checkIn",
      );
    }
  }

  private async loadRules(typeId: string): Promise<RateRule[]> {
    const plan = await this.pg.query<{ id: string }>(
      `SELECT id FROM rate_plans WHERE inventory_type_id = $1 AND is_default = true AND status = 'active' LIMIT 1`,
      [typeId],
    );
    if (!plan.rowCount) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "No rate plan");
    }
    const rules = await this.pg.query<RateRule>(
      `SELECT kind, amount::text, date_from::text, date_to::text, priority
       FROM rate_rules WHERE rate_plan_id = $1`,
      [plan.rows[0].id],
    );
    return rules.rows;
  }

  private priceForNight(date: string, rules: RateRule[]): Decimal {
    const ranked = [...rules].sort((a, b) => b.priority - a.priority);
    const range = ranked.find(
      (r) =>
        r.kind === "date_range" &&
        r.date_from &&
        r.date_to &&
        date >= r.date_from &&
        date <= r.date_to,
    );
    if (range) {
      return money(range.amount);
    }
    const wknd = ranked.find((r) => r.kind === "weekend");
    const wkdy = ranked.find((r) => r.kind === "weekday");
    if (isWeekend(date) && wknd) {
      return money(wknd.amount);
    }
    if (!isWeekend(date) && wkdy) {
      return money(wkdy.amount);
    }
    const base = ranked.find((r) => r.kind === "base");
    if (!base) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Missing base rate");
    }
    return money(base.amount);
  }
}
