import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

admin.initializeApp();

interface SetUserPasswordPayload {
  userId: string;
  newPassword: string;
}

type ProvisionableRole =
  | "supervisor"
  | "teacher"
  | "student"
  | "guardian";

interface CreateUserAccountPayload {
  email: string;
  password: string;
  role: ProvisionableRole;
  name: string;
  username: string;
  phone?: string | null;
  // For role === "supervisor": an INITIAL institute to seed the supervisor's
  // membership with, as a convenience at creation. It is NOT "the" institute —
  // a supervisor may be assigned to several institutes over time via the
  // supervisor_institutes membership docs (al_rasikhoon-3n6). Ignored for other
  // roles.
  instituteId?: string | null;
}

const MIN_PASSWORD_LENGTH = 6;

/**
 * The set of institute ids a supervisor is CURRENTLY assigned to, read off the
 * supervisor_institutes membership docs (al_rasikhoon-3n6). This is the source
 * of truth for supervisor scoping — users/{uid}.institute_id is no longer
 * authoritative (a supervisor may supervise several institutes at once, or be
 * unassigned). Mirrors the firestore.rules supervisorInInstitute() check and
 * honours the same soft-delete: removeSupervisorFromInstitute sets
 * is_active:false rather than deleting, so inactive memberships are excluded.
 */
async function supervisorInstituteIds(uid: string): Promise<Set<string>> {
  const snapshot = await admin
    .firestore()
    .collection("supervisor_institutes")
    .where("supervisor_id", "==", uid)
    .where("is_active", "==", true)
    .get();
  const ids = new Set<string>();
  for (const docSnap of snapshot.docs) {
    const instituteId = docSnap.data().institute_id;
    if (typeof instituteId === "string" && instituteId.length > 0) {
      ids.add(instituteId);
    }
  }
  return ids;
}

const ROLES_BY_CALLER: Record<string, ReadonlySet<ProvisionableRole>> = {
  super_admin: new Set<ProvisionableRole>([
    "supervisor",
    "teacher",
    "student",
    "guardian",
  ]),
  teacher: new Set<ProvisionableRole>(["student", "guardian"]),
  // Supervisors have teacher-parity student management across the institutes
  // they supervise (al_rasikhoon-3n6): they may provision student + guardian
  // accounts. The institute scoping itself is enforced by (a) requiring the
  // supervisor caller to have at least one active supervisor_institutes
  // membership (checked below) and (b) the student doc carrying an institute
  // the caller is a member of, enforced in firestore.rules.
  supervisor: new Set<ProvisionableRole>(["student", "guardian"]),
};

/**
 * Provision a Firebase Auth user AND its users/{uid} Firestore profile
 * atomically on behalf of an admin or teacher caller. The client SDK's
 * createUserWithEmailAndPassword auto-signs-in the new user and would evict
 * the caller's session, so all admin/teacher provisioning flows go through
 * this function.
 *
 * Authorization (custom claim 'role' set by syncRoleClaim below):
 *   - super_admin can provision supervisor | teacher | student | guardian.
 *   - teacher    can provision student | guardian.
 *
 * Supervisor accounts are seeded with an INITIAL institute: the caller passes
 * `instituteId`, which is recorded as a supervisor_institutes/{uid}_{instituteId}
 * membership (the source of truth the supervisor experience resolves via
 * getInstitutesForSupervisor) and also mirrored onto users/{uid}.institute_id
 * for legacy/convenience. Scoping reads the MEMBERSHIP, not that field
 * (al_rasikhoon-3n6): a supervisor may later be assigned to more institutes.
 *
 * Atomicity: pre-checks username uniqueness, creates the auth user, then
 * writes users/{uid} (+ the supervisor_institutes assignment for
 * supervisors). If any Firestore write fails, the auth user is deleted to
 * avoid orphans. (No two-phase commit between Auth and Firestore exists;
 * this rollback closes the dominant client-crash window.)
 *
 * Returns: { uid: string }
 */
