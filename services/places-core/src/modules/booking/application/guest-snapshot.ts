import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";

export type GuestSnapshot = {
  bookerFullName: string;
  bookerPhone: string;
  bookerEmail?: string;
  bookingForOther: boolean;
  guestFullName?: string;
  guestPhone?: string;
};

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const NAME_RE = /^[\p{L}\p{M}][\p{L}\p{M}\s'.-]{1,79}$/u;
const UUID_LIKE = /^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$/i;
const PHONE_INVALID_AR =
  "رقم الجوال غير صالح. استخدم 05xxxxxxxx أو +9665xxxxxxxx";

/** Canonical Saudi mobile: +9665xxxxxxxx. Accepts 05…, +9665…, 9665… */
export function toSaudiMobileE164(raw: unknown): string | null {
  const cleaned = String(raw ?? "").replace(/[\s()-]/g, "").trim();
  if (!cleaned) return null;
  const digits = cleaned.replace(/\D/g, "");
  if (/^\+9665\d{8}$/.test(cleaned)) return cleaned;
  if (/^9665\d{8}$/.test(digits)) return `+${digits}`;
  if (/^05\d{8}$/.test(digits)) return `+966${digits.slice(1)}`;
  return null;
}

function fail(message: string): never {
  throw new AppError(ErrorCodes.VALIDATION_ERROR, message);
}

function clean(raw: unknown): string {
  return String(raw ?? "").replace(/\s+/g, " ").trim();
}

function normalizePhone(raw: unknown): string {
  return toSaudiMobileE164(raw) ?? clean(raw).replace(/[\s-]/g, "");
}

function assertPersonName(value: string, label: string): void {
  if (!NAME_RE.test(value)) {
    fail(`${label} غير صالح`);
  }
  if (UUID_LIKE.test(value.replace(/\s/g, ""))) {
    fail(`${label} غير صالح`);
  }
}

/**
 * Server-side guest/booker snapshot. Never reads Firebase displayName.
 * Stores only Places booking fields — does not mutate Auth/Firestore profiles.
 */
export function parseGuestSnapshot(raw: unknown): GuestSnapshot {
  if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
    fail("بيانات صاحب الحجز مطلوبة");
  }
  const input = raw as Record<string, unknown>;
  const bookerFullName = clean(input.bookerFullName);
  const bookerPhone = normalizePhone(input.bookerPhone);
  const bookerEmailRaw = clean(input.bookerEmail);
  const bookingForOther = input.bookingForOther === true;
  const guestFullName = clean(input.guestFullName);
  const guestPhone = normalizePhone(input.guestPhone);

  if (!bookerFullName) fail("الاسم الكامل لصاحب الحجز مطلوب");
  assertPersonName(bookerFullName, "اسم صاحب الحجز");
  if (!clean(input.bookerPhone)) fail("رقم جوال صاحب الحجز مطلوب");
  if (!toSaudiMobileE164(input.bookerPhone)) fail(PHONE_INVALID_AR);
  if (bookerEmailRaw && !EMAIL_RE.test(bookerEmailRaw)) {
    fail("البريد الإلكتروني غير صالح");
  }

  if (bookingForOther) {
    if (!guestFullName) fail("اسم الضيف مطلوب عند الحجز لشخص آخر");
    assertPersonName(guestFullName, "اسم الضيف");
    if (!clean(input.guestPhone)) fail("رقم جوال الضيف مطلوب عند الحجز لشخص آخر");
    if (!toSaudiMobileE164(input.guestPhone)) fail(PHONE_INVALID_AR);
  }

  const snapshot: GuestSnapshot = {
    bookerFullName,
    bookerPhone,
    bookingForOther,
  };
  if (bookerEmailRaw) snapshot.bookerEmail = bookerEmailRaw;
  if (bookingForOther) {
    snapshot.guestFullName = guestFullName;
    snapshot.guestPhone = guestPhone;
  }
  return snapshot;
}

export function guestSnapshotJson(snapshot: GuestSnapshot): string {
  return JSON.stringify(snapshot);
}

export function readGuestSnapshot(raw: unknown): GuestSnapshot | null {
  if (raw == null) return null;
  let obj: unknown = raw;
  if (typeof raw === "string") {
    try {
      obj = JSON.parse(raw) as unknown;
    } catch {
      return null;
    }
  }
  if (!obj || typeof obj !== "object") return null;
  try {
    return parseGuestSnapshot(obj);
  } catch {
    const rec = obj as Record<string, unknown>;
    const name = clean(rec.bookerFullName);
    const phone = normalizePhone(rec.bookerPhone);
    if (!name || !phone) return null;
    return {
      bookerFullName: name,
      bookerPhone: phone,
      bookerEmail: clean(rec.bookerEmail) || undefined,
      bookingForOther: rec.bookingForOther === true,
      guestFullName: clean(rec.guestFullName) || undefined,
      guestPhone: normalizePhone(rec.guestPhone) || undefined,
    };
  }
}
