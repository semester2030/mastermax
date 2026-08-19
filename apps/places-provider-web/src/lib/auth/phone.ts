/**
 * Core matches the operator phone as an exact E.164 string, so Saudi local
 * spellings (05…, 5…, 966…, 00966…) must be canonicalized before the call.
 */
const ARABIC_DIGITS = /[\u0660-\u0669\u06F0-\u06F9]/g;

function toLatinDigits(input: string): string {
  return input.replace(ARABIC_DIGITS, (d) => {
    const code = d.charCodeAt(0);
    const base = code >= 0x06f0 ? 0x06f0 : 0x0660;
    return String(code - base);
  });
}

export function normalizePhoneE164(raw: string): string | null {
  const cleaned = toLatinDigits(raw)
    .replace(/[\s\-().\u200f\u200e]/g, "")
    .trim();
  if (!cleaned) return null;

  let digits = cleaned.startsWith("+") ? cleaned.slice(1) : cleaned;
  if (!/^\d+$/.test(digits)) return null;

  if (digits.startsWith("00")) digits = digits.slice(2);
  if (digits.startsWith("0")) digits = `966${digits.slice(1)}`;
  else if (digits.startsWith("5") && digits.length === 9) digits = `966${digits}`;

  if (!/^[1-9]\d{7,14}$/.test(digits)) return null;
  return `+${digits}`;
}
