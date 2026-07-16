# Pace editing (teacher + supervisor) and unified session log

Date: 2026-07-16
Branch: `claude/student-screen-ui-issues-f10662`

## Context

Two issues on the student screens, both surfacing on the teacher's
`StudentProfileScreen` and the supervisor's read-only `StudentProgressScreen`:

1. **Pace placement / supervisor access.** "وتيرة الحفظ" (pace) is how many
   curriculum lessons a student covers in one meeting. It is already modelled
   correctly: pace lives on the student (`StudentModel.pace`, a
   `CurriculumPace` value object), is persisted in Firestore, and each meeting
   is composed on the fly from it (`PacedSession`). Changing pace widens or
   narrows the student's *next* meeting automatically. The data placement is
   right — pace is student config set outside any session, and sessions reflect
   it.

   The gap is UI + reach: the edit control exists **only** on the teacher's
   `StudentProfileScreen`. The supervisor's student view is read-only, so a
   supervisor cannot change pace today — even though `CurriculumPace`'s own doc
   says "the teacher and the supervisor may set it", and the Firestore rules
   already authorise a supervisor scoped to the student's institute to write
   the student doc (`firestore.rules`, students `allow update` supervisor
   branch). So this is purely a UI gap: no data-model or security change.

2. **Assessments missing from the session log ("سجل الحلقات").** Lessons and
   تلقين are written to the `sessionRecords` collection; **سرد** is written to
   `sardRecords` and **اختبار** to `examRecords` (separate collections, separate
   models). Every history provider — teacher, supervisor, admin, and the
   student's own — queries **only** `sessionRecords`, so the log silently drops
   both assessment kinds. The user noticed the exam is missing; سرد is missing
   by the identical root cause.

## Non-goals (YAGNI)

- No institution-wide default pace. Pace stays per-student.
- No new detail screens for سرد / اختبار. `SessionDetailScreen` resolves only
  `sessionRecords`, so merged assessment rows render but are **not tappable**
  for now (their `onTap` is null). Lesson/تلقين rows keep navigating to detail.
- No change to how records are written, to the pass/fail model, or to stats.

## Component 1 — Shared pace control

### 1.1 Extract `StudentPaceControl` (shared widget)

New `lib/shared/widgets/student_pace_control.dart` — a `ConsumerWidget` that
renders the existing "وتيرة الحفظ" card (1x / 2x / 3x `SegmentedButton` +
"عدد الحلقات في اللقاء الواحد" caption). It owns the common behaviour:

- reads current multiplier from an injected `CurriculumPace`,
- on selection, calls `studentRepositoryProvider.setStudentPace(...)` inside a
  try/catch, showing the existing "تعذر تحديث وتيرة الحفظ" maroon snackbar on
  failure,
