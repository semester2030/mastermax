import { Injectable } from "@nestjs/common";
import { PoolClient } from "pg";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { money } from "../../../shared/money/money";
import { riyadhTodayIso, stayDates } from "../../../shared/time/stay-dates";
import { checkInInstantReached } from "../../../shared/time/venue-time";
import { CapacityService } from "../../inventory/application/capacity.service";
import { BookingStateMachine } from "../domain/booking-state.machine";
import { BookingLockOrder } from "./booking-lock-order";
import { DarCommissionService } from "../../settlements/application/dar-commission.service";

export type PavOpsResult = {
  bookingId: string;
  status: string;
  paymentMethod: string | null;
  paymentStatus: string | null;
  receivableId?: string;
};

/**
 * Phase 4 — single application service for PAV operational cycle:
 * collect-at-venue → check-in → complete | no-show.
 * Controllers stay thin; all locks/audit/outbox/tenancy live here.
 */
@Injectable()
export class PavOpsService {
  constructor(
    private readonly pg: PgService,
    private readonly sm: BookingStateMachine,
    private readonly capacity: CapacityService,
    private readonly dar: DarCommissionService,
  ) {}

  async collectAtVenue(
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      amount: string;
      currency: string;
      correlationId: string;
    },
    client?: PoolClient,
  ): Promise<PavOpsResult> {
    const run = (c: PoolClient) => this.collectInTx(c, input);
    return client ? run(client) : this.pg.tx(run);
  }

  async checkIn(
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      correlationId: string;
    },
    client?: PoolClient,
  ): Promise<PavOpsResult> {
    const run = (c: PoolClient) => this.checkInInTx(c, input);
    return client ? run(client) : this.pg.tx(run);
  }

  async complete(
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      correlationId: string;
    },
    client?: PoolClient,
  ): Promise<PavOpsResult> {
    const run = (c: PoolClient) => this.completeInTx(c, input);
    return client ? run(client) : this.pg.tx(run);
  }

  async noShow(
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      correlationId: string;
    },
    client?: PoolClient,
  ): Promise<PavOpsResult> {
    const run = (c: PoolClient) => this.noShowInTx(c, input);
    return client ? run(client) : this.pg.tx(run);
  }

  private async lockTenantBooking(
    c: PoolClient,
    bookingId: string,
    providerId: string,
  ): Promise<{
    id: string;
    status: string;
    payment_method: string | null;
    payment_status: string | null;
    venue_id: string;
    provider_id: string;
    inventory_type_id: string;
    quantity: number;
    check_in: string;
    check_out: string;
    slot_code: string | null;
    booking_mode: "nightly" | "daily" | "event_slot";
    hold_id: string | null;
    gross_total: string;
    commission_amount: string;
    timezone: string;
    check_in_time: string | null;
    slot_start_time: string | null;
    slot_timezone: string | null;
  }> {
    const peek = await c.query<{
      venue_id: string;
      provider_id: string;
      hold_id: string | null;
      booking_mode: "nightly" | "daily" | "event_slot";
      check_in: string;
    }>(
      `SELECT b.venue_id, b.provider_id, b.hold_id, v.booking_mode, b.check_in::text
       FROM bookings b JOIN venues v ON v.id = b.venue_id WHERE b.id = $1`,
      [bookingId],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    if (peek.rows[0].provider_id !== providerId) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    await BookingLockOrder.lockVenue(c, peek.rows[0].venue_id);
    if (peek.rows[0].booking_mode === "event_slot") {
      await BookingLockOrder.lockTemplatesForVenue(c, peek.rows[0].venue_id);
      await BookingLockOrder.lockSlotInventoryForVenueDate(
        c,
        peek.rows[0].venue_id,
        peek.rows[0].check_in,
      );
    }
    if (peek.rows[0].hold_id) {
      await BookingLockOrder.lockHold(c, peek.rows[0].hold_id);
    }
    await BookingLockOrder.lockBooking(c, bookingId);

    const row = await c.query<{
      id: string;
      status: string;
      payment_method: string | null;
      payment_status: string | null;
      venue_id: string;
      provider_id: string;
      inventory_type_id: string;
      quantity: number;
      check_in: string;
      check_out: string;
      slot_code: string | null;
      booking_mode: "nightly" | "daily" | "event_slot";
      hold_id: string | null;
      gross_total: string;
      commission_amount: string;
      timezone: string;
      check_in_time: string | null;
      slot_start_time: string | null;
      slot_timezone: string | null;
    }>(
      `SELECT b.id, b.status, b.payment_method, b.payment_status, b.venue_id,
              b.provider_id, b.inventory_type_id, b.quantity,
              b.check_in::text, b.check_out::text, b.slot_code, v.booking_mode,
              b.hold_id, b.gross_total::text, b.commission_amount::text,
              v.timezone, v.check_in_time,
              to_char(b.slot_start_time, 'HH24:MI') AS slot_start_time,
              b.slot_timezone
       FROM bookings b JOIN venues v ON v.id = b.venue_id WHERE b.id = $1`,
      [bookingId],
    );
    return row.rows[0];
  }

  private async collectInTx(
    c: PoolClient,
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      amount: string;
      currency: string;
      correlationId: string;
    },
  ): Promise<PavOpsResult> {
    const b = await this.lockTenantBooking(c, input.bookingId, input.providerId);

    // Idempotent replay: already collected.
    if (
      b.status === "CONFIRMED" &&
      b.payment_method === "PAY_AT_VENUE" &&
      b.payment_status === "COLLECTED_AT_VENUE"
    ) {
      const recv = await c.query<{ id: string }>(
        `SELECT id FROM dar_commission_receivables WHERE booking_id = $1`,
        [b.id],
      );
      return {
        bookingId: b.id,
        status: b.status,
        paymentMethod: b.payment_method,
        paymentStatus: b.payment_status,
        receivableId: recv.rows[0]?.id,
      };
    }

    if (
      b.status !== "CONFIRMED" ||
      b.payment_method !== "PAY_AT_VENUE" ||
      b.payment_status !== "DUE_AT_VENUE"
    ) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Collect requires CONFIRMED + DUE_AT_VENUE",
      );
    }

    if ((input.currency || "SAR").toUpperCase() !== "SAR") {
      throw new AppError(ErrorCodes.PAV_AMOUNT_MISMATCH, "Currency must be SAR");
    }
    if (!money(input.amount).eq(money(b.gross_total))) {
      throw new AppError(
        ErrorCodes.PAV_AMOUNT_MISMATCH,
        "Collected amount must equal booking.gross_total exactly",
        { expected: b.gross_total, got: input.amount },
      );
    }

    await this.sm.transitionPavCollect(c, {
      bookingId: b.id,
      actorUid: input.actorUid,
      actorRole: "provider",
      correlationId: input.correlationId,
      amount: b.gross_total,
    });

    // PAV: provider already held gross — never create provider_receivable.
    const pr = await c.query(
      `SELECT 1 FROM provider_receivables WHERE booking_id = $1`,
      [b.id],
    );
    if (pr.rowCount) {
      throw new AppError(
        ErrorCodes.INTERNAL,
        "PAV path must not create provider_receivables",
        undefined,
        true,
      );
    }

    const { receivableId } = await this.dar.recordOnCollect(c, {
      bookingId: b.id,
      providerId: b.provider_id,
      commissionAmount: b.commission_amount,
      correlationId: input.correlationId,
    });

    return {
      bookingId: b.id,
      status: "CONFIRMED",
      paymentMethod: "PAY_AT_VENUE",
      paymentStatus: "COLLECTED_AT_VENUE",
      receivableId,
    };
  }

  private async checkInInTx(
    c: PoolClient,
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      correlationId: string;
    },
  ): Promise<PavOpsResult> {
    const b = await this.lockTenantBooking(c, input.bookingId, input.providerId);
    if (b.status === "ACTIVE" && b.payment_status === "COLLECTED_AT_VENUE") {
      return {
        bookingId: b.id,
        status: "ACTIVE",
        paymentMethod: b.payment_method,
        paymentStatus: b.payment_status,
      };
    }
    if (b.payment_status !== "COLLECTED_AT_VENUE") {
      throw new AppError(
        ErrorCodes.PAV_COLLECTION_REQUIRED,
        "Check-in requires proven collection",
      );
    }
    await this.sm.transitionPavCheckIn(c, {
      bookingId: b.id,
      actorUid: input.actorUid,
      actorRole: "provider",
      correlationId: input.correlationId,
    });
    return {
      bookingId: b.id,
      status: "ACTIVE",
      paymentMethod: "PAY_AT_VENUE",
      paymentStatus: "COLLECTED_AT_VENUE",
    };
  }

  private async completeInTx(
    c: PoolClient,
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      correlationId: string;
    },
  ): Promise<PavOpsResult> {
    const b = await this.lockTenantBooking(c, input.bookingId, input.providerId);
    if (b.status === "COMPLETED" && b.payment_status === "COLLECTED_AT_VENUE") {
      await this.dar.markDueOnComplete(c, b.id);
      return {
        bookingId: b.id,
        status: "COMPLETED",
        paymentMethod: b.payment_method,
        paymentStatus: b.payment_status,
      };
    }
    await this.sm.transitionPavComplete(c, {
      bookingId: b.id,
      actorUid: input.actorUid,
      actorRole: "provider",
      correlationId: input.correlationId,
    });
    await this.dar.markDueOnComplete(c, b.id);
    return {
      bookingId: b.id,
      status: "COMPLETED",
      paymentMethod: "PAY_AT_VENUE",
      paymentStatus: "COLLECTED_AT_VENUE",
    };
  }

  private async noShowInTx(
    c: PoolClient,
    input: {
      bookingId: string;
      providerId: string;
      actorUid: string;
      correlationId: string;
    },
  ): Promise<PavOpsResult> {
    const b = await this.lockTenantBooking(c, input.bookingId, input.providerId);
    if (b.status === "NO_SHOW" && b.payment_status === "VOIDED") {
      return {
        bookingId: b.id,
        status: "NO_SHOW",
        paymentMethod: b.payment_method,
        paymentStatus: "VOIDED",
      };
    }
    // RC4: event_slot no-show uses the immutable booking snapshot, never the
    // live template. Nightly/daily still use the venue check-in wall time.
    const anchorTime =
      b.booking_mode === "event_slot"
        ? b.slot_start_time
        : b.check_in_time;
    const timeZone =
      b.booking_mode === "event_slot"
        ? (b.slot_timezone ?? b.timezone)
        : b.timezone;
    if (
      !checkInInstantReached({
        checkInDate: b.check_in,
        timeZone,
        checkInTime: anchorTime,
      })
    ) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        b.booking_mode === "event_slot"
          ? "No-show only allowed on/after the event start time"
          : "No-show only allowed on/after the venue-local check-in time",
      );
    }
    await this.sm.transitionPavNoShow(c, {
      bookingId: b.id,
      actorUid: input.actorUid,
      actorRole: "provider",
      correlationId: input.correlationId,
    });
    // Release future booked days only (never current/past). No commission receivable.
    const today = riyadhTodayIso();
    const dates = stayDates(b.booking_mode, b.check_in, b.check_out).filter(
      (d) => d > today,
    );
    if (dates.length && b.booking_mode !== "event_slot") {
      await this.capacity.releaseBooked(
        b.inventory_type_id,
        dates,
        b.quantity,
        c,
      );
    }
    // Phase 7: no-show frees booked event_slot inventory → open.
    if (b.booking_mode === "event_slot") {
      await c.query(
        `UPDATE event_slot_inventory
         SET status = 'open', booking_id = NULL, hold_id = NULL
         WHERE venue_id = $1 AND booking_id = $2 AND status = 'booked'`,
        [b.venue_id, b.id],
      );
    }
    const recv = await c.query(
      `SELECT 1 FROM dar_commission_receivables WHERE booking_id = $1`,
      [b.id],
    );
    if (recv.rowCount) {
      throw new AppError(
        ErrorCodes.INTERNAL,
        "No-show must not leave a DAR commission receivable",
        undefined,
        true,
      );
    }
    return {
      bookingId: b.id,
      status: "NO_SHOW",
      paymentMethod: "PAY_AT_VENUE",
      paymentStatus: "VOIDED",
    };
  }
}
