/**
 * Arabic explanations for Cloudflare media failures.
 *
 * Two failure surfaces reach the operator: Core rejecting an upload session
 * (envelope `MEDIA_PROVIDER_UNAVAILABLE`) and the browser POSTing bytes straight
 * to Cloudflare. Both are mapped here so neither shows up as a bare 500.
 */

export type CloudflareService = "images" | "stream";

const SERVICE_LABEL: Record<CloudflareService, string> = {
  images: "الصور",
  stream: "الفيديو",
};

/** Mirrors `cfReason` in places-core `cloudflare-media.adapter.ts`. */
export function cloudflareReason(
  httpStatus: number,
  cfCode: number | null,
): string {
  switch (cfCode) {
    case 5403:
      return "images_service_not_enabled";
    case 10002:
      return "stream_not_authorized";
    case 10000:
      return "token_invalid";
    case 9109:
      return "token_scope_missing";
    case 5415:
      return "unsupported_content_type";
    default:
      break;
  }
  if (httpStatus === 401) return "token_invalid";
  if (httpStatus === 403) return "not_authorized";
  if (httpStatus === 404) return "resource_not_found";
  if (httpStatus === 415) return "unsupported_content_type";
  if (httpStatus === 429) return "rate_limited";
  if (httpStatus >= 500) return "provider_error";
  return "unknown";
}

function reasonText(reason: string): string {
  switch (reason) {
    case "images_service_not_enabled":
      return "خدمة رفع الصور غير مفعّلة على هذا الحساب. استخدم صورة أخرى أو أعد المحاولة لاحقًا.";
    case "stream_not_authorized":
      return "خدمة رفع الفيديو غير مفعّلة على هذا الحساب. أعد المحاولة لاحقًا.";
    case "token_invalid":
    case "token_scope_missing":
    case "not_authorized":
      return "تعذّر الاتصال بخدمة الرفع. أعد المحاولة بعد قليل.";
    case "unsupported_content_type":
      return "صيغة الملف غير مدعومة. اختر صورة أو فيديوًا شائعًا ثم أعد المحاولة.";
    case "rate_limited":
      return "تجاوزنا حد الرفع اللحظي. انتظر قليلًا ثم أعد المحاولة.";
    case "provider_error":
      return "خطأ مؤقت في خدمة الرفع. أعد المحاولة.";
    case "resource_not_found":
      return "الملف غير موجود بعد الرفع. أعد المحاولة.";
    default:
      return "تعذّر رفع الملف. تحقق من الحجم والصيغة ثم أعد المحاولة.";
  }
}

function compose(service: CloudflareService, reason: string): string {
  return `تعذّر رفع ${SERVICE_LABEL[service]} — ${reasonText(reason)}`;
}

type CoreErrorEnvelope = {
  code?: string;
  message?: string;
  details?: {
    provider?: string;
    service?: string;
    httpStatus?: number;
    cfCode?: number | null;
    cfMessage?: string | null;
    reason?: string;
  };
};

/**
 * Turns a Core error envelope into Arabic when it is a Cloudflare rejection.
 * Returns null for anything else so existing messages stay untouched.
 */
export function describeCoreMediaError(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const envelope = body as CoreErrorEnvelope;
  if (envelope.code !== "MEDIA_PROVIDER_UNAVAILABLE") return null;
  const details = envelope.details ?? {};
  const service: CloudflareService = details.service === "stream" ? "stream" : "images";
  const reason =
    details.reason ?? cloudflareReason(details.httpStatus ?? 0, details.cfCode ?? null);
  return compose(service, reason);
}

/**
 * Explains a failed direct byte upload. Cloudflare answers with its own
 * envelope here, which is how the account-level 5403 surfaces to the browser.
 */
export function describeCloudflareUploadFailure(
  service: CloudflareService,
  httpStatus: number,
  rawBody: string,
): string {
  let cfCode: number | null = null;
  try {
    const parsed = JSON.parse(rawBody) as {
      errors?: Array<{ code?: number; message?: string } | null>;
    };
    const first = parsed.errors?.find((e) => e?.code != null);
    cfCode = typeof first?.code === "number" ? first.code : null;
  } catch {
    cfCode = null;
  }
  return compose(service, cloudflareReason(httpStatus, cfCode));
}
