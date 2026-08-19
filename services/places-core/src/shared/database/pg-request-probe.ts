/**
 * Request-local PostgreSQL query probe (test/evidence instrumentation).
 * Counts every PgService.query during an AsyncLocalStorage scope.
 */
import { AsyncLocalStorage } from 'async_hooks';

export interface PgRequestProbeState {
  total: number;
}

const als = new AsyncLocalStorage<PgRequestProbeState>();

export function getPgRequestProbe(): PgRequestProbeState | undefined {
  return als.getStore();
}

export function notePgQuery(): void {
  const s = als.getStore();
  if (s) s.total += 1;
}

/** Run `fn` with a fresh probe; nested calls replace the active store. */
export async function withPgRequestProbe<T>(
  fn: () => Promise<T>,
): Promise<{ value: T; queryCount: number }> {
  const store: PgRequestProbeState = { total: 0 };
  const value = await als.run(store, fn);
  return { value, queryCount: store.total };
}
