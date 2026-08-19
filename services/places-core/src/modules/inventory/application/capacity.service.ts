import { Injectable } from "@nestjs/common";
import { PoolClient } from "pg";
import { newId } from "../../../shared/ids/ids";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { BookingLockOrder } from "../../booking/application/booking-lock-order";

export interface DailyRow {
  id: string;
  date: string;
  capacity: number;
  held: number;
  booked: number;
  blocked: number;
  available: number;
}

@Injectable()
export class CapacityService {
  constructor(private readonly pg: PgService) {}

  async ensureRows(
    typeId: string,
    dates: string[],
    client: PoolClient,
  ): Promise<void> {
    // Unified lock (F-V2-008): take FOR UPDATE on the inventory_types row before
    // reading quantity_total and seeding daily rows. This serializes against
    // ProviderInventory.patch so a concurrent quantity decrease can never leave a
    // daily row seeded from the stale (old) quantity_total.
    const { quantity_total: base } = await BookingLockOrder.lockInventoryType(
      client,
      typeId,
    );
    for (const date of dates) {
      const blocked = await this.blockedFor(client, typeId, date);
      await client.query(
        `INSERT INTO inventory_daily_capacity
           (id, inventory_type_id, date, capacity, held, booked, blocked)
         VALUES ($1, $2, $3::date, $4, 0, 0, $5)
         ON CONFLICT (inventory_type_id, date) DO NOTHING`,
        [newId(), typeId, date, base, blocked],
      );
    }
  }

  async readMinAvailable(
    typeId: string,
    dates: string[],
    client?: PoolClient,
  ): Promise<number> {
    const sql = `SELECT available FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = ANY($2::date[])`;
    const params = [typeId, dates];
    const res = client
      ? await client.query<{ available: number }>(sql, params)
      : await this.pg.query<{ available: number }>(sql, params);
    if (res.rowCount !== dates.length) {
      return 0;
    }
    return Math.min(...res.rows.map((r) => r.available));
  }

  /** Lock all night rows FOR UPDATE then increment held. Atomic multi-night. */
  async lockAndHold(
    typeId: string,
    dates: string[],
    qty: number,
    client: PoolClient,
  ): Promise<void> {
    await this.ensureRows(typeId, dates, client);
    const locked = await this.lockRows(typeId, dates, client);
    if (locked.rows.some((r) => r.available < qty)) {
      throw new AppError(
        ErrorCodes.AVAILABILITY_CHANGED,
        "Inventory no longer available",
      );
    }
    const upd = await client.query(
      `UPDATE inventory_daily_capacity
       SET held = held + $3
       WHERE inventory_type_id = $1 AND date = ANY($2::date[])
         AND (capacity - held - booked - blocked) >= $3`,
      [typeId, dates, qty],
    );
    this.assertRowCount(upd.rowCount, dates.length, "hold");
  }

  async convertHoldToBooked(
    typeId: string,
    dates: string[],
    qty: number,
    client: PoolClient,
  ): Promise<void> {
    await this.lockRows(typeId, dates, client);
    const upd = await client.query(
      `UPDATE inventory_daily_capacity
       SET held = held - $3, booked = booked + $3
       WHERE inventory_type_id = $1 AND date = ANY($2::date[])
         AND held >= $3`,
      [typeId, dates, qty],
    );
    this.assertRowCount(upd.rowCount, dates.length, "convert");
  }

  async releaseHeld(
    typeId: string,
    dates: string[],
    qty: number,
    client: PoolClient,
  ): Promise<void> {
    if (dates.length === 0) return;
    // Unified order: inventory_types before daily rows (recomputeBlocked below
    // re-enters ensureRows). Prevents inversion vs the hold path (F-V2-008).
    await BookingLockOrder.lockInventoryType(client, typeId);
    await this.lockRows(typeId, dates, client);
    const upd = await client.query(
      `UPDATE inventory_daily_capacity
       SET held = held - $3
       WHERE inventory_type_id = $1 AND date = ANY($2::date[]) AND held >= $3`,
      [typeId, dates, qty],
    );
    this.assertRowCount(upd.rowCount, dates.length, "releaseHeld");
    for (const date of dates) {
      await this.recomputeBlocked(typeId, date, client);
    }
  }

  async releaseBooked(
    typeId: string,
    dates: string[],
    qty: number,
    client: PoolClient,
  ): Promise<void> {
    if (dates.length === 0) return;
    // Unified order: inventory_types before daily rows (recomputeBlocked below
    // re-enters ensureRows). Prevents inversion vs the hold path (F-V2-008).
    await BookingLockOrder.lockInventoryType(client, typeId);
    await this.lockRows(typeId, dates, client);
    const upd = await client.query(
      `UPDATE inventory_daily_capacity
       SET booked = booked - $3
       WHERE inventory_type_id = $1 AND date = ANY($2::date[]) AND booked >= $3`,
      [typeId, dates, qty],
    );
    this.assertRowCount(upd.rowCount, dates.length, "releaseBooked");
    for (const date of dates) {
      await this.recomputeBlocked(typeId, date, client);
    }
  }

