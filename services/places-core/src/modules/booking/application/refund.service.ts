import { Inject, Injectable, Logger } from "@nestjs/common";
import { hostname } from "os";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { money, proportionalShare } from "../../../shared/money/money";
import { stayDates } from "../../../shared/time/stay-dates";
import { hoursUntilCheckIn } from "../../../shared/time/venue-time";
import { OutboxService } from "../../../shared/events/outbox.service";
import { CapacityService } from "../../inventory/application/capacity.service";
import { LedgerService } from "../../ledger/application/ledger.service";
import { PAYMENT_PORT, PaymentPort } from "../../payments/domain/payment.port";
import { BookingStateMachine } from "../domain/booking-state.machine";
import { BookingStatus } from "../domain/booking-states";
import { BookingLockOrder } from "./booking-lock-order";

export type ClaimedRefund = {
  id: string;
  amount: string;
  psp_intent_id: string;
  locked_by: string;
};

/** Stale processing reclaim after this many seconds (worker crash). */
export const REFUND_STALE_SECONDS = 60;

/**
 * Request refund in DB TX → claim → PSP outside TX → finalize.
 * Multi-instance safe via FOR UPDATE SKIP LOCKED claim.
 */
@Injectable()
export class RefundService {
  private readonly logger = new Logger(RefundService.name);
  private readonly workerId = `${hostname()}:${process.pid}:${newId().slice(0, 8)}`;

  constructor(
    private readonly pg: PgService,
    private readonly sm: BookingStateMachine,
    private readonly ledger: LedgerService,
    private readonly capacity: CapacityService,
    private readonly outbox: OutboxService,
    @Inject(PAYMENT_PORT) private readonly psp: PaymentPort,
  ) {}

  async refund(input: {
    bookingId: string;
    actorUid: string;
    actorRole: string;
    kind:
      | "full"
      | "partial"
      | "customer_cancel"
      | "provider_cancel"
      | "operational";
    amount?: string;
    reason: string;
    correlationId: string;
    idempotencyKey?: string;
  }): Promise<{ refundId: string; amount: string; status: string }> {
    const requested = await this.requestRefund(input);
    if (requested.refundId === "none" || requested.status === "completed") {
      return requested;
    }
    await this.dispatchRefund(requested.refundId, input.correlationId);
    const row = await this.pg.query<{
      id: string;
      amount: string;
      status: string;
    }>(`SELECT id, amount::text, status FROM refunds WHERE id = $1`, [
      requested.refundId,
    ]);
    return {
      refundId: row.rows[0].id,
      amount: row.rows[0].amount,
      status: row.rows[0].status,
    };
  }

