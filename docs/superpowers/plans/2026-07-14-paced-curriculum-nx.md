# Paced Curriculum (NX) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a teacher or supervisor set a per-student pace N so one meeting covers N curriculum lessons, with new content, recent review and distant review all scaling correctly.

**Architecture:** A `CurriculumPace` value object on the student, and a pure domain service that *composes* a meeting from N consecutive lesson rows. The curriculum data is never modified and no Qur'an range is ever computed — composition only unions ranges the source already states. At pace 1 the composition code does not run at all: the session's authored blocks are read verbatim, so 1x students are untouched by construction.

**Tech Stack:** Flutter / Dart, Riverpod, Firestore (`fake_cloud_firestore` in tests), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-14-paced-curriculum-nx-design.md`
**Issue:** `al_rasikhoon-g63`

## Global Constraints

- **DDD / Clean Architecture** per `CLAUDE.md`. `lib/domain/` has zero framework dependencies — no `cloud_firestore`, no `flutter`, no Riverpod imports. Composition and pace validation are domain; Firestore reads are repository.
- **The app never authors curriculum content.** Every Qur'an range in a composed meeting must be a range copied from a `SessionModel`'s existing content blocks. Never construct a `QuranContent` from computed surah names or verse numbers.
- **At pace 1, behaviour is byte-identical to today.** Any change that alters what a 1x student sees is a bug.
- **Ordering key is `orderInLevel`.** Never order or advance by `sessionNumber`, `juzNumber`, `date`, or `createdAt`.
- **Session kind is read from data, never inferred from a number.** Use `SessionModel.isLesson` / `.isTalqeen` / `.isAssessment`.
- Arabic domain terms in names and test names: تلقين (talqeen), سرد (sard), اختبار (exam).
- Run tests with `flutter test <path>`. Run `dart analyze` before each commit; it must be clean.
- Commit after each task. Reference `al_rasikhoon-g63` in commit bodies.

## File Structure

**Domain (new, pure):**
- `lib/domain/curriculum/curriculum_pace.dart` — `CurriculumPace` value object.
- `lib/domain/curriculum/paced_session.dart` — `PacedSession` (the composed meeting) + `PacedSessionComposer` (the composition service).

**Data (modified):**
- `lib/data/models/student_model.dart` — add `pace`.
- `lib/data/models/session_record_model.dart` — add `coversSessionIds`, `fromOrderInLevel`, `paceAtTime`; rename `orderInLevel` → `toOrderInLevel`.
- `lib/data/repositories/curriculum_repository.dart` — add `getSessionsForLevel`.
- `lib/data/repositories/session_repository.dart` — meeting-spanning record writes.
- `lib/data/repositories/student_repository.dart` — advance from a given order; set pace.

**Presentation (modified):**
- `lib/features/teacher/providers/teacher_provider.dart` — compose the meeting, write the spanning record, advance past it; `studentCurrentMeetingProvider`.
- `lib/features/supervisor/providers/supervisor_provider.dart` — `supervisorStudentCurrentMeetingProvider` (institute-scoped).
- `lib/features/student/providers/student_provider.dart` — `studentDashboardMeetingProvider`.
- Screens that TEACH a student read the meeting: `teacher/screens/recitation_screen.dart`, `new_memorization_screen.dart`, `session_overview_screen.dart`, `talqeen_session_screen.dart`, `student/screens/student_dashboard_screen.dart`, `admin/screens/admin_student_progress_screen.dart`.
- Screens that BROWSE the curriculum keep the authored row and are **not** touched: `admin/screens/level_detail_screen.dart`, `teacher/widgets/starting_point_picker.dart`.

**Tests (new):**
- `test/unit/domain/curriculum/curriculum_pace_test.dart`
- `test/unit/domain/curriculum/paced_session_test.dart`
- `test/unit/domain/curriculum/paced_session_real_curriculum_test.dart` — walks `data/curriculum/*.json`.

---

### Task 1: `CurriculumPace` value object

**Files:**
- Create: `lib/domain/curriculum/curriculum_pace.dart`
- Test: `test/unit/domain/curriculum/curriculum_pace_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `CurriculumPace` — `const CurriculumPace(int multiplier)`, `CurriculumPace.standard` (multiplier 1), `int get multiplier`, `bool get isStandard`, `CurriculumPace.fromJson(Object?)` → defaults to standard on `null`, `int toJson()`, `==` / `hashCode`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/curriculum/curriculum_pace_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';

void main() {
  group('CurriculumPace', () {
    test('the standard pace is one session per meeting', () {
      expect(CurriculumPace.standard.multiplier, 1);
      expect(CurriculumPace.standard.isStandard, isTrue);
    });

    test('a doubled pace is not the standard pace', () {
      final doubled = CurriculumPace(2);
      expect(doubled.multiplier, 2);
      expect(doubled.isStandard, isFalse);
    });

    test('a pace below one is not a pace', () {
      expect(() => CurriculumPace(0), throwsArgumentError);
      expect(() => CurriculumPace(-1), throwsArgumentError);
    });

    test('a student with no stored pace reads back as the standard pace', () {
      expect(CurriculumPace.fromJson(null), CurriculumPace.standard);
    });

    test('a stored pace reads back as itself', () {
      expect(CurriculumPace.fromJson(3), CurriculumPace(3));
      expect(CurriculumPace(3).toJson(), 3);
    });

    test('a corrupted stored pace surfaces rather than defaulting', () {
      expect(() => CurriculumPace.fromJson(0), throwsArgumentError);
      expect(() => CurriculumPace.fromJson('two'), throwsArgumentError);
    });

    test('two paces of the same multiplier are the same pace', () {
      expect(CurriculumPace(2), CurriculumPace(2));
      expect(CurriculumPace(2).hashCode, CurriculumPace(2).hashCode);
      expect(CurriculumPace(2), isNot(CurriculumPace(3)));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/domain/curriculum/curriculum_pace_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/curriculum/curriculum_pace.dart`:

```dart
/// How many curriculum lessons a student covers in one meeting.
///
/// The curriculum is authored for the average student: one meeting, one session.
/// A student who memorizes quickly can be given N× that — the teacher and the
/// supervisor may set it, and it may change mid-level.
///
/// A pace multiplies LESSONS only. A تلقين, a سرد and an اختبار each always
/// stand alone, at any pace.
class CurriculumPace {
  /// One lesson per meeting — the curriculum exactly as authored.
  static final CurriculumPace standard = CurriculumPace(1);

  final int multiplier;

  /// A value object validates its invariant in its constructor, so this cannot
  /// be `const` — an `assert` would fire only in debug, and a pace of 0 read
  /// from a corrupted document in production would sail through.
  CurriculumPace(this.multiplier) {
    if (multiplier < 1) {
      throw ArgumentError.value(
        multiplier,
        'multiplier',
        'A pace covers at least one session',
      );
    }
  }

  /// Reads a pace from storage.
  ///
  /// Absence is not corruption: every student created before paced curricula has
  /// no stored pace and is, correctly, a standard-pace student. A stored value
  /// that is not a valid multiplier IS corruption and must surface — silently
  /// defaulting a broken 0 to 1 would hide it forever.
  factory CurriculumPace.fromJson(Object? json) {
    if (json == null) return standard;
    if (json is! int) {
      throw ArgumentError.value(json, 'pace', 'A pace must be a whole number');
    }
    if (json < 1) {
      throw ArgumentError.value(json, 'pace', 'A pace must be at least 1');
    }
    return CurriculumPace(json);
  }

  int toJson() => multiplier;

  bool get isStandard => multiplier == 1;

  @override
  String toString() => 'CurriculumPace(${multiplier}x)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumPace && other.multiplier == multiplier;

  @override
  int get hashCode => multiplier.hashCode;
}
```

Because the constructor validates, it is not `const` — so `CurriculumPace(2)`, never `const CurriculumPace(2)`. The test above is already written that way.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/domain/curriculum/curriculum_pace_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Analyze and commit**

```bash
dart analyze lib/domain/curriculum/curriculum_pace.dart
git add lib/domain/curriculum/curriculum_pace.dart test/unit/domain/curriculum/curriculum_pace_test.dart
git commit -m "feat(curriculum): add CurriculumPace, the per-student session multiplier

A pace of N means one meeting covers N lessons. Absence reads back as the
standard pace; a stored 0 is corruption and surfaces.

Refs: al_rasikhoon-g63"
```

---

### Task 2: `PacedSession` — the composed meeting

**Files:**
- Create: `lib/domain/curriculum/paced_session.dart`
- Test: `test/unit/domain/curriculum/paced_session_test.dart`

**Interfaces:**
- Consumes: `CurriculumPace` (Task 1); `SessionModel`, `QuranContent` from `lib/data/models/session_model.dart`.
- Produces:
  - `PacedSession` — `List<SessionModel> get sessions`, `List<QuranContent> get newContent`, `List<QuranContent> get recentReview`, `List<QuranContent> get distantReview`, `int get fromOrderInLevel`, `int get toOrderInLevel`, `List<String> get coversSessionIds`, `SessionModel get first`, `bool get isBatched`.
  - `PacedSessionComposer.compose({required List<SessionModel> levelSessions, required int startOrderInLevel, required CurriculumPace pace})` → `PacedSession`. Throws `ArgumentError` if no session stands at `startOrderInLevel`.

**Design notes for the implementer (read before writing code):**

`levelSessions` is every session of ONE level, in any order — the composer sorts by `orderInLevel` itself. It must not assume the list is complete or contiguous.

Composition rules, exactly:

1. **The batch.** Start at `startOrderInLevel`. If that session is NOT a lesson (`isTalqeen`, `isSard`, `isExam`), the batch is that session alone and the pace is *ignored*. Otherwise take up to `pace.multiplier` consecutive sessions, stopping before the first one that is not a lesson, that belongs to a different `levelId`, or that is missing from the list.
2. **A pace-1 meeting is never composed.** If the batch has exactly one session, `newContent`, `recentReview` and `distantReview` are that session's own authored blocks, verbatim (each wrapped in a single-element list, or an empty list if the block is null). This is a hard requirement: ~8 rows of the source curriculum disagree with the source's own window rule, and composing them would silently rewrite what a 1x student sees. See the spec.
3. **New content** (batched only) = each batched session's `currentLevelContent`, in order, nulls dropped.
4. **Distant review** (batched only) = each batched session's `distantReviewContent`, in order, nulls dropped. No further rule: the distant cursor sweeps non-overlapping chunks, so concatenation is correct by construction.
5. **Recent review** (batched only) = the `currentLevelContent` of sessions at orders `[K - 2*N, K - 1]` where K is `startOrderInLevel` and N is the multiplier, in ascending order, subject to three exclusions:
   - drop sessions with no `currentLevelContent` (a سرد, an اختبار);
   - drop sessions at an order **before the تلقين that opens the unit containing K** — the window never reaches into the previous unit. Find that تلقين by scanning backwards from K for the nearest session with `isTalqeen`; if there is none, do not clamp.
   - drop any session whose `currentLevelContent` **equals** a block already in this meeting's `newContent` — this is what correctly zeroes the recent block for the unit's first lesson, whose window would otherwise pull in the تلقين's duplicate of the very passage being taught. `QuranContent` has no `==`; compare on the four fields.

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/curriculum/paced_session_test.dart`. Note the local `_session` and `_content` helpers — do not reach for the Firestore fixtures, this is a pure domain test with no mocks.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

QuranContent _content(String surah, int from, int to) =>
    QuranContent(fromSurah: surah, fromVerse: from, toSurah: surah, toVerse: to);

SessionModel _session({
  required int order,
  SessionKind kind = SessionKind.lesson,
  QuranContent? newContent,
  QuranContent? recent,
  QuranContent? distant,
  int level = 1,
  int juz = 30,
}) => SessionModel(
  id: 'L${level}_J${juz}_S$order',
  levelId: level,
  juzNumber: juz,
  sessionNumber: order,
  orderInLevel: order,
  kind: kind,
  currentLevelContent: newContent,
  recentReviewContent: recent,
  distantReviewContent: distant,
);

/// A unit shaped like the real curriculum: a تلقين that opens it, lessons whose
/// recent review is the previous two lessons' new content, then a سرد.
///
/// order 1  تلقين   new: النبأ 1-11
/// order 2  lesson  new: النبأ 1-11    (the تلقين's passage, now recited)
/// order 3  lesson  new: النبأ 12-20   recent: النبأ 1-11
/// order 4  lesson  new: النبأ 21-30   recent: النبأ 1-20
/// order 5  lesson  new: النبأ 31-37   recent: النبأ 12-30   distant: الفاتحة 1-3
/// order 6  lesson  new: النبأ 38-40   recent: النبأ 21-37   distant: الفاتحة 4-7
/// order 7  سرد
List<SessionModel> _unit() => [
  _session(order: 1, kind: SessionKind.talqeen, newContent: _content('النبأ', 1, 11)),
  _session(order: 2, newContent: _content('النبأ', 1, 11)),
  _session(
    order: 3,
    newContent: _content('النبأ', 12, 20),
    recent: _content('النبأ', 1, 11),
  ),
  _session(
    order: 4,
    newContent: _content('النبأ', 21, 30),
    recent: _content('النبأ', 1, 20),
  ),
  _session(
    order: 5,
    newContent: _content('النبأ', 31, 37),
    recent: _content('النبأ', 12, 30),
    distant: _content('الفاتحة', 1, 3),
  ),
  _session(
    order: 6,
    newContent: _content('النبأ', 38, 40),
    recent: _content('النبأ', 21, 37),
    distant: _content('الفاتحة', 4, 7),
  ),
  _session(order: 7, kind: SessionKind.sard),
];

void main() {
  final pace1 = CurriculumPace.standard;
  final pace2 = CurriculumPace(2);
  final pace3 = CurriculumPace(3);

  group('a meeting at the standard pace is the session as authored', () {
    test('it covers exactly the one session it starts on', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace1,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [5]);
      expect(meeting.fromOrderInLevel, 5);
      expect(meeting.toOrderInLevel, 5);
      expect(meeting.isBatched, isFalse);
    });

    test('it reads the authored blocks verbatim, it does not compose them', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace1,
      );

      // The source curriculum has ~8 rows that disagree with its own window
      // rule. Composing at pace 1 would silently rewrite them for every
      // ordinary student, so pace 1 must not compose at all.
      expect(meeting.newContent, [_content('النبأ', 31, 37)]);
      expect(meeting.recentReview, [_content('النبأ', 12, 30)]);
      expect(meeting.distantReview, [_content('الفاتحة', 1, 3)]);
    });
  });

  group('a doubled meeting covers two lessons', () {
    test('its new content is both lessons\' new content', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [5, 6]);
      expect(meeting.fromOrderInLevel, 5);
      expect(meeting.toOrderInLevel, 6);
      expect(meeting.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(meeting.newContent, [
        _content('النبأ', 31, 37),
        _content('النبأ', 38, 40),
      ]);
    });

    test('it sweeps both lessons\' distant review', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      expect(meeting.distantReview, [
        _content('الفاتحة', 1, 3),
        _content('الفاتحة', 4, 7),
      ]);
    });

    test('its recent review is the previous two meetings, not the two rows\' own blocks', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      // The rows' own recent blocks union to النبأ 12-37, which contains
      // النبأ 31-37 — this meeting's OWN new content, taught minutes earlier.
      // The correct window is the new content of orders 1..4.
      expect(meeting.recentReview, [
        _content('النبأ', 1, 11),   // order 1 تلقين
        _content('النبأ', 1, 11),   // order 2
        _content('النبأ', 12, 20),  // order 3
        _content('النبأ', 21, 30),  // order 4
      ]);
    });

    test('its recent review never overlaps its own new content', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      for (final taught in meeting.newContent) {
        expect(
          meeting.recentReview,
          isNot(contains(taught)),
          reason: 'a student cannot review a passage he is learning today',
        );
      }
    });
  });

  group('the recent window respects the unit', () {
    test('the unit\'s first lesson reviews nothing — the تلقين taught what it teaches', () {
      // Order 2 teaches النبأ 1-11, the very passage the تلقين at order 1 read
      // to the student. The authored curriculum gives this row no recent block,
      // and composition must reproduce that.
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 2,
        pace: pace2,
      );

      expect(meeting.recentReview, isEmpty);
    });

    test('the window never reaches back past the تلقين that opens the unit', () {
      // A previous unit, then this one. At pace 3 the window would span 6
      // sessions back — straight through the سرد and into the previous unit.
      final sessions = [
        _session(order: 1, newContent: _content('الفيل', 1, 5)),
        _session(order: 2, newContent: _content('قريش', 1, 4)),
        _session(order: 3, kind: SessionKind.sard),
        _session(order: 4, kind: SessionKind.talqeen, newContent: _content('النبأ', 1, 11)),
        _session(order: 5, newContent: _content('النبأ', 1, 11)),
        _session(order: 6, newContent: _content('النبأ', 12, 20)),
        _session(order: 7, newContent: _content('النبأ', 21, 30)),
        _session(order: 8, newContent: _content('النبأ', 31, 37)),
      ];

      final meeting = PacedSessionComposer.compose(
        levelSessions: sessions,
        startOrderInLevel: 7,
        pace: pace3,
      );

      // Window would be orders 1..6. Clamped to the تلقين at 4, and the سرد
      // carries no new content anyway. الفيل and قريش must NOT appear.
      expect(meeting.recentReview, [
        _content('النبأ', 1, 11), // order 4 تلقين
        _content('النبأ', 1, 11), // order 5
        _content('النبأ', 12, 20), // order 6
      ]);
    });
  });

  group('only lessons batch', () {
    test('a تلقين stands alone however fast the student is', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 1,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [1]);
      expect(meeting.isBatched, isFalse);
      expect(meeting.newContent, [_content('النبأ', 1, 11)]);
    });

    test('a سرد stands alone however fast the student is', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 7,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [7]);
      expect(meeting.isBatched, isFalse);
    });

    test('a batch stops before the سرد rather than swallowing it', () {
      // Orders 5, 6 are lessons; 7 is the سرد. A 3x meeting starting at 5 takes
      // only the two lessons.
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [5, 6]);
      expect(meeting.toOrderInLevel, 6);
    });

    test('a batch stops at the end of the level', () {
      final sessions = [
        _session(order: 1, newContent: _content('النبأ', 1, 11)),
        _session(order: 2, newContent: _content('النبأ', 12, 20)),
      ];

      final meeting = PacedSessionComposer.compose(
        levelSessions: sessions,
        startOrderInLevel: 2,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [2]);
      expect(meeting.toOrderInLevel, 2);
    });
  });

  test('composing from a session the level does not have is an error', () {
    expect(
      () => PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 99,
        pace: pace1,
      ),
      throwsArgumentError,
    );
  });
}
```

`QuranContent` currently has no `==`, so `expect(meeting.newContent, [_content(...)])` will fail on identity. Add value equality to `QuranContent` in `lib/data/models/session_model.dart` as part of this task:

```dart
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranContent &&
          other.fromSurah == fromSurah &&
          other.fromVerse == fromVerse &&
          other.toSurah == toSurah &&
          other.toVerse == toVerse;

  @override
  int get hashCode => Object.hash(fromSurah, fromVerse, toSurah, toVerse);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/domain/curriculum/paced_session_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:al_rasikhoon/domain/curriculum/paced_session.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/domain/curriculum/paced_session.dart`:

```dart
import '../../data/models/session_model.dart';
import 'curriculum_pace.dart';

/// One meeting between a teacher and a student: the N curriculum sessions it
/// discharges, and the three content streams the student recites.
///
/// A meeting is DERIVED, never stored. The curriculum collection holds one row
/// per session and knows nothing of pace; a meeting is composed from those rows
/// on demand. Every range here is a range the curriculum already states — this
/// class unions blocks, it never authors content.
class PacedSession {
  /// The sessions this meeting covers, ascending by [SessionModel.orderInLevel].
  final List<SessionModel> sessions;

  final List<QuranContent> newContent;
  final List<QuranContent> recentReview;
  final List<QuranContent> distantReview;

  const PacedSession({
    required this.sessions,
    required this.newContent,
    required this.recentReview,
    required this.distantReview,
  });

  /// The session the meeting starts on. Its kind, tier and label are the
  /// meeting's — a batch is all lessons, so they agree.
  SessionModel get first => sessions.first;

  int get fromOrderInLevel => sessions.first.orderInLevel;

  /// The last session discharged. THE advancement key: the student's next
  /// meeting begins at `toOrderInLevel + 1`.
  int get toOrderInLevel => sessions.last.orderInLevel;

  List<String> get coversSessionIds =>
      sessions.map((session) => session.id).toList();

  /// Whether this meeting covers more than one session — i.e. whether its
  /// content was composed rather than read verbatim.
  bool get isBatched => sessions.length > 1;

  @override
  String toString() =>
      'PacedSession($fromOrderInLevel..$toOrderInLevel, '
      '${sessions.length} session(s))';
}

/// Composes a [PacedSession] from the curriculum.
///
/// The rules, and why:
///
/// - **Only lessons batch.** A تلقين, a سرد and an اختبار each always stand
///   alone. An assessment is a gate, and its scope was always the whole unit or
///   juz — pace does not touch it.
///
/// - **A meeting of one session is NOT composed.** Its blocks are the row's own,
///   verbatim. The source curriculum has ~8 rows that disagree with its own
///   window rule (surah-name typos, ±1 verse drift, duplicated rows), so
///   composing at pace 1 would silently rewrite what every ordinary student
///   sees. The guarantee that a 1x student is untouched is structural: this code
///   does not run for them.
///
/// - **Distant review concatenates.** It is a cursor sweeping non-overlapping
///   chunks of already-memorized Qur'an, independent of what is taught today, so
///   two rows' distant blocks simply add up.
///
/// - **Recent review does NOT concatenate.** It is a sliding window over the
///   previous two sessions' new content, so two rows' recent blocks overlap each
///   other AND reach into content this meeting is itself teaching. The window is
///   therefore recomputed: the new content of the previous 2N sessions.
class PacedSessionComposer {
  const PacedSessionComposer._();

  static PacedSession compose({
    required List<SessionModel> levelSessions,
    required int startOrderInLevel,
    required CurriculumPace pace,
  }) {
    final byOrder = {
      for (final session in levelSessions) session.orderInLevel: session,
    };

    final start = byOrder[startOrderInLevel];
    if (start == null) {
      throw ArgumentError.value(
        startOrderInLevel,
        'startOrderInLevel',
        'No session stands at this order in the level',
      );
    }

    final batch = _batch(byOrder, start, pace);

    // A meeting of one is the curriculum as authored. Do not compose it.
    if (batch.length == 1) {
      return PacedSession(
        sessions: batch,
        newContent: _blocks([start.currentLevelContent]),
        recentReview: _blocks([start.recentReviewContent]),
        distantReview: _blocks([start.distantReviewContent]),
      );
    }

    final newContent = _blocks(
      batch.map((session) => session.currentLevelContent),
    );

    return PacedSession(
      sessions: batch,
      newContent: newContent,
      recentReview: _recentWindow(
        byOrder: byOrder,
        startOrderInLevel: startOrderInLevel,
        pace: pace,
        taughtToday: newContent,
      ),
      distantReview: _blocks(
        batch.map((session) => session.distantReviewContent),
      ),
    );
  }

  /// Up to [pace] consecutive LESSONS from [start]. A non-lesson stands alone;
  /// a batch stops before the first session that is not a lesson of the same
  /// level, and before a hole in the data.
  static List<SessionModel> _batch(
    Map<int, SessionModel> byOrder,
    SessionModel start,
    CurriculumPace pace,
  ) {
    if (!start.isLesson) return [start];

    final batch = <SessionModel>[start];
    for (var step = 1; step < pace.multiplier; step++) {
      final next = byOrder[start.orderInLevel + step];
      if (next == null) break;
      if (!next.isLesson) break;
      if (next.levelId != start.levelId) break;
      batch.add(next);
    }
    return batch;
  }

  /// The new content of the previous 2N sessions — the previous two meetings'
  /// worth — with three exclusions:
  ///
  /// 1. sessions carrying no new content (a سرد, an اختبار);
  /// 2. sessions before the تلقين that opens this unit — the window never
  ///    reaches into the previous unit;
  /// 3. sessions whose new content this meeting is ITSELF teaching. This is what
  ///    zeroes the recent block for a unit's first lesson: the تلقين before it
  ///    read out the very passage it teaches, and a student cannot review what
  ///    he is learning today.
  static List<QuranContent> _recentWindow({
    required Map<int, SessionModel> byOrder,
    required int startOrderInLevel,
    required CurriculumPace pace,
    required List<QuranContent> taughtToday,
  }) {
    final windowStart = startOrderInLevel - 2 * pace.multiplier;
    final unitStart = _unitStart(byOrder, startOrderInLevel);
    final from = windowStart < unitStart ? unitStart : windowStart;

    final window = <QuranContent>[];
    for (var order = from; order < startOrderInLevel; order++) {
      final content = byOrder[order]?.currentLevelContent;
      if (content == null) continue;
      if (taughtToday.contains(content)) continue;
      window.add(content);
    }
    return window;
  }

  /// The order of the تلقين that opens the unit containing [orderInLevel], or 1
  /// if the level has none before it (nothing to clamp against).
  static int _unitStart(Map<int, SessionModel> byOrder, int orderInLevel) {
    for (var order = orderInLevel; order >= 1; order--) {
      if (byOrder[order]?.isTalqeen ?? false) return order;
    }
    return 1;
  }

  static List<QuranContent> _blocks(Iterable<QuranContent?> blocks) =>
      blocks.whereType<QuranContent>().toList();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/domain/curriculum/paced_session_test.dart`
Expected: PASS, 12 tests.

Then run the existing session-model suite to confirm adding `==` to `QuranContent` broke nothing:

Run: `flutter test test/unit/data/models/session_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

```bash
dart analyze lib/domain/curriculum/paced_session.dart lib/data/models/session_model.dart
git add lib/domain/curriculum/paced_session.dart lib/data/models/session_model.dart test/unit/domain/curriculum/paced_session_test.dart
git commit -m "feat(curriculum): compose an N-lesson meeting from the curriculum

Distant review concatenates — it is a cursor over non-overlapping chunks.
Recent review does NOT: it is a sliding window, so two rows' blocks overlap
and reach into content the meeting is itself teaching. It is recomputed as
the new content of the previous 2N sessions, clamped at the unit's تلقين.

A meeting of one session is read verbatim, never composed: ~8 source rows
disagree with the source's own window rule, so composing at pace 1 would
rewrite what ordinary students see.

Refs: al_rasikhoon-g63"
```

---

### Task 3: Prove pace 1 is untouched, against the real curriculum

**Files:**
- Create: `test/unit/domain/curriculum/paced_session_real_curriculum_test.dart`

**Interfaces:**
- Consumes: `PacedSessionComposer`, `CurriculumPace`, `SessionModel.fromJson`.
- Produces: nothing. This is the safety net for the whole feature.

This task is test-only and has no production code. It is what licenses the claim that no existing student is affected — it walks all 952 sessions of the real curriculum, not fixtures.

- [ ] **Step 1: Write the test**

Create `test/unit/domain/curriculum/paced_session_real_curriculum_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

/// The curriculum as it ships, read from `data/curriculum/` — not fixtures.
///
/// Fixtures cannot prove this: the claim is about the REAL 952 sessions, whose
/// source data is known to contain ~8 rows that disagree with its own window
/// rule (see al_rasikhoon-drw). Those rows are exactly the ones that would break
/// if pace 1 ever started composing.
List<SessionModel> _sessionsOfLevel(int level) {
  final file = File('data/curriculum/sessions_level_$level.json');
  final decoded = jsonDecode(file.readAsStringSync());
  final rows = decoded is Map<String, dynamic>
      ? (decoded['sessions'] as List)
      : (decoded as List);

  return rows.map((row) {
    final json = Map<String, dynamic>.from(row as Map);
    final id =
        'L${json['level_id']}_J${json['juz_number']}_S${json['session_number']}';
    return SessionModel.fromJson(id, json);
  }).toList();
}

void main() {
  final levels = [for (var level = 1; level <= 10; level++) level];

  group('the standard pace leaves the curriculum exactly as authored', () {
    for (final level in levels) {
      test('level $level: every session composes to its own blocks', () {
        final sessions = _sessionsOfLevel(level);
        expect(sessions, isNotEmpty, reason: 'level $level has no sessions');

        for (final session in sessions) {
          final meeting = PacedSessionComposer.compose(
            levelSessions: sessions,
            startOrderInLevel: session.orderInLevel,
            pace: CurriculumPace.standard,
          );

          expect(
            meeting.coversSessionIds,
            [session.id],
            reason: '${session.id} must stand alone at the standard pace',
          );
          expect(
            meeting.newContent,
            session.currentLevelContent == null
                ? isEmpty
                : [session.currentLevelContent],
            reason: '${session.id} new content was rewritten',
          );
          expect(
            meeting.recentReview,
            session.recentReviewContent == null
                ? isEmpty
                : [session.recentReviewContent],
            reason: '${session.id} recent review was rewritten',
          );
          expect(
            meeting.distantReview,
            session.distantReviewContent == null
                ? isEmpty
                : [session.distantReviewContent],
            reason: '${session.id} distant review was rewritten',
          );
        }
      });
    }
  });

  group('a doubled student never reviews what he is learning today', () {
    for (final level in levels) {
      test('level $level: recent review never intersects new content', () {
        final sessions = _sessionsOfLevel(level);

        for (final session in sessions) {
          final meeting = PacedSessionComposer.compose(
            levelSessions: sessions,
            startOrderInLevel: session.orderInLevel,
            pace: CurriculumPace(2),
          );

          for (final taught in meeting.newContent) {
            expect(
              meeting.recentReview,
              isNot(contains(taught)),
              reason:
                  'a 2x meeting at ${session.id} asks the student to review '
                  '${taught.rangeAr}, which it is teaching him today',
            );
          }
        }
      });
    }
  });

  group('an assessment is never swallowed by a fast student', () {
    for (final level in levels) {
      test('level $level: no batch contains a سرد, an اختبار or a تلقين', () {
        final sessions = _sessionsOfLevel(level);

        for (final session in sessions) {
          for (final multiplier in [2, 3, 5]) {
            final meeting = PacedSessionComposer.compose(
              levelSessions: sessions,
              startOrderInLevel: session.orderInLevel,
              pace: CurriculumPace(multiplier),
            );

            if (meeting.isBatched) {
              expect(
                meeting.sessions.every((s) => s.isLesson),
                isTrue,
                reason:
                    'a ${multiplier}x meeting at ${session.id} batched a '
                    'session that is not a lesson',
              );
            } else {
              expect(meeting.coversSessionIds, [session.id]);
            }
          }
        }
      });
    }
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/unit/domain/curriculum/paced_session_real_curriculum_test.dart`
Expected: PASS, 30 tests.

If `File('data/curriculum/...')` does not resolve, the test's working directory is the package root — confirm with `flutter test` run from `al_rasikhoon/`. Do not copy the curriculum into `test/`: the point is to read what ships.

**If the first group FAILS, STOP.** It means pace 1 is not passing authored blocks through verbatim, and the whole no-regression guarantee is void. Fix `PacedSessionComposer` before continuing; do not weaken the test.

- [ ] **Step 3: Commit**

```bash
git add test/unit/domain/curriculum/paced_session_real_curriculum_test.dart
git commit -m "test(curriculum): prove pace 1 leaves all 952 real sessions untouched

Walks data/curriculum/*.json, not fixtures — the ~8 rows whose source data
disagrees with its own window rule are exactly the ones that would break if
pace 1 ever started composing.

Also pins, across the real curriculum: a 2x meeting never asks a student to
review what it is teaching him today, and no batch ever swallows a تلقين,
a سرد or an اختبار.

Refs: al_rasikhoon-g63"
```

---

### Task 4: Persist the pace on the student

**Files:**
- Modify: `lib/data/models/student_model.dart`
- Modify: `lib/data/repositories/student_repository.dart`
- Test: `test/unit/data/models/student_model_test.dart` (create if absent)

**Interfaces:**
- Consumes: `CurriculumPace` (Task 1).
- Produces:
  - `StudentModel.pace` → `CurriculumPace`, defaulting to `CurriculumPace.standard`. Firestore key `pace`.
  - `StudentModel.copyWith({CurriculumPace? pace, ...})` — extend the existing signature.
  - `StudentRepository.setStudentPace(String studentId, CurriculumPace pace)` → `Future<void>`.

- [ ] **Step 1: Write the failing test**

Add to `test/unit/data/models/student_model_test.dart` (create the file with the standard header if it does not exist — check first with `ls test/unit/data/models/`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';

void main() {
  group('a student carries the pace the teacher set for them', () {
    test('a student created before paced curricula runs at the standard pace', () {
      final student = StudentModel.fromJson('s1', {
        'user_id': 'u1',
        'institute_id': 'i1',
        'created_at': null,
      });

      expect(student.pace, CurriculumPace.standard);
    });

    test('a doubled student reads back doubled', () {
      final student = StudentModel.fromJson('s1', {
        'user_id': 'u1',
        'institute_id': 'i1',
        'pace': 2,
        'created_at': null,
      });

      expect(student.pace, CurriculumPace(2));
      expect(student.toFirestore()['pace'], 2);
    });
  });
}
```

`StudentModel` may not have a `fromJson(id, map)` constructor — it has `fromFirestore(DocumentSnapshot)`. Check `lib/data/models/student_model.dart` first. If only `fromFirestore` exists, either extract a `fromJson` (preferred — it is what makes the model testable without Firestore, and `SessionModel` already does exactly this) or write the test against `FakeFirebaseFirestore`, following `test/unit/data/models/session_model_test.dart`. Extracting `fromJson` is the better change and is in scope.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/models/student_model_test.dart`
Expected: FAIL — `pace` is not defined.

- [ ] **Step 3: Write the implementation**

In `lib/data/models/student_model.dart`:

Import the pace, add the field with its doc comment, wire it through the constructor, `fromFirestore`/`fromJson`, `toFirestore`, and `copyWith`:

```dart
import '../../domain/curriculum/curriculum_pace.dart';

  /// How many lessons this student covers in one meeting.
  ///
  /// The curriculum is authored for the average student — one meeting, one
  /// session. A student who memorizes quickly can be run at N×, set by their
  /// teacher or supervisor, changeable mid-level.
  ///
  /// The student stores where a meeting STARTS, never how far it extends: the
  /// extent is derived from this pace at read time, which is what lets a pace
  /// change take effect immediately with nothing to migrate.
  final CurriculumPace pace;
```

Constructor: `this.pace = CurriculumPace.standard,` — note `CurriculumPace.standard` is `static final`, not `const`, so the constructor cannot stay `const`. If `StudentModel`'s constructor is `const`, drop `const` from it and fix the resulting analyzer errors at its call sites (`dart analyze` will list them).

`fromJson`/`fromFirestore`: `pace: CurriculumPace.fromJson(data['pace']),`
`toFirestore`: `'pace': pace.toJson(),`
`copyWith`: add `CurriculumPace? pace,` and `pace: pace ?? this.pace,`.

In `lib/data/repositories/student_repository.dart`, add:

```dart
  /// Sets how many lessons the student covers in one meeting.
  ///
  /// Takes effect on the student's very next meeting: the pending meeting's
  /// extent is derived from this pace, not stored, so there is nothing to
  /// migrate and no position to fix up. Records already written keep the pace
  /// they were recorded at.
  Future<void> setStudentPace(String studentId, CurriculumPace pace) async {
    await _studentsCollection.doc(studentId).update({
      'pace': pace.toJson(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
```

Import `CurriculumPace` there.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/data/models/student_model_test.dart test/unit/data/repositories/`
Expected: PASS. The repository suite must stay green — `updateStudent` strips `current_*` keys but not `pace`, which is correct: pace is not a position.

- [ ] **Step 5: Analyze and commit**

```bash
dart analyze lib/data/models/student_model.dart lib/data/repositories/student_repository.dart
git add lib/data/models/student_model.dart lib/data/repositories/student_repository.dart test/unit/data/models/student_model_test.dart
git commit -m "feat(student): carry the curriculum pace on the student

A student stores where a meeting starts, never how far it extends — the
extent is derived from the pace at read time, so a mid-level pace change
takes effect on the next meeting with nothing to migrate.

Refs: al_rasikhoon-g63"
```

---

### Task 5: Read a whole level's sessions

**Files:**
- Modify: `lib/data/repositories/curriculum_repository.dart`
- Test: `test/unit/data/repositories/curriculum_repository_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `CurriculumRepository.getSessionsForLevel({required int level})` → `Future<List<SessionModel>>`, ordered by `order_in_level` ascending.

Composition needs the level's sessions, not one document. `getSessionsForJuz` is the closest existing method — mirror it exactly.

- [ ] **Step 1: Write the failing test**

Add to `test/unit/data/repositories/curriculum_repository_test.dart`, inside the existing top-level `group`. Read the file first to match its `setUp` and its use of `seedSession` from `curriculum_fixtures.dart`.

```dart
    test('a level yields every one of its sessions, in teaching order', () async {
      // Level 1 runs juz 30 → 29. Ordering by juz would put 29 first; ordering
      // by order_in_level is the only rule that gets the teaching order right.
      await seedSession(firestore, level: 1, juz: 29, session: 1, order: 3);
      await seedSession(firestore, level: 1, juz: 30, session: 1, order: 1);
      await seedSession(firestore, level: 1, juz: 30, session: 2, order: 2);
      await seedSession(firestore, level: 2, juz: 27, session: 1, order: 1);

      final sessions = await repository.getSessionsForLevel(level: 1);

      expect(sessions.map((s) => s.orderInLevel), [1, 2, 3]);
      expect(sessions.map((s) => s.id), [
        'L1_J30_S1',
        'L1_J30_S2',
        'L1_J29_S1',
      ]);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/repositories/curriculum_repository_test.dart`
Expected: FAIL — `getSessionsForLevel` is not defined.

- [ ] **Step 3: Write the implementation**

In `lib/data/repositories/curriculum_repository.dart`, beneath `getSessionsForJuz`:

```dart
  /// Every session of [level], ordered by `order_in_level` — the level's
  /// teaching order, juz boundaries included.
  ///
  /// This is what a paced meeting is composed from: the composer needs the
  /// sessions AROUND the student's position (the batch ahead of it, the recent
  /// window behind it), and only the level holds all of them. Ordering by juz
  /// would be wrong in both directions — levels 1-9 descend, level 10 ascends.
  Future<List<SessionModel>> getSessionsForLevel({required int level}) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: level)
        .orderBy('order_in_level')
        .get();

    return query.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/data/repositories/curriculum_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

```bash
dart analyze lib/data/repositories/curriculum_repository.dart
git add lib/data/repositories/curriculum_repository.dart test/unit/data/repositories/curriculum_repository_test.dart
git commit -m "feat(curriculum): read a whole level's sessions in teaching order

A paced meeting is composed from the sessions around the student's position,
and only the level holds all of them.

Refs: al_rasikhoon-g63"
```

---

### Task 6: A session record spans the meeting

**Files:**
- Modify: `lib/data/models/session_record_model.dart`
- Modify: `lib/data/repositories/session_repository.dart`
- Test: `test/unit/data/models/session_record_model_test.dart` (create if absent)
- Test: `test/unit/data/repositories/session_repository_test.dart`

**Interfaces:**
- Consumes: `PacedSession` (Task 2).
- Produces on `SessionRecordModel`:
  - `int fromOrderInLevel`
  - `int toOrderInLevel` — **replaces `orderInLevel`**; the advancement key.
  - `List<String> coversSessionIds`
  - `int paceAtTime`
  - `bool get isBatched` → `coversSessionIds.length > 1`
  - Firestore keys: `from_order_in_level`, `to_order_in_level`, `covers_session_ids`, `pace_at_time`.
- Produces on `SessionRepository`: `createSessionRecord` and `createTalqeenRecord` each take `required PacedSession meeting` in place of `curriculumSessionId`, `sessionNumber` and `orderInLevel`.

**Backward compatibility — non-negotiable.** Every record written before this feature has `order_in_level` and no span. On read:

```
to_order_in_level   ← data['to_order_in_level']   ?? data['order_in_level'] ?? 1
from_order_in_level ← data['from_order_in_level'] ?? to_order_in_level
covers_session_ids  ← data['covers_session_ids']  ?? [curriculum_session_id]
pace_at_time        ← data['pace_at_time']        ?? 1
```

Every existing record must therefore read back as a single-session, pace-1 meeting. `getLatestSessionRecord` orders on `order_in_level`; that must become `to_order_in_level`, and **the tie-break rationale in its doc comment still holds** — a later meeting always carries a strictly greater `to_order_in_level` within a level. Keep writing `order_in_level` alongside `to_order_in_level` (same value) so old records and new sort together in that query, and note in the doc comment that it is a compatibility mirror. Check `firestore.indexes.json` for a composite index on `(student_id, date, order_in_level)` — if one exists, add the `to_order_in_level` variant.

- [ ] **Step 1: Write the failing test**

In `test/unit/data/models/session_record_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';

void main() {
  group('a record spans the meeting it recorded', () {
    test('a record written before paced curricula is a one-session meeting', () {
      final record = SessionRecordModel.fromJson('r1', {
        'student_id': 's1',
        'teacher_id': 't1',
        'curriculum_session_id': 'L1_J30_S5',
        'level_id': 1,
        'session_number': 5,
        'order_in_level': 5,
        'attempt_number': 1,
        'passed': true,
      });

      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 5);
      expect(record.coversSessionIds, ['L1_J30_S5']);
      expect(record.paceAtTime, 1);
      expect(record.isBatched, isFalse);
    });

    test('a doubled meeting records both sessions it discharged', () {
      final record = SessionRecordModel.fromJson('r1', {
        'student_id': 's1',
        'teacher_id': 't1',
        'curriculum_session_id': 'L1_J30_S6',
        'level_id': 1,
        'session_number': 6,
        'from_order_in_level': 5,
        'to_order_in_level': 6,
        'covers_session_ids': ['L1_J30_S5', 'L1_J30_S6'],
        'pace_at_time': 2,
        'attempt_number': 1,
        'passed': true,
      });

      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 6);
      expect(record.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(record.paceAtTime, 2);
      expect(record.isBatched, isTrue);
    });

    test('a record keeps the pace it was recorded at, not the student\'s current one', () {
      // The student may be moved back to 1x tomorrow. History must not be
      // rewritten: this meeting really did cover two sessions.
      final record = SessionRecordModel.fromJson('r1', {
        'student_id': 's1',
        'teacher_id': 't1',
        'curriculum_session_id': 'L1_J30_S6',
        'level_id': 1,
        'session_number': 6,
        'from_order_in_level': 5,
        'to_order_in_level': 6,
        'covers_session_ids': ['L1_J30_S5', 'L1_J30_S6'],
        'pace_at_time': 2,
        'attempt_number': 1,
        'passed': true,
      });

      expect(record.toFirestore()['pace_at_time'], 2);
      // The compatibility mirror: old readers and the ordering query both
      // depend on order_in_level, which must equal the meeting's LAST session.
      expect(record.toFirestore()['order_in_level'], 6);
      expect(record.toFirestore()['to_order_in_level'], 6);
    });
  });
}
```

`SessionRecordModel` may have only `fromFirestore`. If so, extract `fromJson(String id, Map<String, dynamic> json)` and have `fromFirestore` delegate, exactly as `SessionModel` does. That extraction is in scope.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/models/session_record_model_test.dart`
Expected: FAIL — `fromOrderInLevel` is not defined.

- [ ] **Step 3: Write the implementation**

In `lib/data/models/session_record_model.dart`, replace the `orderInLevel` field with the span. Keep the existing doc comment's reasoning and extend it:

```dart
  /// The first session this meeting discharged.
  final int fromOrderInLevel;

  /// The LAST session this meeting discharged, and THE advancement key: the
  /// student's next meeting begins at `toOrderInLevel + 1`.
  ///
  /// Copied verbatim from the curriculum, never recomputed from
  /// [sessionNumber]. It is the only thing that orders session records within a
  /// level: juz numbers cannot (level 10 teaches juz 1 → 2 → 3), and
  /// [date]/[createdAt] cannot either, since both come from the same
  /// `DateTime.now()` at write time and can tie. This can: a later meeting
  /// always carries a strictly greater [toOrderInLevel] within a level.
  final int toOrderInLevel;

  /// Every curriculum session this ONE recitation discharged. A student at 2x
  /// recites two sessions' content in one sitting and is graded once — writing
  /// two records would fabricate an observation that never happened.
  final List<String> coversSessionIds;

  /// The pace in force when this was recorded. History must not be rewritten
  /// when the student's pace later changes.
  final int paceAtTime;

  bool get isBatched => coversSessionIds.length > 1;
```

`fromJson` — the compatibility reads spelled out above. `toFirestore` writes `from_order_in_level`, `to_order_in_level`, `covers_session_ids`, `pace_at_time`, **and** `order_in_level: toOrderInLevel` as the compatibility mirror.

In `lib/data/repositories/session_repository.dart`, change both factories to take the meeting. `createSessionRecord`:

```dart
  Future<SessionRecordModel> createSessionRecord({
    required String studentId,
    required String teacherId,
    required PacedSession meeting,
    required int levelId,
    int? hizbNumber,
    required int attemptNumber,
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
    String? notes,
    DateTime? now,
  }) {
    final grades = SessionGrades(
      newMemorizationErrors: newMemorizationErrors,
      recentReviewErrors: recentReviewErrors,
      distantReviewErrors: distantReviewErrors,
    );

    final passed = grades.passesForLevel(levelId);

    return _writeSessionRecord(
      (id, writtenAt) => SessionRecordModel(
        id: id,
        studentId: studentId,
        teacherId: teacherId,
        // The record NAMES the last session it discharged, so that a reader
        // that knows nothing of pace still lands on the right point in the
        // curriculum.
        curriculumSessionId: meeting.sessions.last.id,
        levelId: levelId,
        hizbNumber: hizbNumber,
        sessionNumber: meeting.sessions.last.sessionNumber,
        fromOrderInLevel: meeting.fromOrderInLevel,
        toOrderInLevel: meeting.toOrderInLevel,
        coversSessionIds: meeting.coversSessionIds,
        paceAtTime: meeting.sessions.length,
        date: writtenAt,
        attemptNumber: attemptNumber,
        grades: grades,
        passed: passed,
        repetitionsWithTeacher: repetitionsWithTeacher,
        homeRepetitionsRequired: homeRepetitionsRequired,
        notes: notes,
        createdAt: writtenAt,
      ),
      now: now,
    );
  }
```

Apply the same substitution to `createTalqeenRecord` (a تلقين always stands alone, so its meeting has one session — the shape still holds and needs no special case).

Update `getLatestSessionRecord`'s `orderBy('order_in_level', descending: true)` — leave it as-is. It reads the compatibility mirror, which new records also write, so it keeps working for old and new records alike. Add a line to its doc comment saying so.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/data/models/ test/unit/data/repositories/`
Expected: PASS. Call sites in `teacher_provider.dart` will not compile yet — that is Task 7. If `dart analyze` errors there, that is expected; the *tests* above must still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/session_record_model.dart lib/data/repositories/session_repository.dart test/unit/data/models/session_record_model_test.dart test/unit/data/repositories/session_repository_test.dart
git commit -m "feat(sessions): a session record spans the meeting it recorded

One recitation, one grade, one record — a 2x student who recites two
sessions' content in one sitting is graded once. Writing two records would
fabricate an observation that never happened and make attemptNumber lie.

Records written before this read back as single-session pace-1 meetings, and
order_in_level is still written as a mirror of to_order_in_level so old and
new records sort together.

Refs: al_rasikhoon-g63"
```

---

### Task 7: Teach a paced meeting

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart`
- Modify: `lib/data/repositories/student_repository.dart`
- Test: `test/unit/providers/teacher_provider_test.dart` (follow the existing provider tests — check `ls test/unit/providers/`)

**Interfaces:**
- Consumes: `PacedSessionComposer`, `PacedSession`, `CurriculumPace`, `CurriculumRepository.getSessionsForLevel`, the Task-6 record factories.
- Produces:
  - `StudentRepository.advanceStudentSession(String studentId, {int? fromOrderInLevel})` — advances to `fromOrderInLevel + 1`, defaulting to the student's `currentOrderInLevel` (today's behaviour, unchanged).
  - `ActiveSessionState.meeting` → `PacedSession?`, so the teacher's screens can render every block the meeting covers.

- [ ] **Step 1: Write the failing test**

The key behaviours to pin. Follow the existing provider-test setup (`ProviderContainer` with overridden repositories against `FakeFirebaseFirestore`):

```dart
    test('a doubled student\'s meeting discharges two sessions and advances past both', () async {
      // Student at order 5 of level 1, pace 2. Orders 5 and 6 are lessons.
      // One recitation → one record covering both → next meeting starts at 7.
      final record = await notifier.completeSession();

      expect(record!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 6);
      expect(record.paceAtTime, 2);

      final student = await studentRepo.getStudentById('s1');
      expect(student!.currentOrderInLevel, 7);
    });

    test('a doubled student who fails repeats the whole meeting, not half of it', () async {
      // Errors high enough to fail at level 1.
      final record = await notifier.completeSession();

      expect(record!.passed, isFalse);
      final student = await studentRepo.getStudentById('s1');
      expect(student!.currentOrderInLevel, 5, reason: 'he stays on the meeting');
      expect(student.currentAttempt, 2);
    });

    test('a standard student is completely unaffected', () async {
      final record = await notifier.completeSession();

      expect(record!.coversSessionIds, ['L1_J30_S5']);
      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 5);
      expect(record.paceAtTime, 1);

      final student = await studentRepo.getStudentById('s1');
      expect(student!.currentOrderInLevel, 6);
    });

    test('a doubled student still meets the سرد alone', () async {
      // Student at order 6; order 7 is the سرد. The batch takes only order 6.
      final record = await notifier.completeSession();

      expect(record!.coversSessionIds, ['L1_J30_S6']);
      final student = await studentRepo.getStudentById('s1');
      expect(student!.currentOrderInLevel, 7, reason: 'he lands ON the سرد');
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/providers/teacher_provider_test.dart`
Expected: FAIL — compile error; `completeSession` does not compose a meeting.

- [ ] **Step 3: Write the implementation**

In `lib/data/repositories/student_repository.dart`, generalize the advance. The whole change is to thread a start order through:

```dart
  /// Advance the student past the meeting that ends at [fromOrderInLevel].
  ///
  /// Defaults to the session the student stands on — a standard-pace meeting
  /// covers exactly that one. A paced meeting covers N, so its caller passes the
  /// LAST order it discharged and the student lands on the one after it.
  Future<StudentAdvanceOutcome> advanceStudentSession(
    String studentId, {
    int? fromOrderInLevel,
  }) async {
    final student = await getStudentById(studentId);
    if (student == null) return StudentAdvanceOutcome.studentNotFound;

    final from = fromOrderInLevel ?? student.currentOrderInLevel;
    final outcome = await _nextSession(student, from);
    // ... rest unchanged
  }
```

and in `_nextSession(StudentModel student, int fromOrderInLevel)`, replace both uses of `student.currentOrderInLevel` with `fromOrderInLevel` — the `getSessionByOrderInLevel(orderInLevel: fromOrderInLevel + 1)` lookup and the data-hole check `fromOrderInLevel < catalog.sessionCount`. Nothing else in that method changes.

In `lib/features/teacher/providers/teacher_provider.dart`, compose the meeting before writing the record. In `completeSession`:

```dart
    final curriculumRepo = ref.read(curriculumRepositoryProvider);
    final levelSessions = await curriculumRepo.getSessionsForLevel(
      level: student.currentLevel,
    );

    final meeting = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: student.currentOrderInLevel,
      pace: student.pace,
    );

    final record = await sessionRepo.createSessionRecord(
      studentId: student.id,
      teacherId: currentUser.id,
      meeting: meeting,
      levelId: student.currentLevel,
      hizbNumber: student.currentHizb,
      attemptNumber: student.currentAttempt,
      newMemorizationErrors: state!.part1Errors,
      recentReviewErrors: state!.part2Errors,
      distantReviewErrors: state!.part3Errors,
      repetitionsWithTeacher: state!.repetitionsWithTeacher,
      homeRepetitionsRequired: state!.homeRepetitionsRequired,
      notes: state!.notes,
    );

    StudentAdvanceOutcome? advanceOutcome;
    if (record.passed) {
      // Past the whole meeting — a 2x student who passes has discharged two
      // sessions and must not land back on the second of them.
      advanceOutcome = await studentRepo.advanceStudentSession(
        student.id,
        fromOrderInLevel: meeting.toOrderInLevel,
      );
    } else {
      // He repeats the MEETING, not half of it: his position is unchanged, so
      // the next composition rebuilds the same batch.
      await studentRepo.incrementStudentAttempt(student.id);
    }
```

Apply the same composition to `completeTalqeenSession` — a تلقين always composes to itself, so `meeting.toOrderInLevel == student.currentOrderInLevel` and its advance is unchanged in effect, but it must go through the same path so the record carries a span.

Store the meeting on the session state so the screens can render it: add `final PacedSession? meeting;` to `ActiveSessionState` with its `copyWith`, and set it when the session starts.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test`
Expected: PASS — the whole suite. This task makes the app compile again after Task 6.

- [ ] **Step 5: Analyze and commit**

```bash
dart analyze
git add -A
git commit -m "feat(teacher): teach a paced meeting — N lessons, one grade, one advance

The meeting is composed from the student's live pace at read time, so a pace
change lands on the next meeting with nothing to migrate. A student who
passes advances past every session the meeting discharged; one who fails
repeats the whole meeting, not half of it.

Refs: al_rasikhoon-g63"
```

---

### Task 8: The meeting a student stands on — providers and display

**Files:**
- Modify: `lib/domain/curriculum/paced_session.dart` (display getters)
- Modify: `lib/features/teacher/providers/teacher_provider.dart` (`studentCurrentMeetingProvider`)
- Modify: `lib/features/supervisor/providers/supervisor_provider.dart` (`supervisorStudentCurrentMeetingProvider`)
- Modify: `lib/features/student/providers/student_provider.dart` (`studentDashboardMeetingProvider`)
- Test: `test/unit/providers/student_meeting_provider_test.dart` (create)

**Interfaces:**
- Consumes: `PacedSessionComposer`, `CurriculumPace`, `CurriculumRepository.getSessionsForLevel` (Task 5), `StudentModel.pace` (Task 4).
- Produces:
  - On `PacedSession`: `String get newContentAr`, `String get recentReviewAr`, `String get distantReviewAr`, `bool get hasNewContent`, `bool get hasRecentReview`, `bool get hasDistantReview`.
  - `studentCurrentMeetingProvider` → `FutureProvider.family<PacedSession?, String>` (teacher scope).
  - `supervisorStudentCurrentMeetingProvider` → `FutureProvider.family<PacedSession?, String>` (institute scope).
  - `studentDashboardMeetingProvider` → `FutureProvider<PacedSession?>` (the signed-in student).

The screens render **strings** today (`session.currentLevelContent?.rangeAr ?? ''`). Giving `PacedSession` the same string-shaped API means each screen changes by one line and no layout is touched. That is the whole point of this task: make Task 9 a mechanical substitution.

The three existing providers — `studentCurrentSessionProvider` (teacher), `supervisorStudentCurrentSessionProvider` (institute-scoped, AgDR-0003), `studentDashboardSessionProvider` (the student themself) — each resolve a student and return `getSessionById(student.currentSessionId)`. Each gains a **meeting** twin that composes instead. Do NOT delete the session providers: `starting_point_picker` and the admin curriculum screens legitimately want the authored row, not a student's meeting.

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/student_meeting_provider_test.dart`. Follow `test/unit/providers/teacher_provider_test.dart` for the `ProviderContainer` + `FakeFirebaseFirestore` setup, and seed the curriculum with `seedSession` from `test/unit/data/repositories/curriculum_fixtures.dart`.

```dart
    test('a standard student\'s meeting is the single session he stands on', () async {
      // Student at order 5 of level 1, no pace stored.
      final meeting = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );

      expect(meeting!.coversSessionIds, ['L1_J30_S5']);
      expect(meeting.isBatched, isFalse);
    });

    test('a doubled student\'s meeting covers the next two lessons', () async {
      // Same student, pace 2.
      final meeting = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );

      expect(meeting!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(meeting.toOrderInLevel, 6);
    });

    test('changing the pace mid-level recomposes the pending meeting', () async {
      // The student stores where a meeting STARTS, never how far it extends.
      // A pace change must therefore need no migration and no position fix-up:
      // the very next read widens the meeting.
      final before = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );
      expect(before!.coversSessionIds, ['L1_J30_S5']);

      await studentRepo.setStudentPace('s1', CurriculumPace(2));
      container.invalidate(studentProvider('s1'));

      final after = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );
      expect(after!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(after.fromOrderInLevel, 5, reason: 'he did not move');
    });

    test('a meeting renders its passages as one line per stream', () async {
      final meeting = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );

      expect(meeting!.newContentAr, 'النبأ: 31 - 37 • النبأ: 38 - 40');
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/providers/student_meeting_provider_test.dart`
Expected: FAIL — `studentCurrentMeetingProvider` is not defined.

- [ ] **Step 3: Write the implementation**

Add the display getters to `lib/domain/curriculum/paced_session.dart`:

```dart
  /// The passages of this stream on one line — what a screen shows where it used
  /// to show a single range. A standard meeting has exactly one, so its line is
  /// byte-identical to what the screen rendered before paced curricula.
  static String _line(List<QuranContent> blocks) =>
      blocks.map((block) => block.rangeAr).join(' • ');

  String get newContentAr => _line(newContent);
  String get recentReviewAr => _line(recentReview);
  String get distantReviewAr => _line(distantReview);

  bool get hasNewContent => newContent.isNotEmpty;
  bool get hasRecentReview => recentReview.isNotEmpty;
  bool get hasDistantReview => distantReview.isNotEmpty;
```

In `lib/features/teacher/providers/teacher_provider.dart`, beneath `studentCurrentSessionProvider`:

```dart
/// The MEETING the student stands on: the N curriculum sessions their pace
/// covers, and the three content streams composed from them.
///
/// This is what every screen that teaches or reports on a student must read.
/// [studentCurrentSessionProvider] returns the single authored row and remains
/// correct for anything that browses the CURRICULUM (the starting-point picker,
/// the admin level detail) — but a student at 2x does not meet a row, he meets a
/// meeting.
///
/// The meeting is composed on every read from the student's LIVE pace. Nothing
/// about its extent is stored, which is exactly why a teacher can change a
/// student's pace mid-level and have it land on the next meeting with nothing to
/// migrate.
final studentCurrentMeetingProvider =
    FutureProvider.family<PacedSession?, String>((ref, studentId) async {
      final studentAsync = await ref.watch(studentProvider(studentId).future);
      if (studentAsync == null) return null;

      final student = studentAsync.student;
      final curriculumRepo = ref.watch(curriculumRepositoryProvider);

      final levelSessions = await curriculumRepo.getSessionsForLevel(
        level: student.currentLevel,
      );
      if (levelSessions.isEmpty) return null;

      return PacedSessionComposer.compose(
        levelSessions: levelSessions,
        startOrderInLevel: student.currentOrderInLevel,
        pace: student.pace,
      );
    });
```

The three providers differ ONLY in which provider resolves the student. Do not
triplicate the composition — put it in one place. In
`lib/features/teacher/providers/teacher_provider.dart`, above the provider:

```dart
/// Composes the meeting [student] currently stands on.
///
/// Shared by the teacher, supervisor and student-dashboard meeting providers,
/// which differ only in how they RESOLVE the student (teacher-scoped,
/// institute-scoped per AgDR-0003, or the signed-in student). The composition
/// itself is one rule and lives in one place.
Future<PacedSession?> composeMeetingFor(Ref ref, StudentModel student) async {
  final curriculumRepo = ref.watch(curriculumRepositoryProvider);

  final levelSessions = await curriculumRepo.getSessionsForLevel(
    level: student.currentLevel,
  );
  if (levelSessions.isEmpty) return null;

  return PacedSessionComposer.compose(
    levelSessions: levelSessions,
    startOrderInLevel: student.currentOrderInLevel,
    pace: student.pace,
  );
}
```

`studentCurrentMeetingProvider` then reduces to resolving the student and calling
it. Add the two twins the same way:

- `supervisorStudentCurrentMeetingProvider` in
  `lib/features/supervisor/providers/supervisor_provider.dart`, resolving via
  `supervisorStudentProvider` (institute-scoped, AgDR-0003 — a supervisor-created
  student has a null `teacher_id`, and the teacher-scoped provider would return
  "Student not found").
- `studentDashboardMeetingProvider` in
  `lib/features/student/providers/student_provider.dart`, a plain
  `FutureProvider<PacedSession?>` resolving via `currentStudentProvider`.

Each is then three lines: resolve the student, return null if absent, and
`return composeMeetingFor(ref, student)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/providers/`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

```bash
dart analyze lib/domain/curriculum/paced_session.dart lib/features/teacher/providers/teacher_provider.dart lib/features/supervisor/providers/supervisor_provider.dart lib/features/student/providers/student_provider.dart
git add -A
git commit -m "feat(curriculum): expose the meeting a student stands on

Three providers mirroring the three current-session providers — teacher,
institute-scoped supervisor, and the student themself. The meeting is
composed on every read from the live pace, so a mid-level pace change lands
on the next meeting with nothing to migrate.

The session providers stay: anything browsing the CURRICULUM (the
starting-point picker, the admin level detail) still wants the authored row.

Refs: al_rasikhoon-g63"
```

---

### Task 9: Every screen that teaches shows the whole meeting

**Files:**
- Modify: `lib/features/teacher/screens/recitation_screen.dart:74-80`
- Modify: `lib/features/teacher/screens/new_memorization_screen.dart:35`
- Modify: `lib/features/teacher/screens/session_overview_screen.dart:266-280,369`
- Modify: `lib/features/teacher/screens/talqeen_session_screen.dart:108`
- Modify: `lib/features/student/screens/student_dashboard_screen.dart:347,477`
- Modify: `lib/features/admin/screens/admin_student_progress_screen.dart:250-262`
- Test: Create `test/widget/paced_meeting_rendering_test.dart`

**Interfaces:**
- Consumes: the meeting providers and `PacedSession`'s display getters (Task 8).
- Produces: no new public API.

**Do NOT touch these** — they render the CURRICULUM, not a student's meeting, and must keep showing the authored row:
- `lib/features/admin/screens/level_detail_screen.dart` (browsing the curriculum catalog)
- `lib/features/teacher/widgets/starting_point_picker.dart` (picking a curriculum position)

Each site is a one-line substitution, because Task 8 gave `PacedSession` a string-shaped API:

| screen | from | to |
|---|---|---|
| `recitation_screen.dart` part 1/2/3 | `session.currentLevelContent?.rangeAr ?? ''` | `meeting.newContentAr` / `.recentReviewAr` / `.distantReviewAr` |
| `new_memorization_screen.dart` | `final content = session.currentLevelContent; if (content == null) …` | `if (!meeting.hasNewContent) …` then `meeting.newContentAr` |
| `session_overview_screen.dart` | the three `content:` args | `meeting.newContentAr` etc. |
| `talqeen_session_screen.dart` | `session.currentLevelContent?.rangeAr ?? ''` | `meeting.newContentAr` |
| `student_dashboard_screen.dart` | same | `meeting.newContentAr` |
| `admin_student_progress_screen.dart` | the three `content:` args | the three getters |

Swap each screen's `ref.watch(studentCurrentSessionProvider(id))` for `ref.watch(studentCurrentMeetingProvider(id))` (or the supervisor / dashboard twin — `session_overview_screen.dart:40` branches on `asSupervisor` and needs both). Where a screen also needs the session's *kind* (the تلقين / سرد / اختبار branch at `session_overview_screen.dart`), read it from `meeting.first` — a batch is all lessons, so the first session's kind is the meeting's kind.

`recitation_screen.dart` keeps its `switch (widget.part)`: parts 1/2/3 still map to new / recent / distant. Only the source of the string changes.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/paced_meeting_rendering_test.dart`, following `test/widget/session_overview_talqeen_branch_test.dart` exactly — same `ProviderScope` override style, same model construction.

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
import 'package:al_rasikhoon/features/teacher/screens/session_overview_screen.dart';

/// A 2x student meets TWO lessons in one sitting. Every screen that teaches him
/// must show both passages — showing only the first would have him memorize half
/// of what he was assigned, silently.
void main() {
  QuranContent content(String surah, int from, int to) => QuranContent(
    fromSurah: surah,
    fromVerse: from,
    toSurah: surah,
    toVerse: to,
  );

  SessionModel lesson(int order, QuranContent newContent) => SessionModel(
    id: 'L1_J30_S$order',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: order,
    orderInLevel: order,
    kind: SessionKind.lesson,
    currentLevelContent: newContent,
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S5',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 5,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, PacedSession meeting) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
        ],
        child: const MaterialApp(
          home: SessionOverviewScreen(studentId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a doubled meeting shows both passages it teaches', (
    tester,
  ) async {
    final doubled = PacedSession(
      sessions: [
        lesson(5, content('النبأ', 31, 37)),
        lesson(6, content('النبأ', 38, 40)),
      ],
      newContent: [content('النبأ', 31, 37), content('النبأ', 38, 40)],
      recentReview: [content('النبأ', 12, 20), content('النبأ', 21, 30)],
      distantReview: const [],
    );

    await pump(tester, doubled);

    expect(find.textContaining('النبأ: 31 - 37'), findsOneWidget);
    expect(find.textContaining('النبأ: 38 - 40'), findsOneWidget);
  });

  testWidgets('a standard meeting shows exactly the one passage, as before', (
    tester,
  ) async {
    final standard = PacedSession(
      sessions: [lesson(5, content('النبأ', 31, 37))],
      newContent: [content('النبأ', 31, 37)],
      recentReview: [content('النبأ', 12, 30)],
      distantReview: const [],
    );

    await pump(tester, standard);

    expect(find.textContaining('النبأ: 31 - 37'), findsOneWidget);
    expect(find.textContaining('النبأ: 38 - 40'), findsNothing);
  });
}
```

`SessionOverviewScreen`'s constructor may take more than `studentId` (it has an `asSupervisor` flag) — read the file and match its actual signature.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/paced_meeting_rendering_test.dart`
Expected: FAIL — `studentCurrentMeetingProvider` is not read by the screen; only one passage renders (or the screen throws on the missing session provider).

- [ ] **Step 3: Make the substitutions**

Work through the table above, one screen at a time. After each, run that screen's existing widget test to confirm nothing regressed:

```bash
flutter test test/widget/session_overview_talqeen_branch_test.dart
flutter test test/widget/talqeen_session_screen_test.dart
flutter test test/widget/student_dashboard_talqeen_branch_test.dart
```

Those existing tests override `studentCurrentSessionProvider`. Once a screen reads the meeting provider instead, they will fail — **update them to override `studentCurrentMeetingProvider` with a single-session `PacedSession`**. That is a correct change, not a weakening: the screens genuinely now consume meetings. Do not leave a screen reading both providers to keep an old test green.

- [ ] **Step 4: Run the full suite**

Run: `flutter test && dart analyze`
Expected: PASS, analyzer clean.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(teacher): show every passage a paced meeting covers

A 2x student meets two lessons in one sitting; showing only the first would
have him memorize half of what he was assigned, silently.

The curriculum-browsing screens (admin level detail, starting-point picker)
keep reading the authored row — they show the curriculum, not a meeting.

Refs: al_rasikhoon-g63"
```

---

### Task 10: Set a student's pace

**Files:**
- Modify: `lib/features/teacher/screens/` — the student detail / edit screen (find it in Step 1)
- Test: `test/widget/student_pace_control_test.dart` (create)

**Interfaces:**
- Consumes: `StudentRepository.setStudentPace` (Task 4), `CurriculumPace` (Task 1).
- Produces: no new public API.

- [ ] **Step 1: Find where a teacher or supervisor already edits a student**

```bash
grep -rn "updateStudent\|repositionStudent\|setStudentPace" lib/features/teacher/ lib/features/supervisor/
```

The pace control belongs beside whatever already edits a student's curriculum standing (the flexible-placement / reposition UI is the natural neighbour — see `al_rasikhoon-i1d`, `al_rasikhoon-sne`). Put it there. If both a teacher screen and a supervisor screen exist, add it to both — the spec says either role may set it.

- [ ] **Step 2: Write the failing widget test**

```dart
  testWidgets('a teacher can double a student\'s pace', (tester) async {
    await pump(tester);

    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();

    verify(() => studentRepo.setStudentPace('s1', CurriculumPace(2))).called(1);
  });

  testWidgets('a student\'s pace shows as 1x when none was ever set', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('1x'), findsOneWidget);
  });
```

Match the existing tests' mocking style — check whether the suite uses `mocktail` (`verify(() => ...)`) or a `FakeFirebaseFirestore` round-trip, and follow it. `grep -rn "mocktail" test/ | head -3`.

- [ ] **Step 3: Run to verify it fails, then implement**

Run: `flutter test test/widget/student_pace_control_test.dart`
Expected: FAIL — no pace control exists.

A segmented control of `1x / 2x / 3x` calling `setStudentPace`, with a one-line explanation in Arabic beneath it (e.g. `عدد الحلقات في اللقاء الواحد`). Keep it minimal: it is a number, not a workflow. Do not build an approval flow — the spec says teacher *or* supervisor may set it directly.

After writing, invalidate `studentProvider(studentId)` so the pending meeting recomposes immediately.

- [ ] **Step 4: Run the full suite**

Run: `flutter test && dart analyze`
Expected: PASS, analyzer clean.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(teacher): set a student's pace

Refs: al_rasikhoon-g63"
```

---

### Task 11: Close out

- [ ] **Step 1: Run the whole suite**

```bash
flutter test
dart analyze
```
Expected: all green.

- [ ] **Step 2: Drive the feature in the real app**

Use the `verify` skill. Set a student to 2x, teach a meeting, confirm: both passages show, the recent review does not repeat what is being taught, one record is written covering two sessions, and the student advances by two. Then drop them back to 1x mid-level and confirm the next meeting is a single session again.

- [ ] **Step 3: Close the issue and push**

```bash
bd close al_rasikhoon-g63
git pull --rebase
bd dolt push
git push
git status   # MUST show "up to date with origin"
```

---

## Notes for the implementer

**The two traps in this feature.**

1. **Do not "simplify" pace-1 into the composition path.** It looks like dead code — `if (batch.length == 1) return authored blocks` is exactly what the composer would compute anyway, *for 664 of 672 rows*. For the other 8 it is not, because the source curriculum disagrees with its own rule there (`al_rasikhoon-drw`). Collapsing that branch silently changes what ordinary students see. Task 3 will catch you.

2. **Do not concatenate recent review.** It is the one stream that does not compose by union. Two rows' recent blocks overlap each other and reach into the very content the meeting is teaching today. If a test ever asks you to relax the "recent never intersects new" assertion, the implementation is wrong, not the test.
