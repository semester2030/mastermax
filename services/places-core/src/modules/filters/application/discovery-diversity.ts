/**
 * Bounded mixed-feed diversity (Gate 7B.0.4 algorithm; Gate 7B.4 FilterEngine wiring).
 * Async/batched peek + sort-native keyset — no full-catalog snapshot / OFFSET.
 */

import {
  CursorV2Sort,
  DiversityCursorState,
  DiversityTypeAfter,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
} from './discovery-cursor-v2';

export interface DiversityCandidate {
  id: string;
  venueType: string;
  /** Primary sort key (matches Cursor v2 sv for active sort). */
  sv: string | null;
  sv2?: string | null;
  sv3?: string | null;
  /** Global preference among peeks (lower = prefer). Used when sort-native tie across types. */
  rankKey: string;
}

export type DiversityKeysetState = DiversityCursorState;

/** Per-key sort direction for ORDER BY (id always ASC as final tie-break). */
export const SORT_KEYSET_DIRS: Record<CursorV2Sort, readonly ('asc' | 'desc')[]> = {
  best: ['desc', 'desc', 'desc'],
  rating: ['desc', 'desc'],
  cheapest: ['asc'],
  most_expensive: ['desc'],
  newest: ['desc'],
  near_me: ['asc'],
  near_place: ['asc'],
  search_rank: ['desc', 'desc'],
};

export type DiversityPeekFn = (
  venueType: string,
  after: DiversityTypeAfter | undefined,
) => Promise<DiversityCandidate | null>;

export function emptyDiversityState(): DiversityKeysetState {
  return { lastType: null, streak: 0, perTypeAfter: {} };
}

function canEmit(state: DiversityKeysetState, type: string, k: number): boolean {
  return state.lastType !== type || state.streak < k;
}

