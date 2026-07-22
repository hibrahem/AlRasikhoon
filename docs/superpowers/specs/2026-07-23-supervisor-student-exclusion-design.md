# Supervisor Student Exclusion (مستبعد) — Design

**Date:** 2026-07-23
**Issue:** al_rasikhoon-zg1r
**Status:** Approved

## Problem

Supervisors need a way to stop a student from being taught (مستبعد — excluded
from teaching). An excluded student must not appear in any teacher-facing
student list, but must remain visible to supervisors and admins, who can
restore the student to normal at any time. Every change in either direction
carries an optional free-text reason.

## Decisions (agreed with user)

1. **Exclusion scope — hide only.** The student keeps their teacher assignment
   (`teacher_id` untouched) and their own/guardian app access. Exclusion only
   removes them from teacher-facing lists. Restore is instant and lossless.
2. **Full audit history.** Every exclude/restore writes an immutable audit
   entry (actor, from/to status, reason, timestamp).
3. **Client-side filtering.** Teacher hiding is enforced by repository
   filtering (matching the existing `curriculum_completed` post-filter
   precedent), not by Firestore read rules.
4. **Permissions.** Both supervisors (within their institutes) and admins can
   exclude and restore.
5. **Status enum, not a boolean.** The user expects future states (e.g.
   "paused"), so the model is an extensible enum rather than an `is_excluded`
   flag. The existing `is_active` soft-delete flag is **not** touched; the new
   `status` field lives alongside it and models teaching state only.

## Domain Model

New framework-free enum in the domain layer:

- **File:** `lib/domain/student/student_status.dart`
- **Enum:** `StudentStatus { active, excluded }`
  - Persisted snake-case string values: `'active'`, `'excluded'`.
  - Arabic labels: `نشط`, `مستبعد` (English: Active, Excluded).
  - `StudentStatus.fromString(String?)` returns `active` for null, missing, or
    unknown values — same read-as-safe-default discipline as
    `curriculum_completed`. **No data migration needed**; legacy student
    documents without the field behave as `active`.
  - Adding a future state (e.g. `paused`) is a one-line enum addition.

`StudentModel` (`lib/data/models/student_model.dart`) gains four fields:

| Dart field        | Firestore key       | Type      | Notes                              |
|-------------------|---------------------|-----------|------------------------------------|
| `status`          | `status`            | string    | Defaults to `active` when absent   |
| `statusReason`    | `status_reason`     | string?   | Latest reason (optional)           |
| `statusChangedAt` | `status_changed_at` | timestamp?| Server timestamp of last change    |
| `statusChangedBy` | `status_changed_by` | string?   | UID of the actor                   |

All four are wired through `fromFirestore` / `toFirestore` / `copyWith`.

## Audit Trail

Immutable subcollection `students/{studentId}/status_audit/{autoId}`:

```
{
  from_status: 'active',
  to_status:   'excluded',
  reason:      'سبب اختياري' | null,
  changed_by:  <uid>,
  changed_at:  <serverTimestamp>
}
```

Written in the **same `WriteBatch`** as the student document update, mirroring
`repositionEnrolledStudent` + `reposition_audit`
(`lib/data/repositories/student_repository.dart:305-390`). Named
`status_audit` (not `exclusion_audit`) so future status transitions reuse it.

## Repository

New method on `StudentRepository`:

```dart
Future<void> setStudentStatus(
  String studentId, {
  required StudentStatus status,
  String? reason,
  required UserModel actor,
})
```

Behavior:

1. Load the student; throw if not found or `is_active == false`.
2. **Authorize in the repository** (rules cannot aggregate; stale UI must not
   be trusted — same rationale as `repositionEnrolledStudent`):
   - `actor.role == superAdmin` → allowed anywhere.
   - `actor.role == supervisor` → allowed only when the student's
     `institute_id` is in the supervisor's institute memberships.
   - Anyone else → throw `StudentStatusChangeNotAuthorizedException`.
3. No-op guard: if the student is already in the requested status, return
   without writing.
