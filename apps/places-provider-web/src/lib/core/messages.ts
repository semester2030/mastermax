/** Core returns English operator-auth messages; the UI is Arabic-only. */
const AUTH_MESSAGES_AR: Record<string, string> = {
  "Invalid OTP": "رمز التحقق غير صحيح",
  "Invalid phone": "رقم الجوال غير مسموح به",
  "Challenge consumed": "تم استخدام هذا الرمز مسبقًا — أعد الإرسال",
  "Challenge expired": "انتهت صلاحية الرمز — أعد الإرسال",
  "Challenge locked":
    "تم تجاوز عدد المحاولات — انتظر ١٥ دقيقة ثم أعد الإرسال",
  "Challenge not found": "الرمز غير موجود — أعد الإرسال",
  "OTP send cooldown active": "أعد المحاولة بعد دقيقة واحدة",
  "Bound trial provider not active": "حساب المزود التجريبي غير مُفعّل",
};

export function authMessageAr(message: string): string {
  return AUTH_MESSAGES_AR[message.trim()] ?? message;
}
