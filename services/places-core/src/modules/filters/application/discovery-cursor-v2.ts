/**
 * Cursor v2 contract helpers (Gate 7B.0.3+).
 * Canonical discovery (FilterEngine) emits/accepts Cursor v2 only (Gate 7B.1+).
 */
import { createHash } from 'crypto';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { DiscoverySort } from './discovery-cursor';
import {
  assertCursorV2PayloadShape,
  assertStrictIsoUtc,
  DiversityCursorMode,
} from './discovery-cursor-v2-validate';

export const CURSOR_V2 = 2 as const;
export const RANKING_EPOCH_CURRENT = 1;
export const DIVERSITY_VERSION_CURRENT = 1;
export const DIVERSITY_K_DEFAULT = 2;
export const RANKING_AS_OF_TTL_MS = 15 * 60 * 1000;
export const DISCOVERY_CURSOR_MAX_LENGTH = 4096;
export const CURSOR_DISTANCE_METERS_MAX = 20_050_000;

export type CursorV2Sort =
  | DiscoverySort
  | 'near_place'
  | 'search_rank';

export const CURSOR_V2_ORDER_KEYS: Record<CursorV2Sort, readonly string[]> = {
  best: ['best_score', 'weighted_rating', 'reviews_count', 'id'],
  rating: ['weighted_rating', 'reviews_count', 'id'],
  cheapest: ['starting_price_hint', 'id'],
  most_expensive: ['starting_price_hint', 'id'],
  newest: ['created_at', 'id'],
  near_me: ['distance_meters', 'id'],
  near_place: ['distance_meters', 'id'],
  search_rank: ['text_rank', 'best_score', 'id'],
};

export interface DiversityTypeAfter {
  sv: string | null;
  sv2?: string | null;
  sv3?: string | null;
  id: string;
}

export interface DiversityCursorState {
  lastType: string | null;
  streak: number;
  perTypeAfter: Record<string, DiversityTypeAfter>;
}

export interface CursorV2QueryContext {
  resolvedCanonicalJson: string;
  surface: string;
  q: string | null;
  originLat: number | null;
  originLng: number | null;
  anchorVenueId: string | null;
  rankingVersion: number;
  rankingEpoch: number;
  rankingAsOf: string;
  diversityVersion: number;
  diversityK: number;
}

export interface KeysetCursorV2Payload {
  v: typeof CURSOR_V2;
  sort: CursorV2Sort;
  queryHash: string;
  rankingEpoch: number;
  rankingAsOf: string;
  diversityVersion?: number;
  diversityK?: number;
  diversity?: DiversityCursorState;
  sv: string | null;
  sv2?: string | null;
  sv3?: string | null;
  id: string;
}

function sortKeysDeep(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortKeysDeep);
  }
  if (value && typeof value === 'object' && !(value instanceof Date)) {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(value as Record<string, unknown>).sort()) {
      const v = (value as Record<string, unknown>)[k];
      if (v === undefined) continue;
      out[k] = sortKeysDeep(v);
    }
    return out;
  }
  return value;
}

export function canonicalizeResolvedDto(resolved: Record<string, unknown>): string {
  const copy = { ...resolved };
  delete copy.cursor;
  delete copy.rankingAsOf;
  return JSON.stringify(sortKeysDeep(copy));
}

export function buildQueryHash(ctx: CursorV2QueryContext): string {
  const canonical = JSON.stringify(
    sortKeysDeep({
      resolved: JSON.parse(ctx.resolvedCanonicalJson) as unknown,
      surface: ctx.surface,
      q: ctx.q,
      originLat: ctx.originLat,
      originLng: ctx.originLng,
      anchorVenueId: ctx.anchorVenueId,
      rankingVersion: ctx.rankingVersion,
      rankingEpoch: ctx.rankingEpoch,
      rankingAsOf: ctx.rankingAsOf,
      diversityVersion: ctx.diversityVersion,
      diversityK: ctx.diversityK,
    }),
  );
  return createHash('sha256').update(canonical, 'utf8').digest('hex').slice(0, 32);
}

export function distanceKmToMeters(km: number): number {
  if (!Number.isFinite(km) || km < 0) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid distance for cursor');
  }
  return Math.min(CURSOR_DISTANCE_METERS_MAX, Math.round(km * 1000));
}

export function formatDistanceMetersCursorSv(meters: number): string {
  if (!Number.isInteger(meters) || meters < 0 || meters > CURSOR_DISTANCE_METERS_MAX) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'distance meters out of cursor range');
  }
  return String(meters);
}

export function distanceMetersSqlExpr(latP: number, lngP: number): string {
  return `(
  CASE WHEN v.lat IS NULL OR v.lng IS NULL THEN NULL ELSE
  ROUND((
    6371 * acos(LEAST(1, GREATEST(-1,
      cos(radians($${latP})) * cos(radians(v.lat)) *
      cos(radians(v.lng) - radians($${lngP})) +
      sin(radians($${latP})) * sin(radians(v.lat))
    )))
  ) * 1000)::bigint END
)`;
}

export function encodeCursorV2(
  payload: KeysetCursorV2Payload,
  diversityMode: DiversityCursorMode,
): string {
  if (diversityMode !== 'required' && diversityMode !== 'forbidden') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversityMode must be required|forbidden');
  }
  assertCursorV2PayloadShape(payload, diversityMode);
  const encoded = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  if (encoded.length > DISCOVERY_CURSOR_MAX_LENGTH) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor exceeds max length');
  }
  return encoded;
}

