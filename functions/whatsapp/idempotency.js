/** @fileoverview wa_messages — idempotency عبر wamid + lease/expiry */

const admin = require("firebase-admin");
const {COLLECTIONS} = require("./constants");

/** مدة الـ lease لحالة processing — بعدها يُسمح بإعادة claim. */
const PROCESSING_LEASE_MS = 5 * 60 * 1000;

/**
 * @param {FirebaseFirestore.Timestamp|Date|number|null|undefined} value
 * @returns {number} epoch ms, أو 0 إن غير صالح
 */
function expiresAtMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return 0;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} wamid
 * @returns {Promise<boolean>} true إذا حُجزت للمعالجة (جديدة أو بعد انتهاء lease)
 */
async function claimInboundMessage(db, wamid) {
  const id = String(wamid || "").trim();
  if (!id) return true;

  const ref = db.collection(COLLECTIONS.MESSAGES).doc(id);
  const newExpiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + PROCESSING_LEASE_MS,
  );

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);

    if (!snap.exists) {
      tx.set(ref, {
        direction: "inbound",
        status: "processing",
        attemptCount: 1,
        expiresAt: newExpiresAt,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    }

    const data = snap.data() || {};
    const status = String(data.status || "");

    // اكتملت بنجاح — لا إعادة معالجة
    if (status === "done") {
      return false;
    }

    // processing مع lease ساري — منع الازدواج
    if (status === "processing") {
      const expMs = expiresAtMillis(data.expiresAt);
      if (expMs > Date.now()) {
        return false;
      }

      // lease منتهٍ أو وثيقة عالقة بلا expiresAt — إعادة claim
      const prevAttempts =
        typeof data.attemptCount === "number" && data.attemptCount >= 1 ?
          data.attemptCount :
          1;

      tx.set(
          ref,
          {
            status: "processing",
            attemptCount: prevAttempts + 1,
            expiresAt: newExpiresAt,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      return true;
    }

    // حالات أخرى غير معروفة — لا claim (آمن ضد الازدواج)
    return false;
  });
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} wamid
 * @param {object} patch
 */
async function finalizeInboundMessage(db, wamid, patch) {
  const id = String(wamid || "").trim();
  if (!id) return;
  await db.collection(COLLECTIONS.MESSAGES).doc(id).set(
      {
        ...patch,
        status: "done",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );
}

module.exports = {
  claimInboundMessage,
  finalizeInboundMessage,
  PROCESSING_LEASE_MS,
};
