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
  deleteDoc,
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
    // Teachers. Record writes are scoped to a teacher's OWN students via
    // students.teacher_id (al_rasikhoon-ob7); teacher_b exists so we can assert
    // teacher A is denied on teacher B's students/records.
    await seed("users", "teacher_a", { role: "teacher", name: "Teacher A" });
    await seed("users", "teacher_b", { role: "teacher", name: "Teacher B" });
    // Super admin.
    await seed("users", "admin", { role: "super_admin", name: "Admin" });

    // Read-scoping actors (al_rasikhoon-bpk).
    // Guardians (role only; the child link lives on the student doc).
    await seed("users", "guardian_a", { role: "guardian", name: "Guardian A" });
    await seed("users", "guardian_b", { role: "guardian", name: "Guardian B" });
    // Students-as-users (the person behind a student doc). Their student doc
    // carries user_id == this uid.
    await seed("users", "stu_user_a", { role: "student", name: "Student user A" });
    await seed("users", "stu_user_b", { role: "student", name: "Student user B" });

    // --- Students -----------------------------------------------------------
    // teacher_id assigns the student to a teacher (al_rasikhoon-ob7 scoping):
    // stu_a → teacher_a, stu_b → teacher_b.
    await seed("students", "stu_a", {
      institute_id: INST_A,
      teacher_id: "teacher_a",
      name: "Student A",
    });
    await seed("students", "stu_b", {
      institute_id: INST_B,
      teacher_id: "teacher_b",
      name: "Student B",
    });
    // Legacy student with NO institute_id AND NO teacher_id (must fail closed
    // for both supervisor institute scoping and teacher record scoping).
    await seed("students", "stu_legacy", { name: "Legacy student" });

    // Read-scoping students: each has a linked user (user_id) and guardian
    // (guardian_id), an institute for supervisor scoping, and a teacher_id for
    // teacher scoping (child A → teacher_a, child B → teacher_b).
    await seed("students", "stu_child_a", {
      institute_id: INST_A,
      teacher_id: "teacher_a",
      user_id: "stu_user_a",
      guardian_id: "guardian_a",
      name: "Child A",
    });
    await seed("students", "stu_child_b", {
      institute_id: INST_B,
      teacher_id: "teacher_b",
      user_id: "stu_user_b",
      guardian_id: "guardian_b",
      name: "Child B",
    });

    // --- Records (for update repoint tests) ---------------------------------
    await seed("session_records", "sess_a", {
      student_id: "stu_a",
      score: 5,
    });
    await seed("sard_records", "sard_a", {
      student_id: "stu_a",
      pages: 3,
    });

    // Read-scoping records, one per child, per collection.
    await seed("session_records", "sess_child_a", { student_id: "stu_child_a", score: 5 });
    await seed("session_records", "sess_child_b", { student_id: "stu_child_b", score: 5 });
    await seed("sard_records", "sard_child_a", { student_id: "stu_child_a", pages: 3 });
    await seed("sard_records", "sard_child_b", { student_id: "stu_child_b", pages: 3 });
    await seed("exam_records", "exam_child_a", { student_id: "stu_child_a", errors: 1 });
    await seed("exam_records", "exam_child_b", { student_id: "stu_child_b", errors: 1 });

    // Home practices, one per child (al_rasikhoon-c6e). Each carries a
    // denormalized student_id and scopes through its student like the records
    // above. hp_orphan has NO student_id to prove reads/writes fail closed.
    await seed("home_practices", "hp_child_a", { student_id: "stu_child_a", repetitions: 3 });
    await seed("home_practices", "hp_child_b", { student_id: "stu_child_b", repetitions: 3 });
    await seed("home_practices", "hp_orphan", { repetitions: 3 });
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

  it("ALLOWS a supervisor updating an in-institute session_record (no repoint)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      updateDoc(doc(db, "session_records", "sess_a"), { score: 9 })
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

  // === al_rasikhoon-801 — Sard is TEACHER-ONLY (reverses #29) ===============
  // سرد is conducted by the TEACHER; the supervisor conducts الاختبار. Teacher
  // writes are now scoped to the teacher's OWN students (al_rasikhoon-ob7):
  // stu_a belongs to teacher_a, so these ALLOWs still hold.

  it("ALLOWS a teacher creating a sard_record for their OWN student (al_rasikhoon-801/ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(
      setDoc(doc(db, "sard_records", "sard_new_teacher"), {
        student_id: "stu_a",
        pages: 3,
      })
    );
  });

  it("ALLOWS a teacher updating an existing sard_record for their OWN student (al_rasikhoon-801/ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 9 })
    );
  });

  it("DENIES a supervisor creating a sard_record, even for an in-institute student (al_rasikhoon-801)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_new_sup"), {
        student_id: "stu_a",
        pages: 5,
      })
    );
  });

  it("DENIES a supervisor updating a sard_record, even for an in-institute student (al_rasikhoon-801)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 6 })
    );
  });

  it("DENIES an unauthenticated client writing a sard_record", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_anon"), {
        student_id: "stu_a",
        pages: 1,
      })
    );
  });

  // === al_rasikhoon-801 — Exam is SUPERVISOR-ONLY (unchanged) ===============
  // الاختبار is conducted by the SUPERVISOR; the teacher conducts السرد
  // (see sard_records above). Exclusive on BOTH sides.

  it("DENIES a teacher creating an exam_record (Exam is supervisor-conducted, al_rasikhoon-801)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      setDoc(doc(db, "exam_records", "exam_new_teacher"), {
        student_id: "stu_a",
        errors: 2,
      })
    );
  });

  it("ALLOWS a supervisor creating an exam_record (al_rasikhoon-801)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      setDoc(doc(db, "exam_records", "exam_new_sup"), {
        student_id: "stu_a",
        errors: 2,
      })
    );
  });

  // === al_rasikhoon-bpk — READ scoping on students =========================
  // Previously `allow read: if isAuthenticated()`, so any signed-in user could
  // read every student across institutes. Reads are now scoped by role. Each
  // deny proves the app CANNOT fetch forbidden data even by direct ID (a
  // client .where() filter is not access control); each allow guards against
  // regressing a legitimate read.

  // --- student self-reads ---------------------------------------------------
  it("DENIES a student reading another student's record", async () => {
    const db = asUser("stu_user_a");
    await assertFails(getDoc(doc(db, "students", "stu_child_b")));
  });

  it("ALLOWS a student reading their OWN student record", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(getDoc(doc(db, "students", "stu_child_a")));
  });

  // --- guardian reads -------------------------------------------------------
  it("DENIES a guardian reading a student who is not their child", async () => {
    const db = asUser("guardian_a");
    await assertFails(getDoc(doc(db, "students", "stu_child_b")));
  });

  it("ALLOWS a guardian reading their own child's student record", async () => {
    const db = asUser("guardian_a");
    await assertSucceeds(getDoc(doc(db, "students", "stu_child_a")));
  });

  // --- supervisor institute scoping (reuses write-side helper) --------------
  it("DENIES a supervisor of institute A reading a student of institute B", async () => {
    const db = asUser("sup_a");
    await assertFails(getDoc(doc(db, "students", "stu_child_b")));
  });

  it("ALLOWS a supervisor of institute A reading a student of institute A", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(getDoc(doc(db, "students", "stu_child_a")));
  });

  it("DENIES a supervisor reading a student with no institute_id (fail-closed)", async () => {
    const db = asUser("sup_a");
    await assertFails(getDoc(doc(db, "students", "stu_legacy")));
  });

  // --- teacher scoping (al_rasikhoon-ob7) -----------------------------------
  // Teacher reads are now scoped to the teacher's OWN students via
  // students.teacher_id, closing the cross-institute hole bpk deferred. child A
  // belongs to teacher_a; child B belongs to teacher_b.
  it("DENIES a teacher reading another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(getDoc(doc(db, "students", "stu_child_b")));
  });

  it("ALLOWS a teacher reading their OWN student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(getDoc(doc(db, "students", "stu_child_a")));
  });

  it("DENIES a teacher reading a teacher-less student (fail-closed, al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(getDoc(doc(db, "students", "stu_legacy")));
  });

  it("ALLOWS an admin reading any student", async () => {
    const db = asUser("admin");
    await assertSucceeds(getDoc(doc(db, "students", "stu_child_b")));
  });

  it("DENIES an unauthenticated client reading a student", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "students", "stu_child_a")));
  });

  // === al_rasikhoon-bpk — READ scoping on records ==========================
  // session/sard/exam records carry a denormalized student_id and are scoped
  // through their student (records have no institute_id of their own).

  // --- session_records ------------------------------------------------------
  it("DENIES a student reading another student's session_record", async () => {
    const db = asUser("stu_user_a");
    await assertFails(getDoc(doc(db, "session_records", "sess_child_b")));
  });

  it("ALLOWS a student reading their OWN session_record", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(getDoc(doc(db, "session_records", "sess_child_a")));
  });

  it("DENIES a guardian reading a non-child's session_record", async () => {
    const db = asUser("guardian_a");
    await assertFails(getDoc(doc(db, "session_records", "sess_child_b")));
  });

  it("ALLOWS a guardian reading their child's session_record", async () => {
    const db = asUser("guardian_a");
    await assertSucceeds(getDoc(doc(db, "session_records", "sess_child_a")));
  });

  it("DENIES a supervisor of institute A reading an institute-B session_record", async () => {
    const db = asUser("sup_a");
    await assertFails(getDoc(doc(db, "session_records", "sess_child_b")));
  });

  it("ALLOWS a supervisor of institute A reading an institute-A session_record", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(getDoc(doc(db, "session_records", "sess_child_a")));
  });

  it("DENIES a teacher reading another teacher's session_record (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(getDoc(doc(db, "session_records", "sess_child_b")));
  });

  it("ALLOWS a teacher reading their own student's session_record (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(getDoc(doc(db, "session_records", "sess_child_a")));
  });

  it("DENIES an unauthenticated client reading a session_record", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "session_records", "sess_child_a")));
  });

  // --- sard_records ---------------------------------------------------------
  it("DENIES a guardian reading a non-child's sard_record", async () => {
    const db = asUser("guardian_a");
    await assertFails(getDoc(doc(db, "sard_records", "sard_child_b")));
  });

  it("ALLOWS a guardian reading their child's sard_record", async () => {
    const db = asUser("guardian_a");
    await assertSucceeds(getDoc(doc(db, "sard_records", "sard_child_a")));
  });

  it("DENIES a supervisor of institute A reading an institute-B sard_record", async () => {
    const db = asUser("sup_a");
    await assertFails(getDoc(doc(db, "sard_records", "sard_child_b")));
  });

  it("DENIES a teacher reading another teacher's sard_record (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(getDoc(doc(db, "sard_records", "sard_child_b")));
  });

  it("ALLOWS a teacher reading their own student's sard_record (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(getDoc(doc(db, "sard_records", "sard_child_a")));
  });

  // --- exam_records ---------------------------------------------------------
  it("DENIES a student reading another student's exam_record", async () => {
    const db = asUser("stu_user_a");
    await assertFails(getDoc(doc(db, "exam_records", "exam_child_b")));
  });

  it("ALLOWS a student reading their OWN exam_record", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(getDoc(doc(db, "exam_records", "exam_child_a")));
  });

  it("DENIES a supervisor of institute A reading an institute-B exam_record", async () => {
    const db = asUser("sup_a");
    await assertFails(getDoc(doc(db, "exam_records", "exam_child_b")));
  });

  it("ALLOWS a supervisor of institute A reading an institute-A exam_record", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(getDoc(doc(db, "exam_records", "exam_child_a")));
  });

  it("DENIES a teacher reading another teacher's exam_record (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(getDoc(doc(db, "exam_records", "exam_child_b")));
  });

  it("ALLOWS a teacher reading their own student's exam_record (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(getDoc(doc(db, "exam_records", "exam_child_a")));
  });

  // === al_rasikhoon-ob7 — teacher record WRITE scoping =====================
  // A teacher may create/update session_records and sard_records ONLY for their
  // OWN students (students.teacher_id == uid), resolved through the record's
  // student. On update, BOTH the existing and incoming student are checked so
  // student_id cannot be repointed onto another teacher's student. stu_a/child_a
  // belong to teacher_a; stu_b/child_b belong to teacher_b.

  // --- session_records: create ----------------------------------------------
  it("DENIES a teacher creating a session_record for another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      setDoc(doc(db, "session_records", "sess_cross"), {
        student_id: "stu_b",
        score: 7,
      })
    );
  });

  it("ALLOWS a teacher creating a session_record for their OWN student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(
      setDoc(doc(db, "session_records", "sess_own_new"), {
        student_id: "stu_a",
        score: 7,
      })
    );
  });

  it("DENIES a teacher creating a session_record for a teacher-less student (fail-closed, al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      setDoc(doc(db, "session_records", "sess_legacy"), {
        student_id: "stu_legacy",
        score: 1,
      })
    );
  });

  // --- session_records: update + repoint ------------------------------------
  it("DENIES a teacher updating a session_record of another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      updateDoc(doc(db, "session_records", "sess_child_b"), { score: 9 })
    );
  });

  it("ALLOWS a teacher updating a session_record of their OWN student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(
      updateDoc(doc(db, "session_records", "sess_a"), { score: 9 })
    );
  });

  it("DENIES a teacher repointing a session_record's student_id to another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      updateDoc(doc(db, "session_records", "sess_a"), { student_id: "stu_b" })
    );
  });

  // --- sard_records: create -------------------------------------------------
  it("DENIES a teacher creating a sard_record for another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_cross"), {
        student_id: "stu_b",
        pages: 4,
      })
    );
  });

  // --- sard_records: update + repoint ---------------------------------------
  it("DENIES a teacher updating a sard_record of another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_child_b"), { pages: 9 })
    );
  });

  it("DENIES a teacher repointing a sard_record's student_id to another teacher's student (al_rasikhoon-ob7)", async () => {
    const db = asUser("teacher_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { student_id: "stu_b" })
    );
  });

  // === al_rasikhoon-c6e — home_practices READ scoping ======================
  // Previously `allow read: if isAuthenticated()`, so any signed-in user could
  // read every student's home practice across institutes. Reads now scope by
  // role through the practice's student_id via canReadRecord() — the same matrix
  // as session/sard/exam records. child A → institute A / teacher_a / guardian_a
  // / user stu_user_a; child B → institute B / teacher_b / guardian_b.

  it("DENIES a student reading another student's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertFails(getDoc(doc(db, "home_practices", "hp_child_b")));
  });

  it("ALLOWS a student reading their OWN home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(getDoc(doc(db, "home_practices", "hp_child_a")));
  });

  it("DENIES a guardian reading a non-child's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("guardian_a");
    await assertFails(getDoc(doc(db, "home_practices", "hp_child_b")));
  });

  it("ALLOWS a guardian reading their child's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("guardian_a");
    await assertSucceeds(getDoc(doc(db, "home_practices", "hp_child_a")));
  });

  it("DENIES a supervisor of institute A reading an institute-B home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("sup_a");
    await assertFails(getDoc(doc(db, "home_practices", "hp_child_b")));
  });

  it("ALLOWS a supervisor of institute A reading an institute-A home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(getDoc(doc(db, "home_practices", "hp_child_a")));
  });

  it("DENIES a teacher reading another teacher's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("teacher_a");
    await assertFails(getDoc(doc(db, "home_practices", "hp_child_b")));
  });

  it("ALLOWS a teacher reading their own student's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(getDoc(doc(db, "home_practices", "hp_child_a")));
  });

  it("ALLOWS an admin reading any home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("admin");
    await assertSucceeds(getDoc(doc(db, "home_practices", "hp_child_b")));
  });

  it("DENIES a student reading a home_practice with no student_id (fail-closed, al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertFails(getDoc(doc(db, "home_practices", "hp_orphan")));
  });

  it("DENIES an unauthenticated client reading a home_practice (al_rasikhoon-c6e)", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "home_practices", "hp_child_a")));
  });

  // === al_rasikhoon-c6e — home_practices WRITE scoping =====================
  // A student may create/update/delete ONLY their OWN home_practice (the
  // practice's student_id resolves to a student doc whose user_id == the caller,
  // via isOwnRecord). Previously ANY student could write ANY home_practice. On
  // update BOTH the existing and incoming student must be the caller's, so
  // student_id cannot be repointed onto another student.

  it("ALLOWS a student creating their OWN home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(
      setDoc(doc(db, "home_practices", "hp_own_new"), {
        student_id: "stu_child_a",
        repetitions: 5,
      })
    );
  });

  it("DENIES a student creating a home_practice for another student (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertFails(
      setDoc(doc(db, "home_practices", "hp_cross_new"), {
        student_id: "stu_child_b",
        repetitions: 5,
      })
    );
  });

  it("ALLOWS a student updating their OWN home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(
      updateDoc(doc(db, "home_practices", "hp_child_a"), { repetitions: 9 })
    );
  });

  it("DENIES a student updating another student's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertFails(
      updateDoc(doc(db, "home_practices", "hp_child_b"), { repetitions: 9 })
    );
  });

  it("DENIES a student repointing their home_practice's student_id to another student (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertFails(
      updateDoc(doc(db, "home_practices", "hp_child_a"), { student_id: "stu_child_b" })
    );
  });

  it("ALLOWS a student deleting their OWN home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertSucceeds(
      deleteDoc(doc(db, "home_practices", "hp_child_a"))
    );
  });

  it("DENIES a student deleting another student's home_practice (al_rasikhoon-c6e)", async () => {
    const db = asUser("stu_user_a");
    await assertFails(
      deleteDoc(doc(db, "home_practices", "hp_child_b"))
    );
  });
});
