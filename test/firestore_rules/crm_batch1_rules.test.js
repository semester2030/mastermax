/**
 * PR-009 — CRM batch-1 rules tests (sales / rentals / property_sales).
 * Run with Firestore Emulator + @firebase/rules-unit-testing
 * (ephemeral firebase.json outside the repo — do not modify repo firebase.json).
 */
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const RULES = fs.readFileSync(
  path.join(__dirname, "../../firestore.rules"),
  "utf8"
);

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-pr009-crm-batch1",
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
    // Legacy sales docs (seeded; app no longer writes these fields alone).
    await db.doc(`sales/legacy-owner`).set({
      ownerId: owner,
      salePrice: 10,
    });
    await db.doc(`sales/legacy-user`).set({
      userId: owner,
      salePrice: 11,
    });
  });

  const ownerDb = testEnv.authenticatedContext(owner).firestore();
  const otherDb = testEnv.authenticatedContext(other).firestore();
  // Exercise existing isAdmin() path via custom claim (no change to shared isAdmin helper).
  const adminDb = testEnv
    .authenticatedContext(admin, { token: { admin: true } })
    .firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  // —— sales: companyId owner CRUD ——
  await assertSucceeds(
    ownerDb.collection("sales").doc("s-company").set({
      companyId: owner,
      propertyId: "prop-owned",
      salePrice: 100,
    })
  );
  await assertSucceeds(ownerDb.collection("sales").doc("s-company").get());
  await assertSucceeds(
    ownerDb.collection("sales").doc("s-company").update({ salePrice: 200 })
  );
  await assertFails(
    ownerDb.collection("sales").doc("s-company").update({ companyId: other })
  );
  await assertFails(otherDb.collection("sales").doc("s-company").get());
  await assertFails(
    otherDb.collection("sales").doc("s-company").update({ salePrice: 300 })
  );
  await assertFails(otherDb.collection("sales").doc("s-company").delete());
  await assertSucceeds(adminDb.collection("sales").doc("s-company").get());
  await assertSucceeds(
    adminDb.collection("sales").doc("s-company").update({ salePrice: 201 })
  );
  await assertSucceeds(ownerDb.collection("sales").doc("s-company").delete());

  // —— sales: sellerId owner CRUD ——
  await assertSucceeds(
    ownerDb.collection("sales").doc("s-seller").set({
      sellerId: owner,
      salePrice: 150,
    })
  );
  await assertSucceeds(ownerDb.collection("sales").doc("s-seller").get());
  await assertSucceeds(
    ownerDb.collection("sales").doc("s-seller").update({ salePrice: 160 })
  );
  await assertFails(
    ownerDb.collection("sales").doc("s-seller").update({ sellerId: other })
  );
  await assertFails(otherDb.collection("sales").doc("s-seller").get());
  await assertSucceeds(adminDb.collection("sales").doc("s-seller").get());
  await assertSucceeds(ownerDb.collection("sales").doc("s-seller").delete());

  // —— sales: legacy ownerId / userId access ——
  await assertSucceeds(ownerDb.collection("sales").doc("legacy-owner").get());
  await assertSucceeds(
    ownerDb.collection("sales").doc("legacy-owner").update({ salePrice: 12 })
  );
  await assertFails(
    ownerDb.collection("sales").doc("legacy-owner").update({ ownerId: other })
  );
  await assertFails(otherDb.collection("sales").doc("legacy-owner").get());
  await assertSucceeds(ownerDb.collection("sales").doc("legacy-user").get());
  await assertSucceeds(
    ownerDb.collection("sales").doc("legacy-user").update({ salePrice: 13 })
  );
  await assertFails(
    ownerDb.collection("sales").doc("legacy-user").update({ userId: other })
  );
  await assertFails(otherDb.collection("sales").doc("legacy-user").get());

  // —— sales: non-owner create / unauthenticated ——
  await assertFails(
    otherDb.collection("sales").doc("s-forge").set({
      companyId: owner,
      salePrice: 1,
    })
  );
  await assertFails(
    unauthDb.collection("sales").doc("s-unauth").set({ companyId: owner })
  );
  await assertFails(unauthDb.collection("sales").doc("legacy-owner").get());

  // —— rentals ——
  await assertSucceeds(
    ownerDb.collection("rentals").doc("r1").set({
      ownerId: owner,
      propertyId: "prop-owned",
      monthlyRent: 5000,
    })
  );
  await assertFails(
    otherDb.collection("rentals").doc("r2").set({
      ownerId: owner,
      monthlyRent: 1,
    })
  );
  await assertSucceeds(ownerDb.collection("rentals").doc("r1").get());
  await assertFails(otherDb.collection("rentals").doc("r1").get());
  await assertSucceeds(
    ownerDb.collection("rentals").doc("r1").update({ monthlyRent: 5500 })
  );
  await assertFails(
    otherDb.collection("rentals").doc("r1").update({ monthlyRent: 1 })
  );
  await assertFails(
    ownerDb.collection("rentals").doc("r1").update({ ownerId: other })
  );
  await assertFails(
    unauthDb.collection("rentals").doc("r1").get()
  );
  await assertSucceeds(adminDb.collection("rentals").doc("r1").get());
  await assertSucceeds(
    adminDb.collection("rentals").doc("r1").update({ monthlyRent: 5600 })
  );
  await assertSucceeds(ownerDb.collection("rentals").doc("r1").delete());

  // —— property_sales (ownership via properties.ownerId) ——
  await assertSucceeds(
    ownerDb.collection("property_sales").doc("ps1").set({
      propertyId: "prop-owned",
      sellingPrice: 900000,
    })
  );
  await assertFails(
    otherDb.collection("property_sales").doc("ps2").set({
      propertyId: "prop-owned",
      sellingPrice: 1,
    })
  );
  await assertFails(
    ownerDb.collection("property_sales").doc("ps3").set({
      propertyId: "prop-other",
      sellingPrice: 1,
    })
  );
  await assertFails(
    ownerDb.collection("property_sales").doc("ps-missing").set({
      sellingPrice: 1,
    })
  );
  await assertFails(
    ownerDb.collection("property_sales").doc("ps-invalid").set({
      propertyId: "prop-does-not-exist",
      sellingPrice: 1,
    })
  );
  await assertSucceeds(ownerDb.collection("property_sales").doc("ps1").get());
  await assertFails(otherDb.collection("property_sales").doc("ps1").get());
  await assertFails(unauthDb.collection("property_sales").doc("ps1").get());
  await assertSucceeds(
    ownerDb.collection("property_sales").doc("ps1").update({ sellingPrice: 910000 })
  );
  await assertFails(
    ownerDb.collection("property_sales").doc("ps1").update({
      propertyId: "prop-other",
    })
  );
  await assertFails(
    otherDb.collection("property_sales").doc("ps1").update({ sellingPrice: 1 })
  );
  await assertSucceeds(adminDb.collection("property_sales").doc("ps1").get());
  await assertSucceeds(
    adminDb.collection("property_sales").doc("ps1").update({ sellingPrice: 911000 })
  );
  await assertSucceeds(
    ownerDb.collection("property_sales").doc("ps1").delete()
  );

  await testEnv.cleanup();
  console.log("PR-009 CRM batch-1 rules tests: ALL PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
