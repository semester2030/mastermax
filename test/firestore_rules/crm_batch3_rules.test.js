/**
 * PR-011 — CRM batch-3 rules tests (property_contracts only).
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
    projectId: "demo-pr011-crm-batch3",
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
    await db.doc(`properties/prop-owned`).set({
      ownerId: owner,
      title: "Owned",
    });
    await db.doc(`properties/prop-other`).set({
      ownerId: other,
      title: "Other",
    });
  });

  const ownerDb = testEnv.authenticatedContext(owner).firestore();
  const otherDb = testEnv.authenticatedContext(other).firestore();
  const adminDb = testEnv
    .authenticatedContext(admin, { token: { admin: true } })
    .firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  // —— linked owner CRUD ——
  await assertSucceeds(
    ownerDb.collection("property_contracts").doc("pc1").set({
      propertyId: "prop-owned",
      contractorId: "c1",
      status: "pending",
    })
  );
  await assertSucceeds(ownerDb.collection("property_contracts").doc("pc1").get());
  await assertSucceeds(
    ownerDb
      .collection("property_contracts")
      .doc("pc1")
      .update({ status: "active" })
  );
  await assertFails(
    ownerDb
      .collection("property_contracts")
      .doc("pc1")
      .update({ propertyId: "prop-other" })
  );

  // —— non-owner / unauth ——
  await assertFails(otherDb.collection("property_contracts").doc("pc1").get());
  await assertFails(
    otherDb
      .collection("property_contracts")
      .doc("pc1")
      .update({ status: "hack" })
  );
  await assertFails(otherDb.collection("property_contracts").doc("pc1").delete());
  await assertFails(
    otherDb.collection("property_contracts").doc("pc2").set({
      propertyId: "prop-owned",
      contractorId: "c2",
      status: "pending",
    })
  );
  await assertFails(unauthDb.collection("property_contracts").doc("pc1").get());
  await assertFails(
    unauthDb.collection("property_contracts").doc("pc-u").set({
      propertyId: "prop-owned",
      status: "pending",
    })
  );

  // —— missing / empty / invalid propertyId / wrong property ——
  await assertFails(
    ownerDb.collection("property_contracts").doc("pc-missing").set({
      contractorId: "c3",
      status: "pending",
    })
  );
  await assertFails(
    ownerDb.collection("property_contracts").doc("pc-empty").set({
      propertyId: "",
      contractorId: "c3",
      status: "pending",
    })
  );
  await assertFails(
    ownerDb.collection("property_contracts").doc("pc-invalid").set({
      propertyId: "prop-does-not-exist",
      contractorId: "c3",
      status: "pending",
    })
  );
  await assertFails(
    ownerDb.collection("property_contracts").doc("pc-other").set({
      propertyId: "prop-other",
      contractorId: "c3",
      status: "pending",
    })
  );

  // —— admin preserved (read/update; create remains owner-linked only) ——
  await assertSucceeds(adminDb.collection("property_contracts").doc("pc1").get());
  await assertSucceeds(
    adminDb
      .collection("property_contracts")
      .doc("pc1")
      .update({ status: "admin-ok" })
  );
  await assertFails(
    adminDb.collection("property_contracts").doc("pc-admin-other").set({
      propertyId: "prop-other",
      contractorId: "admin-c",
      status: "pending",
    })
  );
  await assertSucceeds(adminDb.collection("property_contracts").doc("pc1").delete());

  await testEnv.cleanup();
  console.log("PR-011 CRM batch-3 rules tests: ALL PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
