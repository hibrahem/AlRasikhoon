/**
 * Firestore security-rules unit tests — privilege-boundary coverage for the
 * #28 supervisor-scoping work and the Shield (security review) BLOCKING
 * findings on PR #35.
 *
 * Run with the firestore emulator:
 *   npm install            (in this dir)
 *   npm test               (wraps `firebase emulators:exec --only firestore`)
 *
 * The rules read a caller's role + institute from their users/{uid} doc
 * (getUserRole() / callerInstituteId() in firestore.rules), NOT from the auth
 * token. So every actor is seeded with a users/{uid} doc via an
 * admin (rules-bypassing) context before the assertions run.
 */

const fs = require("fs");
const path = require("path");
const assert = require("assert");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "alrasikhoon-57151";
const RULES_PATH = path.resolve(__dirname, "../../firestore.rules");

// Institutes used throughout.
const INST_A = "institute_a";
const INST_B = "institute_b";

let testEnv;

// Seed a document bypassing rules (admin context).
async function seed(collPath, id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), collPath, id), data);
  });
}

// Authenticated client context for a given uid (role/institute come from the
// seeded users/{uid} doc, not from the token).
function asUser(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

describe("Firestore rules — supervisor institute scoping (#28 / PR #35)", function () {
  this.timeout(20000);

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(RULES_PATH, "utf8"),
        host: "127.0.0.1",
        port: 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();

    // --- Actors -------------------------------------------------------------
    // Supervisor bound to institute A.
    await seed("users", "sup_a", {
      role: "supervisor",
      institute_id: INST_A,
      name: "Supervisor A",
    });
    // Supervisor bound to institute B (cross-institute Sard tests, #29).
    await seed("users", "sup_b", {
      role: "supervisor",
      institute_id: INST_B,
      name: "Supervisor B",
    });
    // Teacher (no institute scoping on records; used to assert Sard is
    // supervisor-only, #29).
    await seed("users", "teacher_a", { role: "teacher", name: "Teacher A" });
    // Super admin.
    await seed("users", "admin", { role: "super_admin", name: "Admin" });

    // --- Students -----------------------------------------------------------
    await seed("students", "stu_a", { institute_id: INST_A, name: "Student A" });
    await seed("students", "stu_b", { institute_id: INST_B, name: "Student B" });
    // Legacy student with NO institute_id (must fail closed).
    await seed("students", "stu_legacy", { name: "Legacy student" });

    // --- Records (for update repoint tests) ---------------------------------
    await seed("session_records", "sess_a", {
      student_id: "stu_a",
      score: 5,
    });
    await seed("sard_records", "sard_a", {
      student_id: "stu_a",
      pages: 3,
    });
  });

  // === Finding #1 — self-service privilege escalation ======================

  it("DENIES a supervisor self-promoting to super_admin", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "users", "sup_a"), { role: "super_admin" })
    );
  });

  it("DENIES a supervisor changing their own institute_id", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "users", "sup_a"), { institute_id: INST_B })
    );
  });

  it("ALLOWS a supervisor editing other profile fields on their own doc", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      updateDoc(doc(db, "users", "sup_a"), { name: "Supervisor A (renamed)" })
    );
  });

  it("ALLOWS a super_admin to change any user's role + institute", async () => {
    const db = asUser("admin");
    await assertSucceeds(
      updateDoc(doc(db, "users", "sup_a"), {
        role: "super_admin",
        institute_id: INST_B,
      })
    );
  });

  // === Finding #2 — record repoint to another institute ====================

  it("DENIES a supervisor repointing a session_record's student_id to another institute", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "session_records", "sess_a"), { student_id: "stu_b" })
    );
  });

  it("DENIES a supervisor repointing a sard_record's student_id to another institute", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { student_id: "stu_b" })
    );
  });

  it("ALLOWS a supervisor updating an in-institute session_record (no repoint)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      updateDoc(doc(db, "session_records", "sess_a"), { score: 9 })
    );
  });

  it("ALLOWS a supervisor updating an in-institute sard_record (no repoint)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 7 })
    );
  });

  // === Cross-institute student write ========================================

  it("DENIES a supervisor writing (create) an out-of-institute student", async () => {
    const db = asUser("sup_a");
    await assertFails(
      setDoc(doc(db, "students", "new_b"), {
        institute_id: INST_B,
        name: "New B",
      })
    );
  });

  it("DENIES a supervisor updating an out-of-institute student", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "students", "stu_b"), { name: "tampered" })
    );
  });

  it("ALLOWS a supervisor creating an in-institute student", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      setDoc(doc(db, "students", "new_a"), {
        institute_id: INST_A,
        name: "New A",
      })
    );
  });

  // === Fail-closed on missing institute_id =================================

  it("DENIES a supervisor updating a student with no institute_id (fail-closed)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "students", "stu_legacy"), { name: "tampered" })
    );
  });

  it("DENIES a supervisor creating a session_record for a student with no institute_id (fail-closed)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      setDoc(doc(db, "session_records", "sess_legacy"), {
        student_id: "stu_legacy",
        score: 1,
      })
    );
  });

  // === Positive create: supervisor record for in-institute student =========

  it("ALLOWS a supervisor creating a session_record for an in-institute student", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      setDoc(doc(db, "session_records", "sess_new"), {
        student_id: "stu_a",
        score: 8,
      })
    );
  });

  // === #29 — Sard is SUPERVISOR-ONLY (teacher write removed) ================

  it("DENIES a teacher creating a sard_record (Sard is supervisor-only, #29)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_new_teacher"), {
        student_id: "stu_a",
        pages: 3,
      })
    );
  });

  it("DENIES a teacher updating an existing sard_record (Sard is supervisor-only, #29)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 9 })
    );
  });

  it("ALLOWS a supervisor creating a sard_record for an in-institute student (#29)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      setDoc(doc(db, "sard_records", "sard_new_sup"), {
        student_id: "stu_a",
        pages: 5,
      })
    );
  });

  it("ALLOWS a supervisor updating an in-institute sard_record (no repoint, #29)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 6 })
    );
  });

  it("DENIES a supervisor creating a sard_record for an out-of-institute student (cross-institute, #29)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_cross"), {
        student_id: "stu_b",
        pages: 4,
      })
    );
  });

  it("DENIES a supervisor in institute B updating a sard_record whose student is in institute A (cross-institute, #29)", async () => {
    const db = asUser("sup_b");
    // sard_a belongs to stu_a (institute A); sup_b is scoped to institute B.
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 8 })
    );
  });

  it("DENIES a supervisor creating a sard_record for a student with no institute_id (fail-closed, #29)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_legacy"), {
        student_id: "stu_legacy",
        pages: 1,
      })
    );
  });
});
