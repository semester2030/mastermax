/** @fileoverview GET verify + POST router — Meta WhatsApp webhook */

const {CHANNELS, WHATSAPP_DISABLED_MESSAGE_AR} = require("./constants");
const {
  envStr,
  isWhatsAppEnabled,
  isSignatureRequired,
  getVerifyToken,
  resolveChannelByPhoneNumberId,
} = require("./config");
const {verifyMetaSignature} = require("./verifySignature");
const {claimInboundMessage, finalizeInboundMessage} = require("./idempotency");
const {enforceWhatsAppRateLimit} = require("./rateLimit");
const {writeAuditLog} = require("./auditLog");
const {consumerPipeline} = require("./consumerPipeline");
const {businessPipeline} = require("./businessPipeline");
const {normalizeE164} = require("./phoneUtils");

/**
 * @param {FirebaseFirestore.Firestore} db
 * @returns {(req: import("firebase-functions/v2/https").Request, res: import("firebase-functions/v2/https").Response) => Promise<void>}
 */
function createWebhookHandler(db) {
  return async function whatsappWebhook(req, res) {
    try {
      if (req.method === "GET") {
        return handleVerify(req, res);
      }

      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      if (!isWhatsAppEnabled()) {
        res.status(503).send("disabled");
        return;
      }

      if (isSignatureRequired()) {
        const secret = envStr("WHATSAPP_APP_SECRET");
        const sig = String(req.get("X-Hub-Signature-256") || "").trim();
        const rawBody = req.rawBody;

        if (!sig) {
          console.warn("[whatsapp] POST without X-Hub-Signature-256");
          res.status(403).send("Forbidden");
          return;
        }
        if (!Buffer.isBuffer(rawBody) || rawBody.length === 0) {
          console.error("[whatsapp] rawBody missing — cannot verify Meta signature");
          res.status(403).send("Forbidden");
          return;
        }
        if (!verifyMetaSignature(secret, rawBody, sig)) {
          console.warn("[whatsapp] signature_rejected", {
            secretLen: secret.length,
            rawBodyLen: rawBody.length,
          });
          await writeAuditLog(db, {
            event: "signature_rejected",
            denied: true,
          });
          res.status(403).send("Forbidden");
          return;
        }
      }

      const body = req.body || {};
      if (body.object !== "whatsapp_business_account") {
        res.status(404).send("Not Found");
        return;
      }

      const entries = Array.isArray(body.entry) ? body.entry : [];
      for (const entry of entries) {
        const changes = Array.isArray(entry.changes) ? entry.changes : [];
        for (const change of changes) {
          if (change.field !== "messages") continue;
          const value = change.value || {};
          const phoneNumberId = String(value.metadata?.phone_number_id || "");
          const channel = resolveChannelByPhoneNumberId(phoneNumberId);

          if (!channel) {
            console.warn("[whatsapp] unknown phone_number_id:", phoneNumberId,
                "expected:", envStr("WHATSAPP_PHONE_NUMBER_ID_CONSUMER"));
            continue;
          }

          const messages = Array.isArray(value.messages) ? value.messages : [];
          if (messages.length > 0) {
            console.info("[whatsapp] inbound messages:", messages.length,
                "from phone_number_id:", phoneNumberId);
          }
          for (const msg of messages) {
            await processInboundMessage(db, {
              channel,
              phoneNumberId,
              msg,
            });
          }

          const statuses = Array.isArray(value.statuses) ? value.statuses : [];
          for (const st of statuses) {
            await finalizeInboundMessage(db, st.id, {
              deliveryStatus: st.status,
              channel,
            });
          }
        }
      }

      res.status(200).send("OK");
    } catch (err) {
      console.error("[whatsapp] webhook error:", err);
      res.status(500).send("Error");
    }
  };
}

/**
 * @param {import("firebase-functions/v2/https").Request} req
 * @param {import("firebase-functions/v2/https").Response} res
 */
function handleVerify(req, res) {
  const mode = String(req.query["hub.mode"] || "");
  const token = String(req.query["hub.verify_token"] || "");
  const challenge = String(req.query["hub.challenge"] || "");

  if (mode === "subscribe" && token === getVerifyToken()) {
    res.status(200).send(challenge);
    return;
  }

  res.status(403).send("Forbidden");
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {object} opts
 */
async function processInboundMessage(db, opts) {
  const msg = opts.msg || {};
  if (msg.type !== "text") return;

  const wamid = String(msg.id || "");
  const from = normalizeE164(msg.from);
  const text = String(msg.text?.body || "").trim();
  if (!from || !text) return;

  console.info("[whatsapp] processing text from", from, "preview:", text.slice(0, 80));

  // PR-021: claim يحترم lease/expiry — false = مكررة أو processing ضمن lease ساري
  const isNew = await claimInboundMessage(db, wamid);
  if (!isNew) {
    console.info("[whatsapp] skip inbound (duplicate or active lease):", wamid);
    return;
  }

  try {
    await enforceWhatsAppRateLimit(db, opts.channel, from);
  } catch (err) {
    if (err?.code === "rate_limited") {
      const {sendTextMessage} = require("./metaSend");
      await sendTextMessage(opts.channel, from, err.message);
      await finalizeInboundMessage(db, wamid, {
        channel: opts.channel,
        from,
        body: text,
        error: "rate_limited",
      });
      return;
    }
    throw err;
  }

  if (!isWhatsAppEnabled()) {
    const {sendTextMessage} = require("./metaSend");
    await sendTextMessage(opts.channel, from, WHATSAPP_DISABLED_MESSAGE_AR);
    return;
  }

  let result;
  if (opts.channel === CHANNELS.BUSINESS) {
    result = await businessPipeline({db, from, text});
  } else {
    result = await consumerPipeline({db, from, text, wamid});
  }

  await finalizeInboundMessage(db, wamid, {
    channel: opts.channel,
    from,
    body: text,
    replyPreview: String(result?.replyText || "").slice(0, 500),
    listingIds: result?.listingIds || [],
    tenantId: result?.tenantId || null,
    denied: result?.denied === true,
  });
}

/**
 * Mock inbound — للاختبار المحلي بدون Meta
 * @param {FirebaseFirestore.Firestore} db
 * @param {object} payload
 */
async function simulateInboundForTest(db, payload) {
  const channel = payload.channel === CHANNELS.BUSINESS ?
    CHANNELS.BUSINESS :
    CHANNELS.CONSUMER;
  const from = normalizeE164(payload.from || "966500000001");
  const text = String(payload.text || "").trim();
  const wamid = String(payload.wamid || `test_${Date.now()}`);

  await processInboundMessage(db, {
    channel,
    phoneNumberId: channel === CHANNELS.BUSINESS ? "mock_business" : "mock_consumer",
    msg: {
      id: wamid,
      from,
      type: "text",
      text: {body: text},
    },
  });
}

module.exports = {
  createWebhookHandler,
  simulateInboundForTest,
};