- on **success only**, invokes an injected `void Function() onPaceChanged` so
  each host refreshes exactly its own providers (the widget stays free of any
  host's provider graph).

API:

```dart
StudentPaceControl({
  required String studentId,
  required CurriculumPace currentPace,
  required VoidCallback onPaceChanged,
})
```

The teacher screen's `_buildPaceControl` / `_setPace` are deleted and replaced
by a `StudentPaceControl` whose `onPaceChanged` invalidates
`teacherStudentsProvider` + `studentProvider(studentId)` (exactly today's
behaviour, unchanged).

### 1.2 Supervisor — inline on the student view

`StudentProgressScreen` already accepts a router-injected, role-specific slot
(`repositionSection`) rendered under the header, with the admin route passing
nothing. Add a second optional slot `paceSection` the same way:

- `StudentProgressScreen({... Widget? paceSection})`, rendered under the header
  next to `repositionSection`.
- Supervisor route injects
  `paceSection: StudentPaceControl(studentId, currentPace, onPaceChanged: ...)`
  whose `onPaceChanged` invalidates `supervisorStudentProvider(studentId)` +
  `supervisorStudentCurrentMeetingProvider(studentId)`.
- Admin route passes nothing → admin stays read-only.

The screen stays role-agnostic: it never imports the supervisor feature; it
just renders whatever widget the router injects.

### 1.3 Supervisor — quick action in the student list

Add a "تغيير وتيرة الحفظ" `ListTile` to the existing long-press bottom sheet in
`SupervisorStudentsScreen._showStudentActions` (beside assign-teacher /
reset-password). It opens a small `AlertDialog` hosting the same
`StudentPaceControl`; `onPaceChanged` invalidates `supervisorStudentsProvider`
and closes the dialog.

## Component 2 — Unified session log

### 2.1 `StudentHistoryEntry` (domain read-model)

New `lib/domain/session/student_history_entry.dart` — a kind-agnostic view of
one history row:

```dart
enum StudentHistoryKind { lesson, talqeen, sard, exam }

class StudentHistoryEntry {
  final String id;
  final StudentHistoryKind kind;
  final String titleAr;
  final List<String> subtitleLines;
  final bool passed;          // ignored for talqeen at render time
  final DateTime date;
  final SessionDuration? duration;
  final String? detailRecordId; // non-null ⇒ tappable to SessionDetailScreen
}
```

Mapping rules:

| Source record | kind | titleAr | passed | detailRecordId |
|---|---|---|---|---|
| `SessionRecordModel` (lesson) | lesson | "الحلقة {n}" | record.passed | record.id |
| `SessionRecordModel` (talqeen) | talqeen | "تلقين" | (n/a) | record.id |
| `SardRecordModel` | sard | scope label | record.passed | null |
| `ExamRecordModel` | exam | scope label | record.passed | null |

### 2.2 `SessionRepository.getStudentHistory`

New method mirroring `getStudentStatistics`'s existing "fetch all three
collections" pattern: fetch `sessionRecords` + `sardRecords` + `examRecords`
for the student, map each to `StudentHistoryEntry`, merge, sort by `date`
descending, and apply the same 50-row bound the current session-only history
uses. (Bound applied after merge.)

### 2.3 Providers

Change the four history providers to return
`List<StudentHistoryEntry>` and call `getStudentHistory`:

- `teacherStudentSessionHistoryProvider`
- `supervisorStudentSessionHistoryProvider`
- `adminStudentSessionHistoryProvider`
- `studentHistoryProvider` (the student's own history)

### 2.4 Render sites

Both current render sites consume `StudentHistoryEntry`:

- `StudentProgressScreen` — its field type
  `FutureProviderFamily<List<SessionRecordModel>, String> sessionHistoryProvider`
  becomes `...<List<StudentHistoryEntry>, String>`. The inline `_SessionHistoryList`
  card renders from the entry: badge/outcome from `kind`+`passed`, and
  `onTap` only when `detailRecordId != null` (navigating via the injected
  `sessionDetailRoute`).
- `StudentProfileScreen._SessionHistorySection` (teacher) — feeds
  `SessionRecordRow` from the entry, passing `onTap` only when
  `detailRecordId != null` (`SessionRecordRow.onTap` is already nullable).
- The student-facing history screen (`session_history_screen.dart`) consumes
  entries the same way.

Talqeen still renders with no pass/fail badge; assessments render with نجح /
رسب. No averaging of component grades (existing rule preserved).

## Testing

- **Domain**: `CurriculumPace` unchanged. `StudentHistoryEntry` mapping — a unit
  test per source kind asserting title, passed handling, and navigability
  (`detailRecordId` null for sard/exam, non-null for lesson/talqeen).
- **Repository**: `getStudentHistory` merges the three collections, sorts by
  date desc, and bounds to 50 (fake/seeded Firestore per existing
  `session_repository_test.dart`).
- **Widget**: `StudentPaceControl` writes pace and fires `onPaceChanged` on
  success; shows the snackbar and does **not** fire it on failure. Supervisor
  `StudentProgressScreen` renders the injected `paceSection`; admin does not.
  History render shows an exam row and leaves it non-tappable; a lesson row
  stays tappable.

## Rollout / risk

- No migration, no rules change, no write-path change → low risk.
- Type change on `sessionHistoryProvider` ripples to `StudentProgressScreen`
  and its two callers in the router; the compiler enforces every site is
  updated.
- Delivered in two independently committable milestones: (A) shared pace
  control + supervisor reach, (B) unified log.
