/**
 * Process role for Places Core (Phase 6 / F-V3-005).
 * - api (default): HTTP only — workers do NOT auto-start timers
 * - worker: background only — timers start via OnModuleInit
 * Override: PLACES_RUN_WORKERS=true forces timers on (ops escape hatch).
 */
export type PlacesRunMode = 'api' | 'worker';

export function placesRunMode(): PlacesRunMode {
  const raw = (process.env.PLACES_RUN_MODE ?? 'api').trim().toLowerCase();
  return raw === 'worker' ? 'worker' : 'api';
}

export function shouldAutoStartWorkers(): boolean {
  if (process.env.NODE_ENV === 'test') {
    return false;
  }
  if (process.env.PLACES_RUN_WORKERS === 'true') {
    return true;
  }
  return placesRunMode() === 'worker';
}
