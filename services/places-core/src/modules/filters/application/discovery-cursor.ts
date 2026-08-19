import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

export type DiscoverySort =
  | 'best'
  | 'rating'
  | 'cheapest'
  | 'most_expensive'
  | 'newest'
  | 'near_me'
  | 'near_place'
  | 'search_rank';

export interface KeysetCursorPayload {
  v: 1;
  sort: DiscoverySort;
  /** Primary sort value (string); null = SQL NULL. */
  sv: string | null;
  /** Secondary sort (e.g. reviews_count for rating). */
  sv2?: string | null;
  id: string;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;
/** Non-negative decimal; no exponent, no leading zeros (except 0 / 0.x). */
const NONNEG_DECIMAL_RE = /^(?:0|[1-9]\d*)(?:\.\d+)?$/;
/** Non-negative integer; no decimal, no exponent. */
const NONNEG_INT_RE = /^(?:0|[1-9]\d*)$/;
/**
 * PostgreSQL NUMERIC(12,2) domain for price cursors:
 * up to 10 integer digits + optional 1–2 fractional digits. No exponent.
 */
const PRICE_CURSOR_RE = /^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/;

/** Discovery DTO filter max — NOT the cursor domain. */
export const DISCOVERY_FILTER_PRICE_MAX = 1_000_000;
/** Price cursor max = PostgreSQL NUMERIC(12,2). */
export const CURSOR_PRICE_MAX = 9_999_999_999.99;
export const CURSOR_PRICE_MAX_TEXT = '9999999999.99';
/** Half Earth circumference in meters — near_me cursor upper bound. */
export const CURSOR_DISTANCE_METERS_MAX = 20_050_000;
/** @deprecated use CURSOR_DISTANCE_METERS_MAX — kept for docs clarity */
export const CURSOR_DISTANCE_KM_MAX = 20_050;
export const CURSOR_RATING_MIN = 0;
export const CURSOR_RATING_MAX = 99.99;
export const CURSOR_PG_INT_MAX = 2_147_483_647;

export function encodeCursor(payload: KeysetCursorPayload): string {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function assertUuid(id: unknown): asserts id is string {
  if (typeof id !== 'string' || !UUID_RE.test(id)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor id');
  }
}

function rejectSpecialNumericToken(raw: string, label: string): void {
  if (/^[-+]?nan$/i.test(raw) || /^[-+]?infinity$/i.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `invalid cursor ${label}`);
  }
}

function parseNonNegDecimal(raw: string, min: number, max: number, label: string): number {
  rejectSpecialNumericToken(raw, label);
  if (!NONNEG_DECIMAL_RE.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  const n = Number(raw);
  if (!Number.isFinite(n) || n < min || n > max) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `cursor ${label} out of range`);
  }
  return n;
}

/** Price cursor: NUMERIC(12,2) domain — separate from Discovery filter 0…1_000_000. */
function parsePriceCursorSv(raw: string): void {
  rejectSpecialNumericToken(raw, 'sv');
  if (!PRICE_CURSOR_RE.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sv for price sort');
  }
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0 || n > CURSOR_PRICE_MAX) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor sv out of range');
  }
}

/**
 * Format a DB NUMERIC(12,2) value as a cursor sv that decodeCursor always accepts.
 * No clamping; only canonical string form (at most 2 fractional digits, no exponent).
 */
export function formatPriceCursorSv(value: unknown): string {
  const trimmed = String(value).trim();
  if (PRICE_CURSOR_RE.test(trimmed)) {
    parsePriceCursorSv(trimmed);
    return trimmed;
  }
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > CURSOR_PRICE_MAX) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'price cursor value outside NUMERIC(12,2)');
  }
  const fixed = n.toFixed(2);
  if (!PRICE_CURSOR_RE.test(fixed)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'price cursor value outside NUMERIC(12,2)');
  }
  if (fixed.endsWith('.00')) {
    return fixed.slice(0, -3);
  }
  if (fixed.endsWith('0')) {
    return fixed.slice(0, -1);
  }
  return fixed;
}

