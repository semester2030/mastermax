export type BookingMode = 'nightly' | 'daily' | 'event_slot';

/**
 * Nightly: [checkIn, checkOut).
 * Daily: inclusive calendar dates.
 * event_slot: single day = checkIn (checkOut ignored for length; must be >= checkIn).
 */
export function stayDates(
  mode: BookingMode,
  checkIn: string,
  checkOut: string,
): string[] {
  const start = parseIsoDate(checkIn);
  const end = parseIsoDate(checkOut);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    throw new Error('invalid dates');
  }
  if (mode === 'event_slot') {
    if (end < start) {
      throw new Error('end must be on/after start');
    }
    return [toIsoDate(start)];
  }
  if (mode === 'nightly' && end <= start) {
    throw new Error('checkOut must be after checkIn');
  }
  if (mode === 'daily' && end < start) {
    throw new Error('end must be on/after start');
  }
  const dates: string[] = [];
  const cursor = new Date(start);
  const last = mode === 'nightly' ? addDays(end, -1) : end;
  while (cursor <= last) {
    dates.push(toIsoDate(cursor));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  if (dates.length === 0) {
    throw new Error('stay produces no dates');
  }
  return dates;
}

/**
 * SQL `generate_series(...)` matching {@link stayDates} for a booking_mode expression.
 * Valid as a FROM-item (CASE wrapping generate_series is illegal in PostgreSQL).
 * Used by Discovery so dated filters share nightly/daily/event_slot semantics with Quote/Hold.
 */
export function stayDatesSqlSeries(
  checkInSql: string,
  checkOutSql: string,
  modeSql: string,
): string {
  return `generate_series(
    ${checkInSql}::date,
    CASE
      WHEN ${modeSql} = 'daily' THEN ${checkOutSql}::date
      WHEN ${modeSql} = 'event_slot' THEN ${checkInSql}::date
      ELSE GREATEST((${checkOutSql}::date - 1), ${checkInSql}::date)
    END,
    '1 day'::interval
  )`;
}

/** Predicate: stay day open under availability_rules + type-level overrides. */
export function stayDayOpenUnderRulesSql(
  inventoryTypeAlias: string,
  daySql: string,
): string {
  const it = inventoryTypeAlias;
  const day = daySql;
  return `(
    NOT EXISTS (
      SELECT 1 FROM availability_overrides ao_block
      WHERE ao_block.inventory_type_id = ${it}.id
        AND ao_block.inventory_unit_id IS NULL
        AND ao_block.date = (${day})::date
        AND ao_block.kind IN ('block', 'maintenance')
    )
    AND (
      EXISTS (
        SELECT 1 FROM availability_overrides ao_open
        WHERE ao_open.inventory_type_id = ${it}.id
          AND ao_open.inventory_unit_id IS NULL
          AND ao_open.date = (${day})::date
          AND ao_open.kind = 'open'
      )
      OR NOT EXISTS (
        SELECT 1 FROM availability_rules ar0 WHERE ar0.inventory_type_id = ${it}.id
      )
      OR EXISTS (
        SELECT 1 FROM availability_rules ar
        WHERE ar.inventory_type_id = ${it}.id
          AND ar.is_open = TRUE
          AND (ar.effective_from IS NULL OR (${day})::date >= ar.effective_from)
          AND (ar.effective_to IS NULL OR (${day})::date <= ar.effective_to)
          AND ((ar.dow_mask >> EXTRACT(DOW FROM (${day})::timestamp)::int) & 1) = 1
      )
    )
  )`;
}

export function parseIsoDate(value: string): Date {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

export function toIsoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function addDays(d: Date, n: number): Date {
  const x = new Date(d);
  x.setUTCDate(x.getUTCDate() + n);
  return x;
}

/** Saudi weekend: Friday + Saturday (Asia/Riyadh). */
export function isWeekend(isoDate: string): boolean {
  const dow = parseIsoDate(isoDate).getUTCDay();
  return dow === 5 || dow === 6;
}

/** Asia/Riyadh calendar today (YYYY-MM-DD) for inventory release filters. */
export function riyadhTodayIso(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Riyadh' }).format(
    new Date(),
  );
}
