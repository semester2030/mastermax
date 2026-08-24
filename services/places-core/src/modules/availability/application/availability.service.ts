import { Injectable } from "@nestjs/common";
import { PoolClient } from "pg";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { parseIsoDate, stayDates } from "../../../shared/time/stay-dates";
import { CapacityService } from "../../inventory/application/capacity.service";
import { BookingLockOrder } from "../../booking/application/booking-lock-order";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";
import { metrics } from "../../../shared/observability/metrics";

@Injectable()
export class AvailabilityService {
  constructor(
    private readonly pg: PgService,
    private readonly capacity: CapacityService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  async search(input: {
    venueId: string;
    inventoryTypeId: string;
    checkIn: string;
    checkOut: string;
    quantity: number;
  }): Promise<{
    available: boolean;
    remaining: number;
    units: Array<{ id: string; label: string }>;
  }> {
    const started = Date.now();
    const venue = await this.pg.query<{
      booking_mode: "nightly" | "daily" | "event_slot";
      venue_type: string;
    }>("SELECT booking_mode, venue_type FROM venues WHERE id = $1", [
      input.venueId,
    ]);
    if (!venue.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    this.caps.requireEventSlotPathAllowed(venue.rows[0].booking_mode);
    await this.caps.requireBookingEnabled(venue.rows[0].venue_type);
    const type = await this.pg.query<{
      id: string;
      status: string;
      inventory_model: string;
    }>(
      `SELECT id, status, inventory_model FROM inventory_types WHERE id = $1 AND venue_id = $2`,
      [input.inventoryTypeId, input.venueId],
    );
    if (!type.rowCount) {
      throw new AppError(
        ErrorCodes.NOT_FOUND,
        "Inventory type not found for venue",
      );
    }
    if (type.rows[0].status !== "active") {
      return { available: false, remaining: 0, units: [] };
    }
    const mode = venue.rows[0].booking_mode ?? "nightly";
    const dates = stayDates(mode, input.checkIn, input.checkOut);
    const open = await this.datesOpenUnderRules(input.inventoryTypeId, dates);
    if (!open) {
      metrics.observe("availability_latency", Date.now() - started);
      return { available: false, remaining: 0, units: [] };
    }
    if (type.rows[0].inventory_model === "physical") {
      const qty = input.quantity;
      const units = await this.pg.tx(async (c) => {
        await BookingLockOrder.lockInventoryType(c, input.inventoryTypeId);
        return this.capacity.listAvailablePhysicalUnits(
          input.inventoryTypeId,
          input.checkIn,
          input.checkOut,
          dates,
          c,
        );
      });
      metrics.observe("availability_latency", Date.now() - started);
      return {
        available: units.length >= qty && qty === 1,
        remaining: units.length,
        units,
      };
    }
    await this.pg.tx(async (c) => {
      await this.capacity.ensureRows(input.inventoryTypeId, dates, c);
    });
    const remaining = await this.capacity.readMinAvailable(
      input.inventoryTypeId,
      dates,
    );
    metrics.observe("availability_latency", Date.now() - started);
    return { available: remaining >= input.quantity, remaining, units: [] };
  }

  /**
   * Apply availability_rules + type-level overrides.
   * No rules → open by default. Rules present → date must match an open rule (dow + window).
   * Override kind=block|maintenance closes the date; kind=open forces open.
   */
  async datesOpenUnderRules(
    inventoryTypeId: string,
    dates: string[],
    client?: PoolClient,
  ): Promise<boolean> {
    type RuleRow = {
      dow_mask: number;
      is_open: boolean;
      effective_from: string | null;
      effective_to: string | null;
    };
    type OverrideRow = { date: string; kind: string };
    const rules = client
      ? await client.query<RuleRow>(
          `SELECT dow_mask, is_open, effective_from::text, effective_to::text
           FROM availability_rules WHERE inventory_type_id = $1`,
          [inventoryTypeId],
        )
      : await this.pg.query<RuleRow>(
          `SELECT dow_mask, is_open, effective_from::text, effective_to::text
           FROM availability_rules WHERE inventory_type_id = $1`,
          [inventoryTypeId],
        );
    const overrides = client
      ? await client.query<OverrideRow>(
          `SELECT date::text, kind FROM availability_overrides
           WHERE inventory_type_id = $1 AND inventory_unit_id IS NULL
             AND date = ANY($2::date[])`,
          [inventoryTypeId, dates],
        )
      : await this.pg.query<OverrideRow>(
          `SELECT date::text, kind FROM availability_overrides
           WHERE inventory_type_id = $1 AND inventory_unit_id IS NULL
             AND date = ANY($2::date[])`,
          [inventoryTypeId, dates],
        );
    const byDate = new Map<string, string[]>();
    for (const o of overrides.rows) {
      const list = byDate.get(o.date) ?? [];
      list.push(o.kind);
      byDate.set(o.date, list);
    }
    for (const date of dates) {
      const kinds = byDate.get(date) ?? [];
      if (kinds.includes("block") || kinds.includes("maintenance")) {
        return false;
      }
      if (kinds.includes("open")) {
        continue;
      }
      if (!rules.rowCount) {
        continue;
      }
      const dow = parseIsoDate(date).getUTCDay(); // 0=Sun … 6=Sat; bit N in dow_mask
      const matched = rules.rows.some((r) => {
        if (!r.is_open) {
          return false;
        }
        if (r.effective_from && date < r.effective_from) {
          return false;
        }
        if (r.effective_to && date > r.effective_to) {
          return false;
        }
        return ((r.dow_mask >> dow) & 1) === 1;
      });
      if (!matched) {
        return false;
      }
    }
    return true;
  }
}
