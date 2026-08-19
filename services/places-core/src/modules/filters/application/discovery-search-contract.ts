/**
 * Search contract (Gate 7B.2 closed by 7B.3.1).
 * NFC + AR/EN normalize aligned with places_normalize_search (migration 011).
 * Phrases = independent AND conjuncts: (document match OR resolved venue types).
 * % _ \ are literal text via escaped ILIKE binds (not rejected).
 */

import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

export const SEARCH_TOKEN_MAX = 8;
export const SEARCH_SIMILARITY_THRESHOLD = 0.25;
export const SEARCH_Q_MIN_LEN = 2;
export const SEARCH_Q_MAX_LEN = 100;

const AR_DIACRITICS = /[\u064B-\u065F\u0670\u06D6-\u06ED]/g;
const AR_TATWEEL = /\u0640/g;
const AR_ALEF = /[\u0622\u0623\u0625\u0671]/g;
const AR_YEH = /[\u0649\u06CC]/g;
const AR_TEH_MARBUTA = /\u0629/g;

export function normalizeSearchText(input: string): string {
  let s = input.normalize('NFC');
  s = s.replace(AR_TATWEEL, '');
  s = s.replace(AR_DIACRITICS, '');
  s = s.replace(AR_ALEF, '\u0627');
  s = s.replace(AR_YEH, '\u064A');
  s = s.replace(AR_TEH_MARBUTA, '\u0647');
  s = s.toLowerCase();
  s = s.replace(/\s+/g, ' ').trim();
  return s;
}

export function escapeLikeLiteral(token: string): string {
  return token.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_');
}

/**
 * blank/whitespace → null (no search).
 * single-char / too short → 400. % _ \ kept as literals.
 */
export function prepareSearchQuery(q: string): string[] | null {
  if (typeof q !== 'string' || !q.trim()) return null;
  return tokenizeSearchQuery(q);
}

/** @deprecated use prepareSearchQuery — blank no longer throws. */
export function assertSearchQuery(q: string): string[] {
  const tokens = prepareSearchQuery(q);
  if (!tokens) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'q blank');
  }
  return tokens;
}

export function tokenizeSearchQuery(q: string): string[] {
  const trimmed = normalizeSearchText(q);
  if (!trimmed) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'q blank');
  }
  if (trimmed.length < SEARCH_Q_MIN_LEN) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'q too short');
  }
  if (trimmed.length > SEARCH_Q_MAX_LEN) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'q too long');
  }
  const tokens = trimmed.split(' ').filter(Boolean);
  if (tokens.length > SEARCH_TOKEN_MAX) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'q too many tokens');
  }
  return tokens;
}

export interface LabelPhrase {
  phrase: string;
  venueTypes: readonly string[];
}

export interface TokenMatchPlan {
  raw: string;
  escaped: string;
  venueTypesFromLabel: string[];
}

/** Multi-word phrase conjunct (document OR types). */
export interface PhraseMatchPlan {
  raw: string;
  escaped: string;
  venueTypes: string[];
}

export interface PlannedSearch {
  plans: TokenMatchPlan[];
  phrasePlans: PhraseMatchPlan[];
  /** @deprecated aggregated dump — prefer phrasePlans */
  phraseVenueTypes: string[];
}

/** Merge independent label rows that share a normalized phrase into one Set. */
export function aggregateLabelPhrases(labels: LabelPhrase[]): Map<string, Set<string>> {
  const map = new Map<string, Set<string>>();
  for (const lab of labels) {
    const phrase = normalizeSearchText(lab.phrase);
    if (!phrase) continue;
    const set = map.get(phrase) ?? new Set<string>();
    for (const vt of lab.venueTypes) set.add(vt);
    map.set(phrase, set);
  }
  return map;
}

/**
 * Aggregate phrases first, then longest-phrase-first consume.
 * Each matched multi-word phrase → independent conjunct.
 * Remaining tokens AND; same phrase merges types across label rows.
 */
export function planSearchTokens(
  tokens: string[],
  labels: LabelPhrase[],
): PlannedSearch {
  const aggregated = aggregateLabelPhrases(labels);
  const byLen = [...aggregated.entries()].sort((a, b) => b[0].length - a[0].length);
  const used = new Array(tokens.length).fill(false);
  const phrasePlans: PhraseMatchPlan[] = [];
  const lower = tokens.map((t) => normalizeSearchText(t));

  for (const [phrase, types] of byLen) {
    const parts = phrase.split(' ').filter(Boolean);
    if (parts.length < 2) continue;
    for (let i = 0; i <= lower.length - parts.length; i++) {
      if (used.slice(i, i + parts.length).some(Boolean)) continue;
      if (parts.every((p, j) => lower[i + j] === p)) {
        for (let j = 0; j < parts.length; j++) used[i + j] = true;
        phrasePlans.push({
          raw: phrase,
          escaped: escapeLikeLiteral(phrase),
          venueTypes: [...types],
        });
      }
    }
  }

  const single = new Map<string, Set<string>>();
  for (const [phrase, types] of aggregated) {
    if (phrase.includes(' ')) continue;
    single.set(phrase, types);
  }

  const plans: TokenMatchPlan[] = [];
  tokens.forEach((_token, i) => {
    if (used[i]) return;
    const raw = lower[i];
    const types = single.get(raw);
    plans.push({
      raw,
      escaped: escapeLikeLiteral(raw),
      venueTypesFromLabel: types ? [...types] : [],
    });
  });
  return {
    plans,
    phrasePlans,
    phraseVenueTypes: phrasePlans.flatMap((p) => p.venueTypes),
  };
}

