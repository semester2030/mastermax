import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

export type CapabilityGate = 'discovery' | 'booking' | 'provider';

/**
 * Fail-closed venue-type capability checks (Gate 7A.2).
 * Missing row = reject. Never allow on absent capability.
 */
@Injectable()
export class VenueTypeCapabilityPolicy {
  constructor(private readonly pg: PgService) {}

  async requireDiscoveryEnabled(venueType: string): Promise<void> {
    await this.require(venueType, 'discovery');
  }

  async requireBookingEnabled(venueType: string, client?: PoolClient): Promise<void> {
    await this.require(venueType, 'booking', client);
  }

  async requireProviderEnabled(venueType: string): Promise<void> {
    await this.require(venueType, 'provider');
  }

  /**
   * RC4 kill switch: block NEW quote/availability/hold/confirm/provider create
   * when booking_mode is event_slot unless PLACES_EVENT_SLOT_ENABLED=true.
   * Historical GET/cancel remain allowed (callers must not use this gate).
   */
  requireEventSlotPathAllowed(bookingMode: string): void {
    if (bookingMode !== 'event_slot') {
      return;
    }
    // Runtime env (not frozen AppEnv) so tests can toggle without reboot.
    if (process.env.PLACES_EVENT_SLOT_ENABLED !== 'true') {
      throw new AppError(
        ErrorCodes.EVENT_SLOT_DISABLED,
        'Event-slot booking temporarily disabled (palace/hall kill switch)',
      );
    }
  }

  async isDiscoveryEnabled(venueType: string): Promise<boolean> {
    const row = await this.load(venueType);
    return !!row?.enabled_for_discovery;
  }

  private async load(venueType: string, client?: PoolClient): Promise<{
    enabled_for_discovery: boolean;
    enabled_for_booking: boolean;
    enabled_for_provider: boolean;
  } | null> {
    type CapabilityRow = {
      enabled_for_discovery: boolean;
      enabled_for_booking: boolean;
      enabled_for_provider: boolean;
    };
    const sql = `SELECT enabled_for_discovery, enabled_for_booking, enabled_for_provider
       FROM venue_type_capabilities WHERE venue_type = $1`;
    const res = client
      ? await client.query<CapabilityRow>(sql, [venueType])
      : await this.pg.query<CapabilityRow>(sql, [venueType]);
    return res.rowCount ? res.rows[0] : null;
  }

  private async require(venueType: string, gate: CapabilityGate, client?: PoolClient): Promise<void> {
    const row = await this.load(venueType, client);
    if (!row) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Venue type capability missing for ${venueType} (fail-closed)`,
      );
    }
    const ok =
      gate === 'discovery'
        ? row.enabled_for_discovery
        : gate === 'booking'
          ? row.enabled_for_booking
          : row.enabled_for_provider;
    if (!ok) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Venue type ${venueType} not enabled for ${gate}`,
      );
    }
  }
}
