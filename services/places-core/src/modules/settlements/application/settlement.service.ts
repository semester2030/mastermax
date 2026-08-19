import { Injectable } from '@nestjs/common';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { newId } from '../../../shared/ids/ids';
import { OutboxService } from '../../../shared/events/outbox.service';
import { AuditService } from '../../audit/application/audit.service';
import { money } from '../../../shared/money/money';

/**
 * Settlement membership via settlement_items.
 * Period: half-open [period_start, period_end) in Asia/Riyadh → UTC via eligible_at.
 * Draft = snapshot; Pay revalidates — never silent recalc (ADR Gate 3C).
 * Phase 4: stub_paid forbidden; PAV bookings excluded from provider payout.
 */
@Injectable()
export class SettlementService {
  constructor(
    private readonly pg: PgService,
    private readonly outbox: OutboxService,
    private readonly audit: AuditService,
  ) {}

  async createDraft(input: {
    providerId: string;
    periodStart: string;
    periodEnd: string;
    actorUid: string;
    correlationId: string;
  }): Promise<{ settlementId: string; net: string; itemCount: number }> {
    return this.pg.tx(async (c) => {
      const existing = await c.query<{ id: string; net: string; status: string }>(
        `SELECT id, net::text, status FROM settlements
         WHERE provider_id = $1 AND period_start = $2::date AND period_end = $3::date
         FOR UPDATE`,
        [input.providerId, input.periodStart, input.periodEnd],
      );
      if (existing.rowCount) {
        if (existing.rows[0].status === 'stale') {
          await c.query(`DELETE FROM settlement_items WHERE settlement_id = $1`, [existing.rows[0].id]);
          await c.query(`DELETE FROM settlements WHERE id = $1 AND status = 'stale'`, [existing.rows[0].id]);
        } else {
          const cnt = await c.query<{ c: number }>(
            `SELECT count(*)::int AS c FROM settlement_items WHERE settlement_id = $1`,
            [existing.rows[0].id],
          );
          return {
            settlementId: existing.rows[0].id,
            net: existing.rows[0].net,
            itemCount: cnt.rows[0].c,
          };
        }
      }
      const mode = await c.query<{ settlement_mode: string }>(
        'SELECT settlement_mode FROM providers WHERE id = $1',
        [input.providerId],
      );
      const members = await c.query<{
        receivable_id: string;
        booking_id: string;
        amount: string;
        gross: string;
        commission: string;
      }>(
        `SELECT pr.id AS receivable_id, pr.booking_id, pr.amount::text,
                b.gross_total::text AS gross, b.commission_amount::text AS commission
         FROM provider_receivables pr
         JOIN bookings b ON b.id = pr.booking_id
         WHERE pr.provider_id = $1
           AND pr.status = 'eligible'
           AND b.payment_method IS DISTINCT FROM 'PAY_AT_VENUE'
           AND pr.eligible_at IS NOT NULL
           AND pr.eligible_at >= ($2::date::timestamp AT TIME ZONE 'Asia/Riyadh')
           AND pr.eligible_at <  ($3::date::timestamp AT TIME ZONE 'Asia/Riyadh')
           AND NOT EXISTS (
             SELECT 1 FROM settlement_items si
             JOIN settlements s ON s.id = si.settlement_id
             WHERE si.provider_receivable_id = pr.id
               AND s.status IN ('draft', 'approved', 'paid', 'pending_transfer')
           )
         FOR UPDATE OF pr`,
        [input.providerId, input.periodStart, input.periodEnd],
      );
      let gross = money('0');
      let commission = money('0');
      let net = money('0');
      for (const m of members.rows) {
        gross = gross.add(money(m.gross));
        commission = commission.add(money(m.commission));
        net = net.add(money(m.amount));
      }
      const refundsRow = await c.query<{ refunds: string }>(
        `SELECT COALESCE(sum(r.amount),0)::text AS refunds FROM refunds r
         JOIN bookings bb ON bb.id = r.booking_id
         WHERE bb.provider_id = $1 AND r.status = 'completed'
           AND r.created_at >= ($2::date::timestamp AT TIME ZONE 'Asia/Riyadh')
           AND r.created_at <  ($3::date::timestamp AT TIME ZONE 'Asia/Riyadh')`,
        [input.providerId, input.periodStart, input.periodEnd],
      );
      const id = newId();
      await c.query(
        `INSERT INTO settlements (id, provider_id, period_start, period_end, gross, commission, refunds, net, status, mode)
         VALUES ($1,$2,$3::date,$4::date,$5,$6,$7,$8,'draft',$9)`,
        [
          id,
          input.providerId,
          input.periodStart,
          input.periodEnd,
          gross.toString(),
          commission.toString(),
          refundsRow.rows[0].refunds,
          net.toString(),
          mode.rows[0]?.settlement_mode ?? 'weekly_batch',
        ],
      );
      for (const m of members.rows) {
        await c.query(
          `INSERT INTO settlement_items (id, settlement_id, provider_receivable_id, booking_id, amount_snapshot)
           VALUES ($1,$2,$3,$4,$5)`,
          [newId(), id, m.receivable_id, m.booking_id, m.amount],
        );
      }
      await this.outbox.enqueue('settlement.created', { settlementId: id }, c);
      await this.audit.write(
        {
          actorUid: input.actorUid,
          actorRole: 'placesFinance',
          entityType: 'settlement',
          entityId: id,
          after: { net: net.toString(), itemCount: members.rowCount, period: 'half-open Asia/Riyadh' },
          correlationId: input.correlationId,
        },
        c,
      );
      return { settlementId: id, net: net.toString(), itemCount: members.rowCount ?? 0 };
    });
  }

