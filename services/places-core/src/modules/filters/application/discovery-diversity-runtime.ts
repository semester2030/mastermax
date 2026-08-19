/**
 * Gate 7B.4.3 — Fixed-chunk Mixed Feed Diversity runtime.
 * B = max(1, ceil(limit / typeCount)); warm+refill fetch B only.
 * candidateQueryCount ≤ 2×typeCount + 1
 * candidateProjectionRows ≤ 2×(typeCount + limit)
 * No OFFSET / full snapshot / per-item N+1 / types×limit preload.
 */
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { PgService } from '../../../shared/database/pg.service';
import {
  CursorV2Sort,
  DiversityCursorState,
  DiversityTypeAfter,
  KeysetCursorV2Payload,
  RANKING_EPOCH_CURRENT,
} from './discovery-cursor-v2';
import { formatWeightedRatingCursorSv } from './discovery-cursor-encode';
import { BuiltDiscoveryQuery } from './discovery-query';
import { discoveryPageSql } from './discovery-page-sql';
import {
  DiversityCandidate,
  DiversityPeekFn,
  diversifyKeysetPage,
  emptyDiversityState,
  isStrictlyAfterForSort,
} from './discovery-diversity';

function createdAtSv(value: unknown): string | null {
  if (value == null) return null;
  const d = value instanceof Date ? value : new Date(String(value));
  if (!Number.isFinite(d.getTime())) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid created_at for diversity peek');
  }
  return d.toISOString();
}

export function rowToDiversityCandidate(
  sort: CursorV2Sort,
  row: Record<string, unknown>,
): DiversityCandidate {
  const id = String(row.id);
  const venueType = String(row.venue_type);
  if (sort === 'best') {
    return {
      id,
      venueType,
      sv: Number(row.best_score ?? 0).toFixed(6),
      sv2: formatWeightedRatingCursorSv(row.weighted_rating),
      sv3: String(Number(row.reviews_count ?? 0)),
      rankKey: id,
    };
  }
  if (sort === 'newest') {
    return {
      id,
      venueType,
      sv: createdAtSv(row.created_at),
      rankKey: id,
    };
  }
  throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversity only supports best|newest');
}

export function typeAfterAsCursorPayload(
  sort: CursorV2Sort,
  after: DiversityTypeAfter,
  rankingAsOf: string,
): KeysetCursorV2Payload {
  return {
    v: 2,
    sort,
    queryHash: '0'.repeat(32),
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf,
    sv: after.sv,
    sv2: after.sv2,
    sv3: after.sv3,
    id: after.id,
  };
}

/** Fixed chunk B = max(1, ceil(limit / typeCount)). */
export function computeChunkSize(limit: number, typeCount: number): number {
  if (limit < 1) return 1;
  if (typeCount < 1) return 1;
  return Math.max(1, Math.ceil(limit / typeCount));
}

/** @deprecated alias — prefer computeChunkSize (Gate 7B.4.3). */
export function computeInitialBatch(limit: number, typeCount: number): number {
  return computeChunkSize(limit, typeCount);
}

export function diversityRowBound(typeCount: number, limit: number): number {
  return 2 * (typeCount + limit);
}

/** Warm (T) + refill budget (T+1) ⇒ ≤ 2T+1 candidate queries. */
export function diversityCandidateQueryBound(typeCount: number): number {
  return 2 * typeCount + 1;
}

export async function loadCandidateVenueTypes(
  pg: PgService,
  built: BuiltDiscoveryQuery,
): Promise<string[]> {
  const res = await pg.query<{ venue_type: string }>(
    `SELECT DISTINCT v.venue_type
     FROM venues v
     WHERE ${built.whereSql}
     ORDER BY v.venue_type ASC`,
    built.whereParams,
  );
  return res.rows.map((r) => r.venue_type);
}

export type DiversityQueryRebuild = (
  venueType: string,
  after: DiversityTypeAfter | undefined,
) => BuiltDiscoveryQuery;

