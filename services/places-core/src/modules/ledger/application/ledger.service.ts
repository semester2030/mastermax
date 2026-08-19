import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { newId } from '../../../shared/ids/ids';
import { Decimal } from '../../../shared/money/decimal';
import { money } from '../../../shared/money/money';

/**
 * Ledger entry type scopes (Gate 3D.1):
 * - BOOKING_SCOPED: customer_payment, dar_commission, provider_receivable, refund, adjustment, fee, reversal
 * - PROVIDER / SETTLEMENT_SCOPED: settlement, payout (booking_id MUST be NULL; reference = settlement:<id>)
 */
export type LedgerType =
  | 'customer_payment'
  | 'dar_commission'
  | 'provider_receivable'
  | 'refund'
  | 'payout'
  | 'settlement'
  | 'adjustment'
  | 'fee'
  | 'reversal';

export interface LedgerLine {
  type: LedgerType;
  direction: 'debit' | 'credit';
  amount: string;
  idempotencyKey: string;
}

@Injectable()
export class LedgerService {
  async postGroup(
    client: PoolClient,
    meta: {
      /** Null for provider/settlement-scoped journals (settlement, payout). */
      bookingId: string | null;
      paymentId?: string;
      providerId: string;
      createdBy: string;
      correlationId: string;
      reference: string;
    },
    lines: LedgerLine[],
  ): Promise<void> {
    let debit = Decimal.zero();
    let credit = Decimal.zero();
    for (const line of lines) {
      const amt = money(line.amount);
      if (line.direction === 'debit') {
        debit = debit.add(amt);
      } else {
        credit = credit.add(amt);
      }
    }
    if (!debit.eq(credit)) {
      throw new AppError(ErrorCodes.INTERNAL, 'Ledger group is not balanced', {
        debit: debit.toString(),
        credit: credit.toString(),
      });
    }
    for (const line of lines) {
      await client.query(
        `INSERT INTO ledger_entries (
           id, booking_id, payment_id, provider_id, amount, currency, direction, type,
           status, reference, created_by, idempotency_key, correlation_id
         ) VALUES ($1,$2,$3,$4,$5,'SAR',$6,$7,'posted',$8,$9,$10,$11)`,
        [
          newId(),
          meta.bookingId,
          meta.paymentId ?? null,
          meta.providerId,
          line.amount,
          line.direction,
          line.type,
          meta.reference,
          meta.createdBy,
          line.idempotencyKey,
          meta.correlationId,
        ],
      );
    }
  }
}
