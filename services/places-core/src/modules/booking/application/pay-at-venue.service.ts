import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { CapacityService } from '../../inventory/application/capacity.service';
import { VenueTypeCapabilityPolicy } from '../../filters/application/venue-type-capability.policy';
import { stayDates } from '../../../shared/time/stay-dates';
import { BookingStateMachine } from '../domain/booking-state.machine';
import { BookingLockOrder } from './booking-lock-order';

export type PayAtVenueConfirmResult = {
  bookingId: string;
  humanCode: string;
  status: 'CONFIRMED';
  paymentMethod: 'PAY_AT_VENUE';
  paymentStatus: 'DUE_AT_VENUE';
  grossTotal: string;
  currency: string;
  dueAtVenueAmount: string;
  checkIn: string;
  checkOut: string;
  slotCode: string | null;
  confirmedAt: string;
};

@Injectable()
export class PayAtVenueService {
  constructor(
    private readonly pg: PgService,
    private readonly sm: BookingStateMachine,
    private readonly capacity: CapacityService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  async confirm(input: {
    uid: string;
    holdId: string;
    correlationId: string;
  }): Promise<PayAtVenueConfirmResult> {
    return this.pg.tx(async (c) => this.confirmInTx(c, input));
  }

  async confirmInTx(
    c: PoolClient,
    input: { uid: string; holdId: string; correlationId: string },
  ): Promise<PayAtVenueConfirmResult> {
    // Non-locking ID lookup
    const lookup = await c.query<{
      hold_id: string;
      booking_id: string;
      venue_id: string;
      provider_id: string;
      inventory_type_id: string;
      booking_mode: 'nightly' | 'daily' | 'event_slot';
      slot_code: string | null;
      check_in: string;
      check_out: string;
      quantity: number;
      consumer_firebase_uid: string;
      hold_status: string;
      expires_at: Date;
      booking_status: string;
      payment_method: string | null;
      payment_status: string | null;
      gross_total: string;
      currency: string;
      human_code: string;
      confirmed_at: Date | null;
    }>(
      `SELECT h.id AS hold_id, b.id AS booking_id, b.venue_id, b.provider_id,
              b.inventory_type_id, v.booking_mode, b.slot_code,
              b.check_in::text, b.check_out::text, b.quantity,
              b.consumer_firebase_uid, h.status AS hold_status, h.expires_at,
              b.status AS booking_status, b.payment_method, b.payment_status,
              b.gross_total::text, b.currency, b.human_code, b.confirmed_at
       FROM booking_holds h
       JOIN bookings b ON b.hold_id = h.id
       JOIN venues v ON v.id = b.venue_id
       WHERE h.id = $1`,
      [input.holdId],
    );
    if (!lookup.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Hold not found');
    }
    const row = lookup.rows[0];
    if (row.consumer_firebase_uid !== input.uid) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Hold not found');
    }

    if (
      row.booking_status === 'CONFIRMED' &&
      row.payment_method === 'PAY_AT_VENUE' &&
      row.payment_status === 'DUE_AT_VENUE'
    ) {
      throw new AppError(
        ErrorCodes.BOOKING_ALREADY_CONFIRMED,
        'Booking already confirmed',
      );
    }

    // Lock order
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
    await BookingLockOrder.lockHold(c, row.hold_id);
    await BookingLockOrder.lockBooking(c, row.booking_id);

    // Re-read under locks
    const held = await c.query<{
      status: string;
      expires_at: Date;
      consumer_firebase_uid: string;
    }>(
      `SELECT status, expires_at, consumer_firebase_uid FROM booking_holds WHERE id = $1`,
      [row.hold_id],
    );
    const booking = await c.query<{
      status: string;
      payment_method: string | null;
      payment_status: string | null;
      gross_total: string;
      currency: string;
      human_code: string;
      slot_code: string | null;
      check_in: string;
      check_out: string;
      inventory_type_id: string;
      quantity: number;
      provider_id: string;
      confirmed_at: Date | null;
    }>(
      `SELECT status, payment_method, payment_status, gross_total::text, currency,
              human_code, slot_code, check_in::text, check_out::text,
              inventory_type_id, quantity, provider_id, confirmed_at
       FROM bookings WHERE id = $1`,
      [row.booking_id],
    );
    const h = held.rows[0];
    const b = booking.rows[0];
    if (h.consumer_firebase_uid !== input.uid) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Hold not found');
    }

