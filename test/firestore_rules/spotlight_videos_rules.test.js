/**
 * PR-012 — spotlight_videos write ownership rules tests.
 * RULES_PATH may point at an isolated clean rules file.
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const RULES = fs.readFileSync(
  process.env.RULES_PATH ||
    path.join(__dirname, "../../firestore.rules"),
  "utf8"
);

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-pr012-spotlight",
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
    await db.doc(`users/${admin}`).set({ isAdmin: true });
    // Legacy doc: sellerId only
    await db.doc(`spotlight_videos/legacy-seller`).set({
      sellerId: owner,
      title: "Legacy",
      viewsCount: 0,
      likesCount: 0,
    });
  });

  const ownerDb = testEnv.authenticatedContext(owner).firestore();
  const otherDb = testEnv.authenticatedContext(other).firestore();
  const adminDb = testEnv
    .authenticatedContext(admin, { token: { admin: true } })
    .firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  // —— READ preserved (public) ——
  await assertSucceeds(unauthDb.collection("spotlight_videos").doc("legacy-seller").get());
  await assertSucceeds(otherDb.collection("spotlight_videos").doc("legacy-seller").get());

  // —— CREATE ——
  await assertSucceeds(
    ownerDb.collection("spotlight_videos").doc("v1").set({
      userId: owner,
      sellerId: owner,
      title: "Mine",
      viewsCount: 0,
      likesCount: 0,
    })
  );
  await assertFails(
    otherDb.collection("spotlight_videos").doc("v2").set({
      userId: owner,
      sellerId: owner,
      title: "Forge",
    })
  );
  await assertFails(
    unauthDb.collection("spotlight_videos").doc("v3").set({
      userId: owner,
      sellerId: owner,
      title: "Noauth",
    })
  );
  await assertFails(
    ownerDb.collection("spotlight_videos").doc("v-missing").set({
      title: "No owner fields",
    })
  );
  await assertFails(
    ownerDb.collection("spotlight_videos").doc("v-empty").set({
      userId: "",
      sellerId: "",
      title: "Empty",
    })
  );

  // —— UPDATE owner / immutability / non-owner / unauth ——
  await assertSucceeds(
    ownerDb.collection("spotlight_videos").doc("v1").update({ title: "Mine 2" })
  );
  await assertFails(
    ownerDb.collection("spotlight_videos").doc("v1").update({ userId: other })
  );
  await assertFails(
    ownerDb.collection("spotlight_videos").doc("v1").update({ sellerId: other })
  );
  await assertFails(
    otherDb.collection("spotlight_videos").doc("v1").update({ title: "Hack" })
  );
  await assertFails(
    unauthDb.collection("spotlight_videos").doc("v1").update({ title: "Hack" })
  );

  // —— Public counter updates (any authenticated) ——
  await assertSucceeds(
    otherDb.collection("spotlight_videos").doc("v1").update({
      viewsCount: 1,
    })
  );
  await assertSucceeds(
    otherDb.collection("spotlight_videos").doc("v1").update({
      likesCount: 1,
    })
  );
  await assertFails(
    otherDb.collection("spotlight_videos").doc("v1").update({
      viewsCount: 2,
      title: "smuggle",
    })
  );

  // —— LEGACY sellerId-only owner ——
  await assertSucceeds(
    ownerDb.collection("spotlight_videos").doc("legacy-seller").update({
      title: "Legacy updated",
    })
  );
  await assertFails(
    otherDb.collection("spotlight_videos").doc("legacy-seller").update({
      title: "No",
    })
  );

  // —— ADMIN ——
  await assertSucceeds(
    adminDb.collection("spotlight_videos").doc("v1").update({ title: "Admin" })
  );
  await assertSucceeds(
    adminDb.collection("spotlight_videos").doc("v1").delete()
  );

  // Recreate for owner delete
  await assertSucceeds(
    ownerDb.collection("spotlight_videos").doc("v4").set({
      userId: owner,
      sellerId: owner,
      title: "Del",
    })
  );
  await assertFails(otherDb.collection("spotlight_videos").doc("v4").delete());
  await assertFails(unauthDb.collection("spotlight_videos").doc("v4").delete());
  await assertSucceeds(ownerDb.collection("spotlight_videos").doc("v4").delete());

  await testEnv.cleanup();
  console.log("PR-012 spotlight_videos rules tests: ALL PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
