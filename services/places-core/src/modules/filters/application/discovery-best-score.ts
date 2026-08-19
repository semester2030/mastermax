/**
 * Locked best_score SQL (Gate 7B.3 / closed 7B.3.1).
 * Weights: rating 0.45 + reviews 0.20 + freshness 0.15 + playable media 0.10.
 * No availability_hint / proximity.
 * Domain NUMERIC(8,6).
 *
 * Gate 7B.5.1: rating+reviews+video are STORED as venues.best_score_static
 * (identical algebra); query adds freshness only. Projection/ORDER BY stay equal.
 */
/** rankingAsOfParam = $n bind of timestamptz used as freshness "now". */
export function bestScoreSqlExpr(rankingAsOfParam: number): string {
  return `(
  (
    COALESCE(v.best_score_static, 0::numeric)
    + 0.15 * EXP(
      -LN(2) * GREATEST(
        0,
        EXTRACT(EPOCH FROM ($${rankingAsOfParam}::timestamptz - v.created_at)) / 86400.0
      ) / 90.0
    )
  )::numeric(8,6)
)`;
}