function matchConjunctSql(rawP: number, escP: number, typeP: number): string {
  // `%` uses gin_trgm with pg_trgm.similarity_threshold (set to SEARCH_SIMILARITY_THRESHOLD
  // on the pool). Equivalent to similarity(doc, token) >= threshold — index-friendly.
  return `(
      v.search_document ILIKE '%' || $${escP} || '%' ESCAPE '\\'
      OR v.search_document % $${rawP}
      OR (cardinality($${typeP}::text[]) > 0 AND v.venue_type = ANY($${typeP}::text[]))
    )`;
}

export function buildSearchPredicate(
  planCount: number,
  phrasePlanCountOrHasPhrase: number | boolean,
  startP: number,
): { sql: string; bindCount: number } {
  const phrasePlanCount =
    typeof phrasePlanCountOrHasPhrase === 'boolean'
      ? phrasePlanCountOrHasPhrase
        ? 1
        : 0
      : phrasePlanCountOrHasPhrase;
  if (planCount < 1 && phrasePlanCount < 1) {
    return { sql: 'TRUE', bindCount: 0 };
  }
  // Legacy boolean=true: append single venue_type ANY bind (pre-7B.3.1 shape)
  if (typeof phrasePlanCountOrHasPhrase === 'boolean' && phrasePlanCountOrHasPhrase) {
    const parts: string[] = [];
    let p = startP;
    const rawBase = p;
    p += planCount;
    const escBase = p;
    p += planCount;
    const typeBase = p;
    p += planCount;
    for (let i = 0; i < planCount; i++) {
      parts.push(matchConjunctSql(rawBase + i, escBase + i, typeBase + i));
    }
    const tokenAnd = parts.length > 0 ? parts.join(' AND ') : 'TRUE';
    const sql = `((${tokenAnd}) AND v.venue_type = ANY($${p}::text[]))`;
    return { sql, bindCount: p + 1 - startP };
  }

  const parts: string[] = [];
  let p = startP;
  for (let i = 0; i < planCount; i++) {
    parts.push(matchConjunctSql(p, p + 1, p + 2));
    p += 3;
  }
  for (let i = 0; i < phrasePlanCount; i++) {
    parts.push(matchConjunctSql(p, p + 1, p + 2));
    p += 3;
  }
  return { sql: parts.join(' AND '), bindCount: p - startP };
}

export function flattenSearchParams(
  plans: TokenMatchPlan[],
  phrasePlansOrTypes: PhraseMatchPlan[] | string[] = [],
): unknown[] {
  if (
    phrasePlansOrTypes.length > 0 &&
    typeof (phrasePlansOrTypes as unknown[])[0] === 'string'
  ) {
    const types = phrasePlansOrTypes as string[];
    const raws = plans.map((x) => x.raw);
    const escaped = plans.map((x) => x.escaped);
    const typeArrs = plans.map((x) => x.venueTypesFromLabel);
    return [...raws, ...escaped, ...typeArrs, types];
  }
  const phrasePlans = phrasePlansOrTypes as PhraseMatchPlan[];
  const out: unknown[] = [];
  for (const x of plans) {
    out.push(x.raw, x.escaped, x.venueTypesFromLabel);
  }
  for (const x of phrasePlans) {
    out.push(x.raw, x.escaped, x.venueTypes);
  }
  return out;
}

export function searchRankSql(rawArrayParamIndex: number): string {
  return `(
  SELECT COALESCE(AVG(similarity(v.search_document, t.token)), 0)::numeric(8,6)
  FROM unnest($${rawArrayParamIndex}::text[]) AS t(token)
)`;
}

export const SEARCH_INDEX_CONTRACT =
  'CREATE INDEX idx_venues_search_document_trgm ON venues USING gin (search_document gin_trgm_ops)';

export const SEARCH_PERF_STATUS =
  'SEE_GATE7B31_EXPLAIN — representative EXPLAIN(ANALYZE,BUFFERS) in pack; further tuning deferred to 7B.5 if needed';
