/**
 * Canonical Places Core background workers (Phase 6 / F-V3-005).
 * /healthz/workers fails closed (503) if any name is missing, stale, or error.
 */
export const CANONICAL_WORKERS = [
  "hold_expiry",
  "eligibility",
  "refund",
  "outbox",
  "media_cf_delete",
  "media_orphan",
] as const;

export type CanonicalWorkerName = (typeof CANONICAL_WORKERS)[number];

export function isCanonicalWorker(name: string): name is CanonicalWorkerName {
  return (CANONICAL_WORKERS as readonly string[]).includes(name);
}
