/**
 * Deterministic in-process rendezvous for concurrent hold races (Phase 7 RC3).
 * Armed by tests; production env never sets PLACES_HOLD_BARRIER so this is a no-op.
 */
let need = 0;
let waiters: Array<() => void> = [];
let released = false;

export function armHoldBarrier(n: number): void {
  need = n;
  waiters = [];
  released = false;
}

export function releaseHoldBarrier(): void {
  released = true;
  const pending = waiters;
  waiters = [];
  for (const w of pending) w();
}

export function holdBarrierArrive(): Promise<void> {
  if (process.env.PLACES_HOLD_BARRIER !== '1') {
    return Promise.resolve();
  }
  if (released) {
    return Promise.resolve();
  }
  return new Promise((resolve) => {
    waiters.push(resolve);
    if (waiters.length >= need && need > 0) {
      releaseHoldBarrier();
    }
  });
}
