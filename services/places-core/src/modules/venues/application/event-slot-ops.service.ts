import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../shared/auth/auth-user';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { newId } from '../../../shared/ids/ids';
import { AuditService } from '../../audit/application/audit.service';
import { TenancyService } from '../../providers/application/tenancy.service';
import { VenueTypeCapabilityPolicy } from '../../filters/application/venue-type-capability.policy';
import { BookingLockOrder } from '../../booking/application/booking-lock-order';

/**
 * Provider event_slot template + inventory management (Phase 7).
 * Booking paths remain gated by PLACES_EVENT_SLOT_ENABLED + DB capabilities
 * (OFF by default until external approval).
 */
@Injectable()
export class EventSlotOpsService {
  constructor(
    private readonly pg: PgService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  private async requireEventVenue(
    actor: string | AuthUser,
    venueId: string,
  ): Promise<{ providerId: string; bookingMode: string }> {
    const v = await this.pg.query<{
      provider_id: string;
      booking_mode: string;
      venue_type: string;
    }>(
      `SELECT provider_id, booking_mode, venue_type FROM venues WHERE id = $1`,
      [venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Venue not found');
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, 'calendar.edit');
    this.caps.requireEventSlotPathAllowed(v.rows[0].booking_mode);
    if (v.rows[0].booking_mode !== 'event_slot') {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'Venue booking_mode must be event_slot',
      );
    }
    return {
      providerId: v.rows[0].provider_id,
      bookingMode: v.rows[0].booking_mode,
    };
  }

  async upsertTemplate(
    actor: string | AuthUser,
    input: {
      venueId: string;
      inventoryTypeId: string;
      code: string;
      labelAr?: string;
      startTime: string;
      endTime: string;
      capacity?: number;
      basePrice: string;
      status?: 'active' | 'inactive';
    },
    correlationId: string,
  ): Promise<{ templateId: string }> {
    await this.requireEventVenue(actor, input.venueId);
    const it = await this.pg.query(
      `SELECT 1 FROM inventory_types WHERE id = $1 AND venue_id = $2`,
      [input.inventoryTypeId, input.venueId],
    );
    if (!it.rowCount) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'inventoryTypeId must belong to venue',
      );
    }
    if (!/^\d{2}:\d{2}(:\d{2})?$/.test(input.startTime) || !/^\d{2}:\d{2}(:\d{2})?$/.test(input.endTime)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'startTime/endTime must be HH:MM');
    }
    // Cross-midnight not supported in Phase 7 TIME model (same slot_date).
    if (input.startTime >= input.endTime) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'startTime must be before endTime (cross-midnight not supported)',
      );
    }

    return this.pg.tx(async (c) => {
      await BookingLockOrder.lockVenue(c, input.venueId);
      const existing = await c.query<{ id: string }>(
        `SELECT id FROM event_slot_templates WHERE venue_id = $1 AND code = $2`,
        [input.venueId, input.code],
      );
      let templateId: string;
      if (existing.rowCount) {
        templateId = existing.rows[0].id;
        await c.query(
          `UPDATE event_slot_templates SET
             label_ar = COALESCE($3, label_ar),
             start_time = $4::time,
             end_time = $5::time,
             capacity = COALESCE($6, capacity),
             base_price = $7::numeric,
             inventory_type_id = $8,
             status = COALESCE($9, status)
           WHERE id = $1 AND venue_id = $2`,
          [
            templateId,
            input.venueId,
            input.labelAr ?? null,
            input.startTime,
            input.endTime,
            input.capacity ?? null,
            input.basePrice,
            input.inventoryTypeId,
            input.status ?? null,
          ],
        );
      } else {
        templateId = newId();
        await c.query(
          `INSERT INTO event_slot_templates
             (id, venue_id, code, label_ar, start_time, end_time, capacity, base_price, inventory_type_id, status)
           VALUES ($1,$2,$3,$4,$5::time,$6::time,$7,$8::numeric,$9,$10)`,
          [
            templateId,
            input.venueId,
            input.code,
            input.labelAr ?? input.code,
            input.startTime,
            input.endTime,
            input.capacity ?? 1,
            input.basePrice,
            input.inventoryTypeId,
            input.status ?? 'active',
          ],
        );
      }
      await this.audit.write(
        {
          actorUid: typeof actor === 'string' ? actor : actor.uid,
          actorRole: 'provider',
          entityType: 'event_slot_template',
          entityId: templateId,
          after: input,
          correlationId,
        },
        c,
      );
      return { templateId };
    });
  }

  /**
   * Generate open inventory rows for [dateFrom, dateTo] inclusive.
   * Idempotent: existing rows are left unchanged.
   */
  async generateInventory(
    actor: string | AuthUser,
    input: {
      venueId: string;
      templateId: string;
      dateFrom: string;
      dateTo: string;
    },
    correlationId: string,
  ): Promise<{ created: number; skipped: number }> {
    await this.requireEventVenue(actor, input.venueId);
    if (input.dateFrom > input.dateTo) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'dateFrom must be <= dateTo');
    }
    return this.pg.tx(async (c) => {
      await BookingLockOrder.lockVenue(c, input.venueId);
      const tpl = await c.query<{ id: string; venue_id: string; status: string }>(
        `SELECT id, venue_id, status FROM event_slot_templates
         WHERE id = $1 AND venue_id = $2 FOR UPDATE`,
        [input.templateId, input.venueId],
      );
      if (!tpl.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, 'Template not found');
      }
      if (tpl.rows[0].status !== 'active') {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Template inactive');
      }
      const dates = await c.query<{ d: string }>(
        `SELECT generate_series($1::date, $2::date, '1 day'::interval)::date::text AS d`,
        [input.dateFrom, input.dateTo],
      );
      let created = 0;
      let skipped = 0;
      for (const { d } of dates.rows) {
        const ins = await c.query(
          `INSERT INTO event_slot_inventory
             (id, venue_id, slot_template_id, slot_date, status)
           VALUES ($1,$2,$3,$4::date,'open')
           ON CONFLICT (slot_template_id, slot_date) DO NOTHING`,
          [newId(), input.venueId, input.templateId, d],
        );
        if (ins.rowCount) created += 1;
        else skipped += 1;
      }
      await this.audit.write(
        {
          actorUid: typeof actor === 'string' ? actor : actor.uid,
          actorRole: 'provider',
          entityType: 'event_slot_inventory',
          entityId: input.templateId,
          after: { ...input, created, skipped },
          correlationId,
        },
        c,
      );
      return { created, skipped };
    });
  }

  /** Atomic open↔blocked (never from held/booked). */
  async setInventoryStatus(
    actor: string | AuthUser,
    input: {
      venueId: string;
      inventoryId: string;
      status: 'open' | 'blocked';
      reason: string;
    },
    correlationId: string,
  ): Promise<{ id: string; status: string }> {
    await this.requireEventVenue(actor, input.venueId);
    return this.pg.tx(async (c) => {
      await BookingLockOrder.lockVenue(c, input.venueId);
      const row = await c.query<{
        id: string;
        status: string;
        hold_id: string | null;
        booking_id: string | null;
      }>(
        `SELECT id, status, hold_id, booking_id FROM event_slot_inventory
         WHERE id = $1 AND venue_id = $2 FOR UPDATE`,
        [input.inventoryId, input.venueId],
      );
      if (!row.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, 'Slot inventory not found');
      }
      const cur = row.rows[0];
      if (cur.status === 'held' || cur.status === 'booked') {
        throw new AppError(
          ErrorCodes.DUPLICATE_REQUEST,
          `Cannot set ${input.status} while status=${cur.status}`,
        );
      }
      if (cur.status === input.status) {
        return { id: cur.id, status: cur.status };
      }
      const upd = await c.query(
        `UPDATE event_slot_inventory SET status = $2
         WHERE id = $1 AND status IN ('open','blocked') AND hold_id IS NULL AND booking_id IS NULL
         RETURNING id, status`,
        [input.inventoryId, input.status],
      );
      if (!upd.rowCount) {
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, 'Slot status race');
      }
      await this.audit.write(
        {
          actorUid: typeof actor === 'string' ? actor : actor.uid,
          actorRole: 'provider',
          entityType: 'event_slot_inventory',
          entityId: input.inventoryId,
          before: { status: cur.status },
          after: { status: input.status },
          reason: input.reason,
          correlationId,
        },
        c,
      );
      return { id: upd.rows[0].id, status: upd.rows[0].status };
    });
  }

  async listInventory(
    actor: string | AuthUser,
    venueId: string,
    dateFrom?: string,
    dateTo?: string,
  ): Promise<unknown[]> {
    await this.requireEventVenue(actor, venueId);
    const r = await this.pg.query(
      `SELECT esi.id, esi.slot_date, esi.status, esi.hold_id, esi.booking_id,
              est.code AS slot_code, est.start_time, est.end_time, est.base_price,
              est.inventory_type_id
       FROM event_slot_inventory esi
       JOIN event_slot_templates est ON est.id = esi.slot_template_id
       WHERE esi.venue_id = $1
         AND ($2::date IS NULL OR esi.slot_date >= $2::date)
         AND ($3::date IS NULL OR esi.slot_date <= $3::date)
       ORDER BY esi.slot_date, est.start_time`,
      [venueId, dateFrom ?? null, dateTo ?? null],
    );
    return r.rows.map((row) => ({
      id: row.id,
      slotDate: row.slot_date,
      status: row.status,
      slotCode: row.slot_code,
      startTime: row.start_time,
      endTime: row.end_time,
      basePrice: row.base_price,
      inventoryTypeId: row.inventory_type_id,
      holdId: row.hold_id,
      bookingId: row.booking_id,
    }));
  }
}
