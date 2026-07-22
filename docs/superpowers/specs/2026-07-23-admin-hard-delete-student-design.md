# Admin Hard Delete of Student — Design

**Date:** 2026-07-23 · **Issue:** al_rasikhoon-go8d

## Goal

A super admin (the app's only "admin" role) can permanently delete any student.
The delete cascades over **all** of the student's data and is gated behind a
warning confirmation dialog. This is distinct from the existing soft delete
(`is_active: false`), which stays untouched for every other flow.

## Why the cascade lives in a Cloud Function

Two hard constraints rule out a client-side cascade:

1. **Firestore rules block it.** `session_records`, `sard_records`, and
   `exam_records` define no client `delete` rule (denied by default), and
   `home_practices` allows delete only by the owning student.
2. **Auth deletion needs the Admin SDK.** The client SDK cannot delete another
   user's Firebase Auth account; only `admin.auth().deleteUser(uid)` can.

A single callable also gives one authorization checkpoint (`request.auth.token
.role === 'super_admin'`, the same custom-claim pattern `createUserAccount` and
`setUserPassword` already use) instead of loosening rules across four
collections.

## Cloud Function: `hardDeleteStudent`

`onCall`, `us-central1`, payload `{ studentId }`. Authorization: authenticated
caller with the `super_admin` role claim; anything else → `permission-denied`.
Missing student → `not-found`.

Deletion order is children-first so a mid-run crash leaves the student doc
intact and the operation retryable (re-run resumes; no invisible orphans):

1. `session_records`, `sard_records`, `exam_records`, `home_practices` where
   `student_id == studentId` — batched deletes in chunks (Firestore batch cap
   is 500 writes).
2. `students/{studentId}/reposition_audit` subcollection (Firestore does NOT
   auto-delete subcollections with the parent doc).
3. `students/{studentId}` itself.
4. The linked account, only if no other student doc references the same
   `user_id`: delete `users/{userId}` (this also fires `syncRoleClaim`, which
   clears the role claim) and the Firebase Auth user (tolerating
   `user-not-found`). The guardian's account is a reference *out* and is never
   deleted — a guardian may guard other students.

Returns per-collection deletion counts for the audit log.

No `firestore.rules` change is needed — the Admin SDK bypasses rules.

## Client

- `FirebaseService.hardDeleteStudent({studentId})` — thin callable wrapper,
  mirroring `provisionUserAccount`.
- `StudentRepository.hardDeleteStudent(studentId)` — delegates to the service;
  sits next to the soft `deleteStudent` with contrasting doc comments.
- **UI:** the admin-only `AllStudentsScreen` per-row actions sheet gains a
  destructive "حذف الطالب نهائيًا" tile (maroon, `delete_forever` icon). It
  opens `DeleteStudentDialog` (new, `lib/features/admin/widgets/`): a warning
  AlertDialog naming the student and spelling out exactly what is erased and
  that it cannot be undone. Confirm shows a loading state, calls the
  repository, invalidates `allStudentsProvider` + `adminStatsProvider`, and
  reports success/failure via SnackBar (messenger captured before the async
  gap, per the `ResetPasswordDialog` hardening).

Supervisor and teacher surfaces get no delete entry point — this is strictly
super-admin.

## Testing

- `test/widget/delete_student_dialog_test.dart` — warning text shown; cancel
  performs no delete; confirm calls `StudentRepository.hardDeleteStudent`
  (mocktail mock via provider override); failure surfaces an error SnackBar.
- `test/unit/data/repositories/student_repository_hard_delete_test.dart` —
  repository delegates to `FirebaseService.hardDeleteStudent`.
- Functions have no test harness (lint + tsc only) — `npm run lint` and
  `npm run build` gate the TypeScript.