export function assertRankingAsOfFresh(rankingAsOf: string, nowMs = Date.now()): void {
  assertStrictIsoUtc(rankingAsOf, 'rankingAsOf');
  const t = Date.parse(rankingAsOf);
  if (!Number.isFinite(t) || nowMs - t > RANKING_AS_OF_TTL_MS || t > nowMs + 60_000) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'rankingAsOf expired or invalid');
  }
}

export function decodeCursorV2(
  raw: string,
  expectedSort: CursorV2Sort,
  expectedQueryHash: string,
  expectedEpoch: number,
  expectedRankingAsOf: string,
  diversityMode: DiversityCursorMode,
  expectedDiversityVersion: number = DIVERSITY_VERSION_CURRENT,
  expectedDiversityK: number = DIVERSITY_K_DEFAULT,
): KeysetCursorV2Payload {
  const parsed = parseCursorV2Structural(raw, diversityMode);
  if (parsed.sort !== expectedSort) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor sort mismatch');
  }
  if (parsed.queryHash !== expectedQueryHash) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor queryHash mismatch');
  }
  if (parsed.rankingEpoch !== expectedEpoch) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor rankingEpoch mismatch');
  }
  if (parsed.rankingAsOf !== expectedRankingAsOf) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor rankingAsOf mismatch');
  }
  assertRankingAsOfFresh(parsed.rankingAsOf);
  if (diversityMode === 'required') {
    if (parsed.diversityVersion !== expectedDiversityVersion) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor diversityVersion mismatch');
    }
    if (parsed.diversityK !== expectedDiversityK) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor diversityK mismatch');
    }
  }
  return parsed;
}

/**
 * Structural + preflight cursor validation (Gate 7B.3.2) — BEFORE any SQL.
 * Validates: structure, version, sort keyset ranges, rankingEpoch shape,
 * rankingAsOf ISO + TTL freshness.
 * Does NOT validate queryHash match (that is after resolvers via assertCursorV2Context).
 */
export function parseCursorV2Structural(
  raw: string,
  diversityMode: DiversityCursorMode = 'forbidden',
): KeysetCursorV2Payload {
  if (diversityMode !== 'required' && diversityMode !== 'forbidden') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversityMode must be required|forbidden');
  }
  if (raw.length > DISCOVERY_CURSOR_MAX_LENGTH) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor exceeds max length');
  }
  let parsed: KeysetCursorV2Payload;
  try {
    parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as KeysetCursorV2Payload;
  } catch {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor');
  }
  if (!parsed || parsed.v !== CURSOR_V2) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor version unsupported');
  }
  assertCursorV2PayloadShape(parsed, diversityMode);
  assertRankingAsOfFresh(parsed.rankingAsOf);
  return parsed;
}

/**
 * Pre-SQL sort/epoch match against effective request (no hash yet).
 * Call after structural parse + applyDiscoveryDefaults on the request (still before resolvers).
 */
export function assertCursorV2PreflightSortEpoch(
  parsed: KeysetCursorV2Payload,
  effectiveSort: CursorV2Sort,
  expectedEpoch: number = RANKING_EPOCH_CURRENT,
): void {
  if (parsed.sort !== effectiveSort) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor sort mismatch');
  }
  if (parsed.rankingEpoch !== expectedEpoch) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor rankingEpoch mismatch');
  }
}

/**
 * Context/hash validation AFTER resolvers, BEFORE COUNT/page SQL (Gate 7B.3.2).
 * Sort/epoch/TTL already enforced in preflight; re-check sort + rankingAsOf identity,
 * then queryHash.
 */
export function assertCursorV2Context(
  parsed: KeysetCursorV2Payload,
  expectedSort: CursorV2Sort,
  expectedQueryHash: string,
  expectedEpoch: number,
  expectedRankingAsOf: string,
): void {
  if (parsed.sort !== expectedSort) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor sort mismatch');
  }
  if (parsed.queryHash !== expectedQueryHash) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor queryHash mismatch');
  }
  if (parsed.rankingEpoch !== expectedEpoch) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor rankingEpoch mismatch');
  }
  if (parsed.rankingAsOf !== expectedRankingAsOf) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor rankingAsOf mismatch');
  }
}

export function buildWorstCaseBestDiversityCursor(
  rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z'),
): string {
  const types = ['hotel', 'chalet', 'hall', 'farm', 'resort', 'villa', 'apartment', 'camp'];
  const ids = [
    'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    'bbbbbbbb-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    'cccccccc-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    'dddddddd-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    'eeeeeeee-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    'ffffffff-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    '11111111-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    '22222222-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  ];
  const perTypeAfter: Record<string, DiversityTypeAfter> = {};
  types.forEach((t, i) => {
    perTypeAfter[t] = { sv: '0.999999', sv2: '5.00', sv3: '2147483647', id: ids[i] };
  });
  return encodeCursorV2(
    {
      v: 2,
      sort: 'best',
      queryHash: 'a'.repeat(32),
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      diversityVersion: DIVERSITY_VERSION_CURRENT,
      diversityK: DIVERSITY_K_DEFAULT,
      diversity: {
        lastType: 'wedding_hall_long_type_name_xx',
        streak: 2,
        perTypeAfter,
      },
      sv: '0.999999',
      sv2: '5.00',
      sv3: '2147483647',
      id: ids[0],
    },
    'required',
  );
}

export { assertCursorV2PayloadShape, type DiversityCursorMode } from './discovery-cursor-v2-validate';
