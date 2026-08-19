/**
 * Timezone-aware instants for cancel / no-show windows (Phase 4 RC2).
 *
 * Cancel windows and no-show eligibility must be anchored to the venue's local
 * wall-clock time (venues.timezone + venues.check_in_time), and for event_slot
 * bookings to the slot's start/end time (event_slot_templates.start_time /
 * end_time) — never to a hardcoded +03:00 midnight or a naive Date.now() date
 * comparison.
 */

/** Default check-in wall time when a venue leaves venues.check_in_time NULL. */
export const DEFAULT_CHECK_IN_TIME = '15:00';

/**
 * Offset (ms) between wall-clock time in `timeZone` and UTC at the given instant.
 * local_wall_epoch === utc_epoch + tzOffsetMs(utc_epoch, tz).
 */
export function tzOffsetMs(epochMs: number, timeZone: string): number {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const map: Record<string, string> = {};
  for (const p of dtf.formatToParts(new Date(epochMs))) {
    if (p.type !== 'literal') {
      map[p.type] = p.value;
    }
  }
  let hour = Number(map.hour);
  if (hour === 24) {
    // Some ICU builds emit hour '24' for midnight.
    hour = 0;
  }
  const wallAsUtc = Date.UTC(
    Number(map.year),
    Number(map.month) - 1,
    Number(map.day),
    hour,
    Number(map.minute),
    Number(map.second),
  );
  return wallAsUtc - epochMs;
}

/** Parse "HH:MM" or "HH:MM:SS" → { h, m }. Falls back to 00:00 on garbage. */
function parseHhMm(time: string | null | undefined): { h: number; m: number } {
  if (!time) {
    return { h: 0, m: 0 };
  }
  const [hh, mm] = time.split(':');
  const h = Number(hh);
  const m = Number(mm);
  return {
    h: Number.isFinite(h) ? h : 0,
    m: Number.isFinite(m) ? m : 0,
  };
}

/**
 * Absolute UTC instant (ms) of a local wall-clock date+time in `timeZone`.
 * Two-pass correction handles DST transitions generically (Asia/Riyadh has none).
 */
export function zonedWallTimeToUtcMs(
  dateIso: string,
  time: string | null | undefined,
  timeZone: string,
): number {
  const [y, mo, d] = dateIso.split('-').map(Number);
  const { h, m } = parseHhMm(time);
  const guess = Date.UTC(y, mo - 1, d, h, m, 0);
  let inst = guess - tzOffsetMs(guess, timeZone);
  inst = guess - tzOffsetMs(inst, timeZone);
  return inst;
}

/**
 * Hours from `nowMs` until the booking's check-in instant, computed in the
 * venue timezone using check_in_time (or slot start_time for event_slot).
 * Positive => check-in is in the future.
 */
export function hoursUntilCheckIn(input: {
  checkInDate: string;
  timeZone: string;
  checkInTime?: string | null;
  nowMs?: number;
}): number {
  const now = input.nowMs ?? Date.now();
  const anchor = zonedWallTimeToUtcMs(
    input.checkInDate,
    input.checkInTime ?? DEFAULT_CHECK_IN_TIME,
    input.timeZone,
  );
  return (anchor - now) / 36e5;
}

/**
 * True when the check-in instant (venue-local date + time) has been reached.
 * For non-event bookings this gates no-show; for event_slot pass the slot
 * start_time so no-show cannot be marked before the event starts.
 */
export function checkInInstantReached(input: {
  checkInDate: string;
  timeZone: string;
  checkInTime?: string | null;
  nowMs?: number;
}): boolean {
  const now = input.nowMs ?? Date.now();
  const anchor = zonedWallTimeToUtcMs(
    input.checkInDate,
    input.checkInTime ?? DEFAULT_CHECK_IN_TIME,
    input.timeZone,
  );
  return now >= anchor;
}
