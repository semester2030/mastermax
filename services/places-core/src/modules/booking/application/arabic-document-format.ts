const MONTHS_AR = [
  "يناير",
  "فبراير",
  "مارس",
  "أبريل",
  "مايو",
  "يونيو",
  "يوليو",
  "أغسطس",
  "سبتمبر",
  "أكتوبر",
  "نوفمبر",
  "ديسمبر",
];

/** Calendar date only — never ISO / `00:00:00.000Z`. */
export function formatArabicDate(raw: unknown): string {
  if (raw == null) return "—";
  if (raw instanceof Date && !Number.isNaN(raw.getTime())) {
    return formatArabicDate(
      `${raw.getUTCFullYear()}-${String(raw.getUTCMonth() + 1).padStart(2, "0")}-${String(raw.getUTCDate()).padStart(2, "0")}`,
    );
  }
  const text = String(raw).trim();
  const day = text.slice(0, 10);
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day);
  if (!m) return "—";
  return `${Number(m[3])} ${MONTHS_AR[Number(m[2]) - 1]} ${m[1]}`;
}

export function formatArabicMoney(amount: unknown): string {
  if (amount == null || amount === "") return "— ر.س";
  return `${String(amount)} ر.س`;
}

export function formatArabicIssueDate(now = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Riyadh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const y = parts.find((p) => p.type === "year")?.value;
  const mo = parts.find((p) => p.type === "month")?.value;
  const da = parts.find((p) => p.type === "day")?.value;
  return formatArabicDate(`${y}-${mo}-${da}`);
}

export function guestCountLabel(adults: unknown, children: unknown): string {
  const a = adults == null ? 0 : Number(adults);
  const c = children == null ? 0 : Number(children);
  if (!Number.isFinite(a) && !Number.isFinite(c)) return "—";
  return `${a || 0} بالغ · ${c || 0} طفل`;
}

export function quoteItemLabelAr(raw: string): string {
  const text = String(raw ?? "").trim();
  const lower = text.toLowerCase();
  if (lower === "nights" || lower === "night") return "الليالي";
  if (lower.startsWith("night ")) {
    return `ليلة ${formatArabicDate(text.slice(6))}`;
  }
  if (lower.startsWith("slot ")) {
    const bits = text.split(/\s+/);
    const date = bits[bits.length - 1];
    return `فترة ${formatArabicDate(date)}`;
  }
  if (lower === "extra guest" || lower === "extra_guest") return "ضيف إضافي";
  if (lower === "fees") return "رسوم";
  if (lower === "discount") return "خصم";
  if (lower === "extras") return "إضافات";
  return text;
}
