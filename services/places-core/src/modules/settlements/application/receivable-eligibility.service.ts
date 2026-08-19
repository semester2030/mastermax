import { Injectable, Logger } from '@nestjs/common';
import { PgService } from '../../../shared/database/pg.service';

/**
 * Phase 4: eligibility NEVER auto-completes bookings.
 * It only promotes provider_receivables for bookings already COMPLETED (PSP path).
 * PAV bookings are excluded entirely from provider_receivables eligibility.
 */
@Injectable()
export class ReceivableEligibilityService {
  private readonly logger = new Logger(ReceivableEligibilityService.name);

  constructor(private readonly pg: PgService) {}

  /**
   * Promote due COMPLETED stays: check_out + delay (Asia/Riyadh) <= asOf.
   * Idempotent — running twice does not duplicate eligible transitions.
   */
  async promoteDue(asOfDate?: string, _correlationId = 'eligibility'): Promise<number> {
    const asOf =
      asOfDate ??
      new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Riyadh' }).format(new Date());
    let promoted = 0;
    const due = await this.pg.query<{
      booking_id: string;
      receivable_id: string;
      delay_hours: number;
      check_out: string;
    }>(
      `SELECT b.id AS booking_id, pr.id AS receivable_id,
              COALESCE(v.receivable_eligibility_delay_hours, 0) AS delay_hours,
              b.check_out::text
       FROM bookings b
       JOIN provider_receivables pr ON pr.booking_id = b.id
       JOIN venues v ON v.id = b.venue_id
       WHERE pr.status = 'pending'
         AND b.status = 'COMPLETED'
         AND b.payment_method IS DISTINCT FROM 'PAY_AT_VENUE'
         AND (b.check_out + make_interval(hours => COALESCE(v.receivable_eligibility_delay_hours, 0)))::date
             <= $1::date
       ORDER BY b.check_out
       LIMIT 200`,
      [asOf],
    );
    for (const row of due.rows) {
      try {
        await this.pg.tx(async (c) => {
          const lock = await c.query<{ recv_status: string; booking_status: string }>(
            `SELECT pr.status AS recv_status, b.status AS booking_status
             FROM bookings b
             JOIN provider_receivables pr ON pr.booking_id = b.id
             WHERE b.id = $1 AND pr.id = $2
             FOR UPDATE OF b, pr`,
            [row.booking_id, row.receivable_id],
          );
          if (
            !lock.rowCount ||
            lock.rows[0].recv_status !== 'pending' ||
            lock.rows[0].booking_status !== 'COMPLETED'
          ) {
            return;
          }
          const upd = await c.query(
            `UPDATE provider_receivables
             SET status = 'eligible',
                 eligible_at = (($2::date::timestamp + make_interval(hours => $3)) AT TIME ZONE 'Asia/Riyadh'),
                 updated_at = now()
             WHERE id = $1 AND status = 'pending'`,
            [row.receivable_id, row.check_out, row.delay_hours],
          );
          if ((upd.rowCount ?? 0) === 1) {
            promoted += 1;
          }
        });
      } catch (err) {
        this.logger.warn({ bookingId: row.booking_id, err: String(err) });
      }
    }
    return promoted;
  }

  async markEligibleForBooking(bookingId: string, _correlationId: string): Promise<void> {
    await this.pg.tx(async (c) => {
      const row = await c.query<{
        status: string;
        receivable_id: string;
        recv_status: string;
        check_out: string;
        delay_hours: number;
        payment_method: string | null;
      }>(
        `SELECT b.status, pr.id AS receivable_id, pr.status AS recv_status,
                b.check_out::text, COALESCE(v.receivable_eligibility_delay_hours, 0) AS delay_hours,
                b.payment_method
         FROM bookings b
         LEFT JOIN provider_receivables pr ON pr.booking_id = b.id
         JOIN venues v ON v.id = b.venue_id
         WHERE b.id = $1
         FOR UPDATE OF b`,
        [bookingId],
      );
      if (!row.rowCount || !row.rows[0].receivable_id) {
        return;
      }
      if (row.rows[0].payment_method === 'PAY_AT_VENUE') {
        return;
      }
      // Never auto-complete — only promote if already COMPLETED.
      if (row.rows[0].status !== 'COMPLETED') {
        return;
      }
      if (row.rows[0].recv_status === 'pending') {
        await c.query(
          `UPDATE provider_receivables
           SET status = 'eligible',
               eligible_at = (($2::date::timestamp + make_interval(hours => $3)) AT TIME ZONE 'Asia/Riyadh'),
               updated_at = now()
           WHERE id = $1 AND status = 'pending'`,
          [row.rows[0].receivable_id, row.rows[0].check_out, row.rows[0].delay_hours],
        );
      }
    });
  }
}