function parseNonNegInt(raw: string, max: number, label: string): number {
  rejectSpecialNumericToken(raw, label);
  if (!NONNEG_INT_RE.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  let bi: bigint;
  try {
    bi = BigInt(raw);
  } catch {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  if (bi < 0n || bi > BigInt(max)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `cursor ${label} out of range`);
  }
  return Number(bi);
}

function assertNoUnexpectedSv2(sort: DiscoverySort, sv2: unknown): void {
  if (sv2 === undefined || sv2 === null) {
    return;
  }
  throw new AppError(
    ErrorCodes.VALIDATION_ERROR,
    `unexpected cursor sv2 for ${sort} sort`,
  );
}

function assertSvForSort(sort: DiscoverySort, sv: unknown, sv2: unknown): void {
  if (sv !== null && typeof sv !== 'string') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sv');
  }

  if (sort === 'best' || sort === 'rating') {
    if (typeof sv !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'missing cursor sv for rating sort');
    }
    if (typeof sv2 !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'missing cursor sv2 for rating sort');
    }
    parseNonNegDecimal(sv, CURSOR_RATING_MIN, CURSOR_RATING_MAX, 'sv');
    parseNonNegInt(sv2, CURSOR_PG_INT_MAX, 'sv2');
    return;
  }

  if (sort === 'cheapest' || sort === 'most_expensive') {
    assertNoUnexpectedSv2(sort, sv2);
    if (sv != null) {
      parsePriceCursorSv(sv);
    }
    return;
  }

  if (sort === 'near_me') {
    assertNoUnexpectedSv2(sort, sv2);
    if (sv != null) {
      parseNonNegInt(sv, CURSOR_DISTANCE_METERS_MAX, 'sv');
    }
    return;
  }

  if (sort === 'newest') {
    assertNoUnexpectedSv2(sort, sv2);
    if (sv != null) {
      if (typeof sv !== 'string') {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sv for newest sort');
      }
      assertStrictIsoUtc(sv);
    }
  }
}

/** Reject regex-matching but impossible dates (e.g. 2035-99-99T99:99:99Z) before SQL. */
function assertStrictIsoUtc(sv: string): void {
  if (!ISO_RE.test(sv)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sv for newest sort');
  }
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?Z$/.exec(sv);
  if (!m) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sv for newest sort');
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const h = Number(m[4]);
  const mi = Number(m[5]);
  const s = Number(m[6]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid cursor datetime for newest sort');
  }
  const dt = new Date(Date.UTC(y, mo - 1, d, h, mi, s));
  if (
    Number.isNaN(dt.getTime()) ||
    dt.getUTCFullYear() !== y ||
    dt.getUTCMonth() !== mo - 1 ||
    dt.getUTCDate() !== d ||
    dt.getUTCHours() !== h ||
    dt.getUTCMinutes() !== mi ||
    dt.getUTCSeconds() !== s
  ) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid cursor datetime for newest sort');
  }
}

export function decodeCursor(raw: string, expectedSort: DiscoverySort): KeysetCursorPayload {
  let parsed: KeysetCursorPayload;
  try {
    parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as KeysetCursorPayload;
  } catch {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor');
  }
  if (!parsed || parsed.v !== 1 || typeof parsed.sort !== 'string') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor');
  }
  assertUuid(parsed.id);
  if (parsed.sort !== expectedSort) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor sort mismatch');
  }
  const allowed: DiscoverySort[] = [
    'best',
    'rating',
    'cheapest',
    'most_expensive',
    'newest',
    'near_me',
  ];
  if (!allowed.includes(parsed.sort)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sort');
  }
  assertSvForSort(parsed.sort, parsed.sv, parsed.sv2);
  return parsed;
}

export function cursorFromRow(
  sort: DiscoverySort,
  row: {
    id: string;
    weighted_rating?: unknown;
    reviews_count?: unknown;
    starting_price_hint?: unknown;
    created_at?: unknown;
    distance_meters?: unknown;
    distance_km?: unknown;
  },
): string {
  const id = String(row.id);
  if (sort === 'cheapest' || sort === 'most_expensive') {
    return encodeCursor({
      v: 1,
      sort,
      sv: row.starting_price_hint == null ? null : formatPriceCursorSv(row.starting_price_hint),
      id,
    });
  }
  if (sort === 'newest') {
    return encodeCursor({
      v: 1,
      sort,
      sv:
        row.created_at == null
          ? null
          : row.created_at instanceof Date
            ? row.created_at.toISOString()
            : new Date(String(row.created_at)).toISOString(),
      id,
    });
  }
  if (sort === 'near_me') {
    let meters: number | null = null;
    if (row.distance_meters != null) {
      meters = Math.trunc(Number(row.distance_meters));
    } else if (row.distance_km != null) {
      meters = Math.round(Number(row.distance_km) * 1000);
    }
    return encodeCursor({
      v: 1,
      sort,
      sv: meters == null || !Number.isFinite(meters) ? null : String(meters),
      id,
    });
  }
  return encodeCursor({
    v: 1,
    sort,
    sv: String(Number(row.weighted_rating ?? 0)),
    sv2: String(Number(row.reviews_count ?? 0)),
    id,
  });
}