4. Batch write: update `status`, `status_reason`, `status_changed_at`
   (server timestamp), `status_changed_by`, `updated_at` on the student doc,
   and create the `status_audit` entry.

New domain exception `StudentStatusChangeNotAuthorizedException` following the
existing `RepositionNotAuthorizedException` pattern.

## Teacher Hiding (query filtering)

Post-filter `status != excluded` (the `getStudentsReadyForExam` precedent —
a `where` clause would break on legacy docs missing the field):

- `getStudentsForTeacher` (`student_repository.dart:487`)
- `streamStudentsForTeacher` (`student_repository.dart:891`)
- `getStudentsReadyForExam` (`student_repository.dart:581`) — an excluded
  student is not being taught, so they leave the exam-ready queue too.

Supervisor and admin list methods stay **unfiltered**; excluded students
appear with a badge (see UI).

## Firestore Rules

Add a `status_audit` match block inside the student match, modeled on
`reposition_audit` (`firestore.rules:309-316`):

- `read`: anyone who can read the parent student (`canReadStudent`).
- `create`: super admin, or supervisor of the student's institute.
- `update, delete`: `false` (immutable trail).

The existing student `update` rule (`firestore.rules:293-300`) already permits
supervisor writes on institute-scoped students and admin writes generally —
no change needed for the new fields.

## UI

**Supervisor** (`lib/features/supervisor/screens/supervisor_students_screen.dart`)
and **Admin** (`lib/features/admin/screens/all_students_screen.dart`):

- New entry in the existing `⋮` / long-press actions bottom sheet:
  - Student active → **«استبعاد من التدريس»**
  - Student excluded → **«إلغاء الاستبعاد»**
- Tapping opens `StudentStatusDialog` — a new
  `lib/features/supervisor/widgets/student_status_dialog.dart` cloned from
  `AssignTeacherDialog`:
  - Confirmation text describing the action.
  - **Optional** multiline reason `TextField` (no validation — empty allowed).
  - When restoring, the dialog shows the current exclusion reason (and who/when)
    for context.
  - `AppButton` with `isLoading`; on success: `ref.invalidate` of the relevant
    students provider + success `SnackBar`; captures messenger/navigator before
    the async gap, `context.mounted` checks after awaits.
- **Badge:** excluded students show a «مستبعد» chip via the existing
  `StudentCard.trailing` slot in supervisor/admin lists (distinct
  warning-toned styling per app theme).

**Teacher** screens: no UI change — excluded students are filtered out at the
repository layer.

Strings follow the existing convention in these screens (inline Arabic
literals), matching «تعيين معلم» etc.

## Error Handling

- Unauthorized actor → domain exception surfaced as an error `SnackBar`.
- Offline/write failure → existing repository error propagation; dialog stays
  open with the error message, `isLoading` reset.
- Concurrent change (student already in target status) → silent no-op; list
  refresh shows the true state.

## Testing

Domain language names, per project conventions:

- **Model:** `test_student_without_status_field_reads_as_active`,
  round-trip serialization of all four new fields, unknown status string →
  `active`.
- **Repository:** supervisor of another institute cannot change status;
  teacher cannot change status; admin can; excluded student disappears from
  teacher list and exam-ready queue but not from supervisor/admin lists;
  audit entry written with actor and reason; no-op when already in target
  status.
- **Widget:** exclusion dialog submits with and without a reason; restore
  dialog shows the stored reason.

## Changelog

Stakeholder bullet under `## Unreleased`:

> يستطيع المشرف الآن استبعاد طالب من التدريس مع ذكر السبب؛ الطالب المستبعد
> يختفي من قوائم المعلم ويظل ظاهرًا للمشرف والمدير مع إمكانية إعادته في أي وقت.

## Out of Scope

- Blocking the student's/guardian's own app access while excluded.
- Firestore-rules-level read denial for teachers.
- A `paused` state (the enum is designed to accept it later).
- Migrating `is_active` into the status enum.
