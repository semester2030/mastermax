/**
 * Cursor v2 encode from SQL row for canonical discovery (Gate 7B.1+ / 7B.4 diversity).
 */
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { formatPriceCursorSv } from './discovery-cursor';
import {
  CursorV2Sort,
  DiversityCursorState,
  DiversityCursorMode,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  encodeCursorV2,
  formatDistanceMetersCursorSv,
  KeysetCursorV2Payload,
  RANKING_EPOCH_CURRENT,
} from './discovery-cursor-v2';

function createdAtCursor(value: unknown): string {
  const d = value instanceof Date ? value : new Date(String(value));
  if (!Number.isFinite(d.getTime())) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid created_at for cursor');
  }
  return d.toISOString();
}

/**
 * Encode weighted_rating for cursor — identical scale to SQL NUMERIC comparison.
 * No clamp: ORDER BY / keyset use raw v.weighted_rating (column NUMERIC(4,2)).
 */
export function formatWeightedRatingCursorSv(value: unknown): string {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid weighted_rating for cursor');
  }
  return n.toFixed(2);
}

export function cursorV2FromRow(
  sort: CursorV2Sort,
  row: Record<string, unknown>,
  ctx: {
    queryHash: string;
    rankingAsOf: string;
    rankingEpoch?: number;
    diversityVersion?: number;
    diversityK?: number;
    diversity?: DiversityCursorState;
  },
  diversityMode: DiversityCursorMode = 'forbidden',
): string {
  const id = String(row.id);
  const base = {
    v: 2 as const,
    sort,
    queryHash: ctx.queryHash,
    rankingEpoch: ctx.rankingEpoch ?? RANKING_EPOCH_CURRENT,
    rankingAsOf: ctx.rankingAsOf,
    id,
  };
  let payload: KeysetCursorV2Payload;
  if (sort === 'cheapest' || sort === 'most_expensive') {
    const sv =
      row.starting_price_hint == null ? null : formatPriceCursorSv(row.starting_price_hint);
    payload = { ...base, sv };
  } else if (sort === 'newest') {
    payload = {
      ...base,
      sv: row.created_at == null ? null : createdAtCursor(row.created_at),
    };
  } else if (sort === 'near_me' || sort === 'near_place') {
    payload = {
      ...base,
      sv:
        row.distance_meters == null
          ? null
          : formatDistanceMetersCursorSv(Math.trunc(Number(row.distance_meters))),
    };
  } else if (sort === 'rating') {
    payload = {
      ...base,
      // Raw weighted_rating (NUMERIC) — must match ORDER BY / keyset (no clamp).
      sv: formatWeightedRatingCursorSv(row.weighted_rating),
      sv2: String(Number(row.reviews_count ?? 0)),
    };
  } else if (sort === 'best') {
    payload = {
      ...base,
      sv: Number(row.best_score ?? 0).toFixed(6),
      // Tie-break uses raw weighted_rating in ORDER BY/keyset — encode identically.
      sv2: formatWeightedRatingCursorSv(row.weighted_rating),
      sv3: String(Number(row.reviews_count ?? 0)),
    };
  } else if (sort === 'search_rank') {
    payload = {
      ...base,
      sv: Number(row.text_rank ?? 0).toFixed(6),
      sv2: Number(row.best_score ?? 0).toFixed(6),
    };
  } else {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'unsupported sort for cursor');
  }
  if (diversityMode === 'required') {
    if (!ctx.diversity) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversity state required for cursor emit');
    }
    payload = {
      ...payload,
      diversityVersion: ctx.diversityVersion ?? DIVERSITY_VERSION_CURRENT,
      diversityK: ctx.diversityK ?? DIVERSITY_K_DEFAULT,
      diversity: ctx.diversity,
    };
  }
  return encodeCursorV2(payload, diversityMode);
}

export function normalizeRankingAsOf(raw?: string | null): string {
  if (raw) {
    const t = Date.parse(raw);
    if (!Number.isFinite(t)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid rankingAsOf');
    }
    return new Date(t).toISOString().replace(/\.\d{3}Z$/, '.000Z');
  }
  return new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
}

export function peekCursorV2RankingAsOf(raw: string): string | null {
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as {
      v?: number;
      rankingAsOf?: string;
    };
    if (parsed?.v !== 2 || typeof parsed.rankingAsOf !== 'string') return null;
    return parsed.rankingAsOf;
  } catch {
    return null;
  }
}
