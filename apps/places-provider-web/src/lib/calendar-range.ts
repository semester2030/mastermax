/** Inclusive YYYY-MM-DD range helpers. No timezone math beyond the date string. */

const ISO = /^(\d{4})-(\d{2})-(\d{2})$/;

export function isIsoDate(value: string): boolean {
  if (!ISO.test(value)) return false;
  const [y, m, d] = value.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  return (
    dt.getUTCFullYear() === y &&
    dt.getUTCMonth() === m - 1 &&
    dt.getUTCDate() === d
  );
}

export function eachIsoDate(from: string, to: string, maxDays = 62): string[] {
  if (!isIsoDate(from) || !isIsoDate(to)) return [];
  if (from > to) return [];
  const out: string[] = [];
  let cursor = from;
  while (cursor <= to) {
    out.push(cursor);
    if (out.length > maxDays) return out.slice(0, maxDays);
    const [y, m, d] = cursor.split("-").map(Number);
    const next = new Date(Date.UTC(y, m - 1, d + 1));
    cursor = next.toISOString().slice(0, 10);
  }
  return out;
}

export function monthGrid(year: number, monthIndex: number): (string | null)[] {
  const first = new Date(Date.UTC(year, monthIndex, 1));
  const startPad = first.getUTCDay(); // Sunday-first, matches Arabic week labels
  const days = new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();
  const cells: (string | null)[] = Array.from({ length: startPad }, () => null);
  for (let d = 1; d <= days; d++) {
    const iso = new Date(Date.UTC(year, monthIndex, d)).toISOString().slice(0, 10);
    cells.push(iso);
  }
  while (cells.length % 7 !== 0) cells.push(null);
  return cells;
}

export type CalendarDay = {
  date: string;
  inventoryTypeId?: string;
  available?: number;
  blocked?: number;
  booked?: number;
  held?: number;
};

export function calendarDateOf(row: Record<string, unknown>): string {
  const raw = row.date ?? row.day;
  if (typeof raw === "string") return raw.slice(0, 10);
  if (raw instanceof Date) return raw.toISOString().slice(0, 10);
  return "";
}

export function asCalendarDays(data: unknown): CalendarDay[] {
  const rows = Array.isArray(data)
    ? data
    : data && typeof data === "object" && "items" in data
      ? (data as { items: unknown[] }).items
      : [];
  return rows.flatMap((row) => {
    if (!row || typeof row !== "object") return [];
    const rec = row as Record<string, unknown>;
    const date = calendarDateOf(rec);
    if (!date) return [];
    return [
      {
        date,
        inventoryTypeId: String(
          rec.inventoryTypeId ?? rec.inventory_type_id ?? "",
        ),
        available: Number(rec.available ?? 0),
        blocked: Number(rec.blocked ?? 0),
        booked: Number(rec.booked ?? 0),
        held: Number(rec.held ?? 0),
      },
    ];
  });
}

export function dayKind(
  days: CalendarDay[],
  date: string,
  inventoryTypeId?: string,
): "open" | "block" | "busy" | "empty" {
  const match = days.filter(
    (d) =>
      d.date === date &&
      (!inventoryTypeId || d.inventoryTypeId === inventoryTypeId),
  );
  if (match.length === 0) return "empty";
  if (match.some((d) => (d.blocked ?? 0) > 0)) return "block";
  if (match.some((d) => (d.booked ?? 0) > 0 || (d.held ?? 0) > 0)) return "busy";
  if (match.some((d) => (d.available ?? 0) > 0)) return "open";
  return "empty";
}
