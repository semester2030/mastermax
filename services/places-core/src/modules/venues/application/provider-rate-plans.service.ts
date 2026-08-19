import { Injectable } from "@nestjs/common";
import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from "class-validator";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { AuthUser } from "../../../shared/auth/auth-user";
import { AuditService } from "../../audit/application/audit.service";
import { TenancyService } from "../../providers/application/tenancy.service";

export class CreateRatePlanDto {
  @IsUUID()
  providerId!: string;

  @IsUUID()
  venueId!: string;

  @IsUUID()
  inventoryTypeId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(3)
  @IsIn(['SAR'])
  currency?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}

export class PatchRatePlanDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;

  @IsOptional()
  @IsIn(["active", "inactive"])
  status?: "active" | "inactive";
}

export type RatePlanDto = {
  id: string;
  inventoryTypeId: string;
  venueId: string;
  name: string;
  currency: string;
  isDefault: boolean;
  status: string;
};

@Injectable()
export class ProviderRatePlansService {
  constructor(
    private readonly pg: PgService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
  ) {}

  async create(
    user: AuthUser,
    body: CreateRatePlanDto,
    correlationId: string,
  ): Promise<RatePlanDto> {
    const m = await this.tenancy.require(user, body.providerId, "pricing.edit");
    const inv = await this.pg.query<{ venue_id: string }>(
      `SELECT venue_id FROM inventory_types WHERE id = $1`,
      [body.inventoryTypeId],
    );
    if (!inv.rowCount || inv.rows[0].venue_id !== body.venueId) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Inventory type not found for venue");
    }
    const venue = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM venues WHERE id = $1`,
      [body.venueId],
    );
    if (!venue.rowCount || venue.rows[0].provider_id !== body.providerId) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }

    const id = newId();
    const currency = (body.currency ?? "SAR").toUpperCase();
    if (currency !== "SAR") {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Only SAR currency is supported",
      );
    }
    const isDefault = body.isDefault !== false;

    return this.pg.tx(async (c) => {
      // Serialize default-plan creates per inventory type (F-V3-011 partial).
      await c.query(
        `SELECT id FROM inventory_types WHERE id = $1 FOR UPDATE`,
        [body.inventoryTypeId],
      );
      if (isDefault) {
        await c.query(
          `UPDATE rate_plans SET is_default = FALSE
           WHERE inventory_type_id = $1 AND is_default = TRUE`,
          [body.inventoryTypeId],
        );
      }
      const ins = await c.query<{
        id: string;
        inventory_type_id: string;
        name: string;
        currency: string;
        is_default: boolean;
        status: string;
      }>(
        `INSERT INTO rate_plans (id, inventory_type_id, name, currency, is_default, status)
         VALUES ($1,$2,$3,$4,$5,'active')
         RETURNING id, inventory_type_id, name, currency, is_default, status`,
        [id, body.inventoryTypeId, body.name, currency, isDefault],
      );
      const row = ins.rows[0];
      const dto: RatePlanDto = {
        id: row.id,
        inventoryTypeId: row.inventory_type_id,
        venueId: body.venueId,
        name: row.name,
        currency: row.currency,
        isDefault: row.is_default,
        status: row.status,
      };
      await this.audit.write(
        {
          actorUid: user.uid,
          actorRole: m.actorRole,
          entityType: "rate_plan",
          entityId: id,
          after: { ...dto, onBehalfOfProviderId: m.onBehalfOfProviderId },
          correlationId,
        },
        c,
      );
      return dto;
    });
  }

  async list(
    user: AuthUser,
    providerId: string,
    venueId?: string,
  ): Promise<{ items: RatePlanDto[]; nextCursor: null }> {
    await this.tenancy.require(user, providerId, "pricing.edit");
    const rows = venueId
      ? await this.pg.query<{
          id: string;
          inventory_type_id: string;
          venue_id: string;
          name: string;
          currency: string;
          is_default: boolean;
          status: string;
        }>(
          `SELECT rp.id, rp.inventory_type_id, it.venue_id, rp.name, rp.currency,
                  rp.is_default, rp.status
           FROM rate_plans rp
           JOIN inventory_types it ON it.id = rp.inventory_type_id
           JOIN venues v ON v.id = it.venue_id
           WHERE v.provider_id = $1 AND it.venue_id = $2
           ORDER BY rp.is_default DESC, rp.name ASC`,
          [providerId, venueId],
        )
      : await this.pg.query<{
          id: string;
          inventory_type_id: string;
          venue_id: string;
          name: string;
          currency: string;
          is_default: boolean;
          status: string;
        }>(
          `SELECT rp.id, rp.inventory_type_id, it.venue_id, rp.name, rp.currency,
                  rp.is_default, rp.status
           FROM rate_plans rp
           JOIN inventory_types it ON it.id = rp.inventory_type_id
           JOIN venues v ON v.id = it.venue_id
           WHERE v.provider_id = $1
           ORDER BY it.venue_id, rp.is_default DESC, rp.name ASC`,
          [providerId],
        );

    return {
      items: rows.rows.map((r) => ({
        id: r.id,
        inventoryTypeId: r.inventory_type_id,
        venueId: r.venue_id,
        name: r.name,
        currency: r.currency,
        isDefault: r.is_default,
        status: r.status,
      })),
      nextCursor: null,
    };
  }

  async patch(
    user: AuthUser,
    id: string,
    body: PatchRatePlanDto,
    correlationId: string,
  ): Promise<RatePlanDto> {
    const existing = await this.pg.query<{
      id: string;
      inventory_type_id: string;
      venue_id: string;
      provider_id: string;
      name: string;
      currency: string;
      is_default: boolean;
      status: string;
    }>(
      `SELECT rp.id, rp.inventory_type_id, it.venue_id, v.provider_id,
              rp.name, rp.currency, rp.is_default, rp.status
       FROM rate_plans rp
       JOIN inventory_types it ON it.id = rp.inventory_type_id
       JOIN venues v ON v.id = it.venue_id
       WHERE rp.id = $1`,
      [id],
    );
    if (!existing.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Rate plan not found");
    }
    const row = existing.rows[0];
    const m = await this.tenancy.require(user, row.provider_id, "pricing.edit");

    return this.pg.tx(async (c) => {
      const nextDefault = body.isDefault ?? row.is_default;
      if (nextDefault && !row.is_default) {
        await c.query(
          `UPDATE rate_plans SET is_default = FALSE
           WHERE inventory_type_id = $1 AND is_default = TRUE AND id <> $2`,
          [row.inventory_type_id, id],
        );
      }
      const upd = await c.query<{
        id: string;
        inventory_type_id: string;
        name: string;
        currency: string;
        is_default: boolean;
        status: string;
      }>(
        `UPDATE rate_plans SET
           name = COALESCE($2, name),
           is_default = COALESCE($3, is_default),
           status = COALESCE($4, status)
         WHERE id = $1
         RETURNING id, inventory_type_id, name, currency, is_default, status`,
        [id, body.name ?? null, body.isDefault ?? null, body.status ?? null],
      );
      const u = upd.rows[0];
      const dto: RatePlanDto = {
        id: u.id,
        inventoryTypeId: u.inventory_type_id,
        venueId: row.venue_id,
        name: u.name,
        currency: u.currency,
        isDefault: u.is_default,
        status: u.status,
      };
      await this.audit.write(
        {
          actorUid: user.uid,
          actorRole: m.actorRole,
          entityType: "rate_plan",
          entityId: id,
          before: {
            name: row.name,
            isDefault: row.is_default,
            status: row.status,
          },
          after: dto,
          correlationId,
        },
        c,
      );
      return dto;
    });
  }
}
