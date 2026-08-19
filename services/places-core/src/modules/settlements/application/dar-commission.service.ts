import { Injectable } from "@nestjs/common";
import { PoolClient } from "pg";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { money } from "../../../shared/money/money";

/**
 * Phase 4: DAR commission receivable for PAV.
 * Amount ALWAYS comes from booking.commission_amount snapshot — never recalculated.
 * Never creates provider_receivables / provider payouts for PAV.
 */
@Injectable()
export class DarCommissionService {
  /**
   * Idempotent: one receivable per booking. Status starts pending_completion.
   */
  async recordOnCollect(
    client: PoolClient,
    input: {
      bookingId: string;
      providerId: string;
      commissionAmount: string;
      correlationId: string;
    },
  ): Promise<{ receivableId: string; created: boolean }> {
    const amt = money(input.commissionAmount);
    if (amt.toString().startsWith("-")) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Commission snapshot must be non-negative",
      );
    }
    const existing = await client.query<{ id: string; status: string }>(
      `SELECT id, status FROM dar_commission_receivables WHERE booking_id = $1 FOR UPDATE`,
      [input.bookingId],
    );
    if (existing.rowCount) {
      return { receivableId: existing.rows[0].id, created: false };
    }
    const id = newId();
    await client.query(
      `INSERT INTO dar_commission_receivables (
         id, booking_id, provider_id, amount, currency, status, collected_at
       ) VALUES ($1,$2,$3,$4,'SAR','pending_completion', now())`,
      [id, input.bookingId, input.providerId, amt.toString()],
    );
    return { receivableId: id, created: true };
  }

  /** pending_completion → due on booking completion (idempotent). */
  async markDueOnComplete(
    client: PoolClient,
    bookingId: string,
  ): Promise<void> {
    await client.query(
      `UPDATE dar_commission_receivables
       SET status = 'due', due_at = now(), updated_at = now()
       WHERE booking_id = $1 AND status = 'pending_completion'`,
      [bookingId],
    );
  }

  /**
   * Fail-closed: cannot mark paid without a real external transfer reference.
   * Without a bank connector, only pending_transfer is allowed.
   */
  async markPendingTransfer(
    client: PoolClient,
    receivableId: string,
  ): Promise<void> {
    const upd = await client.query(
      `UPDATE dar_commission_receivables
       SET status = 'pending_transfer', updated_at = now()
       WHERE id = $1 AND status = 'due'`,
      [receivableId],
    );
    if (upd.rowCount !== 1) {
      throw new AppError(
        ErrorCodes.SETTLEMENT_TRANSFER_UNAVAILABLE,
        "DAR commission not due or already in transfer",
      );
    }
  }

  refusePaidWithoutTransfer(): never {
    throw new AppError(
      ErrorCodes.SETTLEMENT_TRANSFER_UNAVAILABLE,
      "Cannot mark DAR commission paid without external_transfer_ref (bank connector absent)",
    );
  }
}
