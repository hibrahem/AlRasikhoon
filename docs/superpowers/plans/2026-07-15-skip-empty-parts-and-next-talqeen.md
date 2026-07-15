# Skip Empty Parts + Next-Passage Talqeen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Skip the recent/distant evaluation parts when they have no content, and add a talqeen step that recites the next (or, on a fail, the same) new passage before the session closes.

**Architecture:** A pure domain helper on `PacedSession` (`presentParts` / `partAfter`) drives which recitation parts the flow walks. The three teacher recitation screens consume it. A new `NextContentTalqeenScreen` becomes the sole place a session closes; the summary screen now navigates to it instead of completing the session. A shared composer helper builds the "next meeting" for the preview.

**Tech Stack:** Flutter, Riverpod, go_router, Firebase (fake_cloud_firestore + mocktail in tests).

## Global Constraints

- DDD / Clean Architecture per repo `CLAUDE.md`: domain logic (`presentParts`, next-meeting composition) stays framework-free in `lib/domain` / pure providers; no ORM/UI in domain.
- All user-facing strings are Arabic, matching the existing screens.
- Part 1 (الحفظ الجديد) is ALWAYS present, even when empty — only parts 2/3 are skippable.
- Grades are unchanged: a skipped part is 0 errors, which already passes; do not alter `GradeCalculator`.
- End-of-level next-passage preview is out of scope — render the no-new-content note there.
- Test runner: `flutter test <path>`.
- Spec: `docs/superpowers/specs/2026-07-15-skip-empty-parts-and-next-talqeen-design.md`.

---

### Task 1: `presentParts` / `partAfter` domain helper

**Files:**
- Modify: `lib/domain/curriculum/paced_session.dart` (add getters after `hasDistantReview`, ~line 136)
- Test: `test/unit/domain/curriculum/paced_session_present_parts_test.dart`

**Interfaces:**
- Produces:
  - `List<int> PacedSession.presentParts` — always starts with `1`; includes `2` iff `hasRecentReview`, `3` iff `hasDistantReview`.
  - `int? PacedSession.partAfter(int part)` — the next present part after `part`, or `null` if `part` is the last present part (or not present).

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/curriculum/paced_session_present_parts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

QuranContent _c(String surah, int from, int to) =>
    QuranContent(fromSurah: surah, fromVerse: from, toSurah: surah, toVerse: to);

SessionModel _lesson() => SessionModel(
      id: 'L1_J30_S1',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: 1,
      orderInLevel: 1,
      kind: SessionKind.lesson,
    );

PacedSession _meeting({
  required List<QuranContent> newC,
  required List<QuranContent> recent,
  required List<QuranContent> distant,
}) =>
    PacedSession(
      sessions: [_lesson()],
      newContent: newC,
      recentReview: recent,
      distantReview: distant,
    );