function cmpStr(a: string, b: string): number {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

const NUMERIC_RE = /^(?:0|[1-9]\d*)(?:\.\d+)?$/;
const ISO_LIKE = /^\d{4}-\d{2}-\d{2}T/;

function cmpKey(a: string, b: string): number {
  if (a === b) return 0;
  if (ISO_LIKE.test(a) && ISO_LIKE.test(b)) return cmpStr(a, b);
  if (NUMERIC_RE.test(a) && NUMERIC_RE.test(b)) {
    const frac = Math.max(
      a.includes('.') ? a.split('.')[1].length : 0,
      b.includes('.') ? b.split('.')[1].length : 0,
    );
    const scale = 10n ** BigInt(frac);
    const toScaled = (s: string): bigint => {
      const [ip, fp = ''] = s.split('.');
      const padded = (fp + '0'.repeat(frac)).slice(0, frac);
      return BigInt(ip) * scale + BigInt(padded || '0');
    };
    const d = toScaled(a) - toScaled(b);
    return d < 0n ? -1 : d > 0n ? 1 : 0;
  }
  return cmpStr(a, b);
}

/**
 * ORDER BY compare with NULLS LAST.
 * Returns <0 if `a` appears before `b` in the result stream.
 */
export function orderCmpNullsLast(
  a: string | null | undefined,
  b: string | null | undefined,
  dir: 'asc' | 'desc',
): number {
  const aNull = a == null;
  const bNull = b == null;
  if (aNull && bNull) return 0;
  if (aNull) return 1;
  if (bNull) return -1;
  const d = cmpKey(a, b);
  return dir === 'asc' ? d : -d;
}

function keysOf(c: { sv: string | null; sv2?: string | null; sv3?: string | null }): (string | null)[] {
  return [c.sv, c.sv2 ?? null, c.sv3 ?? null];
}

/**
 * SQL-style keyset continuation for the active sort (NULLS LAST).
 * Deleted bookmarks resume without re-emitting earlier rows.
 */
export function isStrictlyAfterForSort(
  sort: CursorV2Sort,
  c: DiversityCandidate,
  after: DiversityTypeAfter,
): boolean {
  const dirs = SORT_KEYSET_DIRS[sort];
  const ck = keysOf(c);
  const ak = keysOf(after);
  for (let i = 0; i < dirs.length; i++) {
    const o = orderCmpNullsLast(ck[i], ak[i], dirs[i]);
    if (o !== 0) return o > 0;
  }
  return c.id > after.id;
}

/** @deprecated prefer isStrictlyAfterForSort — kept for simple desc streams in unit peeks */
export function isStrictlyAfterKeyset(
  c: DiversityCandidate,
  after: DiversityTypeAfter,
  dir: 'asc' | 'desc',
): boolean {
  const sort: CursorV2Sort = dir === 'desc' ? 'most_expensive' : 'cheapest';
  return isStrictlyAfterForSort(sort, c, after);
}

export function peekFromSortedStreams(
  streams: ReadonlyMap<string, readonly DiversityCandidate[]>,
  sort: CursorV2Sort = 'best',
): DiversityPeekFn {
  return async (venueType, after) => {
    const ordered = streams.get(venueType);
    if (!ordered || ordered.length === 0) return null;
    if (!after) return ordered[0] ?? null;
    for (const c of ordered) {
      if (isStrictlyAfterForSort(sort, c, after)) return c;
    }
    return null;
  };
}

/** Batched peek across types (Promise.all) — ready for DB/async backends. */
export async function peekAllTypes(
  types: readonly string[],
  perTypeAfter: Record<string, DiversityTypeAfter | undefined>,
  peek: DiversityPeekFn,
): Promise<DiversityCandidate[]> {
  const results = await Promise.all(types.map((t) => peek(t, perTypeAfter[t])));
  return results.filter((r): r is DiversityCandidate => r != null);
}

function toAfter(c: DiversityCandidate): DiversityTypeAfter {
  const after: DiversityTypeAfter = { sv: c.sv, id: c.id };
  if (c.sv2 !== undefined) after.sv2 = c.sv2;
  if (c.sv3 !== undefined) after.sv3 = c.sv3;
  return after;
}

export async function diversifyKeysetPage(
  types: readonly string[],
  peek: DiversityPeekFn,
  state: DiversityKeysetState,
  limit: number,
  maxConsecutiveSameType = DIVERSITY_K_DEFAULT,
  sort: CursorV2Sort = 'best',
): Promise<{ items: DiversityCandidate[]; nextState: DiversityKeysetState; exhausted: boolean }> {
  if (limit < 1) throw new Error('limit must be >= 1');
  if (maxConsecutiveSameType < 1) throw new Error('maxConsecutiveSameType must be >= 1');

  const items: DiversityCandidate[] = [];
  const next: DiversityKeysetState = {
    lastType: state.lastType,
    streak: state.streak,
    perTypeAfter: { ...state.perTypeAfter },
  };
  const dirs = SORT_KEYSET_DIRS[sort];

  while (items.length < limit) {
    const peeks = await peekAllTypes(types, next.perTypeAfter, peek);
    if (peeks.length === 0) break;

    const eligible = peeks.filter((p) => canEmit(next, p.venueType, maxConsecutiveSameType));
    const pool = eligible.length > 0 ? eligible : peeks;
    pool.sort((a, b) => {
      for (let i = 0; i < dirs.length; i++) {
        const o = orderCmpNullsLast(keysOf(a)[i], keysOf(b)[i], dirs[i]);
        if (o !== 0) return o;
      }
      // Final tie-break = id ASC only (rankKey must not precede id).
      return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
    const chosen = pool[0];
    items.push(chosen);
    next.perTypeAfter[chosen.venueType] = toAfter(chosen);
    if (chosen.venueType === next.lastType) {
      // When no alternate type exists, continue emitting but never store streak > K
      // so Cursor validators (streak <= diversityK) always accept the state.
      next.streak = Math.min(maxConsecutiveSameType, next.streak + 1);
    } else {
      next.lastType = chosen.venueType;
      next.streak = 1;
    }
  }

  const remain = await peekAllTypes(types, next.perTypeAfter, peek);
  return { items, nextState: next, exhausted: remain.length === 0 };
}

export function serializeDiversityState(state: DiversityKeysetState): string {
  return JSON.stringify(state);
}

export function deserializeDiversityState(raw: string): DiversityKeysetState {
  const parsed = JSON.parse(raw) as DiversityKeysetState;
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('malformed diversity state');
  }
  return {
    lastType: parsed.lastType ?? null,
    streak: parsed.streak ?? 0,
    perTypeAfter: parsed.perTypeAfter ?? {},
  };
}

export const DIVERSITY_META = {
  version: DIVERSITY_VERSION_CURRENT,
  defaultK: DIVERSITY_K_DEFAULT,
} as const;
