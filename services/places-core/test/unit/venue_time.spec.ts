import {
  tzOffsetMs,
  zonedWallTimeToUtcMs,
  hoursUntilCheckIn,
  checkInInstantReached,
  DEFAULT_CHECK_IN_TIME,
} from '../../src/shared/time/venue-time';

describe('venue-time (Phase 4 RC2 — tz-aware cancel/no-show anchors)', () => {
  it('Asia/Riyadh is UTC+3 with no DST', () => {
    const jan = Date.UTC(2026, 0, 15, 0, 0, 0);
    const jul = Date.UTC(2026, 6, 15, 0, 0, 0);
    expect(tzOffsetMs(jan, 'Asia/Riyadh')).toBe(3 * 36e5);
    expect(tzOffsetMs(jul, 'Asia/Riyadh')).toBe(3 * 36e5);
  });

  it('converts a Riyadh wall time to the correct UTC instant', () => {
    // 15:00 Riyadh == 12:00Z
    const inst = zonedWallTimeToUtcMs('2026-12-20', '15:00', 'Asia/Riyadh');
    expect(new Date(inst).toISOString()).toBe('2026-12-20T12:00:00.000Z');
  });

  it('honors a non-Riyadh timezone (America/New_York, EST UTC-5)', () => {
    // 18:00 New York (EST) == 23:00Z
    const inst = zonedWallTimeToUtcMs('2026-01-10', '18:00', 'America/New_York');
    expect(new Date(inst).toISOString()).toBe('2026-01-10T23:00:00.000Z');
  });

  it('hoursUntilCheckIn uses check_in_time, not midnight', () => {
    // now = 2026-12-19 12:00Z ; check-in 2026-12-20 15:00 Riyadh (=12:00Z) => 24h
    const now = Date.UTC(2026, 11, 19, 12, 0, 0);
    const hrs = hoursUntilCheckIn({
      checkInDate: '2026-12-20',
      timeZone: 'Asia/Riyadh',
      checkInTime: '15:00',
      nowMs: now,
    });
    expect(Math.round(hrs)).toBe(24);
  });

  it('midnight-vs-check_in_time differ by exactly the check_in_time offset', () => {
    const now = Date.UTC(2026, 11, 19, 0, 0, 0);
    const atMidnight = hoursUntilCheckIn({
      checkInDate: '2026-12-20',
      timeZone: 'Asia/Riyadh',
      checkInTime: '00:00',
      nowMs: now,
    });
    const at15 = hoursUntilCheckIn({
      checkInDate: '2026-12-20',
      timeZone: 'Asia/Riyadh',
      checkInTime: '15:00',
      nowMs: now,
    });
    expect(Math.round(at15 - atMidnight)).toBe(15);
  });

  it('default check-in time is 15:00 when null', () => {
    const now = Date.UTC(2026, 11, 20, 12, 0, 0);
    const withNull = hoursUntilCheckIn({
      checkInDate: '2026-12-20',
      timeZone: 'Asia/Riyadh',
      checkInTime: null,
      nowMs: now,
    });
    const withExplicit = hoursUntilCheckIn({
      checkInDate: '2026-12-20',
      timeZone: 'Asia/Riyadh',
      checkInTime: DEFAULT_CHECK_IN_TIME,
      nowMs: now,
    });
    expect(withNull).toBeCloseTo(withExplicit, 6);
  });

  it('checkInInstantReached is false before the local anchor, true at/after', () => {
    // event starts 18:00 Riyadh (=15:00Z) on 2026-12-20
    const before = Date.UTC(2026, 11, 20, 14, 59, 0); // 17:59 Riyadh
    const after = Date.UTC(2026, 11, 20, 15, 1, 0); // 18:01 Riyadh
    expect(
      checkInInstantReached({
        checkInDate: '2026-12-20',
        timeZone: 'Asia/Riyadh',
        checkInTime: '18:00',
        nowMs: before,
      }),
    ).toBe(false);
    expect(
      checkInInstantReached({
        checkInDate: '2026-12-20',
        timeZone: 'Asia/Riyadh',
        checkInTime: '18:00',
        nowMs: after,
      }),
    ).toBe(true);
  });
});