    // In-TX capability recheck (runtime env — not frozen module snapshot)
    const enabled = process.env.PLACES_PAY_AT_VENUE_ENABLED === 'true';
    const allowlist = (process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    if (!enabled) {
      throw new AppError(
        ErrorCodes.PAY_AT_VENUE_DISABLED,
        'Pay-at-Venue disabled',
      );
    }
    if (allowlist.length > 0 && !allowlist.includes(b.provider_id)) {
      throw new AppError(
        ErrorCodes.PAY_AT_VENUE_DISABLED,
        'Provider not allowlisted for Pay-at-Venue',
      );
    }
    this.caps.requireEventSlotPathAllowed(row.booking_mode);

    if (h.status !== 'ACTIVE' || new Date(h.expires_at) <= new Date()) {
      throw new AppError(ErrorCodes.HOLD_NOT_ACTIVE, 'Hold not active');
    }
    if (b.status === 'CONFIRMED' && b.payment_method === 'PAY_AT_VENUE') {
      throw new AppError(
        ErrorCodes.BOOKING_ALREADY_CONFIRMED,
        'Booking already confirmed',
      );
    }
    if (b.status !== 'HOLDING') {
      throw new AppError(ErrorCodes.HOLD_NOT_ACTIVE, 'Booking not HOLDING');
    }

    if (row.booking_mode === 'event_slot') {
      await this.convertSlotHeldToBooked(
        c,
        row.venue_id,
        row.check_in,
        b.slot_code,
        row.hold_id,
        row.booking_id,
      );
    } else {
      const dates = stayDates(row.booking_mode, b.check_in, b.check_out);
      await this.capacity.convertHoldToBooked(
        b.inventory_type_id,
        dates,
        b.quantity,
        c,
      );
      await this.capacity.convertPhysicalOccupancyToBooked(
        row.hold_id,
        row.booking_id,
        c,
      );
    }

    await this.sm.transitionPayAtVenueConfirm(c, {
      bookingId: row.booking_id,
      actorUid: input.uid,
      actorRole: 'consumer',
      correlationId: input.correlationId,
    });

    await c.query(
      `UPDATE booking_holds SET status = 'CONVERTED' WHERE id = $1 AND status = 'ACTIVE'`,
      [row.hold_id],
    );

    const after = await c.query<{ confirmed_at: Date }>(
      `SELECT confirmed_at FROM bookings WHERE id = $1`,
      [row.booking_id],
    );

    return {
      bookingId: row.booking_id,
      humanCode: b.human_code,
      status: 'CONFIRMED',
      paymentMethod: 'PAY_AT_VENUE',
      paymentStatus: 'DUE_AT_VENUE',
      grossTotal: b.gross_total,
      currency: b.currency,
      dueAtVenueAmount: b.gross_total,
      checkIn: b.check_in,
      checkOut: b.check_out,
      slotCode: b.slot_code,
      confirmedAt: new Date(after.rows[0].confirmed_at).toISOString(),
    };
  }

  private async convertSlotHeldToBooked(
    c: PoolClient,
    venueId: string,
    slotDate: string,
    slotCode: string | null,
    holdId: string,
    bookingId: string,
  ): Promise<void> {
    if (!slotCode) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'slotCode required');
    }
    const rows = await BookingLockOrder.lockSlotInventoryForVenueDate(
      c,
      venueId,
      slotDate,
    );
    const target = rows.find((r) => r.code === slotCode);
    if (!target) {
      throw new AppError(
        ErrorCodes.SLOT_OR_CAPACITY_CONFLICT,
        'Slot inventory missing',
      );
    }
    if (target.status !== 'held' || target.hold_id !== holdId) {
      throw new AppError(
        ErrorCodes.SLOT_OR_CAPACITY_CONFLICT,
        'Slot not held by this hold',
      );
    }
    const cas = await c.query(
      `UPDATE event_slot_inventory
       SET status = 'booked', booking_id = $2, hold_id = NULL
       WHERE id = $1 AND status = 'held' AND hold_id = $3 AND booking_id IS NULL`,
      [target.id, bookingId, holdId],
    );
    if (cas.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.SLOT_OR_CAPACITY_CONFLICT,
        'Slot confirm CAS failed',
      );
    }
  }
}
