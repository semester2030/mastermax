/**
 * Operator-facing Arabic errors. Never leak JSON, IDs, paths, or HTTP codes.
 */

const UUID_RE =
  /[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi;
const JSONISH_RE = /[{[][\s\S]*[}\]]/;
const HTTP_RE = /\bHTTP\s*\d{3}\b/gi;
const PATH_RE = /\/v1\/[A-Za-z0-9/_-]+/g;
const CODE_RE = /\b[A-Z][A-Z0-9_]{3,}\b/g;

const KNOWN: Array<{ test: RegExp; message: string }> = [
  {
    test: /unauthenticated|missing_session|جلسة/i,
    message: "انتهت الجلسة. سجّل الدخول ثم أعد المحاولة.",
  },
  {
    test: /missing.?provider|onBehalfOfProviderId/i,
    message: "تعذّر التعرف على حساب المطوّر. سجّل الدخول من جديد.",
  },
  {
    test: /approved venue-level image|صورة واحدة معتمدة|cityId|districtId|latitude|longitude|coordinates|hero video|cover image/i,
    message:
      "يلزم مدينة وحي وشارع وإحداثيات صحيحة، وفيديو رئيسي معتمد، وصورة غلاف، وسعر وإتاحة، ووسائط معتمدة لكل وحدة نشطة.",
  },
  {
    test: /quota|حد الفيديو|maxVideos|videos/i,
    message: "وصلت إلى الحد الأقصى للفيديو (٣). احذف فيديوًا قبل رفع آخر.",
  },
  {
    test: /images.?cap|حد الصور|maxImages/i,
    message: "وصلت إلى الحد الأقصى للصور (٣٠). احذف صورة قبل رفع أخرى.",
  },
  {
    test: /cloudflare|stub|MEDIA_PROVIDER/i,
    message:
      "تعذّر رفع الملف الآن. تحقق من اتصال الرفع ثم أعد المحاولة. إن استمر الخطأ فالخدمة غير جاهزة.",
  },
  {
    test: /rate.?plan|خطة السعر/i,
    message: "أنشئ خطة سعر أولاً، ثم أدخل السعر الأساسي.",
  },
  {
    test: /inventory.?type|لا توجد وحدات|unit/i,
    message: "أضف وحدة واحدة على الأقل من «خيارات متقدمة → الوحدات» ثم حدّد الإتاحة.",
  },
  {
    test: /availability|توفر|إتاحة/i,
    message: "تعذّر حفظ الإتاحة. اختر يومًا أو نطاق أيام ثم أعد الحفظ.",
  },
  {
    test: /pricing|سعر/i,
    message: "تعذّر حفظ السعر. أدخل مبلغًا صحيحًا بالريال ثم أعد المحاولة.",
  },
  {
    test: /validation/i,
    message: "بعض البيانات ناقصة أو غير صحيحة. راجع الحقول المطلوبة ثم أعد المحاولة.",
  },
  {
    test: /not found|404/i,
    message: "العنصر غير موجود أو لم يعد متاحًا. حدّث الصفحة ثم أعد المحاولة.",
  },
  {
    test: /conflict|409|cas.?version/i,
    message: "تغيّرت البيانات من جهاز آخر. حدّث الصفحة ثم أعد المحاولة.",
  },
  {
    test: /network|fetch|ECONN|timeout/i,
    message: "تعذّر الاتصال. تحقق من الشبكة ثم أعد المحاولة.",
  },
];

function stripTechnical(input: string): string {
  return input
    .replace(JSONISH_RE, " ")
    .replace(UUID_RE, "")
    .replace(HTTP_RE, "")
    .replace(PATH_RE, "")
    .replace(CODE_RE, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

export function operatorErrorAr(raw: unknown): string {
  const text =
    typeof raw === "string"
      ? raw
      : raw instanceof Error
        ? raw.message
        : "حدث خطأ غير متوقع";
  for (const row of KNOWN) {
    if (row.test.test(text)) return row.message;
  }
  const cleaned = stripTechnical(text);
  if (!cleaned || cleaned.length < 8 || /[{}\[\]\\]/.test(cleaned)) {
    return "تعذّر إتمام العملية. راجع البيانات ثم أعد المحاولة.";
  }
  return cleaned;
}