export interface DiversityPageMetrics {
  /**
   * PG queries outside COUNT + DISTINCT + candidates (intent / caps / anchor / labels / …).
   * Filled by FilterEngine from request-local probe; runtime leaves 0.
   */
  resolverQueryCount: number;
  /** Outer COUNT(*) for total — filled by FilterEngine. */
  countQueryCount: number;
  /** DISTINCT types query count (0|1). */
  distinctQueryCount: number;
  /** Rows returned by DISTINCT (type count). */
  distinctRowCount: number;
  /** Per-type candidate/projection peeks + refills only. */
  candidateQueryCount: number;
  /** Projection rows fetched across candidate queries. */
  candidateProjectionRows: number;
  /** Alias of candidateProjectionRows (compat). */
  rowsFetched: number;
  /** Rows emitted on this page. */
  returnedRowCount: number;
  /**
   * Honest total = observed PgService.query count for the request (FilterEngine probe).
   * Not a sum of guessed buckets.
   */
  totalRequestQueryCount: number;
  /** Observed probe total (same as totalRequestQueryCount when instrumented). */
  observedPgQueryCount?: number;
  /** distinct + candidate only (compat; excludes resolvers/COUNT). */
  queryCount: number;
  typeCount: number;
  limit: number;
  chunkSize: number;
  /** Compat alias of chunkSize. */
  initialBatch: number;
  rowBound: number;
  candidateQueryBound: number;
}

export interface DiversityPageResult {
  rows: Record<string, unknown>[];
  nextState: DiversityCursorState;
  exhausted: boolean;
  metrics: DiversityPageMetrics;
}

export function toAfter(c: DiversityCandidate): DiversityTypeAfter {
  const after: DiversityTypeAfter = { sv: c.sv, id: c.id };
  if (c.sv2 !== undefined) after.sv2 = c.sv2;
  if (c.sv3 !== undefined) after.sv3 = c.sv3;
  return after;
}

/**
 * Fixed-chunk peek:
 * - Warm: B rows per type (typeCount queries).
 * - Refill: B rows whenever a type buffer empties; unlimited refills per type.
 * - Always resumes from the same per-type keyset (`after`).
 */
export function makeFixedChunkDiversityPeek(opts: {
  pg: PgService;
  rebuild: DiversityQueryRebuild;
  sort: CursorV2Sort;
  types: readonly string[];
  chunkSize: number;
  perTypeAfter: Record<string, DiversityTypeAfter | undefined>;
  metrics: { candidateQueryCount: number; candidateProjectionRows: number };
  rowById: Map<string, Record<string, unknown>>;
}): { peek: DiversityPeekFn; warm: () => Promise<void> } {
  const buffers = new Map<string, DiversityCandidate[]>();
  const exhausted = new Map<string, boolean>();

  async function fetchBatch(
    venueType: string,
    after: DiversityTypeAfter | undefined,
    batchSize: number,
  ): Promise<DiversityCandidate[]> {
    const built = opts.rebuild(venueType, after);
    const pageWhere = built.cursorSql
      ? `${built.whereSql} AND (${built.cursorSql})`
      : built.whereSql;
    const pageParams = [
      ...built.whereParams,
      ...built.sortParams,
      ...built.cursorParams,
      batchSize,
    ];
    const sql = discoveryPageSql(built, pageWhere, pageParams.length);
    opts.metrics.candidateQueryCount += 1;
    const res = await opts.pg.query(sql, pageParams);
    opts.metrics.candidateProjectionRows += res.rows.length;
    if (res.rows.length < batchSize) exhausted.set(venueType, true);
    const out: DiversityCandidate[] = [];
    for (const r of res.rows as Record<string, unknown>[]) {
      const c = rowToDiversityCandidate(opts.sort, r);
      opts.rowById.set(c.id, r);
      out.push(c);
    }
    return out;
  }

  async function warm(): Promise<void> {
    await Promise.all(
      opts.types.map(async (venueType) => {
        const after = opts.perTypeAfter[venueType];
        const batch = await fetchBatch(venueType, after, opts.chunkSize);
        buffers.set(venueType, batch);
      }),
    );
  }

  const peek: DiversityPeekFn = async (venueType, after) => {
    let buf = buffers.get(venueType) ?? [];
    if (after) {
      buf = buf.filter((c) => isStrictlyAfterForSort(opts.sort, c, after));
    }
    buffers.set(venueType, buf);

    while (buf.length === 0 && !exhausted.get(venueType)) {
      const batch = await fetchBatch(venueType, after, opts.chunkSize);
      buf = batch.filter((c) => !after || isStrictlyAfterForSort(opts.sort, c, after));
      buffers.set(venueType, buf);
      if (buf.length === 0) break;
    }

    if (buf.length === 0) return null;
    return buf[0];
  };

  return { peek, warm };
}

