import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { newId } from '../../../shared/ids/ids';
import { OutboxService } from '../../../shared/events/outbox.service';

/**
 * ADR-GATE7A1 — Weighted rating OPTION A:
 * Fixed prior mean m=4.0, strength C=10.
 * weighted = (C*m + sum) / (C + n)
 * Never recompute global mean per venue write.
 */
export const RATING_PRIOR_STRENGTH = 10;
export const RATING_PRIOR_MEAN = 4.0;
/** @deprecated use RATING_PRIOR_MEAN */
export const RATING_PRIOR_MEAN_FALLBACK = RATING_PRIOR_MEAN;

@Injectable()
export class ReviewService {
  constructor(
    private readonly pg: PgService,
    private readonly outbox: OutboxService,
  ) {}

  async create(uid: string, bookingId: string, rating: number, body?: string): Promise<{ reviewId: string }> {
    const b = await this.pg.query<{ status: string; venue_id: string; consumer_firebase_uid: string }>(
      'SELECT status, venue_id, consumer_firebase_uid FROM bookings WHERE id = $1',
      [bookingId],
    );
    if (!b.rowCount || b.rows[0].consumer_firebase_uid !== uid) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking not found');
    }
    if (b.rows[0].status !== 'COMPLETED') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Review allowed after COMPLETED');
    }
    const id = newId();
    const venueId = b.rows[0].venue_id;
    try {
      await this.pg.tx(async (c) => {
        await c.query(`SELECT id FROM venues WHERE id = $1 FOR UPDATE`, [venueId]);
        await c.query(
          `INSERT INTO reviews (id, booking_id, venue_id, consumer_firebase_uid, rating, body, status)
           VALUES ($1,$2,$3,$4,$5,$6,'published')`,
          [id, bookingId, venueId, uid, rating, body ?? null],
        );
        await this.recomputeVenueRating(venueId, c);
        await this.outbox.enqueue('review.created', { reviewId: id, bookingId }, c);
      });
    } catch (e: unknown) {
      const code = (e as { code?: string })?.code;
      if (code === '23505') {
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, 'One review per booking');
      }
      throw e;
    }
    return { reviewId: id };
  }

  /** Trusted reviews only: published; insert requires COMPLETED booking. One per booking. */
  async recomputeVenueRating(venueId: string, client: PoolClient): Promise<void> {
    const agg = await client.query<{ n: string; s: string; avg: string }>(
      `SELECT COUNT(*)::text AS n, COALESCE(SUM(rating),0)::text AS s,
              COALESCE(AVG(rating),0)::text AS avg
       FROM reviews WHERE venue_id = $1 AND status = 'published'`,
      [venueId],
    );
    const n = Number(agg.rows[0]?.n ?? 0);
    const sum = Number(agg.rows[0]?.s ?? 0);
    const avg = n > 0 ? Number(agg.rows[0]?.avg ?? 0) : 0;
    const weighted =
      n === 0 ? 0 : (RATING_PRIOR_STRENGTH * RATING_PRIOR_MEAN + sum) / (RATING_PRIOR_STRENGTH + n);

    await client.query(
      `UPDATE venues SET
         rating_average = $2,
         reviews_count = $3,
         rating_sum = $4,
         weighted_rating = $5,
         updated_at = now()
       WHERE id = $1`,
      [venueId, avg.toFixed(2), n, sum, weighted.toFixed(2)],
    );
  }
}
