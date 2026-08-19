/**
 * Pre-SQL Cursor v2 shape validation (Gate 7B.0.5).
 */
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import type {
  CursorV2Sort,
  DiversityTypeAfter,
  KeysetCursorV2Payload,
} from './discovery-cursor-v2';

export type DiversityCursorMode = 'required' | 'forbidden';

const CURSOR_DISTANCE_METERS_MAX = 20_050_000;
const DIVERSITY_VERSION_CURRENT = 1;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/;
const NONNEG_INT_RE = /^(?:0|[1-9]\d*)$/;
const PRICE_CURSOR_RE = /^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/;
/** Fixed-scale decimal — no IEEE Number compare. Allows optional leading minus. */
const DECIMAL_BODY_RE = /^-?(?:0|[1-9]\d*)(?:\.\d+)?$/;

const ALLOWED_TOP: ReadonlySet<string> = new Set([
  'v',
  'sort',
  'queryHash',
  'rankingEpoch',
  'rankingAsOf',
  'diversityVersion',
  'diversityK',
  'diversity',
  'sv',
  'sv2',
  'sv3',
  'id',
]);

function assertUuid(id: unknown, label = 'id'): asserts id is string {
  if (typeof id !== 'string' || !UUID_RE.test(id)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
}

function rejectSpecial(raw: string, label: string): void {
  if (/^[-+]?nan$/i.test(raw) || /^[-+]?infinity$/i.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `invalid cursor ${label}`);
  }
}

/** Compare decimal strings at fixed scale without Number precision loss. */
export function decimalStringInRange(
  raw: string,
  min: string,
  max: string,
  maxFrac: number,
  label: string,
): void {
  rejectSpecial(raw, label);
  if (!DECIMAL_BODY_RE.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  const frac = raw.includes('.') ? raw.split('.')[1].length : 0;
  if (frac > maxFrac) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  const scale = 10n ** BigInt(maxFrac);
  const toScaled = (s: string): bigint => {
    const neg = s.startsWith('-');
    const body = neg ? s.slice(1) : s;
    const [ip, fp = ''] = body.split('.');
    const padded = (fp + '0'.repeat(maxFrac)).slice(0, maxFrac);
    const v = BigInt(ip) * scale + BigInt(padded || '0');
    return neg ? -v : v;
  };
  const n = toScaled(raw);
  if (n < toScaled(min) || n > toScaled(max)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `cursor ${label} out of range`);
  }
}

function parseIntToken(raw: string, max: number, label: string): void {
  rejectSpecial(raw, label);
  if (!NONNEG_INT_RE.test(raw)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  const bi = BigInt(raw);
  if (bi < 0n || bi > BigInt(max)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `cursor ${label} out of range`);
  }
}

