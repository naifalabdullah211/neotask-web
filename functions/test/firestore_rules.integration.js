"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  deleteField,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} = require("firebase/firestore");

const projectId = "neotask-spark-rules-test";
const validProof = "a".repeat(64);
let testEnv;

async function provisionProof() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "system", "manager_bootstrap"), {
      proofHash: validProof,
      createdAt: new Date().toISOString(),
    });
  });
}

function bootstrapTransaction(database, uid, proof) {
  const userRef = doc(database, "users", uid);
  const lockRef = doc(database, "system", "manager_lock");
  const proofRef = doc(database, "system", "manager_bootstrap");
  return runTransaction(database, async (transaction) => {
    const lock = await transaction.get(lockRef);
    assert.equal(lock.exists(), false);
    transaction.set(userRef, {
      uid,
      name: "Official Manager",
      email: "manager@neotask.local",
      employeeNumber: "900001",
      role: "manager",
      accountStatus: "active",
      createdAt: new Date().toISOString(),
      soundMessagesEnabled: true,
      soundTasksEnabled: true,
      remindersEnabled: true,
      weeklyCapacityHours: 40,
      managerWelcomeVersion: 0,
      bootstrapProof: proof,
    });
    transaction.set(lockRef, {
      createdBy: uid,
      createdAt: new Date().toISOString(),
    });
    transaction.delete(proofRef);
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "..", "firestore.rules"),
          "utf8",
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await provisionProof();
});

after(async () => {
  await testEnv.cleanup();
});

test("bootstrap proof cannot be read by an authenticated client", async () => {
  const database = testEnv.authenticatedContext("reader").firestore();
  await assertFails(getDoc(doc(database, "system", "manager_bootstrap")));
});

test("wrong proof cannot create a manager or lock", async () => {
  const database = testEnv.authenticatedContext("attacker").firestore();
  await assertFails(bootstrapTransaction(database, "attacker", "b".repeat(64)));
});

test("valid proof atomically creates one manager and consumes itself", async () => {
  const uid = "official-manager";
  const database = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(bootstrapTransaction(database, uid, validProof));

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    assert.equal((await getDoc(doc(adminDb, "users", uid))).exists(), true);
    assert.equal(
        (await getDoc(doc(adminDb, "system", "manager_lock"))).exists(),
        true,
    );
    assert.equal(
        (await getDoc(doc(adminDb, "system", "manager_bootstrap"))).exists(),
        false,
    );
  });

  await assertSucceeds(
      updateDoc(doc(database, "users", uid), {
        bootstrapProof: deleteField(),
      }),
  );
});

test("an employee cannot promote their own profile", async () => {
  const uid = "employee";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", uid), {
      uid,
      employeeNumber: "400200",
      role: "employee",
      accountStatus: "active",
    });
  });
  const database = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
      updateDoc(doc(database, "users", uid), {role: "manager"}),
  );
});

test("manager atomically links and removes an active agent rule record", async () => {
  const uid = "manager-agent-rules";
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", uid), {
      uid,
      employeeNumber: "900010",
      role: "manager",
      accountStatus: "active",
    });
  });

  const database = testEnv.authenticatedContext(uid).firestore();
  const ruleId = "rule-1";
  const ideaId = "idea-1";
  const createBatch = writeBatch(database);
  createBatch.set(doc(database, "manager_agent_rules", ruleId), {
    ruleId,
    instruction: "نبّه الفريق عند تأخر المهمة",
    createdBy: uid,
    createdByName: "المدير",
    createdAt: serverTimestamp(),
    active: true,
  });
  createBatch.set(doc(database, "manager_ideas", ideaId), {
    ideaId,
    content: "نبّه الفريق عند تأخر المهمة",
    authorUid: uid,
    authorName: "المدير",
    createdAt: serverTimestamp(),
    status: "new",
    recordType: "rule",
    actionType: "update_agent_rule",
    recordTitle: "تنبيه المهام المتأخرة",
    ruleId,
  });

  await assertSucceeds(createBatch.commit());
  await assertSucceeds(
      getDoc(doc(database, "manager_agent_rules", ruleId)),
  );
  await assertSucceeds(getDoc(doc(database, "manager_ideas", ideaId)));

  const deleteBatch = writeBatch(database);
  deleteBatch.delete(doc(database, "manager_agent_rules", ruleId));
  deleteBatch.delete(doc(database, "manager_ideas", ideaId));
  await assertSucceeds(deleteBatch.commit());
});