export const createUserAccount = onCall<CreateUserAccountPayload>(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }

    const callerRole = request.auth.token.role as string | undefined;
    const allowed = callerRole ? ROLES_BY_CALLER[callerRole] : undefined;
    if (!allowed) {
      throw new HttpsError(
        "permission-denied",
        "Only admins and teachers can provision accounts",
      );
    }

    const { email, password, role, name, username, phone, instituteId } =
      request.data ?? ({} as CreateUserAccountPayload);

    if (!email || typeof email !== "string") {
      throw new HttpsError("invalid-argument", "email is required");
    }
    if (!password || typeof password !== "string") {
      throw new HttpsError("invalid-argument", "password is required");
    }
    if (password.length < MIN_PASSWORD_LENGTH) {
      throw new HttpsError("invalid-argument", "weak-password");
    }
    if (!name || typeof name !== "string" || name.trim().length === 0) {
      throw new HttpsError("invalid-argument", "name is required");
    }
    if (!username || typeof username !== "string" || username.trim().length === 0) {
      throw new HttpsError("invalid-argument", "username is required");
    }
    if (!role || !allowed.has(role as ProvisionableRole)) {
      throw new HttpsError(
        "permission-denied",
        `Caller role '${callerRole}' cannot provision role '${role}'`,
      );
    }

    // A supervisor caller may only provision accounts for institutes they
    // supervise (al_rasikhoon-3n6). Scoping is now the supervisor_institutes
    // MEMBERSHIP, not users/{caller}.institute_id: a supervisor assigned to NO
    // institute cannot provision at all. The provisioned student/guardian is
    // then bound to a specific institute by the student doc the client writes,
    // and firestore.rules (isSupervisorOfStudentInstitute → supervisorInInstitute)
    // enforces that the student's institute_id is one of the caller's memberships
    // — so per-institute scoping is enforced at that write, and this gate only
    // rejects a supervisor with an empty membership set.
    if (callerRole === "supervisor") {
      const callerInstitutes = await supervisorInstituteIds(request.auth.uid);
      if (callerInstitutes.size === 0) {
        throw new HttpsError(
          "permission-denied",
          "supervisor-has-no-institute",
        );
      }
    }

    // Supervisors are bound to exactly one institute at creation time.
    let normalizedInstituteId: string | null = null;
    if (role === "supervisor") {
      if (
        !instituteId ||
        typeof instituteId !== "string" ||
        instituteId.trim().length === 0
      ) {
        throw new HttpsError(
          "invalid-argument",
          "instituteId is required for supervisor accounts",
        );
      }
      normalizedInstituteId = instituteId.trim();
      const instituteDoc = await admin
        .firestore()
        .collection("institutes")
        .doc(normalizedInstituteId)
        .get();
      if (!instituteDoc.exists || instituteDoc.data()?.is_active === false) {
        throw new HttpsError("not-found", "institute-not-found");
      }
    }

    const normalizedUsername = username.trim().toLowerCase();

    const usernameClash = await admin
      .firestore()
      .collection("users")
      .where("username", "==", normalizedUsername)
      .limit(1)
      .get();
    if (!usernameClash.empty) {
      throw new HttpsError("already-exists", "username-taken");
    }

    let uid: string;
    try {
      const userRecord = await admin.auth().createUser({ email, password });
      uid = userRecord.uid;
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "email-already-in-use");
      }
      if (code === "auth/invalid-email") {
        throw new HttpsError("invalid-argument", "invalid-email");
      }
      if (code === "auth/invalid-password") {
        throw new HttpsError("invalid-argument", "weak-password");
      }
      logger.error("createUserAccount: auth.createUser failed", {
        caller: request.auth.uid,
        error: String(e),
      });
      throw new HttpsError("internal", "Account creation failed");
    }

    try {
      const userDoc: Record<string, unknown> = {
        username: normalizedUsername,
        email,
        name: name.trim(),
        role,
        phone: phone ?? null,
        auth_provider: "email_password",
        is_active: true,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      };
      // Carry the institute binding on the account record itself so the
      // permission/scoping model (#28) can enforce it without a join read.
      if (normalizedInstituteId) {
        userDoc.institute_id = normalizedInstituteId;
      }

      if (normalizedInstituteId) {
        // Write the user doc and the supervisor_institutes assignment in one
        // atomic batch — the supervisor experience resolves institutes via
        // getInstitutesForSupervisor() against this join collection.
        const batch = admin.firestore().batch();
        batch.set(admin.firestore().collection("users").doc(uid), userDoc);
        batch.set(
          admin
            .firestore()
            .collection("supervisor_institutes")
            .doc(`${uid}_${normalizedInstituteId}`),
          {
            supervisor_id: uid,
            institute_id: normalizedInstituteId,
            assigned_at: admin.firestore.FieldValue.serverTimestamp(),
            is_active: true,
          },
        );
        await batch.commit();
      } else {
        await admin.firestore().collection("users").doc(uid).set(userDoc);
      }
    } catch (e) {
      // Roll back the auth user so we don't leak an orphan.
      logger.error("createUserAccount: Firestore write failed, rolling back auth user", {
        caller: request.auth.uid,
        uid,
        error: String(e),
      });
      try {
        await admin.auth().deleteUser(uid);
      } catch (rollbackErr) {
        logger.error("createUserAccount: rollback deleteUser also failed", {
          uid,
          error: String(rollbackErr),
        });
      }
      throw new HttpsError("internal", "Account creation failed");
    }

    logger.info("createUserAccount: created", {
      caller: request.auth.uid,
      callerRole,
      uid,
      role,
      instituteId: normalizedInstituteId,
    });
    return { uid };
  },
);