  /**
   * F-V2-008: reconcile future daily capacity when quantity_total changes.
   * Past dates are never mutated. held/booked are never rewritten.
   */
  async reconcileQuantityTotal(
    typeId: string,
    newTotal: number,
    client: PoolClient,
    fromDateInclusive: string,
  ): Promise<void> {
    if (!Number.isInteger(newTotal) || newTotal < 0) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "quantity_total must be a non-negative integer",
      );
    }
    const locked = await client.query<{
      date: string;
      held: number;
      booked: number;
      blocked: number;
    }>(
      `SELECT date::text, held, booked, blocked
       FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date >= $2::date
       ORDER BY date
       FOR UPDATE`,
      [typeId, fromDateInclusive],
    );
    for (const row of locked.rows) {
      const used =
        Number(row.held) + Number(row.booked) + Number(row.blocked);
      if (used > newTotal) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Cannot reduce quantity_total below held+booked+blocked for a future day",
          { date: row.date, used, newTotal },
        );
      }
    }
    if (locked.rowCount) {
      await client.query(
        `UPDATE inventory_daily_capacity
         SET capacity = $2
         WHERE inventory_type_id = $1 AND date >= $3::date`,
        [typeId, newTotal, fromDateInclusive],
      );
    }
  }

  async setBlocked(
    typeId: string,
    date: string,
    blocked: number,
    client?: PoolClient,
  ): Promise<void> {
    const run = async (c: PoolClient): Promise<void> => {
      await this.ensureRows(typeId, [date], c);
      await this.lockRows(typeId, [date], c);
      const upd = await c.query(
        `UPDATE inventory_daily_capacity SET blocked = $3
         WHERE inventory_type_id = $1 AND date = $2::date
           AND (held + booked + $3) <= capacity`,
        [typeId, date, blocked],
      );
      this.assertRowCount(upd.rowCount, 1, "setBlocked");
    };
    if (client) {
      await run(client);
      return;
    }
    await this.pg.tx(run);
  }

  async recomputeBlocked(
    typeId: string,
    date: string,
    client: PoolClient,
  ): Promise<number> {
    await this.ensureRows(typeId, [date], client);
    const blocked = await this.blockedFor(client, typeId, date);
    await this.setBlocked(typeId, date, blocked, client);
    return blocked;
  }

  private async lockRows(
    typeId: string,
    dates: string[],
    client: PoolClient,
  ): Promise<{ rowCount: number; rows: DailyRow[] }> {
    const locked = await client.query<DailyRow>(
      `SELECT id, date::text, capacity, held, booked, blocked, available
       FROM inventory_daily_capacity
       WHERE inventory_type_id = $1 AND date = ANY($2::date[])
       ORDER BY date
       FOR UPDATE`,
      [typeId, dates],
    );
    if (locked.rowCount !== dates.length) {
      throw new AppError(
        ErrorCodes.AVAILABILITY_CHANGED,
        "Inventory rows missing for stay",
      );
    }
    return { rowCount: locked.rowCount ?? 0, rows: locked.rows };
  }

  private assertRowCount(
    actual: number | null,
    expected: number,
    op: string,
  ): void {
    if (actual !== expected) {
      throw new AppError(
        ErrorCodes.INTERNAL,
        `Inventory invariant failed on ${op}`,
        { expected, actual },
        true,
      );
    }
  }

  private async blockedFor(
    client: PoolClient,
    typeId: string,
    date: string,
  ): Promise<number> {
    const typeLevel = await client.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM availability_overrides
       WHERE inventory_type_id = $1
         AND inventory_unit_id IS NULL
         AND date = $2::date
         AND kind IN ('block', 'maintenance')`,
      [typeId, date],
    );
    if (Number(typeLevel.rows[0].c) > 0) {
      const cap = await client.query<{
        capacity: number;
        held: number;
        booked: number;
      }>(
        `SELECT capacity, held, booked FROM inventory_daily_capacity
         WHERE inventory_type_id = $1 AND date = $2::date`,
        [typeId, date],
      );
      if (cap.rowCount) {
        const row = cap.rows[0];
        return Math.max(
          0,
          Number(row.capacity) - Number(row.held) - Number(row.booked),
        );
      }
      const type = await client.query<{ quantity_total: number }>(
        `SELECT quantity_total FROM inventory_types WHERE id = $1`,
        [typeId],
      );
      return type.rowCount ? Number(type.rows[0].quantity_total) : 0;
    }

    // Unit-level block/maintenance reduces pooled available (Acceptance A–H B).
    // Never add unit capacity on top of quantity_total (F-V3-011 partial).
    const ov = await client.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM availability_overrides
       WHERE inventory_type_id = $1
         AND inventory_unit_id IS NOT NULL
         AND date = $2::date
         AND kind IN ('block', 'maintenance')`,
      [typeId, date],
    );
    const units = await client.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM inventory_units
       WHERE inventory_type_id = $1 AND status IN ('maintenance', 'oos', 'blocked')`,
      [typeId],
    );
    return Number(ov.rows[0].c) + Number(units.rows[0].c);
  }
}