export function assertStrictIsoUtc(sv: string, label = 'sv'): void {
  if (!ISO_RE.test(sv)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,3})?Z$/.exec(sv);
  if (!m) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${label}`);
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const h = Number(m[4]);
  const mi = Number(m[5]);
  const s = Number(m[6]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `invalid cursor datetime for ${label}`);
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
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `invalid cursor datetime for ${label}`);
  }
}

function assertNoSv2(sort: CursorV2Sort, sv2: unknown): void {
  if (sv2 === undefined || sv2 === null) return;
  throw new AppError(ErrorCodes.VALIDATION_ERROR, `unexpected cursor sv2 for ${sort}`);
}

function assertNoSv3(sort: CursorV2Sort, sv3: unknown): void {
  if (sv3 === undefined || sv3 === null) return;
  throw new AppError(ErrorCodes.VALIDATION_ERROR, `unexpected cursor sv3 for ${sort}`);
}

export function assertSortKeyset(
  sort: CursorV2Sort,
  sv: unknown,
  sv2: unknown,
  sv3: unknown,
  labelPrefix = '',
): void {
  const p = labelPrefix ? `${labelPrefix}.` : '';
  if (sort === 'best') {
    if (typeof sv !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${p}sv for best`);
    }
    decimalStringInRange(sv, '0', '1', 6, `${p}sv`);
    if (typeof sv2 !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `missing cursor ${p}sv2 for best`);
    }
    // weighted_rating column is NUMERIC(4,2) — allow full column range (not star 0..5).
    decimalStringInRange(sv2, '-99.99', '99.99', 2, `${p}sv2`);
    if (typeof sv3 !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `missing cursor ${p}sv3 for best`);
    }
    parseIntToken(sv3, 2_147_483_647, `${p}sv3`);
    return;
  }
  if (sort === 'rating') {
    assertNoSv3(sort, sv3);
    if (typeof sv !== 'string' || typeof sv2 !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `missing cursor ${p}sv/sv2 for rating`);
    }
    decimalStringInRange(sv, '-99.99', '99.99', 2, `${p}sv`);
    parseIntToken(sv2, 2_147_483_647, `${p}sv2`);
    return;
  }
  if (sort === 'cheapest' || sort === 'most_expensive') {
    assertNoSv2(sort, sv2);
    assertNoSv3(sort, sv3);
    if (sv != null) {
      if (typeof sv !== 'string') {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${p}sv`);
      }
      rejectSpecial(sv, `${p}sv`);
      if (!PRICE_CURSOR_RE.test(sv)) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${p}sv for price`);
      }
      decimalStringInRange(sv, '0', '9999999999.99', 2, `${p}sv`);
    }
    return;
  }
  if (sort === 'newest') {
    assertNoSv2(sort, sv2);
    assertNoSv3(sort, sv3);
    if (sv != null) {
      if (typeof sv !== 'string') {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${p}sv`);
      }
      assertStrictIsoUtc(sv, `${p}sv`);
    }
    return;
  }
  if (sort === 'near_me' || sort === 'near_place') {
    assertNoSv2(sort, sv2);
    assertNoSv3(sort, sv3);
    if (sv != null) {
      if (typeof sv !== 'string') {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, `malformed cursor ${p}sv`);
      }
      parseIntToken(sv, CURSOR_DISTANCE_METERS_MAX, `${p}sv`);
    }
    return;
  }
  if (sort === 'search_rank') {
    assertNoSv3(sort, sv3);
    if (typeof sv !== 'string' || typeof sv2 !== 'string') {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `missing cursor ${p}sv/sv2 for search_rank`);
    }
    decimalStringInRange(sv, '0', '1', 6, `${p}sv`);
    decimalStringInRange(sv2, '0', '1', 6, `${p}sv2`);
    return;
  }
  throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor sort');
}

function assertTypeAfter(sort: CursorV2Sort, type: string, after: unknown): void {
  if (!type || typeof type !== 'string' || type.length > 64) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid diversity perTypeAfter key');
  }
  if (after == null || typeof after !== 'object' || Array.isArray(after)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid diversity perTypeAfter value');
  }
  const obj = after as DiversityTypeAfter;
  for (const k of Object.keys(obj)) {
    if (!['sv', 'sv2', 'sv3', 'id'].includes(k)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `unexpected diversity after field ${k}`);
    }
  }
  assertUuid(obj.id, `perTypeAfter.${type}.id`);
  assertSortKeyset(sort, obj.sv, obj.sv2, obj.sv3, `perTypeAfter.${type}`);
}

export function assertCursorV2PayloadShape(
  parsed: KeysetCursorV2Payload,
  diversityMode: DiversityCursorMode,
): void {
  if (diversityMode !== 'required' && diversityMode !== 'forbidden') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversityMode must be required|forbidden');
  }
  if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor');
  }
  for (const k of Object.keys(parsed as object)) {
    if (!ALLOWED_TOP.has(k)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `unexpected cursor field ${k}`);
    }
  }
  if (typeof parsed.queryHash !== 'string' || !/^[0-9a-f]{32}$/.test(parsed.queryHash)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor queryHash');
  }
  if (!Number.isInteger(parsed.rankingEpoch) || parsed.rankingEpoch < 1) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor rankingEpoch');
  }
  assertStrictIsoUtc(parsed.rankingAsOf, 'rankingAsOf');
  assertUuid(parsed.id);
  assertSortKeyset(parsed.sort, parsed.sv, parsed.sv2, parsed.sv3);

  const hasDiv = parsed.diversity != null;
  const hasVer = parsed.diversityVersion != null;
  const hasK = parsed.diversityK != null;
  const anyDiv = hasDiv || hasVer || hasK;

  if (diversityMode === 'forbidden') {
    if (anyDiv) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversity fields forbidden for this request');
    }
    return;
  }

  // diversityMode === 'required'
  if (!hasDiv || !hasVer || !hasK) {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      'diversity required: diversityVersion, diversityK, and diversity state',
    );
  }
  if (
    !Number.isInteger(parsed.diversityVersion) ||
    parsed.diversityVersion! < 1 ||
    parsed.diversityVersion! > DIVERSITY_VERSION_CURRENT
  ) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor diversityVersion');
  }
  if (
    !Number.isInteger(parsed.diversityK) ||
    parsed.diversityK! < 1 ||
    parsed.diversityK! > 10
  ) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'malformed cursor diversityK');
  }
  if (typeof parsed.diversity !== 'object' || Array.isArray(parsed.diversity)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid diversity state');
  }
  const d = parsed.diversity!;
  const required = ['lastType', 'streak', 'perTypeAfter'];
  for (const k of required) {
    if (!(k in d)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `missing diversity field ${k}`);
    }
  }
  for (const k of Object.keys(d)) {
    if (!required.includes(k)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, `unexpected diversity field ${k}`);
    }
  }
  if (!Number.isInteger(d.streak) || d.streak < 0 || d.streak > parsed.diversityK!) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid diversity streak');
  }
  if (d.lastType != null && (typeof d.lastType !== 'string' || d.lastType.length > 64)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid diversity lastType');
  }
  if (!d.perTypeAfter || typeof d.perTypeAfter !== 'object' || Array.isArray(d.perTypeAfter)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid diversity perTypeAfter');
  }
  for (const [t, after] of Object.entries(d.perTypeAfter)) {
    assertTypeAfter(parsed.sort, t, after);
  }
}