  async requestRefund(input: {
    bookingId: string;
    actorUid: string;
    actorRole: string;
    kind:
      | "full"
      | "partial"
      | "customer_cancel"
      | "provider_cancel"
      | "operational";
    amount?: string;
    reason: string;
    correlationId: string;
    idempotencyKey?: string;
  }): Promise<{ refundId: string; amount: string; status: string }> {
    return this.pg.tx(async (c) => {
      if (input.idempotencyKey) {
        const priorKey = await c.query<{
          id: string;
          amount: string;
          status: string;
        }>(
          `SELECT id, amount::text, status FROM refunds
           WHERE actor_uid = $1 AND idempotency_key = $2`,
          [input.actorUid, input.idempotencyKey],
        );
        if (priorKey.rowCount) {
          return {
            refundId: priorKey.rows[0].id,
            amount: priorKey.rows[0].amount,
            status: priorKey.rows[0].status,
          };
        }
      }
      // RC5 unified lock order: peek → venue → templates/slots → hold → booking → payment.
      const peek = await c.query<{
        id: string;
        venue_id: string;
        hold_id: string | null;
        check_in: string;
        booking_mode: "nightly" | "daily" | "event_slot";
      }>(
        `SELECT b.id, b.venue_id, b.hold_id, b.check_in::text, v.booking_mode
         FROM bookings b
         JOIN venues v ON v.id = b.venue_id
         WHERE b.id = $1`,
        [input.bookingId],
      );
      if (!peek.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
      }
      const peekRow = peek.rows[0];
      await BookingLockOrder.lockVenue(c, peekRow.venue_id);
      if (peekRow.booking_mode === "event_slot") {
        await BookingLockOrder.lockTemplatesForVenue(c, peekRow.venue_id);
        await BookingLockOrder.lockSlotInventoryForVenueDate(
          c,
          peekRow.venue_id,
          peekRow.check_in,
        );
      }
      if (peekRow.hold_id) {
        await BookingLockOrder.lockHold(c, peekRow.hold_id);
      }
      await BookingLockOrder.lockBooking(c, peekRow.id);

      if (input.idempotencyKey) {
        const priorLocked = await c.query<{
          id: string;
          amount: string;
          status: string;
        }>(
          `SELECT id, amount::text, status FROM refunds
           WHERE actor_uid = $1 AND idempotency_key = $2
           FOR UPDATE`,
          [input.actorUid, input.idempotencyKey],
        );
        if (priorLocked.rowCount) {
          return {
            refundId: priorLocked.rows[0].id,
            amount: priorLocked.rows[0].amount,
            status: priorLocked.rows[0].status,
          };
        }
      }

      const b = await c.query<{
        id: string;
        status: string;
        provider_id: string;
        inventory_type_id: string;
        quantity: number;
        check_in: string;
        check_out: string;
        venue_id: string;
        hold_id: string;
        gross_total: string;
        commission_amount: string;
        provider_net: string;
        consumer_firebase_uid: string;
        payment_method: string | null;
        slot_code: string | null;
        booking_mode: 'nightly' | 'daily' | 'event_slot';
        timezone: string;
        check_in_time: string | null;
        cancellation_policy_snapshot_json: {
          free_until_hours_before_checkin: number;
          fee_bps_after: number;
        };
      }>(
        `SELECT b.id, b.status, b.provider_id, b.inventory_type_id, b.quantity,
                b.check_in::text, b.check_out::text,
                b.venue_id, b.hold_id, b.gross_total::text, b.commission_amount::text, b.provider_net::text,
                b.consumer_firebase_uid, b.payment_method, b.slot_code,
                v.booking_mode, v.timezone, v.check_in_time,
                b.cancellation_policy_snapshot_json
         FROM bookings b JOIN venues v ON v.id = b.venue_id WHERE b.id = $1`,
        [input.bookingId],
      );
      if (!b.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
      }
      const booking = b.rows[0];

      // PAV never goes through PSP refund — cancel path yields CANCELLED+VOIDED only.
      if (booking.payment_method === "PAY_AT_VENUE") {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Pay-at-Venue bookings must use cancel path (CANCELLED+VOIDED); PSP refund is not allowed",
        );
      }

      // Ownership inside the same TX as the mutation (fail-closed).
      if (input.actorRole === "consumer") {
        if (booking.consumer_firebase_uid !== input.actorUid) {
          throw new AppError(
            ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
            "Not booking owner",
          );
        }
      } else if (input.actorRole === "provider") {
        const member = await c.query(
          `SELECT 1 FROM provider_users
           WHERE provider_id = $1 AND firebase_uid = $2 AND status = 'active'`,
          [booking.provider_id, input.actorUid],
        );
        if (!member.rowCount) {
          throw new AppError(
            ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
            "Not provider member",
          );
        }
      } else if (
        input.actorRole !== "admin" &&
        input.actorRole !== "placesAdmin" &&
        input.actorRole !== "system" &&
        input.actorRole !== "webhook"
      ) {
        throw new AppError(
          ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
          "Unsupported actor role",
        );
      }

      const existingOpen = await c.query<{
        id: string;
        amount: string;
        status: string;
      }>(
        `SELECT id, amount::text, status FROM refunds
         WHERE booking_id = $1 AND status IN ('pending', 'processing')
         ORDER BY created_at DESC LIMIT 1`,
        [booking.id],
      );
      if (existingOpen.rowCount) {
        return {
          refundId: existingOpen.rows[0].id,
          amount: existingOpen.rows[0].amount,
          status: existingOpen.rows[0].status,
        };
      }

      if (booking.status === "CANCELLED" || booking.status === "REFUNDED") {
        const last = await c.query<{
          id: string;
          amount: string;
          status: string;
        }>(
          `SELECT id, amount::text, status FROM refunds WHERE booking_id = $1 ORDER BY created_at DESC LIMIT 1`,
          [booking.id],
        );
        if (last.rowCount) {
          return {
            refundId: last.rows[0].id,
            amount: last.rows[0].amount,
            status: last.rows[0].status,
          };
        }
        return { refundId: "none", amount: "0.00", status: "none" };
      }

      const isPartial = input.kind === "partial";
      const cancellable = isPartial
        ? ["CONFIRMED", "ACTIVE", "COMPLETED"].includes(booking.status)
        : [
            "CONFIRMED",
            "ACTIVE",
            "COMPLETED",
            "HOLDING",
            "PENDING_PAYMENT",
          ].includes(booking.status);
      if (!cancellable) {
        throw new AppError(
          ErrorCodes.BOOKING_NOT_CANCELLABLE,
          "Booking cannot be refunded/cancelled",
        );
      }

      const pay = await c.query<{
        id: string;
        psp_intent_id: string;
        status: string;
      }>(
        `SELECT id, psp_intent_id, status FROM payments WHERE booking_id = $1 AND status = 'succeeded' FOR UPDATE`,
        [booking.id],
      );

      const refundedSum = await c.query<{ s: string }>(
        `SELECT COALESCE(SUM(amount), 0)::text AS s FROM refunds
         WHERE booking_id = $1 AND status IN ('completed', 'pending', 'processing')`,
        [booking.id],
      );
      const already = money(refundedSum.rows[0]?.s ?? "0");
      const gross = money(booking.gross_total);
      const remaining = gross.sub(already);
      // Phase 4 RC2: resolve the venue-local cancel anchor time. event_slot uses
      // the slot start_time so the policy window closes relative to the event.
      let anchorTime: string | null = booking.check_in_time;
      if (booking.booking_mode === "event_slot" && booking.slot_code) {
        const tpl = await c.query<{ start_time: string }>(
          `SELECT to_char(start_time, 'HH24:MI') AS start_time
           FROM event_slot_templates
           WHERE venue_id = $1 AND code = $2`,
          [booking.venue_id, booking.slot_code],
        );
        anchorTime = tpl.rows[0]?.start_time ?? anchorTime;
      }
      // Full/cancel kinds refund remaining (supports partial-then-full to last hala).
      let next = money(
        this.computeAmount(booking, input.kind, input.amount, remaining, anchorTime),
      );
      if (!isPartial && next.gt(remaining)) {
        next = remaining;
      }
      if (!next.isPositive()) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Refund amount must be positive",
        );
      }
      if (already.add(next).gt(gross)) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Refund exceeds remaining bookable amount",
        );
      }
      // Partial must be strictly less than remaining (100% uses full/cancel kinds).
      if (isPartial && (next.gt(remaining) || next.eq(remaining))) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Partial refund must be less than remaining",
        );
      }
      const amount = next.toString();

      const venue = await c.query<{
        booking_mode: "nightly" | "daily" | "event_slot";
      }>("SELECT booking_mode FROM venues WHERE id = $1", [booking.venue_id]);
      const dates = stayDates(
        venue.rows[0].booking_mode,
        booking.check_in,
        booking.check_out,
      );
      // Full cancel/refund: release only unconsumed future nights (never historical).
      const today = new Intl.DateTimeFormat("en-CA", {
        timeZone: "Asia/Riyadh",
      }).format(new Date());
      const unconsumedDates = dates.filter((d) => d >= today);

      // Partial: never cancel booking and never release inventory without an explicit full-cancel contract.
      if (!isPartial) {
        if (
          booking.status === "HOLDING" ||
          booking.status === "PENDING_PAYMENT"
        ) {
          // Pre-confirm holds: all nights are unconsumed.
          await this.capacity.releaseHeld(
            booking.inventory_type_id,
            dates,
            booking.quantity,
            c,
          );
          await c.query(
            `UPDATE booking_holds SET status = 'RELEASED' WHERE id = $1 AND status = 'ACTIVE'`,
            [booking.hold_id],
          );
        } else if (
          booking.status === "CONFIRMED" ||
          booking.status === "ACTIVE" ||
          booking.status === "COMPLETED"
        ) {
          if (unconsumedDates.length > 0) {
            await this.capacity.releaseBooked(
              booking.inventory_type_id,
              unconsumedDates,
              booking.quantity,
              c,
            );
          }
        }

        const from = booking.status as BookingStatus;
        if (from === "COMPLETED") {
          // COMPLETED → REFUND_PENDING (CANCELLED is illegal from COMPLETED).
          await this.sm.transition(c, {
            bookingId: booking.id,
            from: "COMPLETED",
            to: "REFUND_PENDING",
            actorUid: input.actorUid,
            actorRole: input.actorRole,
            correlationId: input.correlationId,
            reason: input.reason,
            eventName: "refund.requested",
          });
        } else if (
          ["CONFIRMED", "ACTIVE", "HOLDING", "PENDING_PAYMENT"].includes(from)
        ) {
          await this.sm.transition(c, {
            bookingId: booking.id,
            from,
            to: "CANCELLED",
            actorUid: input.actorUid,
            actorRole: input.actorRole,
            correlationId: input.correlationId,
            reason: input.reason,
            eventName: "booking.cancelled",
          });
          await c.query(
            `UPDATE bookings SET cancelled_at = now() WHERE id = $1`,
            [booking.id],
          );
        }
      }

      if (!pay.rowCount) {
        return { refundId: "none", amount: "0.00", status: "none" };
      }

      if (!isPartial && booking.status !== "COMPLETED") {
        // After CANCELLED transition above, status in memory may be stale — read if needed.
        const cur = await c.query<{ status: string }>(
          `SELECT status FROM bookings WHERE id = $1`,
          [booking.id],
        );
        if (cur.rows[0].status === "CANCELLED") {
          await this.sm.transition(c, {
            bookingId: booking.id,
            from: "CANCELLED",
            to: "REFUND_PENDING",
            actorUid: input.actorUid,
            actorRole: input.actorRole,
            correlationId: input.correlationId,
            eventName: "refund.requested",
          });
        }
      } else if (isPartial) {
        // Money-only partial: stay on current booking status; refund row tracks PSP/ledger.
        // No REFUND_PENDING terminalization of the stay.
      }

      const refundId = newId();
      await c.query(
        `INSERT INTO refunds (id, payment_id, booking_id, amount, reason, kind, status, attempt_count, actor_uid, idempotency_key)
         VALUES ($1,$2,$3,$4,$5,$6,'pending',0,$7,$8)`,
        [
          refundId,
          pay.rows[0].id,
          booking.id,
          amount,
          input.reason,
          input.kind,
          input.actorUid,
          input.idempotencyKey ?? null,
        ],
      );
      await this.outbox.enqueue(
        "refund.requested",
        { refundId, bookingId: booking.id, paymentId: pay.rows[0].id },
        c,
      );
      return { refundId, amount, status: "pending" };
    });
  }

  async reapStale(staleSeconds = REFUND_STALE_SECONDS): Promise<number> {
    const r = await this.pg.query(
      `UPDATE refunds
       SET status = 'pending', locked_at = NULL, locked_by = NULL,
           next_attempt_at = NULL
       WHERE status = 'processing'
         AND locked_at < now() - ($1 || ' seconds')::interval`,
      [String(staleSeconds)],
    );
    return r.rowCount ?? 0;
  }

  /** Claim up to N pending refunds (SKIP LOCKED). */
  async claimBatch(
    limit = 20,
    workerId = this.workerId,
  ): Promise<ClaimedRefund[]> {
    await this.reapStale();
    return this.pg.tx(async (c) => {
      const rows = await c.query<{
        id: string;
        amount: string;
        psp_intent_id: string;
      }>(
        `SELECT r.id, r.amount::text, p.psp_intent_id
         FROM refunds r
         JOIN payments p ON p.id = r.payment_id
         WHERE r.status = 'pending'
           AND (r.next_attempt_at IS NULL OR r.next_attempt_at <= now())
         ORDER BY r.created_at ASC
         FOR UPDATE OF r SKIP LOCKED
         LIMIT $1`,
        [limit],
      );
      const claimed: ClaimedRefund[] = [];
      for (const row of rows.rows) {
        await c.query(
          `UPDATE refunds
           SET status = 'processing', locked_at = now(), locked_by = $2,
               attempt_count = attempt_count + 1, last_error = NULL
           WHERE id = $1`,
          [row.id, workerId],
        );
        claimed.push({ ...row, locked_by: workerId });
      }
      return claimed;
    });
  }

  async claimOne(
    refundId: string,
    workerId = this.workerId,
  ): Promise<ClaimedRefund | null> {
    await this.reapStale();
    return this.pg.tx(async (c) => {
      const row = await c.query<{
        id: string;
        amount: string;
        psp_intent_id: string;
        status: string;
      }>(
        `SELECT r.id, r.amount::text, p.psp_intent_id, r.status
         FROM refunds r JOIN payments p ON p.id = r.payment_id
         WHERE r.id = $1 FOR UPDATE OF r`,
        [refundId],
      );
      if (!row.rowCount) {
        return null;
      }
      if (row.rows[0].status === "completed") {
        return null;
      }
      if (row.rows[0].status === "processing") {
        return null;
      }
      if (row.rows[0].status !== "pending") {
        return null;
      }
      await c.query(
        `UPDATE refunds
         SET status = 'processing', locked_at = now(), locked_by = $2,
             attempt_count = attempt_count + 1, last_error = NULL
         WHERE id = $1`,
        [refundId, workerId],
      );
      return {
        id: row.rows[0].id,
        amount: row.rows[0].amount,
        psp_intent_id: row.rows[0].psp_intent_id,
        locked_by: workerId,
      };
    });
  }

  async processClaimed(
    claimed: ClaimedRefund,
    correlationId: string,
  ): Promise<void> {
    try {
      // F-REV4-05: if PSP already succeeded before finalize crashed, skip re-call.
      const priorPsp = await this.pg.query<{
        psp_refund_id: string | null;
        status: string;
      }>(`SELECT psp_refund_id, status FROM refunds WHERE id = $1`, [
        claimed.id,
      ]);
      if (priorPsp.rows[0]?.status === "completed") {
        return;
      }
      let pspRefundId = priorPsp.rows[0]?.psp_refund_id ?? null;
      if (!pspRefundId) {
        const pspRefund = await this.psp.refund({
          pspIntentId: claimed.psp_intent_id,
          amount: claimed.amount,
          operationId: claimed.id,
        });
        pspRefundId = pspRefund.pspRefundId;
        // Persist PSP id before finalize so reclaim cannot double-hit PSP.
        await this.pg.query(
          `UPDATE refunds SET psp_refund_id = $2
           WHERE id = $1 AND psp_refund_id IS NULL`,
          [claimed.id, pspRefundId],
        );
      }
      await this.finalizeRefund(claimed.id, pspRefundId, correlationId);
    } catch (err) {
      const msg = String(err).slice(0, 500);
      this.logger.warn({ refundId: claimed.id, err: msg });
      const attempts = await this.pg.query<{ attempt_count: number }>(
        `SELECT attempt_count FROM refunds WHERE id = $1`,
        [claimed.id],
      );
      const n = attempts.rows[0]?.attempt_count ?? 1;
      if (n >= 5) {
        await this.pg.query(
          `UPDATE refunds SET status = 'failed', last_error = $2, locked_at = NULL, locked_by = NULL
           WHERE id = $1 AND status = 'processing'`,
          [claimed.id, msg],
        );
      } else {
        await this.pg.query(
          `UPDATE refunds
           SET status = 'pending', last_error = $2, locked_at = NULL, locked_by = NULL,
               next_attempt_at = now() + interval '5 seconds'
           WHERE id = $1 AND status = 'processing'`,
          [claimed.id, msg],
        );
      }
    }
  }

  async dispatchRefund(refundId: string, correlationId: string): Promise<void> {
    const existing = await this.pg.query<{ status: string }>(
      `SELECT status FROM refunds WHERE id = $1`,
      [refundId],
    );
    if (existing.rows[0]?.status === "completed") {
      return;
    }
    const claimed = await this.claimOne(refundId);
    if (!claimed) {
      return;
    }
    await this.processClaimed(claimed, correlationId);
  }

  async finalizeRefund(
    refundId: string,
    pspRefundId: string,
    correlationId: string,
  ): Promise<void> {
    await this.pg.tx(async (c) => {
      const r = await c.query<{
        id: string;
        status: string;
        amount: string;
        booking_id: string;
        payment_id: string;
        provider_id: string;
        gross_total: string;
        commission_amount: string;
        provider_net: string;
        booking_status: string;
      }>(
        `SELECT r.id, r.status, r.amount::text, r.booking_id, r.payment_id,
                b.provider_id, b.gross_total::text, b.commission_amount::text, b.provider_net::text,
                b.status AS booking_status
         FROM refunds r
         JOIN bookings b ON b.id = r.booking_id
         WHERE r.id = $1 FOR UPDATE OF r, b`,
        [refundId],
      );
      if (!r.rowCount) {
        return;
      }
      if (r.rows[0].status === "completed") {
        return;
      }
      if (r.rows[0].status !== "processing" && r.rows[0].status !== "pending") {
        return;
      }
      const refund = r.rows[0];
      const upd = await c.query(
        `UPDATE refunds
         SET status = 'completed', psp_refund_id = $2, locked_at = NULL, locked_by = NULL
         WHERE id = $1 AND status IN ('processing','pending')`,
        [refundId, pspRefundId],
      );
      if (!upd.rowCount) {
        return;
      }
      const refundAmtDec = money(refund.amount);
      const gross = money(refund.gross_total);
      const commBack = proportionalShare(
        refundAmtDec,
        gross,
        money(refund.commission_amount),
      );
      let recBack = proportionalShare(
        refundAmtDec,
        gross,
        money(refund.provider_net),
      );
      // F-REV4-06: Customer (refund debit) + Commission + Provider MUST sum to refundAmt.
      const sum = commBack.add(recBack);
      if (!sum.eq(refundAmtDec)) {
        recBack = refundAmtDec.sub(commBack);
      }
      const refundAmt = refundAmtDec;
      if (!commBack.add(recBack).eq(refundAmt)) {
        throw new AppError(
          ErrorCodes.INTERNAL,
          "Ledger/PSP refund amount mismatch",
          undefined,
          true,
        );
      }
      // Three-way invariant: customer debit == commission credit + provider credit.
      if (!money(refundAmt.toString()).eq(commBack.add(recBack))) {
        throw new AppError(
          ErrorCodes.INTERNAL,
          "Customer+Commission+Provider refund legs must sum exactly",
          undefined,
          true,
        );
      }
      await this.ledger.postGroup(
        c,
        {
          bookingId: refund.booking_id,
          paymentId: refund.payment_id,
          providerId: refund.provider_id,
          createdBy: "system",
          correlationId,
          reference: `refund:${refundId}`,
        },
        [
          {
            type: "refund",
            direction: "debit",
            amount: refundAmt.toString(),
            idempotencyKey: `ledger:${refundId}:refund`,
          },
          {
            type: "reversal",
            direction: "credit",
            amount: commBack.toString(),
            idempotencyKey: `ledger:${refundId}:comm_rev`,
          },
          {
            type: "reversal",
            direction: "credit",
            amount: recBack.toString(),
            idempotencyKey: `ledger:${refundId}:recv_rev`,
          },
        ],
      );
      await c.query(
        `UPDATE provider_receivables
         SET amount = GREATEST(amount - $2::numeric, 0),
             status = CASE
               WHEN amount - $2::numeric <= 0 THEN 'adjusted'
               WHEN status IN ('pending', 'eligible', 'held') THEN status
               ELSE status
             END,
             updated_at = now()
         WHERE booking_id = $1`,
        [refund.booking_id, recBack.toString()],
      );
      if (refund.booking_status === "REFUND_PENDING") {
        await this.sm.transition(c, {
          bookingId: refund.booking_id,
          from: "REFUND_PENDING",
          to: "REFUNDED",
          actorUid: "system",
          actorRole: "webhook",
          correlationId,
          eventName: "refund.completed",
        });
      }
      await this.outbox.enqueue(
        "refund.completed",
        { refundId, bookingId: refund.booking_id },
        c,
      );
    });
  }

  async dispatchPending(limit = 20): Promise<number> {
    const claimed = await this.claimBatch(limit);
    for (const row of claimed) {
      await this.processClaimed(row, `refund-worker:${row.id}`);
    }
    return claimed.length;
  }

  private computeAmount(
    booking: {
      check_in: string;
      gross_total: string;
      timezone: string;
      cancellation_policy_snapshot_json: {
        free_until_hours_before_checkin: number;
        fee_bps_after: number;
      };
    },
    kind: string,
    explicit: string | undefined,
    remaining: ReturnType<typeof money>,
    anchorTime: string | null,
  ): string {
    if (kind === "partial" && explicit) {
      return money(explicit).toString();
    }
    if (kind === "partial" && !explicit) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Partial refund requires amount",
      );
    }
    if (
      kind === "provider_cancel" ||
      kind === "operational" ||
      kind === "full"
    ) {
      // Remaining balance (after prior partials) — last-hala exact.
      return remaining.toString();
    }
    const policy = booking.cancellation_policy_snapshot_json;
    const hours = hoursUntilCheckIn({
      checkInDate: booking.check_in,
      timeZone: booking.timezone,
      checkInTime: anchorTime,
    });
    if (hours >= (policy.free_until_hours_before_checkin ?? 48)) {
      return remaining.toString();
    }
    const fee = money(booking.gross_total).ofBps(policy.fee_bps_after ?? 5000);
    const policyAmt = money(booking.gross_total).sub(fee);
    // Cap to remaining so prior partials do not overshoot.
    return (policyAmt.gt(remaining) ? remaining : policyAmt).toString();
  }
}