void main() {
  test('present parts include new plus only the non-empty review streams', () {
    final all = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [_c('النبأ', 1, 5)],
      distant: [_c('الفاتحة', 1, 7)],
    );
    expect(all.presentParts, [1, 2, 3]);

    final noRecent = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [],
      distant: [_c('الفاتحة', 1, 7)],
    );
    expect(noRecent.presentParts, [1, 3]);

    final noReview = _meeting(newC: [_c('النبأ', 1, 11)], recent: [], distant: []);
    expect(noReview.presentParts, [1]);
  });

  test('new memorization part is present even when its content is empty', () {
    final reviewOnly = _meeting(
      newC: [],
      recent: [_c('النبأ', 1, 5)],
      distant: [],
    );
    expect(reviewOnly.presentParts, [1, 2]);
  });

  test('partAfter walks present parts and returns null past the last', () {
    final skipRecent = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [],
      distant: [_c('الفاتحة', 1, 7)],
    );
    expect(skipRecent.partAfter(1), 3); // recent skipped
    expect(skipRecent.partAfter(3), isNull); // last present part
    expect(skipRecent.partAfter(2), isNull); // 2 not present
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/domain/curriculum/paced_session_present_parts_test.dart`
Expected: FAIL — `presentParts`/`partAfter` are not defined.

- [ ] **Step 3: Add the getters**

In `lib/domain/curriculum/paced_session.dart`, immediately after the `hasDistantReview` getter (~line 136), add:

```dart
  /// The recitation parts (1 = new memorization, 2 = recent review, 3 =
  /// distant review) worth evaluating in this meeting. Part 1 is ALWAYS
  /// present — الحفظ الجديد is shown even on a review-only lesson where it is
  /// empty. Parts 2 and 3 appear only when their stream carries content, so a
  /// meeting with no recent/distant review skips those evaluation steps
  /// entirely. Screens walk this list instead of a fixed 1..3.
  List<int> get presentParts => [
        1,
        if (hasRecentReview) 2,
        if (hasDistantReview) 3,
      ];

  /// The present part after [part], or null when [part] is the last present
  /// part (or is not itself present). Drives "next part" navigation so an
  /// empty recent/distant part is never landed on.
  int? partAfter(int part) {
    final parts = presentParts;
    final index = parts.indexOf(part);
    if (index < 0 || index == parts.length - 1) return null;
    return parts[index + 1];
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/domain/curriculum/paced_session_present_parts_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/curriculum/paced_session.dart test/unit/domain/curriculum/paced_session_present_parts_test.dart
git commit -m "feat(curriculum): presentParts/partAfter to skip empty recitation parts"
```

---

### Task 2: Shared recitation-part helper (title + errors)

**Files:**
- Create: `lib/features/teacher/recitation_parts.dart`
- Test: `test/unit/features/teacher/recitation_parts_test.dart`

**Interfaces:**
- Consumes: `ActiveSessionState` from `lib/features/teacher/providers/teacher_provider.dart`.
- Produces:
  - `String recitationPartTitleAr(int part)` — 1→'الحفظ الجديد', 2→'المراجعة القريبة', 3→'المراجعة البعيدة', else 'التسميع'.
  - `int recitationPartErrors(ActiveSessionState session, int part)` — 1→part1Errors, 2→part2Errors, 3→part3Errors, else 0.

- [ ] **Step 1: Write the failing test**

Create `test/unit/features/teacher/recitation_parts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/recitation_parts.dart';

void main() {
  test('recitationPartTitleAr maps each part to its Arabic label', () {
    expect(recitationPartTitleAr(1), 'الحفظ الجديد');
    expect(recitationPartTitleAr(2), 'المراجعة القريبة');
    expect(recitationPartTitleAr(3), 'المراجعة البعيدة');
    expect(recitationPartTitleAr(9), 'التسميع');
  });

  test('recitationPartErrors reads the matching per-part error count', () {
    const session = ActiveSessionState(
      studentId: 's1',
      part1Errors: 4,
      part2Errors: 2,
      part3Errors: 7,
    );
    expect(recitationPartErrors(session, 1), 4);
    expect(recitationPartErrors(session, 2), 2);
    expect(recitationPartErrors(session, 3), 7);
    expect(recitationPartErrors(session, 9), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/features/teacher/recitation_parts_test.dart`
Expected: FAIL — `recitation_parts.dart` does not exist.

- [ ] **Step 3: Create the helper**

Create `lib/features/teacher/recitation_parts.dart`:

```dart
import 'providers/teacher_provider.dart';

/// The Arabic label for a recitation part: 1 = new memorization, 2 = recent
/// review, 3 = distant review. Shared by the recitation, result and summary
/// screens so the three never drift apart.
String recitationPartTitleAr(int part) {
  switch (part) {
    case 1:
      return 'الحفظ الجديد';
    case 2:
      return 'المراجعة القريبة';
    case 3:
      return 'المراجعة البعيدة';
    default:
      return 'التسميع';
  }
}

/// The error count [session] recorded for [part].
int recitationPartErrors(ActiveSessionState session, int part) {
  switch (part) {
    case 1:
      return session.part1Errors;
    case 2:
      return session.part2Errors;
    case 3:
      return session.part3Errors;
    default:
      return 0;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/features/teacher/recitation_parts_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/recitation_parts.dart test/unit/features/teacher/recitation_parts_test.dart
git commit -m "feat(teacher): shared recitation-part title/errors helper"
```

---

### Task 3: Skip empty parts in the recitation flow (screen + result)

**Files:**
- Modify: `lib/features/teacher/screens/recitation_screen.dart`
- Modify: `lib/features/teacher/screens/recitation_result_screen.dart`
- Test: `test/widget/recitation_skip_empty_parts_test.dart`

**Interfaces:**
- Consumes: `PacedSession.presentParts` / `partAfter` (Task 1); `recitationPartTitleAr` / `recitationPartErrors` (Task 2); `ActiveSessionState.meeting`.
- Produces: `ActiveSessionNotifier.seedForTest(ActiveSessionState state)` — a `@visibleForTesting` seam used by Tasks 3, 4, 6, 7 to seed an active session without Firestore (`Notifier.state` is `@protected`, so tests cannot assign it directly).

- [ ] **Step 1: Add a `seedForTest` seam to `ActiveSessionNotifier`**

`Notifier.state` is `@protected` — a test cannot write it from outside the class. Add a seam. In `lib/features/teacher/providers/teacher_provider.dart`, ensure `import 'package:flutter/foundation.dart';` is present (or `import 'package:meta/meta.dart';`), then add this method inside `class ActiveSessionNotifier` (e.g. right after `build()`):

```dart
  /// Seeds an active session directly, bypassing `startSession` and Firestore.
  /// Test-only: widget tests for the recitation/summary/talqeen screens need a
  /// composed meeting in state without a full session start.
  @visibleForTesting
  void seedForTest(ActiveSessionState state) => this.state = state;
```

- [ ] **Step 2: Write the failing test**

Create `test/widget/recitation_skip_empty_parts_test.dart`. It seeds an active session whose meeting has NO recent review (so `presentParts == [1, 3]`), pumps the part-1 result screen, and asserts the "next" button points at the distant review (part 3), skipping recent:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_result_screen.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

SessionModel _lesson() => SessionModel(
      id: 'L1_J30_S1',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: 1,
      orderInLevel: 1,
      kind: SessionKind.lesson,
    );

/// Seeds an active session directly, bypassing startSession, so the test does
/// not need Firestore. The meeting has new + distant content but NO recent.
PacedSession _meetingNoRecent() => PacedSession(
      sessions: [_lesson()],
      newContent: [_c('النبأ', 1, 11)],
      recentReview: const [],
      distantReview: [_c('الفاتحة', 1, 7)],
    );

void main() {
  testWidgets('part-1 result skips empty recent review and points to distant',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        studentProvider.overrideWith((ref, id) async => StudentWithUser(
              student: StudentModel(
                id: 'student-1',
                userId: 'user-1',
                instituteId: 'i1',
                teacherId: 't1',
                currentLevel: 1,
                currentJuz: 30,
                currentHizb: 59,
                currentSession: 1,
                currentAttempt: 1,
                currentOrderInLevel: 1,
                createdAt: DateTime(2026, 1, 1),
              ),
              user: UserModel(
                id: 'user-1',
                username: 'pupil',
                email: 'pupil@x.local',
                name: 'طالب',
                role: UserRole.student,
                authProvider: UserAuthProvider.emailPassword,
                createdAt: DateTime(2026, 1, 1),
              ),
            )),
      ],
    );
    addTearDown(container.dispose);

    // Seed the active session with the no-recent meeting.
    container.read(activeSessionProvider.notifier).seedForTest(
          ActiveSessionState(
            studentId: 'student-1',
            currentPart: 1,
            part1Errors: 1,
            meeting: _meetingNoRecent(),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RecitationResultScreen(
            studentId: 'student-1',
            part: 1,
            errorCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The "next" button names the distant review, NOT the recent review.
    expect(find.textContaining('المراجعة البعيدة'), findsWidgets);
    expect(find.textContaining('المراجعة القريبة'), findsNothing);
    // The chip counts present parts (2), not a fixed 3.
    expect(find.text('الجزء 1 من 2'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/recitation_skip_empty_parts_test.dart`
Expected: FAIL — the current result screen shows "المراجعة القريبة" as the next part and the chip reads "الجزء 1 من 3".

- [ ] **Step 4: Update `recitation_result_screen.dart`**

Add the import at the top:

```dart
import '../recitation_parts.dart';
```

Replace the `_partTitle` getter (lines 24–35) with a call into the shared helper — delete the getter and change its two use sites (`'نتيجة $_partTitle'` in the AppBar and `'إعادة $_partTitle'` on the retry buttons) to `'نتيجة ${recitationPartTitleAr(part)}'` and `'إعادة ${recitationPartTitleAr(part)}'`.

In `build`, right after `final activeSession = ref.watch(activeSessionProvider);` (line 39), add:

```dart
    final meeting = activeSession?.meeting;
    final presentParts = meeting?.presentParts ?? const [1, 2, 3];
    final int? nextPart =
        meeting != null ? meeting.partAfter(part) : (part < 3 ? part + 1 : null);
    final int position = presentParts.contains(part)
        ? presentParts.indexOf(part) + 1
        : part;
```

Replace the part-indicator chip text (line 78) `'الجزء $part من 3'` with:

```dart
                  'الجزء $position من ${presentParts.length}',
```

Replace the "Summary so far" rows (lines 120–131) with a loop over present previous parts:

```dart
                      for (final p in presentParts.where((p) => p < part))
                        _SummaryRow(
                          title: recitationPartTitleAr(p),
                          errors: recitationPartErrors(activeSession, p),
                          level: level,
                        ),
```

Replace the whole `if (part < 3) … else …` action block (lines 137–197) so it branches on `nextPart`:

```dart
              if (nextPart != null)
                Column(
                  children: [
                    AppButton(
                      text: 'التالي: ${recitationPartTitleAr(nextPart)}',
                      onPressed: () {
                        context.pushReplacement(
                          AppRoutes.recitation
                              .replaceFirst(':studentId', studentId)
                              .replaceFirst(':part', '$nextPart'),
                        );
                      },
                      isFullWidth: true,
                      size: AppButtonSize.large,
                    ),
                    const SizedBox(height: 12),
                    if (gradeInfo != null && !gradeInfo.passed)
                      AppButton(
                        text: 'إعادة ${recitationPartTitleAr(part)}',
                        onPressed: () {
                          context.pushReplacement(
                            AppRoutes.recitation
                                .replaceFirst(':studentId', studentId)
                                .replaceFirst(':part', '$part'),
                          );
                        },
                        type: AppButtonType.outline,
                        isFullWidth: true,
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    AppButton(
                      text: 'عرض ملخص الحلقة',
                      onPressed: () {
                        context.push(
                          AppRoutes.sessionSummary
                              .replaceFirst(':studentId', studentId),
                        );
                      },
                      isFullWidth: true,
                      size: AppButtonSize.large,
                    ),
                    const SizedBox(height: 12),
                    if (gradeInfo != null && !gradeInfo.passed)
                      AppButton(
                        text: 'إعادة ${recitationPartTitleAr(part)}',
                        onPressed: () {
                          context.pushReplacement(
                            AppRoutes.recitation
                                .replaceFirst(':studentId', studentId)
                                .replaceFirst(':part', '$part'),
                          );
                        },
                        type: AppButtonType.outline,
                        isFullWidth: true,
                      ),
                  ],
                ),
```

Delete the now-unused `_getNextPartTitle()` method (lines 205–214) and the `_SummaryRow` still uses `title`/`errors`/`level` (unchanged).

- [ ] **Step 5: Update `recitation_screen.dart` to match the counter and end label**

Add the import at the top:

```dart
import '../recitation_parts.dart';
```

Replace the `_partTitle` getter (lines 28–39) with a use of `recitationPartTitleAr(widget.part)` at its two use sites (`title: Text(_partTitle)` in the AppBar → `Text(recitationPartTitleAr(widget.part))`, and the content-card `Text(_partTitle, …)` → `Text(recitationPartTitleAr(widget.part), …)`), then delete the getter.

In the `data:` builder, after the `content` switch (line 97), add:

```dart
          final presentParts = meeting.presentParts;
          final position = presentParts.indexOf(widget.part) + 1;
          final isLastPart = meeting.partAfter(widget.part) == null;
```

Replace the chip text (line 128) `'الجزء ${widget.part} من 3'` with:

```dart
                                    'الجزء $position من ${presentParts.length}',
```

Replace the primary button's label expression (line 218) `widget.part < 3 ? 'التالي' : 'إنهاء التسميع'` with:

```dart
                                isLastPart ? 'إنهاء التسميع' : 'التالي',
```

- [ ] **Step 6: Run the new test and the existing recitation tests**

Run: `flutter test test/widget/recitation_skip_empty_parts_test.dart test/widget/recitation_screen_talqeen_guard_test.dart test/widget/result_grade_loading_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/teacher/providers/teacher_provider.dart lib/features/teacher/screens/recitation_screen.dart lib/features/teacher/screens/recitation_result_screen.dart test/widget/recitation_skip_empty_parts_test.dart
git commit -m "feat(teacher): skip empty recent/distant parts in recitation flow"
```

---

### Task 4: Hide empty part cards on the session summary

**Files:**
- Modify: `lib/features/teacher/screens/session_summary_screen.dart`
- Test: `test/widget/session_summary_hides_empty_parts_test.dart`

**Interfaces:**
- Consumes: `PacedSession.presentParts`; `recitationPartTitleAr` / `recitationPartErrors`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/session_summary_hides_empty_parts_test.dart`. Seed an active session whose meeting has no distant review and assert the "المراجعة البعيدة" card is absent while the other two show:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_summary_screen.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

void main() {
  testWidgets('summary omits the part card for an empty distant review',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        studentProvider.overrideWith((ref, id) async => StudentWithUser(
              student: StudentModel(
                id: 'student-1',
                userId: 'user-1',
                instituteId: 'i1',
                teacherId: 't1',
                currentLevel: 1,
                currentJuz: 30,
                currentHizb: 59,
                currentSession: 1,
                currentAttempt: 1,
                currentOrderInLevel: 1,
                createdAt: DateTime(2026, 1, 1),
              ),
              user: UserModel(
                id: 'user-1',
                username: 'pupil',
                email: 'pupil@x.local',
                name: 'طالب',
                role: UserRole.student,
                authProvider: UserAuthProvider.emailPassword,
                createdAt: DateTime(2026, 1, 1),
              ),
            )),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeSessionProvider.notifier).seedForTest(
          ActiveSessionState(
      studentId: 'student-1',
      part1Errors: 1,
      part2Errors: 0,
      part3Errors: 0,
      meeting: PacedSession(
        sessions: [
          SessionModel(
            id: 'L1_J30_S1',
            levelId: 1,
            juzNumber: 30,
            sessionNumber: 1,
            orderInLevel: 1,
            kind: SessionKind.lesson,
          ),
        ],
        newContent: [_c('النبأ', 1, 11)],
        recentReview: [_c('النبأ', 1, 5)],
        distantReview: const [],
      ),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SessionSummaryScreen(studentId: 'student-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الحفظ الجديد'), findsOneWidget);
    expect(find.text('المراجعة القريبة'), findsOneWidget);
    expect(find.text('المراجعة البعيدة'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/session_summary_hides_empty_parts_test.dart`
Expected: FAIL — the summary currently renders all three cards, so "المراجعة البعيدة" is found.

- [ ] **Step 3: Update `session_summary_screen.dart`**

Add the import:

```dart
import '../recitation_parts.dart';
```

Inside the `studentAsync.when(data: (_) { … })` block, after `final resolvedLevel = level!;` (line 184), add:

```dart
                final presentParts =
                    activeSession.meeting?.presentParts ?? const [1, 2, 3];
```

Replace the three fixed `_PartResultCard` widgets (lines 206–222) with a loop:

```dart
                    for (final p in presentParts) ...[
                      _PartResultCard(
                        title: recitationPartTitleAr(p),
                        errors: recitationPartErrors(activeSession, p),
                        level: resolvedLevel,
                      ),
                      const SizedBox(height: 8),
                    ],
```

- [ ] **Step 4: Run the new test plus the existing summary test**

Run: `flutter test test/widget/session_summary_hides_empty_parts_test.dart test/widget/session_summary_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/screens/session_summary_screen.dart test/widget/session_summary_hides_empty_parts_test.dart
git commit -m "feat(teacher): hide empty part cards on the session summary"
```

---

### Task 5: `composeNextMeetingAfter` + `activeSessionNextMeetingProvider`

**Files:**
- Modify: `lib/shared/providers/meeting_provider.dart` (add `composeNextMeetingAfter`)
- Modify: `lib/features/teacher/providers/teacher_provider.dart` (add `activeSessionNextMeetingProvider`)
- Test: `test/unit/providers/next_meeting_composition_test.dart`

**Interfaces:**
- Consumes: `curriculumRepositoryProvider.getSessionsForLevel(level:)`; `PacedSessionComposer.compose`; `ActiveSessionState.meeting`; `studentProvider`.
- Produces:
  - `Future<PacedSession?> composeNextMeetingAfter(Ref ref, StudentModel student, PacedSession current)` — composes the meeting at `current.toOrderInLevel + 1` in `student.currentLevel`; `null` when no session stands there (end of level) or the level has no rows.
  - `final activeSessionNextMeetingProvider = FutureProvider<PacedSession?>(...)` — resolves the next meeting for the current active session, or `null` when there is no active meeting / student.

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/next_meeting_composition_test.dart`. Use `fake_cloud_firestore` to back a real `CurriculumRepository`, seed a short level, and assert the helper composes the row after a meeting's last order and returns null past the end:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/shared/providers/meeting_provider.dart';

Future<void> _seedSession(
  FakeFirebaseFirestore db, {
  required int order,
  required String kind,
  Map<String, dynamic>? current,
}) async {
  await db.collection('sessions').doc('L1_S$order').set({
    'level_id': 1,
    'juz_number': 30,
    'session_number': order,
    'order_in_level': order,
    'kind': kind,
    'hizb_number': 59,
    if (current != null) 'current_level_content': current,
  });
}

StudentModel _student() => StudentModel(
      id: 'student-1',
      userId: 'user-1',
      instituteId: 'i1',
      teacherId: 't1',
      currentLevel: 1,
      currentJuz: 30,
      currentHizb: 59,
      currentSession: 1,
      currentAttempt: 1,
      currentOrderInLevel: 2,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('composeNextMeetingAfter composes the row after the meeting', () async {
    final db = FakeFirebaseFirestore();
    await _seedSession(db, order: 2, kind: 'lesson', current: {
      'from_surah': 'النبأ',
      'from_verse': 1,
      'to_surah': 'النبأ',
      'to_verse': 11,
    });
    await _seedSession(db, order: 3, kind: 'lesson', current: {
      'from_surah': 'النبأ',
      'from_verse': 12,
      'to_surah': 'النبأ',
      'to_verse': 20,
    });

    final container = ProviderContainer(overrides: [
      curriculumRepositoryProvider
          .overrideWithValue(CurriculumRepository(firestore: db)),
    ]);
    addTearDown(container.dispose);

    final levelSessions =
        await container.read(curriculumRepositoryProvider).getSessionsForLevel(level: 1);
    final current = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: 2,
      pace: const CurriculumPace(1),
    );

    final next = await composeNextMeetingAfter(
      container.read(_refProvider), // see note
      _student(),
      current,
    );
    expect(next, isNotNull);
    expect(next!.fromOrderInLevel, 3);
    expect(next.newContentAr, contains('12'));
  });

  test('composeNextMeetingAfter returns null past the last session', () async {
    final db = FakeFirebaseFirestore();
    await _seedSession(db, order: 2, kind: 'lesson', current: {
      'from_surah': 'النبأ',
      'from_verse': 1,
      'to_surah': 'النبأ',
      'to_verse': 11,
    });

    final container = ProviderContainer(overrides: [
      curriculumRepositoryProvider
          .overrideWithValue(CurriculumRepository(firestore: db)),
    ]);
    addTearDown(container.dispose);

    final levelSessions =
        await container.read(curriculumRepositoryProvider).getSessionsForLevel(level: 1);
    final current = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: 2,
      pace: const CurriculumPace(1),
    );

    final next = await composeNextMeetingAfter(
      container.read(_refProvider),
      _student(),
      current,
    );
    expect(next, isNull);
  });
}

/// `composeNextMeetingAfter` takes a `Ref`. Expose the container's Ref to the
/// test through a trivial provider.
final _refProvider = Provider<Ref>((ref) => ref);
```

> Note: confirm `CurriculumRepository` accepts a `firestore:` named parameter (it does in `session_summary_screen_test.dart`). If `curriculumRepositoryProvider` cannot be overridden with `overrideWithValue`, use `overrideWith((ref) => CurriculumRepository(firestore: db))`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/next_meeting_composition_test.dart`
Expected: FAIL — `composeNextMeetingAfter` is undefined.

- [ ] **Step 3: Add `composeNextMeetingAfter` to `meeting_provider.dart`**

Append to `lib/shared/providers/meeting_provider.dart`:

```dart
/// Composes the meeting the student will stand on AFTER completing [current],
/// used to preview the next new passage before a session closes.
///
/// Composes at `current.toOrderInLevel + 1` within the student's CURRENT
/// level, at the student's live pace — the same rule as [composeMeetingFor].
/// Returns null when no session stands at that order (end of level: the next
/// passage lives in the next level, which this preview deliberately does not
/// load) or when the level has no rows.
Future<PacedSession?> composeNextMeetingAfter(
  Ref ref,
  StudentModel student,
  PacedSession current,
) async {
  final curriculumRepo = ref.watch(curriculumRepositoryProvider);

  final levelSessions = await curriculumRepo.getSessionsForLevel(
    level: student.currentLevel,
  );
  if (levelSessions.isEmpty) return null;

  final nextOrder = current.toOrderInLevel + 1;
  final hasNext =
      levelSessions.any((session) => session.orderInLevel == nextOrder);
  if (!hasNext) return null;

  return PacedSessionComposer.compose(
    levelSessions: levelSessions,
    startOrderInLevel: nextOrder,
    pace: student.pace,
  );
}
```

- [ ] **Step 4: Add `activeSessionNextMeetingProvider` to `teacher_provider.dart`**

Add the import if not present (top of `teacher_provider.dart` already imports `meeting_provider.dart` with `show composeMeetingFor` — widen it):

```dart
import '../../../shared/providers/meeting_provider.dart'
    show composeMeetingFor, composeNextMeetingAfter;
```

After `studentCurrentMeetingProvider` (around line 106), add:

```dart
/// The meeting to PREVIEW after the active session — the passage the teacher
/// recites (تلقين) with the student before closing. Recomposed from the
/// student's live pace like every other meeting. Null when there is no active
/// meeting, the student can't be resolved, or the active meeting is the last
/// in the level.
final activeSessionNextMeetingProvider = FutureProvider<PacedSession?>((
  ref,
) async {
  final active = ref.watch(activeSessionProvider);
  final meeting = active?.meeting;
  if (active == null || meeting == null) return null;

  final studentAsync = ref.watch(studentProvider(active.studentId));
  final student = studentAsync.value?.student;
  if (student == null) return null;

  return composeNextMeetingAfter(ref, student, meeting);
});
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/unit/providers/next_meeting_composition_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/providers/meeting_provider.dart lib/features/teacher/providers/teacher_provider.dart test/unit/providers/next_meeting_composition_test.dart
git commit -m "feat(curriculum): compose the next meeting for the talqeen preview"
```

---

### Task 6: `NextContentTalqeenScreen` + route (closes the session)

**Files:**
- Create: `lib/features/teacher/screens/next_content_talqeen_screen.dart`
- Modify: `lib/routing/app_router.dart` (route constant + GoRoute)
- Test: `test/widget/next_content_talqeen_screen_test.dart`

**Interfaces:**
- Consumes: `activeSessionProvider`, `studentProvider`, `activeSessionNextMeetingProvider` (Task 5); `ActiveSessionState.passesForLevel(level)`; `completeSession()`; `StudentAdvanceOutcome`.
- Produces: `AppRoutes.nextContentTalqeen = '/teacher/session/:studentId/next-content'`; `NextContentTalqeenScreen({required String studentId})`.

- [ ] **Step 1: Add the route constant and GoRoute**

In `lib/routing/app_router.dart`, add the import near the other teacher-screen imports (~line 38):

```dart
import '../features/teacher/screens/next_content_talqeen_screen.dart';
```

Add the constant next to `sessionSummary` (~line 92):

```dart
  static const String nextContentTalqeen =
      '/teacher/session/:studentId/next-content';
```

Add the `GoRoute` in the teacher Students branch immediately after the `sessionSummary` route (~line 417):

```dart
              GoRoute(
                path: AppRoutes.nextContentTalqeen,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return NextContentTalqeenScreen(studentId: studentId);
                },
              ),
```

- [ ] **Step 2: Write the failing test**

Create `test/widget/next_content_talqeen_screen_test.dart`. Two cases: a PASSED session previews the NEXT meeting's new passage; a FAILED session previews the SAME (current) meeting's new passage. Seed the active session and override the next-meeting provider so no Firestore is needed:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/next_content_talqeen_screen.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

SessionModel _lesson(int order) => SessionModel(
      id: 'L1_S$order',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: order,
      orderInLevel: order,
      kind: SessionKind.lesson,
    );

PacedSession _meeting(int order, QuranContent newC) => PacedSession(
      sessions: [_lesson(order)],
      newContent: [newC],
      recentReview: const [],
      distantReview: const [],
    );

StudentWithUser _studentWithUser() => StudentWithUser(
      student: StudentModel(
        id: 'student-1',
        userId: 'user-1',
        instituteId: 'i1',
        teacherId: 't1',
        currentLevel: 1,
        currentJuz: 30,
        currentHizb: 59,
        currentSession: 1,
        currentAttempt: 1,
        currentOrderInLevel: 2,
        createdAt: DateTime(2026, 1, 1),
      ),
      user: UserModel(
        id: 'user-1',
        username: 'pupil',
        email: 'pupil@x.local',
        name: 'طالب',
        role: UserRole.student,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  required int part1Errors,
  required PacedSession current,
  required PacedSession? next,
}) async {
  final container = ProviderContainer(overrides: [
    studentProvider.overrideWith((ref, id) async => _studentWithUser()),
    activeSessionNextMeetingProvider.overrideWith((ref) async => next),
  ]);
  addTearDown(container.dispose);

  container.read(activeSessionProvider.notifier).seedForTest(
        ActiveSessionState(
          studentId: 'student-1',
          part1Errors: part1Errors,
          meeting: current,
        ),
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: NextContentTalqeenScreen(studentId: 'student-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('passed session previews the NEXT passage', (tester) async {
    await _pump(
      tester,
      part1Errors: 0, // passes
      current: _meeting(2, _c('النبأ', 1, 11)),
      next: _meeting(3, _c('النبأ', 12, 20)),
    );
    expect(find.textContaining('12'), findsWidgets); // next passage
    expect(find.text('إنهاء الحلقة'), findsOneWidget);
  });

  testWidgets('failed session previews the SAME current passage',
      (tester) async {
    await _pump(
      tester,
      part1Errors: 99, // fails at level 1
      current: _meeting(2, _c('النبأ', 1, 11)),
      next: _meeting(3, _c('النبأ', 12, 20)),
    );
    expect(find.textContaining('1'), findsWidgets); // النبأ 1-11 (current)
    expect(find.text('إنهاء الحلقة'), findsOneWidget);
  });
}
```

> Note: `part1Errors: 99` must fail at level 1 per `GradeCalculator.sessionPassesForLevel`. If level-1's threshold differs, pick an error count above its محب cutoff — check `lib/core/utils/grade_calculator.dart`.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/next_content_talqeen_screen_test.dart`
Expected: FAIL — `next_content_talqeen_screen.dart` does not exist.

- [ ] **Step 4: Create `next_content_talqeen_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_provider.dart';

/// The talqeen step that closes a session: before ending the الحلقة, the
/// teacher recites the passage the student will memorize next TO the student.
///
/// A PASSED session previews the NEXT meeting's new passage. A FAILED session
/// does not advance — the student repeats the same الحلقة — so it previews the
/// SAME (current) meeting's new passage. When there is no new passage to recite
/// (the next session is a سرد/اختبار, the current level has ended, or a failed
/// review-only lesson), a short note stands in. This screen is the ONLY place
/// the session is completed.
class NextContentTalqeenScreen extends ConsumerStatefulWidget {
  final String studentId;

  const NextContentTalqeenScreen({super.key, required this.studentId});

  @override
  ConsumerState<NextContentTalqeenScreen> createState() =>
      _NextContentTalqeenScreenState();
}

class _NextContentTalqeenScreenState
    extends ConsumerState<NextContentTalqeenScreen> {
  bool _isSaving = false;

  Future<void> _closeSession() async {
    setState(() => _isSaving = true);
    try {
      final record =
          await ref.read(activeSessionProvider.notifier).completeSession();

      final advanceOutcome = ref.read(activeSessionProvider)?.advanceOutcome;
      final progressNotAdvanced = record != null &&
          record.passed &&
          (advanceOutcome == StudentAdvanceOutcome.curriculumDataMissing ||
              advanceOutcome == StudentAdvanceOutcome.studentNotFound);

      if (record != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              progressNotAdvanced
                  ? 'تم حفظ النتيجة، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
                        'تالية في المنهج.'
                  : (record.passed
                        ? 'تم حفظ الحلقة - ناجح'
                        : 'تم حفظ الحلقة - راسب'),
            ),
            backgroundColor: progressNotAdvanced
                ? AppColors.error
                : (record.passed ? AppColors.success : AppColors.warning),
          ),
        );
        context.go(AppRoutes.teacherStudents);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider);
    final studentAsync = ref.watch(studentProvider(widget.studentId));
    final level = studentAsync.value?.student.currentLevel;

    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تلقين المقطع القادم')),
        body: const Center(child: Text('لا توجد جلسة نشطة')),
      );
    }

    // A failed session repeats the SAME meeting; a passed one moves on. Until
    // the level resolves we don't know which — hold the passage back rather
    // than guess.
    final passed = level != null ? active.passesForLevel(level) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تلقين المقطع القادم'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passed == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!passed)
              // Repeats the same session — recite the same new passage again.
              _PassageCard(passage: active.meeting?.newContentAr ?? '')
            else
              // Passed — preview the next meeting's new passage.
              ref.watch(activeSessionNextMeetingProvider).when(
                    data: (next) => _PassageCard(
                      passage: (next != null && next.hasNewContent)
                          ? next.newContentAr
                          : '',
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => const _PassageCard(passage: ''),
                  ),
            const SizedBox(height: 32),
            AppButton(
              text: 'إنهاء الحلقة',
              onPressed: _closeSession,
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }
}

/// The passage to recite, or the no-new-content note when [passage] is empty.
class _PassageCard extends StatelessWidget {
  final String passage;

  const _PassageCard({required this.passage});

  @override
  Widget build(BuildContext context) {
    final hasPassage = passage.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.record_voice_over,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPassage ? 'المقطع القادم للتلقين' : 'لا يوجد حفظ جديد',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          if (hasPassage) ...[
            Text(
              passage,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'اقرأ المقطع على الطالب وردده معه قبل إغلاق الحلقة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else
            Text(
              'لا يوجد مقطع جديد للتلقين قبل إغلاق الحلقة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widget/next_content_talqeen_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/teacher/screens/next_content_talqeen_screen.dart lib/routing/app_router.dart test/widget/next_content_talqeen_screen_test.dart
git commit -m "feat(teacher): talqeen the next passage on a screen that closes the session"
```

---

### Task 7: Rewire the summary button to the talqeen step

**Files:**
- Modify: `lib/features/teacher/screens/session_summary_screen.dart`
- Test: `test/widget/session_summary_navigates_to_talqeen_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.nextContentTalqeen` (Task 6); `activeSessionProvider.notifier.setNotes`.
- Behavior change: the summary's primary button no longer calls `completeSession`; it writes notes and navigates to `nextContentTalqeen`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/session_summary_navigates_to_talqeen_test.dart`. Pump the summary inside a GoRouter with a stub talqeen route, tap the primary button, and assert we navigate WITHOUT the session being completed:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_summary_screen.dart';
import 'package:al_rasikhoon/routing/app_router.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

void main() {
  testWidgets('summary button navigates to talqeen without completing',
      (tester) async {
    final container = ProviderContainer(overrides: [
      studentProvider.overrideWith((ref, id) async => StudentWithUser(
            student: StudentModel(
              id: 'student-1',
              userId: 'user-1',
              instituteId: 'i1',
              teacherId: 't1',
              currentLevel: 1,
              currentJuz: 30,
              currentHizb: 59,
              currentSession: 1,
              currentAttempt: 1,
              currentOrderInLevel: 2,
              createdAt: DateTime(2026, 1, 1),
            ),
            user: UserModel(
              id: 'user-1',
              username: 'pupil',
              email: 'pupil@x.local',
              name: 'طالب',
              role: UserRole.student,
              authProvider: UserAuthProvider.emailPassword,
              createdAt: DateTime(2026, 1, 1),
            ),
          )),
    ]);
    addTearDown(container.dispose);

    container.read(activeSessionProvider.notifier).seedForTest(
          ActiveSessionState(
      studentId: 'student-1',
      part1Errors: 0,
      meeting: PacedSession(
        sessions: [
          SessionModel(
            id: 'L1_S2',
            levelId: 1,
            juzNumber: 30,
            sessionNumber: 2,
            orderInLevel: 2,
            kind: SessionKind.lesson,
          ),
        ],
        newContent: [_c('النبأ', 1, 11)],
        recentReview: const [],
        distantReview: const [],
      ),
          ),
        );

    final router = GoRouter(
      initialLocation: '/teacher/session/student-1/summary',
      routes: [
        GoRoute(
          path: AppRoutes.sessionSummary,
          builder: (_, _) => const SessionSummaryScreen(studentId: 'student-1'),
        ),
        GoRoute(
          path: AppRoutes.nextContentTalqeen,
          builder: (_, _) =>
              const Scaffold(body: Text('TALQEEN_STUB')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('التالي: تلقين المقطع القادم'));
    await tester.pumpAndSettle();

    expect(find.text('TALQEEN_STUB'), findsOneWidget);
    // The session is NOT completed by the summary.
    expect(container.read(activeSessionProvider)?.isComplete, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/session_summary_navigates_to_talqeen_test.dart`
Expected: FAIL — the button still reads "حفظ وإنهاء الحلقة" and completes the session.

- [ ] **Step 3: Rewire the summary button**

In `lib/features/teacher/screens/session_summary_screen.dart`:

Delete the `_isSaving` field (line 25) and the entire `_saveSession` method (lines 34–92) — its close logic now lives in `NextContentTalqeenScreen`.

Replace the primary `AppButton` (lines 279–285) with:

```dart
            AppButton(
              text: 'التالي: تلقين المقطع القادم',
              onPressed: () {
                // Notes and counts persist in the active-session provider, so
                // the talqeen step that follows can complete the session with
                // them. This screen no longer ends the session.
                ref
                    .read(activeSessionProvider.notifier)
                    .setNotes(_notesController.text.trim());
                context.push(
                  AppRoutes.nextContentTalqeen
                      .replaceFirst(':studentId', widget.studentId),
                );
              },
              isFullWidth: true,
              size: AppButtonSize.large,
            ),
```

Keep the "العودة للتعديل" button below it unchanged. Remove the now-unused `StudentAdvanceOutcome` import only if the analyzer flags it (the file may still reference it elsewhere — leave it if used).

- [ ] **Step 4: Run the test plus the existing summary tests**

Run: `flutter test test/widget/session_summary_navigates_to_talqeen_test.dart test/widget/session_summary_screen_test.dart test/widget/session_summary_hides_empty_parts_test.dart`
Expected: PASS.

> If `test/widget/session_summary_screen_test.dart` asserted the old save behavior (it drove the real save button), update it to drive the new flow: tap "التالي: تلقين المقطع القادم", then complete on the talqeen screen. Read that test first and adjust its expectations rather than deleting coverage.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/screens/session_summary_screen.dart test/widget/session_summary_navigates_to_talqeen_test.dart
git commit -m "feat(teacher): summary hands off to the talqeen step instead of closing"
```

---

### Task 8: Full-flow verification + regression sweep

**Files:**
- No production changes expected. Modify existing tests only if this sweep surfaces stale expectations.

- [ ] **Step 1: Run the analyzer**

Run: `flutter analyze`
Expected: No new errors/warnings. Fix any unused-import or dead-code warnings introduced by the moved `_saveSession`.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: PASS. Pay attention to any e2e (`test/e2e/*`) or flow test that walked recitation part 1→2→3 or closed a session from the summary — update it to the new handoff (summary → talqeen → close) if it fails, preserving its original intent.

- [ ] **Step 3: Manual smoke via the run skill (optional but recommended)**

Use the `run` skill to launch the app, start a session for a student whose current lesson has a distant review but no recent review, and confirm: the flow goes part 1 → part 3 (recent skipped), the summary hides the recent card, and "التالي: تلقين المقطع القادم" leads to the passage screen whose "إنهاء الحلقة" closes the session.

- [ ] **Step 4: Commit any test updates**

```bash
git add -A
git commit -m "test: update flow expectations for skip-empty-parts + talqeen handoff"
```

---

## Self-Review Notes

- **Spec coverage:** Part A skip (Tasks 1–4), Part B talqeen + reordering (Tasks 5–7), end-of-level note (Task 5 null path → Task 6 `_PassageCard` note), fail-shows-current (Task 6), no-content note (Task 6). Grades untouched (Global Constraints; verified in Task 4 reasoning).
- **Type consistency:** `presentParts`/`partAfter` (Task 1), `recitationPartTitleAr`/`recitationPartErrors` (Task 2), `composeNextMeetingAfter`/`activeSessionNextMeetingProvider` (Task 5), `AppRoutes.nextContentTalqeen`/`NextContentTalqeenScreen` (Task 6) are used with the same names/signatures in later tasks.
- **Known open items for the executor:** confirm `ActiveSessionNotifier` allows setting `state` in tests (Task 3 note); confirm the level-1 failing error count (Task 6 note); confirm `curriculumRepositoryProvider` override style (Task 5 note). Each has a stated fallback.
