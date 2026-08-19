import { Injectable } from "@nestjs/common";
import { PoolClient } from "pg";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { OutboxService } from "../../../shared/events/outbox.service";
import { AuditService } from "../../audit/application/audit.service";
import { BookingStatus, canTransition } from "./booking-states";

export interface TransitionCtx {
  bookingId: string;
  from: BookingStatus | "";
  to: BookingStatus;
  actorUid: string;
  actorRole: string;
  correlationId: string;
  reason?: string;
  eventName: string;
  eventPayload?: Record<string, unknown>;
}

@Injectable()
export class BookingStateMachine {
  constructor(
    private readonly audit: AuditService,
    private readonly outbox: OutboxService,
  ) {}

  async transition(client: PoolClient, ctx: TransitionCtx): Promise<void> {
    if (!canTransition(ctx.from, ctx.to)) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Illegal booking transition ${ctx.from || "∅"} → ${ctx.to}`,
      );
    }
    // HOLDING→CONFIRMED must use transitionPayAtVenueConfirm (single SQL with payment fields).
    if (ctx.from === "HOLDING" && ctx.to === "CONFIRMED") {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "HOLDING→CONFIRMED requires Pay-at-Venue confirm path",
      );
    }
    if (ctx.bookingId && ctx.from) {
      const upd = await client.query(
        `UPDATE bookings SET status = $2, updated_at = now() WHERE id = $1 AND status = $3`,
        [ctx.bookingId, ctx.to, ctx.from],
      );
      if (upd.rowCount !== 1) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Booking status changed concurrently",
        );
      }
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: ctx.from },
        after: { status: ctx.to },
        reason: ctx.reason,
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      ctx.eventName,
      { bookingId: ctx.bookingId, ...ctx.eventPayload },
      client,
    );
  }

  /**
   * Guarded single SQL UPDATE: status + payment fields + confirmed_at (rowCount=1).
   */
  async transitionPayAtVenueConfirm(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<void> {
    if (!canTransition("HOLDING", "CONFIRMED")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Illegal booking transition HOLDING → CONFIRMED",
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET
         status = 'CONFIRMED',
         payment_method = 'PAY_AT_VENUE',
         payment_status = 'DUE_AT_VENUE',
         confirmed_at = now(),
         updated_at = now()
       WHERE id = $1
         AND status = 'HOLDING'
         AND payment_method IS NULL
         AND payment_status IS NULL`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.BOOKING_ALREADY_CONFIRMED,
        "Booking status changed concurrently or already confirmed",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: "HOLDING", paymentMethod: null, paymentStatus: null },
        after: {
          status: "CONFIRMED",
          paymentMethod: "PAY_AT_VENUE",
          paymentStatus: "DUE_AT_VENUE",
        },
        reason: "confirm_pay_at_venue",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.confirmed_pay_at_venue",
      { bookingId: ctx.bookingId },
      client,
    );
  }

  /** Cancel HOLDING → CANCELLED with payment NULL/NULL (single UPDATE). */
  async transitionCancelHolding(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<void> {
    if (!canTransition("HOLDING", "CANCELLED")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Illegal booking transition HOLDING → CANCELLED",
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET
         status = 'CANCELLED',
         payment_method = NULL,
         payment_status = NULL,
         cancelled_at = now(),
         updated_at = now()
       WHERE id = $1 AND status = 'HOLDING'
         AND payment_method IS NULL AND payment_status IS NULL`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.BOOKING_NOT_CANCELLABLE,
        "Booking not cancellable as HOLDING",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: "HOLDING" },
        after: { status: "CANCELLED" },
        reason: "cancel_holding",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.cancelled",
      { bookingId: ctx.bookingId, path: "holding" },
      client,
    );
  }

  /** Cancel CONFIRMED pay-at-venue → CANCELLED + VOIDED (single UPDATE). */
  async transitionCancelPayAtVenue(
    client: PoolClient,
    ctx: {
      bookingId: string;
      from: "CONFIRMED";
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<void> {
    if (!canTransition(ctx.from, "CANCELLED")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Illegal booking transition ${ctx.from} → CANCELLED`,
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET
         status = 'CANCELLED',
         payment_status = 'VOIDED',
         cancelled_at = now(),
         updated_at = now()
       WHERE id = $1
         AND status = 'CONFIRMED'
         AND payment_method = 'PAY_AT_VENUE'
         AND payment_status = 'DUE_AT_VENUE'`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.BOOKING_NOT_CANCELLABLE,
        "Pay-at-Venue booking not cancellable",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: {
          status: ctx.from,
          paymentMethod: "PAY_AT_VENUE",
          paymentStatus: "DUE_AT_VENUE",
        },
        after: {
          status: "CANCELLED",
          paymentMethod: "PAY_AT_VENUE",
          paymentStatus: "VOIDED",
        },
        reason: "cancel_pay_at_venue",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.cancelled",
      { bookingId: ctx.bookingId, path: "pay_at_venue" },
      client,
    );
  }

  /** PSP webhook confirm: single UPDATE status+payment+confirmed_at. */
  async transitionPspConfirm(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
      paymentId: string;
    },
  ): Promise<void> {
    if (!canTransition("PENDING_PAYMENT", "CONFIRMED")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Illegal booking transition PENDING_PAYMENT → CONFIRMED",
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET
         status = 'CONFIRMED',
         payment_method = 'PSP_CARD',
         payment_status = 'CAPTURED',
         confirmed_at = now(),
         updated_at = now()
       WHERE id = $1 AND status = 'PENDING_PAYMENT'
         AND payment_method IS NULL AND payment_status IS NULL`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Booking status changed concurrently",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: "PENDING_PAYMENT" },
        after: {
          status: "CONFIRMED",
          paymentMethod: "PSP_CARD",
          paymentStatus: "CAPTURED",
        },
        reason: "psp_confirm",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.confirmed",
      { bookingId: ctx.bookingId, paymentId: ctx.paymentId },
      client,
    );
  }

  /** PAV collect-at-venue: CONFIRMED + DUE → same status + COLLECTED_AT_VENUE. */
  async transitionPavCollect(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
      amount: string;
    },
  ): Promise<void> {
    const upd = await client.query(
      `UPDATE bookings SET
         payment_status = 'COLLECTED_AT_VENUE',
         updated_at = now()
       WHERE id = $1
         AND status = 'CONFIRMED'
         AND payment_method = 'PAY_AT_VENUE'
         AND payment_status = 'DUE_AT_VENUE'`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Pay-at-Venue booking not collectable",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { paymentStatus: "DUE_AT_VENUE" },
        after: { paymentStatus: "COLLECTED_AT_VENUE", collectedAmount: ctx.amount },
        reason: "pav_collect_at_venue",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.collected_at_venue",
      { bookingId: ctx.bookingId, amount: ctx.amount },
      client,
    );
  }

  /** PAV check-in: CONFIRMED + COLLECTED → ACTIVE. */
  async transitionPavCheckIn(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<void> {
    if (!canTransition("CONFIRMED", "ACTIVE")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Illegal booking transition CONFIRMED → ACTIVE",
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET status = 'ACTIVE', updated_at = now()
       WHERE id = $1
         AND status = 'CONFIRMED'
         AND payment_method = 'PAY_AT_VENUE'
         AND payment_status = 'COLLECTED_AT_VENUE'`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.PAV_COLLECTION_REQUIRED,
        "Check-in requires COLLECTED_AT_VENUE",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: "CONFIRMED" },
        after: { status: "ACTIVE" },
        reason: "pav_check_in",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.checked_in",
      { bookingId: ctx.bookingId },
      client,
    );
  }

  /** PAV complete: ACTIVE + COLLECTED → COMPLETED. */
  async transitionPavComplete(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<void> {
    if (!canTransition("ACTIVE", "COMPLETED")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Illegal booking transition ACTIVE → COMPLETED",
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET status = 'COMPLETED', updated_at = now()
       WHERE id = $1
         AND status = 'ACTIVE'
         AND payment_method = 'PAY_AT_VENUE'
         AND payment_status = 'COLLECTED_AT_VENUE'`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Pay-at-Venue booking not completable",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: "ACTIVE" },
        after: { status: "COMPLETED" },
        reason: "pav_complete",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.completed",
      { bookingId: ctx.bookingId, path: "pav" },
      client,
    );
  }

  /** PAV no-show: CONFIRMED (+ DUE or after window) → NO_SHOW + VOIDED. */
  async transitionPavNoShow(
    client: PoolClient,
    ctx: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<void> {
    if (!canTransition("CONFIRMED", "NO_SHOW")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Illegal booking transition CONFIRMED → NO_SHOW",
      );
    }
    const upd = await client.query(
      `UPDATE bookings SET
         status = 'NO_SHOW',
         payment_status = 'VOIDED',
         updated_at = now()
       WHERE id = $1
         AND status = 'CONFIRMED'
         AND payment_method = 'PAY_AT_VENUE'
         AND payment_status = 'DUE_AT_VENUE'`,
      [ctx.bookingId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Pay-at-Venue booking not eligible for no-show",
      );
    }
    await this.audit.write(
      {
        actorUid: ctx.actorUid,
        actorRole: ctx.actorRole,
        entityType: "booking",
        entityId: ctx.bookingId,
        before: { status: "CONFIRMED", paymentStatus: "DUE_AT_VENUE" },
        after: { status: "NO_SHOW", paymentStatus: "VOIDED" },
        reason: "pav_no_show",
        correlationId: ctx.correlationId,
      },
      client,
    );
    await this.outbox.enqueue(
      "booking.no_show",
      { bookingId: ctx.bookingId },
      client,
    );
  }
}
