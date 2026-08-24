import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { stayDates, riyadhTodayIso } from '../../../shared/time/stay-dates';
import { hoursUntilCheckIn } from '../../../shared/time/venue-time';
import { CapacityService } from '../../inventory/application/capacity.service';
import { BookingStateMachine } from '../domain/booking-state.machine';
import { BookingLockOrder } from './booking-lock-order';
import { RefundService } from './refund.service';

export type CancelResult = {
  bookingId: string;
  status: string;
  paymentMethod: string | null;
  paymentStatus: string | null;
  refundId?: string;
};

@Injectable()
export class BookingCancelService {
  constructor(
    private readonly pg: PgService,
    private readonly sm: BookingStateMachine,
    private readonly capacity: CapacityService,
    private readonly refunds: RefundService,
  ) {}

  async cancel(input: {
    bookingId: string;
    actorUid: string;
    actorRole: 'consumer' | 'provider' | 'admin';
    reason: string;
    correlationId: string;
    providerId?: string;
    /** When provided (idempotency TX), PAV path runs on this client — no nested BEGIN. */
    client?: PoolClient;
  }): Promise<CancelResult> {
    const peek = await (input.client
      ? input.client.query<{
          status: string;
          payment_method: string | null;
          payment_status: string | null;
          consumer_firebase_uid: string;
          provider_id: string;
        }>(
          `SELECT status, payment_method, payment_status, consumer_firebase_uid, provider_id
           FROM bookings WHERE id = $1`,
          [input.bookingId],
        )
      : this.pg.query<{
          status: string;
          payment_method: string | null;
          payment_status: string | null;
          consumer_firebase_uid: string;
          provider_id: string;
        }>(
          `SELECT status, payment_method, payment_status, consumer_firebase_uid, provider_id
           FROM bookings WHERE id = $1`,
          [input.bookingId],
        ));
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }
    const p = peek.rows[0];
    if (input.actorRole === 'consumer' && p.consumer_firebase_uid !== input.actorUid) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }
    if (
      input.actorRole === 'provider' &&
      input.providerId &&
      p.provider_id !== input.providerId
    ) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }

    // Phase 4: ACTIVE / COMPLETED / NO_SHOW are never cancellable.
    if (
      p.status === 'ACTIVE' ||
      p.status === 'COMPLETED' ||
      p.status === 'NO_SHOW'
    ) {
      throw new AppError(
        ErrorCodes.BOOKING_NOT_CANCELLABLE,
        `Cannot cancel booking in status ${p.status}`,
      );
    }

    const isPav =
      p.payment_method === 'PAY_AT_VENUE' ||
      (p.status === 'HOLDING' && p.payment_method === null);

    if (!isPav) {
      const refunded = await this.refunds.refund({
        bookingId: input.bookingId,
        actorUid: input.actorUid,
        actorRole: input.actorRole,
        kind:
          input.actorRole === 'provider'
            ? 'provider_cancel'
            : input.actorRole === 'admin'
              ? 'operational'
              : 'customer_cancel',
        reason: input.reason,
        correlationId: input.correlationId,
      });
      return {
        bookingId: input.bookingId,
        status: 'CANCELLED',
        paymentMethod: p.payment_method,
        paymentStatus: p.payment_status,
        refundId: refunded.refundId,
      };
    }

    if (input.client) {
      return this.cancelPayAtVenueInTx(input.client, input);
    }
    return this.pg.tx(async (c) => this.cancelPayAtVenueInTx(c, input));
  }

  private async cancelPayAtVenueInTx(
    c: PoolClient,
    input: {
      bookingId: string;
      actorUid: string;
      actorRole: string;
      correlationId: string;
    },
  ): Promise<CancelResult> {
    const lookup = await c.query<{
      id: string;
      status: string;
      payment_method: string | null;
      payment_status: string | null;
      venue_id: string;
      inventory_type_id: string;
      quantity: number;
      check_in: string;
      check_out: string;
      slot_code: string | null;
      booking_mode: 'nightly' | 'daily' | 'event_slot';
      hold_id: string | null;
      timezone: string;
      check_in_time: string | null;
      cancellation_policy_snapshot_json: {
        free_until_hours_before_checkin?: number;
        fee_bps_after?: number;
      } | null;
    }>(
      `SELECT b.id, b.status, b.payment_method, b.payment_status, b.venue_id,
              b.inventory_type_id, b.quantity, b.check_in::text, b.check_out::text,
              b.slot_code, v.booking_mode, b.hold_id,
              v.timezone, v.check_in_time,
              b.cancellation_policy_snapshot_json
       FROM bookings b
       JOIN venues v ON v.id = b.venue_id
       WHERE b.id = $1`,
      [input.bookingId],
    );
    if (!lookup.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }
    const row = lookup.rows[0];

    if (
      row.status === 'CANCELLED' &&
      ((row.payment_method === 'PAY_AT_VENUE' && row.payment_status === 'VOIDED') ||
        (row.payment_method === null && row.payment_status === null))
    ) {
      return {
        bookingId: row.id,
        status: 'CANCELLED',
        paymentMethod: row.payment_method,
        paymentStatus: row.payment_status,
      };
    }

    await BookingLockOrder.lockVenue(c, row.venue_id);
    await BookingLockOrder.lockUnitsForType(c, row.inventory_type_id);
    if (row.booking_mode === 'event_slot') {
      await BookingLockOrder.lockTemplatesForVenue(c, row.venue_id);
      await BookingLockOrder.lockSlotInventoryForVenueDate(
        c,
        row.venue_id,
        row.check_in,
      );
    }
    if (row.hold_id) {
      await BookingLockOrder.lockHold(c, row.hold_id);
    }
    await BookingLockOrder.lockBooking(c, row.id);

    const fresh = await c.query<{
      status: string;
      payment_method: string | null;
      payment_status: string | null;
    }>(
      `SELECT status, payment_method, payment_status FROM bookings WHERE id = $1`,
      [row.id],
    );
    const b = fresh.rows[0];

    if (
      b.status === 'ACTIVE' ||
      b.status === 'COMPLETED' ||
      b.status === 'NO_SHOW'
    ) {
      throw new AppError(
        ErrorCodes.BOOKING_NOT_CANCELLABLE,
        `Cannot cancel booking in status ${b.status}`,
      );
    }

    if (b.status === 'HOLDING') {
      await this.sm.transitionCancelHolding(c, {
        bookingId: row.id,
        actorUid: input.actorUid,
        actorRole: input.actorRole,
        correlationId: input.correlationId,
      });
      await this.release(c, row, 'held');
      if (row.hold_id) {
        await c.query(
          `UPDATE booking_holds SET status = 'RELEASED' WHERE id = $1 AND status = 'ACTIVE'`,
          [row.hold_id],
        );
      }
      return {
        bookingId: row.id,
        status: 'CANCELLED',
        paymentMethod: null,
        paymentStatus: null,
      };
    }

    // Phase 4: PAV cancel only from CONFIRMED + DUE_AT_VENUE (pre-collection).
    // After collection there is no inventable uncollectable fee — refuse.
    if (
      b.status === 'CONFIRMED' &&
      b.payment_method === 'PAY_AT_VENUE' &&
      b.payment_status === 'COLLECTED_AT_VENUE'
    ) {
      throw new AppError(
        ErrorCodes.BOOKING_NOT_CANCELLABLE,
        'Cannot cancel after collection at venue',
      );
    }

    if (
      b.status === 'CONFIRMED' &&
      b.payment_method === 'PAY_AT_VENUE' &&
      b.payment_status === 'DUE_AT_VENUE'
    ) {
      // Free-cancellation window applies to consumer cancels only.
      // After the window: refuse (no invented uncollectable fees).
      // Provider/admin may still void operationally before collection.
      if (input.actorRole === 'consumer') {
        const policy = row.cancellation_policy_snapshot_json ?? {
          free_until_hours_before_checkin: 48,
        };
        const freeHours = policy.free_until_hours_before_checkin ?? 48;
        // Phase 4 RC2: anchor the free window to the venue-local check-in time
        // (venues.timezone + check_in_time). For event_slot use the slot
        // start_time so the window closes relative to the event, not midnight.
        let anchorTime: string | null = row.check_in_time;
        if (row.booking_mode === 'event_slot' && row.slot_code) {
          const tpl = await c.query<{ start_time: string }>(
            `SELECT to_char(start_time, 'HH24:MI') AS start_time
             FROM event_slot_templates
             WHERE venue_id = $1 AND code = $2`,
            [row.venue_id, row.slot_code],
          );
          anchorTime = tpl.rows[0]?.start_time ?? anchorTime;
        }
        const hrs = hoursUntilCheckIn({
          checkInDate: row.check_in,
          timeZone: row.timezone,
          checkInTime: anchorTime,
        });
        if (hrs < freeHours) {
          throw new AppError(
            ErrorCodes.CANCELLATION_WINDOW_CLOSED,
            'Free cancellation window closed; no uncollectable fee will be invented',
            { freeUntilHoursBeforeCheckin: freeHours, hoursUntilCheckIn: hrs },
          );
        }
      }

      await this.sm.transitionCancelPayAtVenue(c, {
        bookingId: row.id,
        from: 'CONFIRMED',
        actorUid: input.actorUid,
        actorRole: input.actorRole,
        correlationId: input.correlationId,
      });
      await this.release(c, row, 'booked');

      // Cancel before collect → no DAR commission receivable must exist.
      const recv = await c.query(
        `SELECT 1 FROM dar_commission_receivables WHERE booking_id = $1`,
        [row.id],
      );
      if (recv.rowCount) {
        throw new AppError(
          ErrorCodes.INTERNAL,
          'Cancel before collect must not leave DAR commission receivable',
          undefined,
          true,
        );
      }

      return {
        bookingId: row.id,
        status: 'CANCELLED',
        paymentMethod: 'PAY_AT_VENUE',
        paymentStatus: 'VOIDED',
      };
    }

    throw new AppError(
      ErrorCodes.BOOKING_NOT_CANCELLABLE,
      'Booking not cancellable via Pay-at-Venue path',
    );
  }

  private async release(
    c: PoolClient,
    row: {
      booking_mode: 'nightly' | 'daily' | 'event_slot';
      inventory_type_id: string;
      quantity: number;
      check_in: string;
      check_out: string;
      venue_id: string;
      id: string;
      hold_id: string | null;
    },
    kind: 'held' | 'booked',
  ): Promise<void> {
    if (row.booking_mode === 'event_slot') {
      await c.query(
        `UPDATE event_slot_inventory
         SET status = 'open', hold_id = NULL, booking_id = NULL
         WHERE venue_id = $1 AND slot_date = $2::date
           AND ((hold_id = $3) OR (booking_id = $4))`,
        [row.venue_id, row.check_in, row.hold_id, row.id],
      );
      return;
    }
    const dates = stayDates(row.booking_mode, row.check_in, row.check_out);
    if (row.hold_id) {
      await this.capacity.releasePhysicalOccupancy(row.hold_id, c);
    }
    if (kind === 'held') {
      await this.capacity.releaseHeld(
        row.inventory_type_id,
        dates,
        row.quantity,
        c,
      );
    } else {
      // Phase 4 / F-V2-006: release FUTURE days only — never current or past.
      const today = riyadhTodayIso();
      const unconsumed = dates.filter((d) => d > today);
      await this.capacity.releaseBooked(
        row.inventory_type_id,
        unconsumed,
        row.quantity,
        c,
      );
    }
  }
}
