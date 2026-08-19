import { Inject, Injectable, forwardRef } from "@nestjs/common";
import { createHash } from "crypto";
import { PoolClient } from "pg";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { stayDates } from "../../../shared/time/stay-dates";
import { metrics } from "../../../shared/observability/metrics";
import { OutboxService } from "../../../shared/events/outbox.service";
import { CapacityService } from "../../inventory/application/capacity.service";
import { LedgerService } from "../../ledger/application/ledger.service";
import { BookingStateMachine } from "../../booking/domain/booking-state.machine";
import { RefundService } from "../../booking/application/refund.service";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";
import { BookingLockOrder } from "../../booking/application/booking-lock-order";
import { PAYMENT_PORT, PaymentPort } from "../domain/payment.port";

const TERMINAL_NO_CONFIRM = [
  "failed",
  "succeeded",
  "refunded_after_expiry",
  "refund_required",
] as const;

@Injectable()
export class PaymentService {
  constructor(
    private readonly pg: PgService,
    @Inject(PAYMENT_PORT) private readonly psp: PaymentPort,
    private readonly capacity: CapacityService,
    private readonly ledger: LedgerService,
    private readonly sm: BookingStateMachine,
    private readonly outbox: OutboxService,
    @Inject(forwardRef(() => RefundService))
    private readonly refunds: RefundService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  /**
   * F2: reserve payment row in DB → commit → PSP createIntent outside TX → attach intent.
   * paymentId is the stable idempotency / operation id for REAL PSP adapters.
   * Gate 7A.3: re-check enabled_for_booking at payment boundary (fail-closed).
   * REV3: failed rows are kept; a new pending payment becomes current on retry.
   */
  async createIntent(input: {
    uid: string;
    holdId: string;
    correlationId: string;
  }): Promise<{
    paymentId: string;
    pspClientSecretOrUrl: string;
    amount: string;
  }> {
    const prepared = await this.pg.tx(async (c) => {
      // RC6: peek then venue → templates/slots → hold → booking (unified lock order).
      const peek = await c.query<{
        id: string;
        status: string;
        consumer_firebase_uid: string;
        quote_id: string;
        expires_at: Date;
        venue_id: string;
        booking_mode: "nightly" | "daily" | "event_slot";
        check_in: string;
        booking_id: string | null;
        booking_status: string | null;
        gross_total: string | null;
        venue_type: string;
      }>(
        `SELECT h.id, h.status, h.consumer_firebase_uid, h.quote_id, h.expires_at,
                v.id AS venue_id, v.booking_mode, h.check_in::text AS check_in,
                b.id AS booking_id, b.status AS booking_status, b.gross_total::text AS gross_total,
                v.venue_type
         FROM booking_holds h
         JOIN inventory_types t ON t.id = h.inventory_type_id
         JOIN venues v ON v.id = t.venue_id
         LEFT JOIN bookings b ON b.hold_id = h.id
         WHERE h.id = $1`,
        [input.holdId],
      );
      if (!peek.rowCount || peek.rows[0].consumer_firebase_uid !== input.uid) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Hold not found");
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
      await BookingLockOrder.lockHold(c, input.holdId);
      if (peekRow.booking_id) {
        await BookingLockOrder.lockBooking(c, peekRow.booking_id);
      }

      const hold = await c.query<{
        id: string;
        status: string;
        consumer_firebase_uid: string;
        quote_id: string;
        expires_at: Date;
      }>(
        `SELECT id, status, consumer_firebase_uid, quote_id, expires_at
         FROM booking_holds WHERE id = $1`,
        [input.holdId],
      );
      if (!hold.rowCount || hold.rows[0].consumer_firebase_uid !== input.uid) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Hold not found");
      }
      if (
        hold.rows[0].status !== "ACTIVE" ||
        new Date(hold.rows[0].expires_at) <= new Date()
      ) {
        throw new AppError(ErrorCodes.HOLD_EXPIRED, "Hold is not active");
      }
      const booking = await c.query<{
        id: string;
        status: string;
        gross_total: string;
        venue_id: string;
      }>(
        `SELECT id, status, gross_total::text, venue_id FROM bookings WHERE hold_id = $1`,
        [input.holdId],
      );
      if (!booking.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
      }
      if (
        !["HOLDING", "PENDING_PAYMENT", "PAYMENT_FAILED"].includes(
          booking.rows[0].status,
        )
      ) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Booking not payable");
      }
      await this.caps.requireBookingEnabled(peekRow.venue_type, c);
      this.caps.requireEventSlotPathAllowed(peekRow.booking_mode);
      const existing = await c.query<{
        id: string;
        status: string;
        psp_intent_id: string | null;
        amount: string;
      }>(
        `SELECT id, status, psp_intent_id, amount::text FROM payments WHERE hold_id = $1 ORDER BY created_at DESC`,
        [input.holdId],
      );
      // Keep failed / after-expiry refund rows; only non-superseded payments are "live".
      const SUPERSEDED = new Set([
        "failed",
        "refund_required",
        "refunded_after_expiry",
        "cancelled",
      ]);
      const live = existing.rows.find((p) => !SUPERSEDED.has(p.status));
      if (live) {
        return {
          paymentId: live.id,
          amount: live.amount,
          holdId: input.holdId,
          needsPsp: !live.psp_intent_id,
          readySecret: live.psp_intent_id
            ? `intent://${live.psp_intent_id}`
            : null,
        };
      }
      const paymentId = newId();
      await c.query(
        `INSERT INTO payments (id, booking_id, hold_id, quote_id, status, amount, currency, psp_name, psp_intent_id)
         VALUES ($1,$2,$3,$4,'pending',$5,'SAR',$6,NULL)`,
        [
          paymentId,
          booking.rows[0].id,
          input.holdId,
          hold.rows[0].quote_id,
          booking.rows[0].gross_total,
          this.psp.pspName,
        ],
      );
      if (booking.rows[0].status === "HOLDING") {
        await this.sm.transition(c, {
          bookingId: booking.rows[0].id,
          from: "HOLDING",
          to: "PENDING_PAYMENT",
          actorUid: input.uid,
          actorRole: "consumer",
          correlationId: input.correlationId,
          eventName: "payment.intent_created",
          eventPayload: { paymentId },
        });
      } else if (booking.rows[0].status === "PAYMENT_FAILED") {
        // Retry after failure while hold remains ACTIVE — new payment is current.
        await this.sm.transition(c, {
          bookingId: booking.rows[0].id,
          from: "PAYMENT_FAILED",
          to: "PENDING_PAYMENT",
          actorUid: input.uid,
          actorRole: "consumer",
          correlationId: input.correlationId,
          eventName: "payment.retry",
          eventPayload: { paymentId },
        });
      }
      return {
        paymentId,
        amount: booking.rows[0].gross_total,
        holdId: input.holdId,
        needsPsp: true,
        readySecret: null as string | null,
      };
    });

