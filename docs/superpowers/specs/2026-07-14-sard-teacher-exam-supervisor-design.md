# السرد is the teacher's, الاختبار is the supervisor's

**Date:** 2026-07-14
**Status:** Approved — ready for implementation planning

## The rule

**السرد (Sard) is conducted by the TEACHER. الاختبار (Exam) is conducted by the SUPERVISOR.**

Exclusive on both sides: a supervisor cannot start a Sard, a teacher cannot start an Exam.

This inverts the Sard half of issue #29 (which made Sard supervisor-only) and leaves the
Exam half exactly as it stands today — exams are already supervisor-only and stay that way.

## Why this is a small change with a wide surface

#29 did not just gate a button. It relocated the Sard routes into the supervisor shell,
removed the teacher's Firestore write, gave the supervisor a session-overview twin so it
could reach Sard within one shell (#45), and pinned all of it with tests. Undoing the rule
means undoing each of those, in the opposite direction.

The domain model was never actually converted: `SardRecordModel` still names its author
`teacherId` / `teacher_id`, and its doc comment reads *"A سرد a student recited to their
teacher."* Under #29 the supervisor's uid was written into a field called `teacher_id`.
This change puts the model and the rule back into agreement.

Assessment copy is already role-neutral for Sard (`يسرد الطالب …`) and already names the
supervisor for Exam (`يختبر المشرف الطالب …`) — see `lib/shared/curriculum/assessment_copy.dart`.
No copy changes are needed beyond deleting the teacher's "supervisor-only" notice.

## Scope

### Routing

| | Today | After |
|---|---|---|
| Sard session | `/supervisor/sard/:studentId` | `/teacher/session/:studentId/sard` |
| Sard result | `/supervisor/sard/:studentId/result` | `/teacher/session/:studentId/sard/result` |
| Supervisor student detail | `/supervisor/students/:studentId` → `SessionOverviewScreen(asSupervisor: true)` | `/supervisor/students/:studentId` → read-only `StudentProgressScreen` |

The Sard routes join the teacher shell's Students branch, alongside `recitation`,
`newMemorization`, and `sessionSummary`.

The router redirect guard flips: today it bounces non-supervisors off `/supervisor/sard`;
after this change it bounces non-teachers off the teacher Sard paths. UI hides the entry
point, the redirect is the navigation-level backstop, and Firestore rules are the true
backstop — the same three-layer shape #29 used.

The #45 cross-shell duplicate-page-key crash cannot recur: the teacher's
الطلاب → session-overview → Sard flow lives entirely inside the teacher shell.

### Screens and providers

- `sard_session_screen.dart` and `sard_result_screen.dart` move from
  `lib/features/supervisor/screens/` to `lib/features/teacher/screens/`. They swap the
  supervisor-scoped providers (`supervisorStudentProvider`,
  `supervisorStudentCurrentSessionProvider`) for the teacher-scoped ones
  (`studentProvider`, `studentCurrentSessionProvider`).
- `SardResultScreen` invalidates the teacher's providers on save and returns to
  `AppRoutes.teacherStudents`, not `AppRoutes.supervisorStudents`.
- `SessionOverviewScreen` loses `_buildSardSupervisorOnlyMessage`, the
  `isSupervisorProvider` check, and its `asSupervisor` flag. A teacher on a سرد session
  simply gets the **بدء السرد** button. The supervisor no longer reaches this screen.
- `AdminStudentProgressScreen` — already explicitly read-only, already rendering the
  student card, current-session card, and level progress — is promoted to a shared
  `StudentProgressScreen` that takes its student / current-session / history providers as
  constructor parameters. The router, as composition root, wires the admin-scoped
  providers for `/admin/students/:id` and the supervisor-scoped ones for
  `/supervisor/students/:studentId`. Passing providers in (rather than importing both
  feature provider files into a shared screen) keeps this from adding to the cross-feature
  reach tracked in `al_rasikhoon-pz2`.
- `SupervisorStudentsScreen` points its card tap at the new progress route.

The supervisor keeps its الطلاب tab: institute-scoped roster management (#28 / AgDR-0003)
was its real value, and a supervisor wants a student's progress in front of them before an
exam. What it loses is the session-overview twin, which existed only as the doorway into
Sard.

### Firestore rules

```
match /sard_records/{sardId} {
  allow read: if isAuthenticated();
  allow create, update: if isTeacher();
}
```

`exam_records` is unchanged (`isSupervisor()`). The `isSupervisorOfRecordStudent` helper
stays — `session_records` still uses it.

**Known looseness, accepted here:** this makes teacher Sard writes unscoped — any teacher
may write any student's sard record. That is looser than the supervisor rule it replaces,
but it is exactly the rule `session_records` already lives under, so it introduces no new
class of hole. Tightening teacher writes to their own students is a real gap in both
collections and is filed separately (see Follow-ups).

## Tests

The existing suite pins the OLD rule explicitly, so inverting the tests IS the red step.
Flip the assertions first, watch them fail, then flip the code.

**`test/rules/firestore.rules.test.js`** — the `#29 — Sard is SUPERVISOR-ONLY` block turns
inside out:

- DENIES a teacher creating a sard_record → **ALLOWS**
- DENIES a teacher updating an existing sard_record → **ALLOWS**
- ALLOWS a supervisor creating a sard_record → **DENIES**
- ALLOWS a supervisor updating an in-institute sard_record → **DENIES**
- The three cross-institute supervisor-Sard cases (repoint student_id, out-of-institute
  create, institute-B update) are **deleted**: with no supervisor Sard write at all, "a
  supervisor writing Sard for the wrong institute" is no longer a distinct case to guard.
  Their `session_records` and `exam_records` twins stay.

**`integration_test/teacher_flow_test.dart`** — `'Teacher is blocked from Sard at a Sard
session (#29 / #44)'` becomes `'Teacher conducts a Sard end-to-end: start → conduct →
save'`: الطلاب → tap student → session overview → بدء السرد → enter errors → result → save.

**`integration_test/supervisor_flow_test.dart`** — `'Supervisor conducts a Sard end-to-end
(#29 / #45)'` inverts into `'Supervisor cannot conduct a Sard'`: tapping a student in the
supervisor's الطلاب lands on the read-only progress screen, and no بدء السرد action exists
anywhere in the supervisor shell. The juz-tier placement test keeps its curriculum
assertion but drives it through the teacher.

**`integration_test/helpers/test_robots.dart`** — the Sard methods (`startSard`,
`enterSardErrors`, `finishSard`, `verifySardResult`, `saveSardResult`) move from
`SupervisorRobot` to `TeacherRobot`; `verifySardBlockedForTeacher` becomes
`verifySardBlockedForSupervisor`.

**Widget tests** (`sard_result_advance_warning_test.dart`, `result_grade_loading_test.dart`)
follow `SardResultScreen` to its new import path. Their assertions are about grading and
advancement, which this change does not touch.

## Data

No migration. Sard records written by supervisors under #29 keep that supervisor's uid in
`teacher_id`: they record who actually conducted the سرد, which is the truth.

## Follow-ups (filed, not fixed here)

1. **A supervisor-created student has no teacher and so can never be assessed.**
   `AddStudentScreen(asSupervisor: true)` writes `teacher_id: null`, so the student appears
   in no teacher's الطلاب list. Once Sard is teacher-only, nobody can conduct their سرد —
   and nobody can conduct their regular حلقة today either, which makes this a pre-existing
   bug that this change merely exposes. The fix is student→teacher assignment, not the Sard
   swap.

2. **Teachers can write session and sard records for students who aren't theirs.**
   `allow create, update: if isTeacher()` is unscoped on `session_records` and (after this
   change) `sard_records`, while supervisors are institute-scoped. Belongs with the P0
   rules work in `al_rasikhoon-bpk`.

## Out of scope

- Any change to the Exam flow, the exam queue, or `exam_records` rules. Exams are already
  supervisor-only and correct.
- Tightening teacher record writes (follow-up 2).
- Student→teacher assignment (follow-up 1).