  /**
   * Phase 4: bank transfer connector is absent — refuse stub_paid entirely.
   * Settlements may only move to pending_transfer (or stay draft); never mark
   * receivables paid without a real external transfer reference.
   */
  async approveAndStubPayout(
    _settlementId: string,
    _actorUid: string,
    _correlationId: string,
  ): Promise<void> {
    throw new AppError(
      ErrorCodes.SETTLEMENT_TRANSFER_UNAVAILABLE,
      'stub_paid payout is forbidden; bank transfer connector is not configured (fail-closed)',
    );
  }

  /** Mark settlement pending_transfer without marking receivables paid. */
  async markPendingTransfer(
    settlementId: string,
    actorUid: string,
    correlationId: string,
  ): Promise<{ status: string }> {
    return this.pg.tx(async (c) => {
      const s = await c.query<{ status: string; provider_id: string }>(
        'SELECT status, provider_id FROM settlements WHERE id = $1 FOR UPDATE',
        [settlementId],
      );
      if (!s.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, 'Settlement not found');
      }
      if (s.rows[0].status === 'pending_transfer' || s.rows[0].status === 'paid') {
        return { status: s.rows[0].status };
      }
      if (s.rows[0].status !== 'draft' && s.rows[0].status !== 'approved') {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          `Settlement not transferable: ${s.rows[0].status}`,
        );
      }
      // Refuse if any item is a PAV booking (defense in depth).
      const pav = await c.query(
        `SELECT 1 FROM settlement_items si
         JOIN bookings b ON b.id = si.booking_id
         WHERE si.settlement_id = $1 AND b.payment_method = 'PAY_AT_VENUE'
         LIMIT 1`,
        [settlementId],
      );
      if (pav.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          'PAV bookings are excluded from provider payout settlements',
        );
      }
      await c.query(
        `UPDATE settlements SET status = 'pending_transfer' WHERE id = $1`,
        [settlementId],
      );
      await this.audit.write(
        {
          actorUid,
          actorRole: 'placesFinance',
          entityType: 'settlement',
          entityId: settlementId,
          after: { status: 'pending_transfer' },
          reason: 'awaiting_external_transfer',
          correlationId,
        },
        c,
      );
      await this.outbox.enqueue(
        'settlement.pending_transfer',
        { settlementId },
        c,
      );
      return { status: 'pending_transfer' };
    });
  }
}