    if (!prepared.needsPsp && prepared.readySecret) {
      return {
        paymentId: prepared.paymentId,
        pspClientSecretOrUrl: prepared.readySecret,
        amount: prepared.amount,
      };
    }

    const intent = await this.psp.createIntent({
      paymentId: prepared.paymentId,
      operationId: prepared.paymentId,
      amount: prepared.amount,
      currency: "SAR",
      holdId: prepared.holdId,
    });

    await this.pg.tx(async (c) => {
      await c.query(
        `UPDATE payments SET psp_intent_id = $2 WHERE id = $1 AND psp_intent_id IS NULL`,
        [prepared.paymentId, intent.pspIntentId],
      );
      const existingAttempt = await c.query<{ id: string }>(
        `SELECT id FROM payment_attempts WHERE payment_id = $1 AND psp_attempt_id = $2 LIMIT 1`,
        [prepared.paymentId, intent.pspIntentId],
      );
      let attemptId: string;
      if (existingAttempt.rowCount) {
        attemptId = existingAttempt.rows[0].id;
      } else {
        attemptId = newId();
        await c.query(
          `INSERT INTO payment_attempts (id, payment_id, status, psp_attempt_id) VALUES ($1,$2,'created',$3)`,
          [attemptId, prepared.paymentId, intent.pspIntentId],
        );
      }
      await c.query(
        `UPDATE payments SET current_attempt_id = $2 WHERE id = $1`,
        [prepared.paymentId, attemptId],
      );
    });

