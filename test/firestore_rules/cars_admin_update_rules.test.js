/**
 * PR-013 — cars admin update alignment (RK-037).
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
    projectId: "demo-pr013-cars-admin",
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
    await db.doc(`users/${owner}`).set({
      userType: "carDealer",
      isAdmin: false,
    });
    await db.doc(`users/${other}`).set({
      userType: "carDealer",
      isAdmin: false,
    });
    await db.doc(`users/${admin}`).set({
      userType: "carDealer",
      isAdmin: true,
    });
  });

  const ownerDb = testEnv.authenticatedContext(owner).firestore();
  const otherDb = testEnv.authenticatedContext(other).firestore();
  const adminDb = testEnv
    .authenticatedContext(admin, { token: { admin: true } })
    .firestore();
  const unauthDb = testEnv.unauthenticatedContext().firestore();

  // —— create preserved (owner) ——
  await assertSucceeds(
    ownerDb.collection("cars").doc("c1").set({
      sellerId: owner,
      brand: "Toyota",
      isActive: true,
    })
  );
  await assertFails(
    otherDb.collection("cars").doc("c2").set({
      sellerId: owner,
      brand: "Forge",
    })
  );

  // —— owner update PASS ——
  await assertSucceeds(
    ownerDb.collection("cars").doc("c1").update({ brand: "Toyota 2" })
  );

  // —— admin update PASS ——
  await assertSucceeds(
    adminDb.collection("cars").doc("c1").update({ brand: "Admin fix" })
  );

  // —— non-owner update DENY ——
  await assertFails(
    otherDb.collection("cars").doc("c1").update({ brand: "Hack" })
  );

  // —— unauthenticated update DENY ——
  await assertFails(
    unauthDb.collection("cars").doc("c1").update({ brand: "Noauth" })
  );

  // —— admin delete still DENY (update-only scope) ——
  await assertFails(adminDb.collection("cars").doc("c1").delete());

  // —— owner delete preserved ——
  await assertSucceeds(ownerDb.collection("cars").doc("c1").delete());

  await testEnv.cleanup();
  console.log("PR-013 cars admin update rules tests: ALL PASSED");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
