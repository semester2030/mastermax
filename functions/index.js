/**
 * Cloud Functions: لا تُخزَّن أسرار Cloudflare في تطبيق العميل.
 *
 * إعداد الأسرار (مرة لكل بيئة):
 *   firebase functions:secrets:set CF_STREAM_TOKEN
 *   firebase functions:secrets:set CF_IMAGES_TOKEN
 *   firebase functions:secrets:set CF_ACCOUNT_ID
 *   firebase functions:secrets:set CF_STREAM_SUBDOMAIN
 *   firebase functions:secrets:set CF_IMAGES_HASH
 *
 * ثم:
 *   firebase deploy --only functions
 *
 * القيم = نفس ما كان في التطبيق سابقاً (توكن Stream، توكن Images، Account ID، subdomain، hash الصور).
 */

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const cfStreamToken = defineSecret("CF_STREAM_TOKEN");
const cfImagesToken = defineSecret("CF_IMAGES_TOKEN");
const cfAccountId = defineSecret("CF_ACCOUNT_ID");
const cfStreamSubdomain = defineSecret("CF_STREAM_SUBDOMAIN");
const cfImagesHash = defineSecret("CF_IMAGES_HASH");

const REGION = "europe-west1";

/** يطابق منطق لوحة الإدارة في firestore.rules (بريد bootstrap أو claim admin). */
function isDashboardAdmin(auth) {
  if (!auth?.token) return false;
  if (auth.token.admin === true) return true;
  const email = auth.token.email;
  return typeof email === "string" && email === "admin@mastermax.com";
}

async function cfJson(method, url, token, bodyObj) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: bodyObj !== undefined ? JSON.stringify(bodyObj) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) {
    const errPart = json.errors ? JSON.stringify(json.errors) : JSON.stringify(json).slice(0, 400);
    throw new Error(errPart || `HTTP ${res.status}`);
  }
  return json;
}

exports.createStreamDirectUpload = onCall(
  {
    region: REGION,
    secrets: [cfStreamToken, cfAccountId, cfStreamSubdomain],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لرفع الفيديو.");
    }
    const title = request.data?.title != null ? String(request.data.title).slice(0, 500) : "";
    const accountId = cfAccountId.value().trim();
    const token = cfStreamToken.value().trim();
    const subdomain = cfStreamSubdomain.value().trim();
    if (!accountId || !token || !subdomain) {
      throw new HttpsError("failed-precondition", "إعدادات الخادم غير مكتملة.");
    }
    const body = {
      maxDurationSeconds: 7200,
      meta: title ? {name: title} : {},
    };
    const json = await cfJson(
      "POST",
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/direct_upload`,
      token,
      body,
    );
    const r = json.result;
    if (!r?.uploadURL || !r?.uid) {
      throw new HttpsError("internal", "استجابة Cloudflare Stream غير متوقعة.");
    }
    return {
      uploadURL: r.uploadURL,
      uid: r.uid,
      customerSubdomain: subdomain,
    };
  },
);

exports.getStreamVideoInfo = onCall(
  {
    region: REGION,
    secrets: [cfStreamToken, cfAccountId],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول.");
    }
    const videoId = String(request.data?.videoId || "").trim();
    if (!videoId) {
      throw new HttpsError("invalid-argument", "videoId مطلوب.");
    }
    const accountId = cfAccountId.value().trim();
    const token = cfStreamToken.value().trim();
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${videoId}`,
      {method: "GET", headers: {Authorization: `Bearer ${token}`}},
    );
    const json = await res.json().catch(() => ({}));
    if (!res.ok || json.success !== true) {
      throw new HttpsError("not-found", "تعذر جلب بيانات الفيديو.");
    }
    return {result: json.result};
  },
);

exports.deleteStreamVideo = onCall(
  {
    region: REGION,
    secrets: [cfStreamToken, cfAccountId],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول.");
    }
    /** معرّف وثيقة spotlight_videos في Firestore (ليس uid سحابة Stream فقط). */
    const spotlightDocId = String(request.data?.videoId || "").trim();
    if (!spotlightDocId) {
      throw new HttpsError("invalid-argument", "videoId مطلوب.");
    }
    const snap = await db.collection("spotlight_videos").doc(spotlightDocId).get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "الفيديو غير موجود.");
    }
    const data = snap.data() || {};
    const sellerId = (data.sellerId || data.userId || "").toString().trim();
    const isOwner = sellerId && sellerId === request.auth.uid;
    const isAdmin = isDashboardAdmin(request.auth);
    if (!isOwner && !isAdmin) {
      throw new HttpsError("permission-denied", "لا يمكنك حذف هذا الفيديو.");
    }
    const cfUid = String(data.cloudflareVideoId || "").trim();
    if (!cfUid) {
      throw new HttpsError("failed-precondition", "لا يوجد معرّف Cloudflare Stream لهذا المقطع.");
    }
    const accountId = cfAccountId.value().trim();
    const token = cfStreamToken.value().trim();
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${cfUid}`,
      {method: "DELETE", headers: {Authorization: `Bearer ${token}`}},
    );
    if (res.status !== 200 && res.status !== 404) {
      const t = await res.text();
      throw new HttpsError("internal", t.slice(0, 400));
    }
    return {ok: true};
  },
);

exports.createImagesDirectUpload = onCall(
  {
    region: REGION,
    secrets: [cfImagesToken, cfAccountId, cfImagesHash],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لرفع الصورة.");
    }
    const accountId = cfAccountId.value().trim();
    const token = cfImagesToken.value().trim();
    const imagesHash = cfImagesHash.value().trim();
    if (!accountId || !token || !imagesHash) {
      throw new HttpsError("failed-precondition", "إعدادات الصور على الخادم غير مكتملة.");
    }
    let json;
    try {
      json = await cfJson(
        "POST",
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v2/direct_upload`,
        token,
        {requireSignedURLs: false},
      );
    } catch (e1) {
      try {
        json = await cfJson(
          "POST",
          `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1/direct_upload`,
          token,
          {requireSignedURLs: false},
        );
      } catch (e2) {
        const m = e2 && e2.message ? String(e2.message) : String(e2);
        throw new HttpsError("internal", `Images direct upload failed: ${m.slice(0, 400)}`);
      }
    }
    const r = json.result;
    if (!r?.uploadURL) {
      throw new HttpsError("internal", "لم يُرجع Cloudflare رابط رفع للصورة.");
    }
    return {uploadURL: r.uploadURL, imagesHash};
  },
);

exports.deleteImageFromCloudflare = onCall(
  {
    region: REGION,
    secrets: [cfImagesToken, cfAccountId],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول.");
    }
    const imageId = String(request.data?.imageId || "").trim();
    if (!imageId) {
      throw new HttpsError("invalid-argument", "imageId مطلوب.");
    }
    const accountId = cfAccountId.value().trim();
    const token = cfImagesToken.value().trim();
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1/${imageId}`,
      {method: "DELETE", headers: {Authorization: `Bearer ${token}`}},
    );
    if (res.status !== 200 && res.status !== 404) {
      const t = await res.text();
      throw new HttpsError("internal", t.slice(0, 400));
    }
    return {ok: true};
  },
);