    return {
      paymentId: prepared.paymentId,
      pspClientSecretOrUrl: intent.clientSecretOrUrl,
      amount: prepared.amount,
    };
  }

  async getForConsumer(
    uid: string,
    paymentId: string,
  ): Promise<{
    id: string;
    status: string;
    bookingId: string;
    amount: string;
    bookingStatus: string | null;
  }> {
    const row = await this.pg.query<{
      id: string;
      status: string;
      booking_id: string;
      amount: string;
      booking_status: string | null;
      consumer_firebase_uid: string;
    }>(
      `SELECT p.id, p.status, p.booking_id, p.amount::text,
              b.status AS booking_status,
              COALESCE(h.consumer_firebase_uid, b.consumer_firebase_uid) AS consumer_firebase_uid
       FROM payments p
       LEFT JOIN booking_holds h ON h.id = p.hold_id
       LEFT JOIN bookings b ON b.id = p.booking_id
       WHERE p.id = $1`,
      [paymentId],
    );
    if (!row.rowCount || row.rows[0].consumer_firebase_uid !== uid) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Payment not found");
    }
    return {
      id: row.rows[0].id,
      status: row.rows[0].status,
      bookingId: row.rows[0].booking_id,
      amount: row.rows[0].amount,
      bookingStatus: row.rows[0].booking_status,
    };
  }

  async handleWebhook(
    rawBody: string,
    signature: string | undefined,
    correlationId: string,
  ): Promise<{ ok: boolean }> {
    if (!this.psp.verifySignature(rawBody, signature)) {
      throw new AppError(
        ErrorCodes.UNAUTHENTICATED,
        "Invalid webhook signature",
      );
    }
    const event = this.psp.parseWebhook(rawBody);
    const hash = createHash("sha256").update(rawBody).digest("hex");

    if (event.type === "refund.completed" && event.refundId) {
      return this.pg
        .tx(async (c) => {
          const ins = await c.query(
            `INSERT INTO webhook_events (id, psp_name, provider_event_id, payload_hash, processed_at, status)
           VALUES ($1,$2,$3,$4,now(),'processed')
           ON CONFLICT (psp_name, provider_event_id) DO NOTHING`,
            [newId(), this.psp.pspName, event.eventId, hash],
          );
          if (!ins.rowCount) {
            return { ok: true };
          }
          return { ok: true };
        })
        .then(async (r) => {
          await this.refunds.finalizeRefund(
            event.refundId!,
            `wh_${event.eventId}`,
            correlationId,
          );
          return r;
        });
    }

    const afterExpiryRefundId = await this.pg.tx(async (c) => {
      const ins = await c.query(
        `INSERT INTO webhook_events (id, psp_name, provider_event_id, payload_hash, processed_at, status)
         VALUES ($1,$2,$3,$4,now(),'processed')
         ON CONFLICT (psp_name, provider_event_id) DO NOTHING`,
        [newId(), this.psp.pspName, event.eventId, hash],
      );
      if (!ins.rowCount) {
        return null as string | null;
      }
      // RC5: peek without locking, then venue → templates/slots → hold → booking → payment.
      const peek = await c.query<{
        id: string;
        booking_id: string;
        hold_id: string;
        amount: string;
        status: string;
        current_attempt_id: string | null;
        psp_intent_id: string | null;
        venue_id: string;
        booking_mode: "nightly" | "daily" | "event_slot";
        check_in: string;
      }>(
        `SELECT p.id, p.booking_id, p.hold_id, p.amount::text, p.status,
                p.current_attempt_id, p.psp_intent_id,
                b.venue_id, v.booking_mode, h.check_in::text AS check_in
         FROM payments p
         JOIN bookings b ON b.id = p.booking_id
         JOIN venues v ON v.id = b.venue_id
         JOIN booking_holds h ON h.id = p.hold_id
         WHERE p.psp_intent_id = $1`,
        [event.pspIntentId],
      );
      if (!peek.rowCount) {
        throw new AppError(
          ErrorCodes.NOT_FOUND,
          "Payment not found for webhook",
        );
      }
      const peekPay = peek.rows[0];

      await BookingLockOrder.lockVenue(c, peekPay.venue_id);
      if (peekPay.booking_mode === "event_slot") {
        await BookingLockOrder.lockTemplatesForVenue(c, peekPay.venue_id);
        await BookingLockOrder.lockSlotInventoryForVenueDate(
          c,
          peekPay.venue_id,
          peekPay.check_in,
        );
      }
      await BookingLockOrder.lockHold(c, peekPay.hold_id);
      await BookingLockOrder.lockBooking(c, peekPay.booking_id);

      const payment = await c.query<{
        id: string;
        booking_id: string;
        hold_id: string;
        amount: string;
        status: string;
        current_attempt_id: string | null;
        psp_intent_id: string | null;
      }>(
        `SELECT id, booking_id, hold_id, amount::text, status, current_attempt_id, psp_intent_id
         FROM payments WHERE id = $1 FOR UPDATE`,
        [peekPay.id],
      );
      if (!payment.rowCount) {
        throw new AppError(
          ErrorCodes.NOT_FOUND,
          "Payment not found for webhook",
        );
      }
      const pay = payment.rows[0];

      // Bind webhook to current attempt identity (fail-closed — F-REV4-07).
      const isCurrentAttempt = await this.isCurrentAttempt(
        c,
        pay,
        event.pspIntentId,
      );

      if (event.type === "payment.failed") {
        if (!isCurrentAttempt || pay.status !== "pending") {
          // Late failed on superseded/old payment must not change booking.
          return null;
        }
        const failUpd = await c.query(
          `UPDATE payments SET status = 'failed' WHERE id = $1 AND status = 'pending'`,
          [pay.id],
        );
        if (failUpd.rowCount !== 1) {
          return null;
        }
        if (pay.current_attempt_id) {
          await c.query(
            `UPDATE payment_attempts SET status = 'failed' WHERE id = $1`,
            [pay.current_attempt_id],
          );
        } else {
          await c.query(
            `UPDATE payment_attempts SET status = 'failed'
             WHERE payment_id = $1 AND psp_attempt_id = $2`,
            [pay.id, event.pspIntentId],
          );
        }
        const b = await c.query<{ status: string }>(
          `SELECT status FROM bookings WHERE id = $1`,
          [pay.booking_id],
        );
        if (b.rows[0].status === "PENDING_PAYMENT") {
          await this.sm.transition(c, {
            bookingId: pay.booking_id,
            from: "PENDING_PAYMENT",
            to: "PAYMENT_FAILED",
            actorUid: "system",
            actorRole: "webhook",
            correlationId,
            eventName: "payment.failed",
            eventPayload: { paymentId: pay.id },
          });
        }
        metrics.inc("payment_failure");
        return null;
      }

      if (event.type !== "payment.succeeded") {
        return null;
      }

      // Terminal / superseded: never confirm booking for this payment.
      if (
        (TERMINAL_NO_CONFIRM as readonly string[]).includes(pay.status) ||
        !isCurrentAttempt
      ) {
        if (pay.status === "succeeded" || pay.status === "refunded_after_expiry") {
          return null;
        }
        if (pay.status === "refund_required") {
          return null;
        }
        // Late success on failed/superseded attempt → refund money, do not confirm.
        return this.enqueueAfterExpiryRefund(c, pay);
      }

      if (pay.status !== "pending") {
        return null;
      }

      // RC5: kill-switch — never confirm event_slot via PSP when OFF.
      if (
        peekPay.booking_mode === "event_slot" &&
        process.env.PLACES_EVENT_SLOT_ENABLED !== "true"
      ) {
        return this.enqueueAfterExpiryRefund(c, pay);
      }

      const hold = await c.query<{
        status: string;
        expires_at: Date;
        inventory_type_id: string;
        quantity: number;
        check_in: string;
        check_out: string;
      }>(
        `SELECT status, expires_at, inventory_type_id, quantity, check_in::text, check_out::text
         FROM booking_holds WHERE id = $1`,
        [pay.hold_id],
      );
      const holdRow = hold.rows[0];
      const holdOk =
        holdRow &&
        holdRow.status === "ACTIVE" &&
        new Date(holdRow.expires_at) > new Date();
      const booking = await c.query<{
        id: string;
        status: string;
        provider_id: string;
        gross_total: string;
        commission_amount: string;
        provider_net: string;
        commission_bps: number;
      }>(
        `SELECT id, status, provider_id, gross_total::text, commission_amount::text, provider_net::text, commission_bps
         FROM bookings WHERE id = $1`,
        [pay.booking_id],
      );
      const confirmable = ["PENDING_PAYMENT"].includes(booking.rows[0].status);
      if (!holdOk || !confirmable) {
        const refundId = await this.enqueueAfterExpiryRefund(c, pay);
        metrics.inc("payment_after_expiry");
        return refundId;
      }

      // Atomic: only the current pending row may become succeeded.
      const succUpd = await c.query(
        `UPDATE payments SET status = 'succeeded' WHERE id = $1 AND status = 'pending'`,
        [pay.id],
      );
      if (succUpd.rowCount !== 1) {
        // Lost race or superseded — do not confirm/convert/ledger.
        return null;
      }
      if (pay.current_attempt_id) {
        await c.query(
          `UPDATE payment_attempts SET status = 'succeeded' WHERE id = $1`,
          [pay.current_attempt_id],
        );
      } else {
        await c.query(
          `UPDATE payment_attempts SET status = 'succeeded'
           WHERE payment_id = $1 AND psp_attempt_id = $2`,
          [pay.id, event.pspIntentId],
        );
      }

      const conv = await c.query(
        `UPDATE booking_holds SET status = 'CONVERTED' WHERE id = $1 AND status = 'ACTIVE'`,
        [pay.hold_id],
      );
      if (conv.rowCount !== 1) {
        throw new AppError(
          ErrorCodes.HOLD_EXPIRED,
          "Hold lost race during confirmation",
        );
      }
      const dates = stayDates(
        peekPay.booking_mode,
        holdRow.check_in,
        holdRow.check_out,
      );
      await this.capacity.convertHoldToBooked(
        holdRow.inventory_type_id,
        dates,
        holdRow.quantity,
        c,
      );
      await this.sm.transitionPspConfirm(c, {
        bookingId: booking.rows[0].id,
        actorUid: "system",
        actorRole: "webhook",
        correlationId,
        paymentId: pay.id,
      });
      const g = booking.rows[0];
      await this.ledger.postGroup(
        c,
        {
          bookingId: g.id,
          paymentId: pay.id,
          providerId: g.provider_id,
          createdBy: "system",
          correlationId,
          reference: `confirm:${g.id}`,
        },
        [
          {
            type: "customer_payment",
            direction: "credit",
            amount: g.gross_total,
            idempotencyKey: `ledger:${pay.id}:customer_payment`,
          },
          {
            type: "dar_commission",
            direction: "debit",
            amount: g.commission_amount,
            idempotencyKey: `ledger:${pay.id}:dar_commission`,
          },
          {
            type: "provider_receivable",
            direction: "debit",
            amount: g.provider_net,
            idempotencyKey: `ledger:${pay.id}:provider_receivable`,
          },
        ],
      );
      const commRow = await c.query<{ id: string }>(
        `SELECT id FROM ledger_entries WHERE idempotency_key = $1`,
        [`ledger:${pay.id}:dar_commission`],
      );
      await c.query(
        `INSERT INTO commissions (id, booking_id, ledger_entry_id, amount, bps) VALUES ($1,$2,$3,$4,$5)`,
        [
          newId(),
          g.id,
          commRow.rows[0].id,
          g.commission_amount,
          g.commission_bps,
        ],
      );
      await c.query(
        `INSERT INTO provider_receivables (id, booking_id, provider_id, amount, status)
         VALUES ($1,$2,$3,$4,'pending')`,
        [newId(), g.id, g.provider_id, g.provider_net],
      );
      metrics.inc("payment_success");
      metrics.inc("booking_confirmation");
      return null;
    });

    if (afterExpiryRefundId) {
      await this.dispatchAfterExpiryRefund(afterExpiryRefundId, correlationId);
    }
    return { ok: true };
  }

  /**
   * Fail-closed (F-REV4-07): missing current_attempt_id / missing attempt row /
   * null psp_attempt_id are NOT treated as current unless status is pending AND
   * payments.psp_intent_id matches the webhook intent.
   */
  private async isCurrentAttempt(
    c: PoolClient,
    pay: {
      id: string;
      status: string;
      current_attempt_id: string | null;
      psp_intent_id: string | null;
    },
    pspIntentId: string,
  ): Promise<boolean> {
    if (pay.psp_intent_id && pay.psp_intent_id !== pspIntentId) {
      return false;
    }
    const pendingMatch =
      pay.status === "pending" &&
      pay.psp_intent_id != null &&
      pay.psp_intent_id === pspIntentId;
    if (!pay.current_attempt_id) {
      return pendingMatch;
    }
    const attempt = await c.query<{ psp_attempt_id: string | null }>(
      `SELECT psp_attempt_id FROM payment_attempts WHERE id = $1`,
      [pay.current_attempt_id],
    );
    if (!attempt.rowCount) {
      return pendingMatch;
    }
    const aid = attempt.rows[0].psp_attempt_id;
    if (!aid) {
      return pendingMatch;
    }
    return aid === pspIntentId;
  }

  private async enqueueAfterExpiryRefund(
    c: PoolClient,
    pay: { id: string; booking_id: string; amount: string; status: string },
  ): Promise<string | null> {
    if (pay.status === "refund_required" || pay.status === "refunded_after_expiry") {
      return null;
    }
    // Mark refund_required only from pending/failed (not succeeded confirm path).
    if (pay.status === "pending" || pay.status === "failed") {
      await c.query(
        `UPDATE payments SET status = 'refund_required' WHERE id = $1 AND status IN ('pending','failed')`,
        [pay.id],
      );
    } else if (pay.status === "succeeded") {
      await c.query(
        `UPDATE payments SET status = 'refund_required' WHERE id = $1 AND status = 'succeeded'`,
        [pay.id],
      );
    }
    const refundId = newId();
    await c.query(
      `INSERT INTO refunds (id, payment_id, booking_id, amount, reason, kind, status)
       VALUES ($1,$2,$3,$4,'payment after hold expiry or non-confirmable booking','after_expiry','pending')`,
      [refundId, pay.id, pay.booking_id, pay.amount],
    );
    await this.outbox.enqueue(
      "refund.requested",
      { refundId, reason: "after_expiry", paymentId: pay.id },
      c,
    );
    return refundId;
  }

  private async dispatchAfterExpiryRefund(
    refundId: string,
    correlationId: string,
  ): Promise<void> {
    const row = await this.pg.query<{
      amount: string;
      psp_intent_id: string;
      payment_id: string;
      status: string;
    }>(
      `SELECT r.amount::text, p.psp_intent_id, r.payment_id, r.status
       FROM refunds r JOIN payments p ON p.id = r.payment_id WHERE r.id = $1`,
      [refundId],
    );
    if (!row.rowCount || row.rows[0].status !== "pending") {
      return;
    }
    const pspRefund = await this.psp.refund({
      pspIntentId: row.rows[0].psp_intent_id,
      amount: row.rows[0].amount,
      operationId: refundId,
    });
    await this.pg.tx(async (c) => {
      await c.query(
        `UPDATE refunds SET status = 'completed', psp_refund_id = $2 WHERE id = $1 AND status = 'pending'`,
        [refundId, pspRefund.pspRefundId],
      );
      await c.query(
        `UPDATE payments SET status = 'refunded_after_expiry' WHERE id = $1 AND status = 'refund_required'`,
        [row.rows[0].payment_id],
      );
      await this.outbox.enqueue(
        "refund.completed",
        { refundId, kind: "after_expiry", correlationId },
        c,
      );
    });
  }
}
