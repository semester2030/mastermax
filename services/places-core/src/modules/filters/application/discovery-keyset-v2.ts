/**
 * Cursor v2 keyset SQL builders for canonical discovery (Gate 7B.1+).
 */
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { CursorV2Sort, KeysetCursorV2Payload } from './discovery-cursor-v2';
import { distanceMetersSqlExpr } from './discovery-cursor-v2';

export function buildCursorV2Keyset(opts: {
  sort: CursorV2Sort;
  cur: KeysetCursorV2Payload;
  priorCount: number;
  priceExpr: string;
  distLatParam?: number;
  distLngParam?: number;
  bestScoreExpr?: string;
  searchRankExpr?: string;
}): { sql: string; params: unknown[] } {
  const { sort, cur, priorCount, priceExpr } = opts;
  if (sort === 'cheapest' || sort === 'most_expensive') {
    const dir = sort === 'cheapest' ? '>' : '<';
    if (cur.sv == null) {
      return { sql: `(${priceExpr} IS NULL AND v.id > $${priorCount + 1})`, params: [cur.id] };
    }
    return {
      sql: `(
        (${priceExpr} ${dir} $${priorCount + 1}::numeric)
        OR (${priceExpr} = $${priorCount + 1}::numeric AND v.id > $${priorCount + 2})
        OR (${priceExpr} IS NULL)
      )`,
      params: [cur.sv, cur.id],
    };
  }
  if (sort === 'newest') {
    if (cur.sv == null) {
      return { sql: `(v.created_at IS NULL AND v.id > $${priorCount + 1})`, params: [cur.id] };
    }
    return {
      sql: `(
        (date_trunc('milliseconds', v.created_at) < $${priorCount + 1}::timestamptz)
        OR (date_trunc('milliseconds', v.created_at) = $${priorCount + 1}::timestamptz AND v.id > $${priorCount + 2})
        OR (v.created_at IS NULL)
      )`,
      params: [cur.sv, cur.id],
    };
  }
  if (sort === 'near_me' || sort === 'near_place') {
    if (opts.distLatParam == null || opts.distLngParam == null) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `${sort} cursor requires origin lat/lng`);
    }
    const dist = distanceMetersSqlExpr(opts.distLatParam, opts.distLngParam);
    if (cur.sv == null) {
      return { sql: `(${dist} IS NULL AND v.id > $${priorCount + 1})`, params: [cur.id] };
    }
    return {
      sql: `(
        (${dist} > $${priorCount + 1}::bigint)
        OR (${dist} = $${priorCount + 1}::bigint AND v.id > $${priorCount + 2})
        OR (${dist} IS NULL)
      )`,
      params: [cur.sv, cur.id],
    };
  }
  if (sort === 'rating') {
    return {
      sql: `(
        (v.weighted_rating < $${priorCount + 1}::numeric)
        OR (v.weighted_rating = $${priorCount + 1}::numeric AND v.reviews_count < $${priorCount + 2}::int)
        OR (v.weighted_rating = $${priorCount + 1}::numeric AND v.reviews_count = $${priorCount + 2}::int AND v.id > $${priorCount + 3})
      )`,
      params: [cur.sv ?? '0', cur.sv2 ?? '0', cur.id],
    };
  }
  if (sort === 'best') {
    const score = opts.bestScoreExpr;
    if (!score) throw new AppError(ErrorCodes.VALIDATION_ERROR, 'best cursor requires score expr');
    return {
      sql: `(
        (${score} < $${priorCount + 1}::numeric)
        OR (${score} = $${priorCount + 1}::numeric AND v.weighted_rating < $${priorCount + 2}::numeric)
        OR (${score} = $${priorCount + 1}::numeric AND v.weighted_rating = $${priorCount + 2}::numeric AND v.reviews_count < $${priorCount + 3}::int)
        OR (${score} = $${priorCount + 1}::numeric AND v.weighted_rating = $${priorCount + 2}::numeric AND v.reviews_count = $${priorCount + 3}::int AND v.id > $${priorCount + 4})
      )`,
      params: [cur.sv ?? '0', cur.sv2 ?? '0', cur.sv3 ?? '0', cur.id],
    };
  }
  if (sort === 'search_rank') {
    const rank = opts.searchRankExpr;
    const score = opts.bestScoreExpr;
    if (!rank || !score) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'search_rank cursor requires rank/score expr');
    }
    return {
      sql: `(
        (${rank} < $${priorCount + 1}::numeric)
        OR (${rank} = $${priorCount + 1}::numeric AND ${score} < $${priorCount + 2}::numeric)
        OR (${rank} = $${priorCount + 1}::numeric AND ${score} = $${priorCount + 2}::numeric AND v.id > $${priorCount + 3})
      )`,
      params: [cur.sv ?? '0', cur.sv2 ?? '0', cur.id],
    };
  }
  throw new AppError(ErrorCodes.VALIDATION_ERROR, 'unsupported cursor sort');
}
