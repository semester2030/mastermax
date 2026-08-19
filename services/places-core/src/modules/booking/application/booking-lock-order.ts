import { PoolClient } from 'pg';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

/**
 * Unified Gate 9A lock order (mandatory for hold / confirm / expiry / cancel / refund / webhook / slot gen / template update):
 * 1) Non-locking lookup for IDs
 * 2) venue FOR UPDATE
 * 3) event_slot_templates for venue ORDER BY id FOR UPDATE
 * 4) event_slot_inventory for venue(+date) ORDER BY id FOR UPDATE
 * 5) hold FOR UPDATE
 * 6) booking FOR UPDATE
 * 7) payment FOR UPDATE (when applicable; webhook/refund)
 * 8) capacity rows ORDER BY date FOR UPDATE (caller / CapacityService)
 */
export class BookingLockOrder {
  static async lockVenue(client: PoolClient, venueId: string): Promise<void> {
    const r = await client.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [
      venueId,
    ]);
    if (!r.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Venue not found');
    }
  }

  /**
   * Lock a set of venue rows FOR UPDATE in a single, deterministic id order so
   * every competing path (hold create / expiry / cancel / provider status)
   * acquires parent venue locks in the same order before touching hold / quote /
   * capacity rows. This is the canonical step-2 entry point when more than one
   * venue may be involved (e.g. a reused idempotency key that points at a hold on
   * a different venue than the incoming quote). Returns the venue ids actually
   * locked (missing ids are silently skipped; existence is validated by callers).
   */
  static async lockVenues(
    client: PoolClient,
    venueIds: readonly string[],
  ): Promise<string[]> {
    const unique = Array.from(new Set(venueIds.filter((v) => !!v))).sort();
    if (unique.length === 0) {
      return [];
    }
    const r = await client.query<{ id: string }>(
      `SELECT id FROM venues WHERE id = ANY($1::uuid[]) ORDER BY id FOR UPDATE`,
      [unique],
    );
    return r.rows.map((row) => row.id);
  }

  /**
   * Lock the inventory_types row FOR UPDATE and return its current quantity_total.
   * Shared gate between ProviderInventory.patch (quantity_total mutation) and
   * CapacityService.ensureRows (daily-row seeding) so daily capacity can never be
   * seeded from a stale quantity_total while a patch is in flight (F-V2-008).
   */
  static async lockInventoryType(
    client: PoolClient,
    inventoryTypeId: string,
  ): Promise<{ quantity_total: number }> {
    const r = await client.query<{ quantity_total: number }>(
      `SELECT quantity_total FROM inventory_types WHERE id = $1 FOR UPDATE`,
      [inventoryTypeId],
    );
    if (!r.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Inventory type not found');
    }
    return { quantity_total: Number(r.rows[0].quantity_total) };
  }

  static async lockTemplatesForVenue(
    client: PoolClient,
    venueId: string,
  ): Promise<void> {
    await client.query(
      `SELECT id FROM event_slot_templates WHERE venue_id = $1 ORDER BY id FOR UPDATE`,
      [venueId],
    );
  }

  static async lockSlotInventoryForVenueDate(
    client: PoolClient,
    venueId: string,
    slotDate: string,
  ): Promise<
    Array<{
      id: string;
      slot_template_id: string;
      status: string;
      hold_id: string | null;
      booking_id: string | null;
      start_time: string;
      end_time: string;
      code: string;
      template_status: string;
      inventory_type_id: string;
    }>
  > {
    const r = await client.query<{
      id: string;
      slot_template_id: string;
      status: string;
      hold_id: string | null;
      booking_id: string | null;
      start_time: string;
      end_time: string;
      code: string;
      template_status: string;
      inventory_type_id: string;
    }>(
      `SELECT esi.id, esi.slot_template_id, esi.status, esi.hold_id, esi.booking_id,
              est.start_time::text, est.end_time::text, est.code,
              est.status AS template_status, est.inventory_type_id::text AS inventory_type_id
       FROM event_slot_inventory esi
       JOIN event_slot_templates est ON est.id = esi.slot_template_id
       WHERE esi.venue_id = $1 AND esi.slot_date = $2::date
       ORDER BY esi.id
       FOR UPDATE OF esi`,
      [venueId, slotDate],
    );
    return r.rows;
  }

  static timesOverlap(
    startA: string,
    endA: string,
    startB: string,
    endB: string,
  ): boolean {
    // half-open [start, end)
    return startA < endB && startB < endA;
  }

  static async lockHold(client: PoolClient, holdId: string): Promise<void> {
    const r = await client.query(
      `SELECT id FROM booking_holds WHERE id = $1 FOR UPDATE`,
      [holdId],
    );
    if (!r.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Hold not found');
    }
  }

  static async lockBookingByHold(
    client: PoolClient,
    holdId: string,
  ): Promise<string> {
    const r = await client.query<{ id: string }>(
      `SELECT id FROM bookings WHERE hold_id = $1 FOR UPDATE`,
      [holdId],
    );
    if (!r.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }
    return r.rows[0].id;
  }

  static async lockBooking(client: PoolClient, bookingId: string): Promise<void> {
    const r = await client.query(
      `SELECT id FROM bookings WHERE id = $1 FOR UPDATE`,
      [bookingId],
    );
    if (!r.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }
  }
}
