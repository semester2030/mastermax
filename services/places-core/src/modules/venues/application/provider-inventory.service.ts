import { Injectable } from '@nestjs/common';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { newId } from '../../../shared/ids/ids';
import { riyadhTodayIso } from '../../../shared/time/stay-dates';
import { AuthUser } from '../../../shared/auth/auth-user';
import { AuditService } from '../../audit/application/audit.service';
import { CapacityService } from '../../inventory/application/capacity.service';
import { TenancyService } from '../../providers/application/tenancy.service';
import { BookingLockOrder } from '../../booking/application/booking-lock-order';

export class CreateInventoryTypeDto {
  @IsUUID()
  providerId!: string;

  @IsUUID()
  venueId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  code!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  labelAr!: string;

  @IsIn(['pooled', 'physical'])
  inventoryModel!: 'pooled' | 'physical';

  @IsInt()
  @Min(0)
  @Max(10000)
  quantityTotal!: number;

  @IsInt()
  @Min(1)
  @Max(100)
  baseOccupancy!: number;

  @IsInt()
  @Min(1)
  @Max(100)
  maxOccupancy!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  sortOrder?: number;
}

export class CreateInventoryUnitDto {
  @IsUUID()
  providerId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(80)
  labelAr!: string;
}

export type InventoryUnitDto = {
  id: string;
  inventoryTypeId: string;
  label: string;
  status: string;
};

export class PatchInventoryTypeDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  labelAr?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  baseOccupancy?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  maxOccupancy?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  quantityTotal?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  sortOrder?: number;

  @IsOptional()
  @IsIn(['active', 'inactive'])
  status?: 'active' | 'inactive';
}

export type InventoryTypeDto = {
  id: string;
  venueId: string;
  code: string;
  labelAr: string;
  inventoryModel: 'pooled' | 'physical';
  quantityTotal: number;
  baseOccupancy: number;
  maxOccupancy: number;
  extraGuestAmount: string;
  sortOrder: number;
  status: string;
  createdAt: string;
};

function mapRow(r: {
  id: string;
  venue_id: string;
  name: string;
  label_ar: string;
  inventory_model: 'pooled' | 'physical';
  quantity_total: number;
  base_occupancy: number;
  max_occupancy: number;
  extra_guest_amount: string;
  sort_order: number;
  status: string;
  created_at: Date;
}): InventoryTypeDto {
  return {
    id: r.id,
    venueId: r.venue_id,
    code: r.name,
    labelAr: r.label_ar,
    inventoryModel: r.inventory_model,
    quantityTotal: Number(r.quantity_total),
    baseOccupancy: Number(r.base_occupancy),
    maxOccupancy: Number(r.max_occupancy),
    extraGuestAmount: r.extra_guest_amount,
    sortOrder: Number(r.sort_order),
    status: r.status,
    createdAt: new Date(r.created_at).toISOString(),
  };
}

const RETURNING = `id, venue_id, name, label_ar, inventory_model, quantity_total, base_occupancy,
                   max_occupancy, extra_guest_amount::text, sort_order, status, created_at`;

@Injectable()
export class ProviderInventoryService {
  constructor(
    private readonly pg: PgService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
    private readonly capacity: CapacityService,
  ) {}

