/**
 * PR-025A — upload_drafts Firestore rules (least privilege + lifecycle).
 * RULES_PATH may point at an isolated rules file.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { Timestamp } = require("firebase/firestore");

const RULES = fs.readFileSync(
  process.env.RULES_PATH ||
    path.join(__dirname, "../../firestore.rules"),
  "utf8"
);

function baseDraft(owner, overrides = {}) {
  const now = Timestamp.now();
  return {
    ownerId: owner,
    entityType: "cloudflare_image",
    status: "pending",
    createdAt: now,
    updatedAt: now,
    attemptCount: 0,
    uploadedImageIds: [],
    lastError: "",
    ...overrides,
  };
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-pr025a-upload-drafts",
    firestore: {
      rules: RULES,
      host: "127.0.0.1",
      port: 8080,
    },
  });

  const owner = "owner-uid-1";
  const other = "other-uid-2";
  const admin = "admin-uid-3";

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${owner}`).set({ isAdmin: false });
    await db.doc(`users/${other}`).set({ isAdmin: false });
    await db.doc(`users/${admin}`).set({ isAdmin: true });
  });

  const ownerDb = testEnv.authenticatedContext(owner).firestore();
  const otherDb = testEnv.authenticatedContext(other).firestore();
  const adminDb = testEnv
    .authenticatedContext(admin, { token: { admin: true } })
    .firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  // —— CREATE ——
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d1").set(baseDraft(owner))
  );
  await assertFails(
    otherDb.collection("upload_drafts").doc("d2").set(baseDraft(owner))
  );
  await assertFails(
    unauthDb.collection("upload_drafts").doc("d3").set(baseDraft(owner))
  );
  await assertFails(
    ownerDb
      .collection("upload_drafts")
      .doc("d4")
      .set(baseDraft(owner, { status: "uploading" }))
  );
  await assertFails(
    ownerDb
      .collection("upload_drafts")
      .doc("d5")
      .set(baseDraft(owner, { status: "completed" }))
  );

  // —— READ ——
  await assertSucceeds(ownerDb.collection("upload_drafts").doc("d1").get());
  await assertFails(otherDb.collection("upload_drafts").doc("d1").get());
  await assertSucceeds(adminDb.collection("upload_drafts").doc("d1").get());

  // —— UPDATE lifecycle ——
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d1").update({
      status: "uploading",
      attemptCount: 1,
      updatedAt: Timestamp.now(),
    })
  );
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d1").update({
      status: "completed",
      uploadedImageIds: ["img_1"],
      updatedAt: Timestamp.now(),
    })
  );

  // Seed uploading doc for failed path
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d6").set(baseDraft(owner))
  );
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d6").update({
      status: "uploading",
      attemptCount: 1,
      updatedAt: Timestamp.now(),
    })
  );
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d6").update({
      status: "failed",
      lastError: "timeout",
      updatedAt: Timestamp.now(),
    })
  );
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d6").update({
      status: "uploading",
      attemptCount: 2,
      lastError: "",
      updatedAt: Timestamp.now(),
    })
  );

  // —— UPDATE denials ——
  await assertFails(
    ownerDb.collection("upload_drafts").doc("d1").update({ ownerId: other })
  );
  // recreate pending→… for createdAt mutation on a fresh doc
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d7").set(baseDraft(owner))
  );
  const createdAt = (await ownerDb.collection("upload_drafts").doc("d7").get())
    .data().createdAt;
  await assertFails(
    ownerDb.collection("upload_drafts").doc("d7").update({
      createdAt: Timestamp.fromMillis(createdAt.toMillis() - 60000),
      updatedAt: Timestamp.now(),
    })
  );
  await assertSucceeds(
    ownerDb.collection("upload_drafts").doc("d7").update({
      status: "uploading",
      attemptCount: 1,
      updatedAt: Timestamp.now(),
    })
  );
  await assertFails(
    ownerDb.collection("upload_drafts").doc("d7").update({
      attemptCount: 0,
      updatedAt: Timestamp.now(),
    })
  );

  // completed → uploading denied (d1 is completed)
  await assertFails(
    ownerDb.collection("upload_drafts").doc("d1").update({
      status: "uploading",
      updatedAt: Timestamp.now(),
    })
  );

  await assertFails(
    otherDb.collection("upload_drafts").doc("d7").update({
      status: "failed",
      lastError: "hack",
      updatedAt: Timestamp.now(),
    })
  );
  await assertFails(
    unauthDb.collection("upload_drafts").doc("d7").update({
      status: "failed",
      updatedAt: Timestamp.now(),
    })
  );

  // admin update not granted
  await assertFails(
    adminDb.collection("upload_drafts").doc("d7").update({
      status: "failed",
      lastError: "admin",
      updatedAt: Timestamp.now(),
    })
  );

  // —— DELETE ——
  await assertFails(ownerDb.collection("upload_drafts").doc("d7").delete());
  await assertFails(otherDb.collection("upload_drafts").doc("d7").delete());
  await assertSucceeds(adminDb.collection("upload_drafts").doc("d7").delete());

  await testEnv.cleanup();
  console.log("PR-025A upload_drafts rules tests: ALL PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