/**
 * Reset another user's password. Used by the admin, teacher, and supervisor
 * detail screens. Authorization:
 *   - super_admin can reset any user.
 *   - teacher can reset a student whose teacher_id matches the caller.
 *   - supervisor can reset a student/guardian in one of the institutes they
 *     supervise (teacher-parity student management, al_rasikhoon-3n6:
 *     scoped by supervisor_institutes membership, not users.institute_id).
 * Custom claim 'role' is set by syncRoleClaim below.
 */
export const setUserPassword = onCall<SetUserPasswordPayload>(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }

    const { userId, newPassword } = request.data ?? {};
    if (!userId || typeof userId !== "string") {
      throw new HttpsError("invalid-argument", "userId is required");
    }
    if (!newPassword || typeof newPassword !== "string") {
      throw new HttpsError("invalid-argument", "newPassword is required");
    }
    if (newPassword.length < MIN_PASSWORD_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters`,
      );
    }

    const callerRole = request.auth.token.role as string | undefined;
    if (callerRole === "super_admin") {
      // Allowed.
    } else if (callerRole === "teacher") {
      // Verify the target is a student of this teacher.
      const targetUserDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();
      if (!targetUserDoc.exists) {
        throw new HttpsError("not-found", "Target user not found");
      }
      const targetRole = targetUserDoc.data()?.role;
      if (targetRole !== "student" && targetRole !== "guardian") {
        throw new HttpsError(
          "permission-denied",
          "Teachers may only reset student/guardian passwords",
        );
      }
      const studentSnapshot = await admin
        .firestore()
        .collection("students")
        .where("user_id", "==", userId)
        .limit(1)
        .get();
      if (studentSnapshot.empty) {
        throw new HttpsError(
          "permission-denied",
          "Teacher cannot reset this user (no student record)",
        );
      }
      const teacherId = studentSnapshot.docs[0].data().teacher_id;
      if (teacherId !== request.auth.uid) {
        throw new HttpsError(
          "permission-denied",
          "Teacher does not own this student",
        );
      }
    } else if (callerRole === "supervisor") {
      // Teacher-parity (al_rasikhoon-3n6): a supervisor may reset a
      // student/guardian password only for a student in ONE OF the institutes
      // they supervise. Scoping is the supervisor_institutes MEMBERSHIP set, not
      // users/{caller}.institute_id — a supervisor may supervise several
      // institutes at once.
      const targetUserDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();
      if (!targetUserDoc.exists) {
        throw new HttpsError("not-found", "Target user not found");
      }
      const targetRole = targetUserDoc.data()?.role;
      if (targetRole !== "student" && targetRole !== "guardian") {
        throw new HttpsError(
          "permission-denied",
          "Supervisors may only reset student/guardian passwords",
        );
      }
      const supervisorInstitutes = await supervisorInstituteIds(
        request.auth.uid,
      );
      if (supervisorInstitutes.size === 0) {
        throw new HttpsError("permission-denied", "supervisor-has-no-institute");
      }
      // The target must be a student in one of the supervisor's institutes (a
      // guardian is reachable via the student they guard). We resolve the
      // candidate student docs by the user link, then check their institute_id
      // against the membership set in code — this avoids a `whereIn` on
      // institute_id (capped at 30) when a supervisor spans many institutes.
      const candidateStudents = await admin
        .firestore()
        .collection("students")
        .where(
          targetRole === "guardian" ? "guardian_id" : "user_id",
          "==",
          userId,
        )
        .limit(20)
        .get();
      const inScope = candidateStudents.docs.some((docSnap) => {
        const instituteId = docSnap.data().institute_id;
        return (
          typeof instituteId === "string" &&
          supervisorInstitutes.has(instituteId)
        );
      });
      if (!inScope) {
        throw new HttpsError(
          "permission-denied",
          "Supervisor cannot reset this user (not in their institutes)",
        );
      }
    } else {
      throw new HttpsError(
        "permission-denied",
        "Only admins, teachers, and supervisors can reset passwords",
      );
    }

    await admin.auth().updateUser(userId, { password: newPassword });
    logger.info("setUserPassword: reset", {
      caller: request.auth.uid,
      target: userId,
    });
    return { success: true };
  },
);

interface HardDeleteStudentPayload {
  studentId: string;
}

/**
 * Firestore batches cap at 500 writes; stay under it while deleting an
 * unbounded query result set. Returns the number of documents deleted.
 */
const DELETE_CHUNK_SIZE = 400;

async function deleteAllMatching(
  query: FirebaseFirestore.Query,
): Promise<number> {
  let deleted = 0;
  for (;;) {
    const snapshot = await query.limit(DELETE_CHUNK_SIZE).get();
    if (snapshot.empty) return deleted;
    const batch = admin.firestore().batch();
    for (const docSnap of snapshot.docs) {
      batch.delete(docSnap.ref);
    }
    await batch.commit();
    deleted += snapshot.size;
  }
}

/**
 * Permanently delete a student and EVERY trace of their data. Super-admin
 * only — this is the hard-delete counterpart of the app-wide soft-delete
 * convention (is_active: false), reserved for the admin "حذف نهائي" flow.
 *
 * The cascade must live here, not on the client: firestore.rules give
 * clients no delete on the progress-record collections, and only the Admin
 * SDK can delete another user's Firebase Auth account.
 *
 * Deletion order is children-first so a mid-run crash leaves the student
 * doc intact and the whole operation retryable (re-running resumes where it
 * stopped; nothing is orphaned invisibly):
 *   1. progress records keyed by student_id (session_records, sard_records,
 *      exam_records, home_practices),
 *   2. the reposition_audit SUBcollection (Firestore does not auto-delete
 *      subcollections with their parent doc),
 *   3. the students/{id} doc itself,
 *   4. the linked users/{uid} doc + Auth account — but only when no other
 *      student doc references the same user_id. The guardian account is a
 *      reference OUT of the aggregate and is never deleted (a guardian may
 *      guard other students).
 *
 * Deleting users/{uid} also fires syncRoleClaim below, clearing the claim.
 */
export const hardDeleteStudent = onCall<HardDeleteStudentPayload>(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const callerRole = request.auth.token.role as string | undefined;
    if (callerRole !== "super_admin") {
      throw new HttpsError(
        "permission-denied",
        "Only super admins can permanently delete students",
      );
    }

    const { studentId } = request.data ?? ({} as HardDeleteStudentPayload);
    if (!studentId || typeof studentId !== "string") {
      throw new HttpsError("invalid-argument", "studentId is required");
    }

    const db = admin.firestore();
    const studentRef = db.collection("students").doc(studentId);
    const studentSnap = await studentRef.get();
    if (!studentSnap.exists) {
      throw new HttpsError("not-found", "student-not-found");
    }
    const userId = studentSnap.data()?.user_id as string | undefined;

    const recordCollections = [
      "session_records",
      "sard_records",
      "exam_records",
      "home_practices",
    ] as const;
    const deletedCounts: Record<string, number> = {};
    for (const collection of recordCollections) {
      deletedCounts[collection] = await deleteAllMatching(
        db.collection(collection).where("student_id", "==", studentId),
      );
    }
    deletedCounts.reposition_audit = await deleteAllMatching(
      studentRef.collection("reposition_audit"),
    );

    await studentRef.delete();

    let accountDeleted = false;
    if (userId) {
      const otherStudentWithSameUser = await db
        .collection("students")
        .where("user_id", "==", userId)
        .limit(1)
        .get();
      if (otherStudentWithSameUser.empty) {
        await db.collection("users").doc(userId).delete();
        try {
          await admin.auth().deleteUser(userId);
        } catch (e) {
          const code = (e as { code?: string }).code;
          if (code !== "auth/user-not-found") {
            // The Firestore data is already gone; surface the auth leftover
            // rather than failing the whole call and re-reporting not-found
            // on retry.
            logger.error("hardDeleteStudent: auth deleteUser failed", {
              caller: request.auth.uid,
              studentId,
              userId,
              error: String(e),
            });
          }
        }
        accountDeleted = true;
      }
    }

    logger.info("hardDeleteStudent: deleted", {
      caller: request.auth.uid,
      studentId,
      userId: userId ?? null,
      accountDeleted,
      deletedCounts,
    });
    return { success: true, deletedCounts };
  },
);

/**
 * Mirror the user doc's `role` field into a Firebase Auth custom claim
 * so it can be checked cheaply in onCall handlers and Firestore rules.
 */
export const syncRoleClaim = onDocumentWritten(
  { document: "users/{uid}", region: "us-central1" },
  async (event) => {
    const uid = event.params.uid;
    const after = event.data?.after.data();

    if (!after) {
      // User doc deleted — clear the role claim.
      try {
        await admin.auth().setCustomUserClaims(uid, null);
      } catch (e) {
        logger.warn("syncRoleClaim: clear failed (auth user may not exist)", {
          uid,
          error: String(e),
        });
      }
      return;
    }

    const role = after.role;
    if (typeof role !== "string") return;

    try {
      await admin.auth().setCustomUserClaims(uid, { role });
    } catch (e) {
      logger.warn("syncRoleClaim: set failed (auth user may not exist yet)", {
        uid,
        role,
        error: String(e),
      });
    }
  },
);