/** @deprecated name — Gate 7B.4.3 uses makeFixedChunkDiversityPeek. */
export const makeBatchedDiversityPeek = makeFixedChunkDiversityPeek;

function buildMetrics(partial: {
  distinctQueryCount: number;
  distinctRowCount: number;
  candidateQueryCount: number;
  candidateProjectionRows: number;
  returnedRowCount: number;
  typeCount: number;
  limit: number;
  chunkSize: number;
  rowBound: number;
  candidateQueryBound: number;
}): DiversityPageMetrics {
  // resolver/count/total filled by FilterEngine from request-local Pg probe.
  return {
    resolverQueryCount: 0,
    countQueryCount: 0,
    distinctQueryCount: partial.distinctQueryCount,
    distinctRowCount: partial.distinctRowCount,
    candidateQueryCount: partial.candidateQueryCount,
    candidateProjectionRows: partial.candidateProjectionRows,
    rowsFetched: partial.candidateProjectionRows,
    returnedRowCount: partial.returnedRowCount,
    totalRequestQueryCount: 0,
    queryCount: partial.distinctQueryCount + partial.candidateQueryCount,
    typeCount: partial.typeCount,
    limit: partial.limit,
    chunkSize: partial.chunkSize,
    initialBatch: partial.chunkSize,
    rowBound: partial.rowBound,
    candidateQueryBound: partial.candidateQueryBound,
  };
}

export async function runMixedFeedDiversityPage(
  pg: PgService,
  baseBuilt: BuiltDiscoveryQuery,
  rebuild: DiversityQueryRebuild,
  limit: number,
  priorState: DiversityCursorState | null,
): Promise<DiversityPageResult> {
  const metrics = { candidateQueryCount: 0, candidateProjectionRows: 0 };
  const distinctQueryCount = 1;
  const types = await loadCandidateVenueTypes(pg, baseBuilt);
  const state = priorState ?? emptyDiversityState();
  const typeCount = types.length;
  const chunkSize = computeChunkSize(limit, Math.max(typeCount, 1));
  const rowBound = diversityRowBound(typeCount, limit);
  const candidateQueryBound = diversityCandidateQueryBound(typeCount);

  if (types.length === 0) {
    return {
      rows: [],
      nextState: state,
      exhausted: true,
      metrics: buildMetrics({
        distinctQueryCount,
        distinctRowCount: 0,
        candidateQueryCount: 0,
        candidateProjectionRows: 0,
        returnedRowCount: 0,
        typeCount: 0,
        limit,
        chunkSize,
        rowBound,
        candidateQueryBound: 0,
      }),
    };
  }

  const rowById = new Map<string, Record<string, unknown>>();
  const { peek, warm } = makeFixedChunkDiversityPeek({
    pg,
    rebuild,
    sort: baseBuilt.sort,
    types,
    chunkSize,
    perTypeAfter: state.perTypeAfter,
    metrics,
    rowById,
  });
  await warm();

  const page = await diversifyKeysetPage(types, peek, state, limit, undefined, baseBuilt.sort);
  const rows = page.items.map((c) => {
    const row = rowById.get(c.id);
    if (!row) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'diversity emit missing row');
    }
    return row;
  });

  return {
    rows,
    nextState: page.nextState,
    exhausted: page.exhausted,
    metrics: buildMetrics({
      distinctQueryCount,
      distinctRowCount: typeCount,
      candidateQueryCount: metrics.candidateQueryCount,
      candidateProjectionRows: metrics.candidateProjectionRows,
      returnedRowCount: rows.length,
      typeCount,
      limit,
      chunkSize,
      rowBound,
      candidateQueryBound,
    }),
  };
}
