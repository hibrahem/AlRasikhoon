import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

admin.initializeApp();

interface SetUserPasswordPayload {
  userId: string;
  newPassword: string;
}

const MIN_PASSWORD_LENGTH = 6;

/**
 * Reset another user's password. Admin-only path used by the admin and
 * teacher detail screens. Authorization:
 *   - super_admin can reset any user.
 *   - teacher can reset a student whose teacher_id matches the caller.
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
    } else {
      throw new HttpsError(
        "permission-denied",
        "Only admins and teachers can reset passwords",
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
