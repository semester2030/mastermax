/**
 * PR-010 — CRM batch-2 rules tests
 * (rental_contracts / branches / businesses).
 *
 * RULES_PATH may point at an isolated clean rules file so WIP working-tree
 * firestore.rules is never required for the run.
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
    projectId: "demo-pr010-crm-batch2",
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

  // —— branches (companyId) ——
  await assertSucceeds(
    ownerDb.collection("branches").doc("b1").set({
      companyId: owner,
      name: "Main",
      address: "Riyadh",
      phone: "0500000000",
      isActive: true,
    })
  );
  await assertSucceeds(ownerDb.collection("branches").doc("b1").get());
  await assertSucceeds(
    ownerDb.collection("branches").doc("b1").update({ name: "Main 2" })
  );
  await assertFails(
    ownerDb.collection("branches").doc("b1").update({ companyId: other })
  );
  await assertFails(otherDb.collection("branches").doc("b1").get());
  await assertFails(
    otherDb.collection("branches").doc("b1").update({ name: "Hack" })
  );
  await assertFails(otherDb.collection("branches").doc("b1").delete());
  await assertFails(
    otherDb.collection("branches").doc("b2").set({
      companyId: owner,
      name: "Forge",
      address: "x",
      phone: "1",
      isActive: true,
    })
  );
  await assertFails(
    unauthDb.collection("branches").doc("b1").get()
  );
  await assertSucceeds(adminDb.collection("branches").doc("b1").get());
  await assertSucceeds(
    adminDb.collection("branches").doc("b1").update({ name: "Admin rename" })
  );
  await assertSucceeds(ownerDb.collection("branches").doc("b1").delete());

  // —— businesses (ownerId) ——
  await assertSucceeds(
    ownerDb.collection("businesses").doc("biz1").set({
      ownerId: owner,
      name: "Biz",
      isActive: true,
    })
  );
  await assertSucceeds(ownerDb.collection("businesses").doc("biz1").get());
  await assertSucceeds(
    ownerDb.collection("businesses").doc("biz1").update({ name: "Biz 2" })
  );
  await assertFails(
    ownerDb.collection("businesses").doc("biz1").update({ ownerId: other })
  );
  await assertFails(otherDb.collection("businesses").doc("biz1").get());
  await assertFails(
    otherDb.collection("businesses").doc("biz1").update({ name: "Hack" })
  );
  await assertFails(otherDb.collection("businesses").doc("biz1").delete());
  await assertFails(
    otherDb.collection("businesses").doc("biz2").set({
      ownerId: owner,
      name: "Forge",
    })
  );
  await assertFails(unauthDb.collection("businesses").doc("biz1").get());
  await assertSucceeds(adminDb.collection("businesses").doc("biz1").get());
  await assertSucceeds(
    adminDb.collection("businesses").doc("biz1").update({ name: "Admin" })
  );
  await assertSucceeds(ownerDb.collection("businesses").doc("biz1").delete());

  // —— rental_contracts (linked property owner) ——
  await assertSucceeds(
    ownerDb.collection("rental_contracts").doc("rc1").set({
      propertyId: "prop-owned",
      tenantId: "t1",
      monthlyRent: 5000,
      status: "active",
    })
  );
  await assertSucceeds(ownerDb.collection("rental_contracts").doc("rc1").get());
  await assertSucceeds(
    ownerDb
      .collection("rental_contracts")
      .doc("rc1")
      .update({ monthlyRent: 5500 })
  );
  await assertFails(
    ownerDb
      .collection("rental_contracts")
      .doc("rc1")
      .update({ propertyId: "prop-other" })
  );
  await assertFails(otherDb.collection("rental_contracts").doc("rc1").get());
  await assertFails(
    otherDb
      .collection("rental_contracts")
      .doc("rc1")
      .update({ monthlyRent: 1 })
  );
  await assertFails(otherDb.collection("rental_contracts").doc("rc1").delete());
  await assertFails(
    otherDb.collection("rental_contracts").doc("rc2").set({
      propertyId: "prop-owned",
      tenantId: "t2",
      status: "active",
    })
  );
  await assertFails(
    ownerDb.collection("rental_contracts").doc("rc-missing").set({
      tenantId: "t3",
      status: "active",
    })
  );
  await assertFails(
    ownerDb.collection("rental_contracts").doc("rc-empty").set({
      propertyId: "",
      tenantId: "t3",
      status: "active",
    })
  );
  await assertFails(
    ownerDb.collection("rental_contracts").doc("rc-invalid").set({
      propertyId: "prop-does-not-exist",
      tenantId: "t3",
      status: "active",
    })
  );
  await assertFails(
    ownerDb.collection("rental_contracts").doc("rc-other-prop").set({
      propertyId: "prop-other",
      tenantId: "t3",
      status: "active",
    })
  );
  await assertFails(unauthDb.collection("rental_contracts").doc("rc1").get());
  await assertSucceeds(adminDb.collection("rental_contracts").doc("rc1").get());
  await assertSucceeds(
    adminDb
      .collection("rental_contracts")
      .doc("rc1")
      .update({ monthlyRent: 5600 })
  );
  await assertSucceeds(ownerDb.collection("rental_contracts").doc("rc1").delete());

  // property_contracts must remain open under PR-010 (deferred) — do not assert harden.

  await testEnv.cleanup();
  console.log("PR-010 CRM batch-2 rules tests: ALL PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