  async create(
    user: AuthUser,
    body: CreateInventoryTypeDto,
    correlationId: string,
  ): Promise<InventoryTypeDto> {
    if (body.maxOccupancy < body.baseOccupancy) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'maxOccupancy < baseOccupancy');
    }
    const quantityTotal =
      body.inventoryModel === 'physical' ? 0 : body.quantityTotal;
    const m = await this.tenancy.require(user, body.providerId, 'venue.crud');
    const venue = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM venues WHERE id = $1`,
      [body.venueId],
    );
    if (!venue.rowCount || venue.rows[0].provider_id !== body.providerId) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Venue not found');
    }
    const id = newId();
    try {
      return await this.pg.tx(async (c) => {
        const ins = await c.query<{
          id: string;
          venue_id: string;
          name: string;
          label_ar: string;
          inventory_model: 'pooled' | 'physical';
          quantity_total: number;
          base_occupancy: number;
          max_occupancy: number;
          extra_guest_amount: string;
          sort_order: number;
          status: string;
          created_at: Date;
        }>(
          `INSERT INTO inventory_types
             (id, venue_id, name, label_ar, inventory_model, quantity_total,
              base_occupancy, max_occupancy, sort_order)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
           RETURNING ${RETURNING}`,
          [
            id,
            body.venueId,
            body.code,
            body.labelAr,
            body.inventoryModel,
            quantityTotal,
            body.baseOccupancy,
            body.maxOccupancy,
            body.sortOrder ?? 0,
          ],
        );
        const dto = mapRow(ins.rows[0]);
        await this.audit.write(
          {
            actorUid: user.uid,
            actorRole: m.actorRole,
            entityType: 'inventory_type',
            entityId: id,
            after: { ...dto, onBehalfOfProviderId: m.onBehalfOfProviderId },
            correlationId,
          },
          c,
        );
        return dto;
      });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (/unique|duplicate/i.test(msg)) {
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, 'Duplicate inventory code');
      }
      throw e;
    }
  }

  async list(
    user: AuthUser,
    providerId: string,
    venueId: string,
  ): Promise<{ items: InventoryTypeDto[]; nextCursor: null }> {
    await this.tenancy.require(user, providerId, 'venue.crud');
    const venue = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM venues WHERE id = $1`,
      [venueId],
    );
    if (!venue.rowCount || venue.rows[0].provider_id !== providerId) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Venue not found');
    }
    const rows = await this.pg.query<{
      id: string;
      venue_id: string;
      name: string;
      label_ar: string;
      inventory_model: 'pooled' | 'physical';
      quantity_total: number;
      base_occupancy: number;
      max_occupancy: number;
      extra_guest_amount: string;
      sort_order: number;
      status: string;
      created_at: Date;
    }>(
      `SELECT ${RETURNING}
       FROM inventory_types WHERE venue_id = $1
       ORDER BY sort_order ASC, name ASC`,
      [venueId],
    );
    return { items: rows.rows.map(mapRow), nextCursor: null };
  }

  async patch(
    user: AuthUser,
    id: string,
    body: PatchInventoryTypeDto,
    correlationId: string,
  ): Promise<InventoryTypeDto> {
    const existing = await this.pg.query<{
      id: string;
      venue_id: string;
      provider_id: string;
      name: string;
      label_ar: string;
      inventory_model: 'pooled' | 'physical';
      quantity_total: number;
      base_occupancy: number;
      max_occupancy: number;
      extra_guest_amount: string;
      sort_order: number;
      status: string;
      created_at: Date;
    }>(
      `SELECT t.id, t.venue_id, v.provider_id, t.name, t.label_ar, t.inventory_model, t.quantity_total,
              t.base_occupancy, t.max_occupancy, t.extra_guest_amount::text, t.sort_order, t.status, t.created_at
       FROM inventory_types t
       JOIN venues v ON v.id = t.venue_id
       WHERE t.id = $1`,
      [id],
    );
    if (!existing.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Inventory type not found');
    }
    const row = existing.rows[0];
    const m = await this.tenancy.require(user, row.provider_id, 'venue.crud');
    const base = body.baseOccupancy ?? Number(row.base_occupancy);
    const max = body.maxOccupancy ?? Number(row.max_occupancy);
    if (max < base) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'maxOccupancy < baseOccupancy');
    }
    return this.pg.tx(async (c) => {
      // Unified lock (F-V2-008): FOR UPDATE on the inventory_types row before
      // reading quantity_total and reconciling daily rows. Serializes against
      // CapacityService.ensureRows so a concurrent hold cannot seed daily rows
      // from a stale quantity_total during a decrease.
      const locked = await BookingLockOrder.lockInventoryType(c, id);
      const prevQty = locked.quantity_total;
      const nextQty =
        body.quantityTotal != null ? Number(body.quantityTotal) : prevQty;
      const upd = await c.query<{
        id: string;
        venue_id: string;
        name: string;
        label_ar: string;
        inventory_model: 'pooled' | 'physical';
        quantity_total: number;
        base_occupancy: number;
        max_occupancy: number;
        extra_guest_amount: string;
        sort_order: number;
        status: string;
        created_at: Date;
      }>(
        `UPDATE inventory_types SET
           label_ar = COALESCE($2, label_ar),
           base_occupancy = $3,
           max_occupancy = $4,
           quantity_total = COALESCE($5, quantity_total),
           sort_order = COALESCE($6, sort_order),
           status = COALESCE($7, status)
         WHERE id = $1
         RETURNING ${RETURNING}`,
        [
          id,
          body.labelAr ?? null,
          base,
          max,
          body.quantityTotal ?? null,
          body.sortOrder ?? null,
          body.status ?? null,
        ],
      );
      if (body.quantityTotal != null && nextQty !== prevQty) {
        await this.capacity.reconcileQuantityTotal(
          id,
          nextQty,
          c,
          riyadhTodayIso(),
        );
      }
      const dto = mapRow(upd.rows[0]);
      await this.audit.write(
        {
          actorUid: user.uid,
          actorRole: m.actorRole,
          entityType: 'inventory_type',
          entityId: id,
          before: mapRow(row),
          after: {
            ...dto,
            onBehalfOfProviderId: m.onBehalfOfProviderId,
            quantityReconciledFrom: prevQty,
            quantityReconciledTo: nextQty,
          },
          correlationId,
        },
        c,
      );
      return dto;
    });
  }

  async listUnits(
    user: AuthUser,
    providerId: string,
    inventoryTypeId: string,
  ): Promise<{ items: InventoryUnitDto[] }> {
    await this.tenancy.require(user, providerId, 'venue.crud');
    const type = await this.pg.query<{
      provider_id: string;
      inventory_model: string;
    }>(
      `SELECT v.provider_id, t.inventory_model
       FROM inventory_types t
       JOIN venues v ON v.id = t.venue_id
       WHERE t.id = $1`,
      [inventoryTypeId],
    );
    if (!type.rowCount || type.rows[0].provider_id !== providerId) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Inventory type not found');
    }
    const rows = await this.pg.query<InventoryUnitDto>(
      `SELECT id, inventory_type_id AS "inventoryTypeId", label, status
       FROM inventory_units
       WHERE inventory_type_id = $1
       ORDER BY label ASC, id ASC`,
      [inventoryTypeId],
    );
    return { items: rows.rows };
  }

  async createUnit(
    user: AuthUser,
    inventoryTypeId: string,
    body: CreateInventoryUnitDto,
    correlationId: string,
  ): Promise<InventoryUnitDto> {
    const type = await this.pg.query<{
      provider_id: string;
      inventory_model: string;
    }>(
      `SELECT v.provider_id, t.inventory_model
       FROM inventory_types t
       JOIN venues v ON v.id = t.venue_id
       WHERE t.id = $1`,
      [inventoryTypeId],
    );
    if (!type.rowCount || type.rows[0].provider_id !== body.providerId) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Inventory type not found');
    }
    const m = await this.tenancy.require(user, body.providerId, 'venue.crud');
    if (type.rows[0].inventory_model !== 'physical') {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'Units can only be added to an independent inventory type',
        { reason: 'physical_units_only' },
      );
    }
    const label = body.labelAr.trim();
    if (!label) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'labelAr required');
    }
    const id = newId();
    try {
      return await this.pg.tx(async (c) => {
        await BookingLockOrder.lockInventoryType(c, inventoryTypeId);
        await c.query(
          `INSERT INTO inventory_units (id, inventory_type_id, label, status)
           VALUES ($1,$2,$3,'active')`,
          [id, inventoryTypeId, label],
        );
        const count = await c.query<{ c: string }>(
          `SELECT count(*)::text AS c FROM inventory_units
           WHERE inventory_type_id = $1 AND status = 'active'`,
          [inventoryTypeId],
        );
        const nextQty = Number(count.rows[0].c);
        await c.query(
          `UPDATE inventory_types SET quantity_total = $2 WHERE id = $1`,
          [inventoryTypeId, nextQty],
        );
        await this.capacity.reconcileQuantityTotal(
          inventoryTypeId,
          nextQty,
          c,
          riyadhTodayIso(),
        );
        await this.audit.write(
          {
            actorUid: user.uid,
            actorRole: m.actorRole,
            entityType: 'inventory_unit',
            entityId: id,
            after: { inventoryTypeId, label, quantityTotal: nextQty },
            correlationId,
          },
          c,
        );
        return {
          id,
          inventoryTypeId,
          label,
          status: 'active',
        };
      });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (/unique|duplicate/i.test(msg)) {
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, 'Duplicate unit label');
      }
      throw e;
    }
  }
}
