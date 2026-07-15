# Session Duration Timer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Time every session from start to save, record the elapsed duration on the session record, show it on the log card with an over/under-target flag, and display a live count-up timer during the session.

**Architecture:** A pure `SessionDuration` value object owns all target/tolerance/cap math and formatting. Session start is a `startedAt` timestamp captured at the start of each flow (in `ActiveSessionState` for lessons/تلقين; in the session screen and threaded via the router for سرد/اختبار). The repository computes the capped elapsed at write time using its existing `writtenAt` seam and stores it as `duration_seconds`. A dumb `SessionTimer` widget ticks once a second off `startedAt`; the log card and both history screens render the recorded duration and its status.

**Tech Stack:** Flutter, Riverpod (Notifier), go_router, Cloud Firestore (`fake_cloud_firestore` + `mocktail` in tests), `intl`.

## Global Constraints

- Target duration = `20 minutes × pace` (constant `kMinutesPerPace = 20`).
- Tolerance band = ±25% (`kToleranceFraction = 0.25`).
- Sanity cap = `3 × target` (`kCapMultiple = 3`); beyond-cap stores the clamped maximum, never null-for-that-reason.
- Assessments (سرد/اختبار) have **no** target → status `none`, no cap, no over/under flag; duration is stored and shown as raw elapsed.
- `duration` is nullable end to end: pre-feature records and any missing `startedAt` store `null` and render nothing. A missing duration never blocks a save.
- Domain layer (`lib/domain/**`) has zero framework dependencies — `SessionDuration` imports nothing from Flutter/Firestore.
- Follow existing patterns: models in `lib/data/models`, persisted keys are `snake_case`, tests grouped with domain-language names under `test/unit/**` and `test/widget/**`.

---

### Task 1: `SessionDuration` value object

The pure core. Owns target derivation, the ±25% status band, the 3× cap, the live-timer level, and both display formats. No Flutter/Firestore imports.

**Files:**
- Create: `lib/domain/session/session_duration.dart`
- Test: `test/unit/domain/session/session_duration_test.dart`

**Interfaces:**
- Produces:
  - `enum DurationStatus { none, under, onTarget, over }`
  - `enum LiveTimerLevel { neutral, warning, danger }`
  - `class SessionDuration` with:
    - `SessionDuration({required Duration elapsed, Duration? target})` — constructor clamps `elapsed` to `target * kCapMultiple` when `target != null`.
    - `final Duration elapsed;` (already capped) and `final Duration? target;`
    - `static const int kMinutesPerPace = 20;`
    - `static const double kToleranceFraction = 0.25;`
    - `static const int kCapMultiple = 3;`
    - `static Duration targetForPace(int pace) => Duration(minutes: kMinutesPerPace * pace);`
    - `DurationStatus get status;`
    - `String get clock;` — `mm:ss` of `elapsed`
    - `String get arabicMinutesLabel;` — e.g. `٢٢ دقيقة`
    - `static String formatClock(Duration d);` — `mm:ss`, zero-padded
    - `static LiveTimerLevel liveTimerLevel(Duration rawElapsed, Duration? target);` — uses UNCAPPED elapsed for the live display: `null`/below-target → neutral, `[target, 2×target)` → warning, `≥ 2×target` → danger.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/domain/session/session_duration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/session/session_duration.dart';

void main() {
  group('SessionDuration', () {
    test('a 1x target is twenty minutes, a 2x target is forty', () {
      expect(SessionDuration.targetForPace(1), const Duration(minutes: 20));
      expect(SessionDuration.targetForPace(2), const Duration(minutes: 40));
    });

    group('status', () {
      test('is none when there is no target', () {
        final d = SessionDuration(elapsed: const Duration(minutes: 22));
        expect(d.status, DurationStatus.none);
      });

      test('is onTarget within the ±25% band', () {
        final target = SessionDuration.targetForPace(1); // 20 min
        // 16..24 min inclusive is on target.
        expect(
          SessionDuration(elapsed: const Duration(minutes: 20), target: target).status,
          DurationStatus.onTarget,
        );
        expect(
          SessionDuration(elapsed: const Duration(minutes: 16), target: target).status,
          DurationStatus.onTarget,
        );
        expect(
          SessionDuration(elapsed: const Duration(minutes: 24), target: target).status,
          DurationStatus.onTarget,
        );
      });

      test('is under below the band and over above it', () {
        final target = SessionDuration.targetForPace(1); // 20 min
        expect(
          SessionDuration(elapsed: const Duration(minutes: 14), target: target).status,
          DurationStatus.under,
        );
        expect(
          SessionDuration(elapsed: const Duration(minutes: 26), target: target).status,
          DurationStatus.over,
        );
      });
    });

    test('elapsed is clamped to three times the target', () {
      final target = SessionDuration.targetForPace(1); // 20 min, cap 60 min
      final d = SessionDuration(
        elapsed: const Duration(hours: 12),
        target: target,
      );
      expect(d.elapsed, const Duration(minutes: 60));
      expect(d.status, DurationStatus.over);
    });

    test('without a target elapsed is stored raw, uncapped', () {
      final d = SessionDuration(elapsed: const Duration(hours: 3));
      expect(d.elapsed, const Duration(hours: 3));
    });

    group('formatting', () {
      test('clock is zero-padded mm:ss', () {
        expect(
          SessionDuration.formatClock(const Duration(minutes: 12, seconds: 5)),
          '12:05',
        );
        expect(SessionDuration.formatClock(Duration.zero), '00:00');
      });

      test('arabic minutes label rounds to the nearest minute', () {
        final d = SessionDuration(elapsed: const Duration(minutes: 22, seconds: 20));
        expect(d.arabicMinutesLabel, '٢٢ دقيقة');
      });
    });

    group('liveTimerLevel', () {
      final target = SessionDuration.targetForPace(1); // 20 min
      test('is neutral with no target', () {
        expect(
          SessionDuration.liveTimerLevel(const Duration(hours: 5), null),
          LiveTimerLevel.neutral,
        );
      });
      test('is neutral below target, warning at target, danger at twice target', () {
        expect(
          SessionDuration.liveTimerLevel(const Duration(minutes: 10), target),
          LiveTimerLevel.neutral,
        );
        expect(
          SessionDuration.liveTimerLevel(const Duration(minutes: 20), target),
          LiveTimerLevel.warning,
        );
        expect(
          SessionDuration.liveTimerLevel(const Duration(minutes: 40), target),
          LiveTimerLevel.danger,
        );
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/domain/session/session_duration_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../session_duration.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/session/session_duration.dart
import 'package:intl/intl.dart';

/// How a measured session length compares to its target.
enum DurationStatus { none, under, onTarget, over }

/// The urgency of the live in-session timer, driving its color.
enum LiveTimerLevel { neutral, warning, danger }

/// The length of a session, judged against its expected length.
///
/// Paced sessions (lesson, تلقين) have a target of `20 min × pace`; a سرد or
/// اختبار has none. With a target the measured [elapsed] is clamped to
/// [kCapMultiple]× it on construction, so a session left open overnight is
/// recorded as the clamped maximum rather than an absurd number.
class SessionDuration {
  static const int kMinutesPerPace = 20;
  static const double kToleranceFraction = 0.25;
  static const int kCapMultiple = 3;

  final Duration elapsed;
  final Duration? target;

  SessionDuration({required Duration elapsed, this.target})
    : elapsed = _capped(elapsed, target);

  static Duration targetForPace(int pace) =>
      Duration(minutes: kMinutesPerPace * pace);

  static Duration _capped(Duration elapsed, Duration? target) {
    if (target == null) return elapsed;
    final cap = target * kCapMultiple;
    return elapsed > cap ? cap : elapsed;
  }

  DurationStatus get status {
    final t = target;
    if (t == null) return DurationStatus.none;
    final lower = t * (1 - kToleranceFraction);
    final upper = t * (1 + kToleranceFraction);
    if (elapsed < lower) return DurationStatus.under;
    if (elapsed > upper) return DurationStatus.over;
    return DurationStatus.onTarget;
  }

  String get clock => formatClock(elapsed);

  String get arabicMinutesLabel {
    final minutes = (elapsed.inSeconds / 60).round();
    return '${NumberFormat('#', 'ar').format(minutes)} دقيقة';
  }

  static String formatClock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static LiveTimerLevel liveTimerLevel(Duration rawElapsed, Duration? target) {
    if (target == null) return LiveTimerLevel.neutral;
    if (rawElapsed >= target * 2) return LiveTimerLevel.danger;
    if (rawElapsed >= target) return LiveTimerLevel.warning;
    return LiveTimerLevel.neutral;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/domain/session/session_duration_test.dart`
Expected: PASS (all tests).

Note: `arabicMinutesLabel` needs Arabic locale data; if the test fails with a locale error, initialize once at the top of `main()` with `await initializeDateFormatting('ar');` — but `NumberFormat('#', 'ar')` uses built-in symbol data and normally needs no init. Only add it if the run demands it.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/session/session_duration.dart test/unit/domain/session/session_duration_test.dart
git commit -m "feat(session): add SessionDuration value object for duration targets and status"
```

---

### Task 2: `duration` on `SessionRecordModel`

Persist the recorded duration on the lesson/تلقين record as `duration_seconds`.

**Files:**
- Modify: `lib/data/models/session_record_model.dart`
- Test: `test/unit/data/models/session_record_model_test.dart` (add a group)

**Interfaces:**
- Consumes: nothing.
- Produces: `SessionRecordModel` gains `final Duration? duration;` (last constructor param, default `null`), round-tripped via `duration_seconds` (int seconds), and included in `copyWith`.

- [ ] **Step 1: Write the failing test** (append inside `main()` in the existing file)

```dart
  group('SessionRecordModel duration', () {
    SessionRecordModel base({Duration? duration}) => SessionRecordModel(
      id: 'r1',
      studentId: 's1',
      teacherId: 't1',
      curriculumSessionId: 'L1_J30_S1',
      kind: SessionKind.lesson,
      juzNumber: 30,
      fromOrderInLevel: 1,
      toOrderInLevel: 1,
      coversSessionIds: const ['L1_J30_S1'],
      date: DateTime(2026, 1, 1),
      attemptNumber: 1,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: true,
      createdAt: DateTime(2026, 1, 1),
      duration: duration,
    );

    test('round-trips a duration as whole seconds', () {
      final json = base(duration: const Duration(minutes: 22)).toFirestore();
      expect(json['duration_seconds'], 22 * 60);
      final read = SessionRecordModel.fromJson('r1', json);
      expect(read.duration, const Duration(minutes: 22));
    });

    test('a record with no duration stores null and reads back null', () {
      final json = base().toFirestore();
      expect(json['duration_seconds'], isNull);
      expect(SessionRecordModel.fromJson('r1', json).duration, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/data/models/session_record_model_test.dart`
Expected: FAIL — `SessionRecordModel` has no named parameter `duration`.

- [ ] **Step 3: Write minimal implementation**

In `lib/data/models/session_record_model.dart`:

Add the field near `createdAt` (after `final DateTime createdAt;`):
```dart
  /// How long the session took, wall-clock from start to save. Null for
  /// records written before sessions were timed, and for any record whose
  /// start was not captured. Capped to 3× the pace target at write time; see
  /// [SessionDuration].
  final Duration? duration;
```

Add to the constructor (after `required this.createdAt,`):
```dart
    this.duration,
```

In `fromJson`, before the closing `);` of the returned `SessionRecordModel(...)` (after `createdAt: ...,`):
```dart
      duration: (json['duration_seconds'] as int?) == null
          ? null
          : Duration(seconds: json['duration_seconds'] as int),
```

In `toFirestore`, after `'created_at': Timestamp.fromDate(createdAt),`:
```dart
      'duration_seconds': duration?.inSeconds,
```

In `copyWith`, add param `Duration? duration,` and pass `duration: duration ?? this.duration,`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/data/models/session_record_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/session_record_model.dart test/unit/data/models/session_record_model_test.dart
git commit -m "feat(session): persist duration on the session record"
```

---

### Task 3: `duration` on `SardRecordModel` and `ExamRecordModel`

Same field on both assessment records. These carry raw (uncapped) elapsed.

**Files:**
- Modify: `lib/data/models/sard_record_model.dart`
- Modify: `lib/data/models/exam_record_model.dart`
- Test: `test/unit/data/models/assessment_record_model_test.dart` (add groups)

**Interfaces:**
- Produces: `SardRecordModel` and `ExamRecordModel` each gain `final Duration? duration;` (last constructor param, default `null`), round-tripped via `duration_seconds`, included in `copyWith`.

- [ ] **Step 1: Write the failing test** (append inside `main()`)

This mirrors the file's existing round-trip pattern exactly: build the record, write `toFirestore()` into a `FakeFirebaseFirestore`, read it back with `fromFirestore`. The file already imports `fake_cloud_firestore` and both models.

```dart
  group('assessment record duration', () {
    test('SardRecordModel round-trips a duration as whole seconds', () async {
      final record = SardRecordModel(
        id: 'sard1',
        studentId: 's1',
        teacherId: 't1',
        curriculumSessionId: 'L1_J30_S7',
        tier: AssessmentTier.unit,
        levelId: 1,
        date: DateTime(2026, 1, 1),
        errorCount: 0,
        grade: 'راسخ',
        passed: true,
        attemptNumber: 1,
        createdAt: DateTime(2026, 1, 1),
        duration: const Duration(minutes: 18),
      );
      expect(record.toFirestore()['duration_seconds'], 18 * 60);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('sard_records').doc('sard1').set(record.toFirestore());
      final doc = await firestore.collection('sard_records').doc('sard1').get();
      expect(SardRecordModel.fromFirestore(doc).duration, const Duration(minutes: 18));
    });

    test('ExamRecordModel round-trips a duration as whole seconds', () async {
      final record = ExamRecordModel(
        id: 'exam1',
        studentId: 's1',
        supervisorId: 'sup1',
        curriculumSessionId: 'L1_J30_S9',
        tier: AssessmentTier.juz,
        levelId: 1,
        date: DateTime(2026, 1, 1),
        errorCount: 0,
        grade: 'راسخ',
        passed: true,
        attemptNumber: 1,
        createdAt: DateTime(2026, 1, 1),
        duration: const Duration(minutes: 30),
      );
      expect(record.toFirestore()['duration_seconds'], 30 * 60);

      final firestore = FakeFirebaseFirestore();
      await firestore.collection('exam_records').doc('exam1').set(record.toFirestore());
      final doc = await firestore.collection('exam_records').doc('exam1').get();
      expect(ExamRecordModel.fromFirestore(doc).duration, const Duration(minutes: 30));
    });

    test('an assessment record with no duration stores null', () {
      final record = SardRecordModel(
        id: 'sard2',
        studentId: 's1',
        teacherId: 't1',
        curriculumSessionId: 'L1_J30_S7',
        tier: AssessmentTier.unit,
        levelId: 1,
        date: DateTime(2026, 1, 1),
        errorCount: 0,
        grade: 'راسخ',
        passed: true,
        attemptNumber: 1,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(record.toFirestore()['duration_seconds'], isNull);
    });
  });
```

`AssessmentTier` comes from `session_model.dart`, already imported in this file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/data/models/assessment_record_model_test.dart`
Expected: FAIL — no named parameter `duration`.

- [ ] **Step 3: Write minimal implementation**

In `lib/data/models/sard_record_model.dart` and `lib/data/models/exam_record_model.dart`, make the identical change to each:

Add field after `final DateTime createdAt;`:
```dart
  /// How long the assessment took, wall-clock from opening the session screen
  /// to save. Raw elapsed — assessments have no pace target, so there is no
  /// cap. Null for records written before assessments were timed.
  final Duration? duration;
```

Add to constructor after `required this.createdAt,`:
```dart
    this.duration,
```

In `fromFirestore`, after `createdAt: ...,`:
```dart
      duration: (data['duration_seconds'] as int?) == null
          ? null
          : Duration(seconds: data['duration_seconds'] as int),
```

In `toFirestore`, after `'created_at': Timestamp.fromDate(createdAt),`:
```dart
      'duration_seconds': duration?.inSeconds,
```

In `copyWith`, add `Duration? duration,` and `duration: duration ?? this.duration,`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/data/models/assessment_record_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/sard_record_model.dart lib/data/models/exam_record_model.dart test/unit/data/models/assessment_record_model_test.dart
git commit -m "feat(session): persist duration on sard and exam records"
```

---

### Task 4: Repository computes duration for lesson & تلقين records

The repository already stamps `writtenAt = now ?? DateTime.now()` inside `_writeSessionRecord`. Given a `startedAt`, it can compute the capped elapsed at exactly that instant using `SessionDuration`, so the write timestamp and the duration never disagree, and the existing `now` seam makes the math testable.

**Files:**
- Modify: `lib/data/repositories/session_repository.dart` (`createSessionRecord`, `createTalqeenRecord`)
- Test: `test/unit/data/repositories/session_repository_test.dart` (add tests to the existing `createSessionRecord` / `createTalqeenRecord` groups)

**Interfaces:**
- Consumes: `SessionDuration.targetForPace(int)` (Task 1); `SessionRecordModel.duration` (Task 2).
- Produces: `createSessionRecord` and `createTalqeenRecord` gain a named param `DateTime? startedAt` (default `null`). When non-null, the returned record's `duration` is `SessionDuration(elapsed: writtenAt − startedAt, target: targetForPace(pace.multiplier)).elapsed`; when null, `duration` is null.

- [ ] **Step 1: Write the failing test** (add inside the existing `group('createSessionRecord', ...)`)

```dart
      test('records the capped wall-clock duration from startedAt to write', () async {
        final started = DateTime(2026, 1, 1, 10, 0, 0);
        final record = await sessionRepository.createSessionRecord(
          studentId: 's1',
          teacherId: 't1',
          meeting: _meeting(id: 'L1_J30_S1', sessionNumber: 1, orderInLevel: 1),
          levelId: 1,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace.standard, // 1x → 20 min target, 60 min cap
          startedAt: started,
          now: started.add(const Duration(minutes: 22)),
        );
        expect(record.duration, const Duration(minutes: 22));
      });

      test('clamps a forgotten session to three times the target', () async {
        final started = DateTime(2026, 1, 1, 10, 0, 0);
        final record = await sessionRepository.createSessionRecord(
          studentId: 's1',
          teacherId: 't1',
          meeting: _meeting(id: 'L1_J30_S1', sessionNumber: 1, orderInLevel: 1),
          levelId: 1,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace.standard,
          startedAt: started,
          now: started.add(const Duration(hours: 12)),
        );
        expect(record.duration, const Duration(minutes: 60));
      });

      test('leaves duration null when no start was captured', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 's1',
          teacherId: 't1',
          meeting: _meeting(id: 'L1_J30_S1', sessionNumber: 1, orderInLevel: 1),
          levelId: 1,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace.standard,
        );
        expect(record.duration, isNull);
      });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/data/repositories/session_repository_test.dart -N createSessionRecord`
Expected: FAIL — no named parameter `startedAt`.

- [ ] **Step 3: Write minimal implementation**

Add the import at the top of `lib/data/repositories/session_repository.dart` (with the other model/domain imports):
```dart
import '../../domain/session/session_duration.dart';
```

`createSessionRecord` — add `DateTime? startedAt,` to the parameter list (next to `DateTime? now,`). Inside the `_writeSessionRecord((id, writtenAt) => ...)` builder, compute the duration and pass it to the model:
```dart
      (id, writtenAt) => SessionRecordModel(
        // ... existing fields unchanged ...
        createdAt: writtenAt,
        duration: startedAt == null
            ? null
            : SessionDuration(
                elapsed: writtenAt.difference(startedAt),
                target: SessionDuration.targetForPace(pace.multiplier),
              ).elapsed,
      ),
```

`createTalqeenRecord` — add `DateTime? startedAt,` to its parameter list and the identical `duration:` line in its builder (it also has `pace`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/data/repositories/session_repository_test.dart`
Expected: PASS (existing tests still green; new ones pass).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/session_repository.dart test/unit/data/repositories/session_repository_test.dart
git commit -m "feat(session): compute and store lesson/talqeen duration at write time"
```

---

### Task 5: Repository computes duration for سرد & اختبار records

These methods currently call `DateTime.now()` twice and have no `now` seam. Add a `now` seam (mirroring the session methods) and a `startedAt`, and store raw (uncapped) elapsed since assessments have no target.

**Files:**
- Modify: `lib/data/repositories/session_repository.dart` (`createSardRecord`, `createExamRecord`)
- Test: `test/unit/data/repositories/session_repository_test.dart` (add a `createSardRecord duration` group; and one exam test)

**Interfaces:**
- Consumes: `SardRecordModel.duration`, `ExamRecordModel.duration` (Task 3).
- Produces: `createSardRecord` and `createExamRecord` each gain `DateTime? startedAt` and `DateTime? now` (both default `null`). `date`/`createdAt` use `writtenAt = now ?? DateTime.now()`. `duration = startedAt == null ? null : writtenAt.difference(startedAt)` — no cap.

- [ ] **Step 1: Write the failing test**

```dart
    group('createSardRecord duration', () {
      test('records raw wall-clock duration, uncapped', () async {
        final started = DateTime(2026, 1, 1, 10, 0, 0);
        final record = await sessionRepository.createSardRecord(
          studentId: 's1',
          teacherId: 't1',
          curriculumSessionId: 'L1_J30_S7',
          tier: AssessmentTier.unit,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
          startedAt: started,
          now: started.add(const Duration(hours: 2)),
        );
        expect(record.duration, const Duration(hours: 2)); // no cap for assessments
      });

      test('leaves duration null when no start was captured', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 's1',
          teacherId: 't1',
          curriculumSessionId: 'L1_J30_S7',
          tier: AssessmentTier.unit,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
        );
        expect(record.duration, isNull);
      });
    });

    group('createExamRecord duration', () {
      test('records raw wall-clock duration', () async {
        final started = DateTime(2026, 1, 1, 10, 0, 0);
        final record = await sessionRepository.createExamRecord(
          studentId: 's1',
          supervisorId: 'sup1',
          curriculumSessionId: 'L1_J30_S9',
          tier: AssessmentTier.juz,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
          startedAt: started,
          now: started.add(const Duration(minutes: 35)),
        );
        expect(record.duration, const Duration(minutes: 35));
      });
    });
```

Add `import 'package:al_rasikhoon/data/models/session_model.dart';` to the test file if `AssessmentTier` is not already imported there (it defines the enum). Check the existing imports first.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/data/repositories/session_repository_test.dart -N "createSardRecord duration"`
Expected: FAIL — no named parameter `startedAt`/`now`.

- [ ] **Step 3: Write minimal implementation**

`createSardRecord` — add `DateTime? startedAt,` and `DateTime? now,` to the parameter list. Replace the two `DateTime.now()` calls:
```dart
    final writtenAt = now ?? DateTime.now();
    final docRef = _sardRecordsCollection.doc();
    final record = SardRecordModel(
      // ... unchanged fields ...
      date: writtenAt,
      // ...
      createdAt: writtenAt,
      duration: startedAt == null ? null : writtenAt.difference(startedAt),
    );
```

`createExamRecord` — the identical change (`supervisorId` in place of `teacherId`, `_examRecordsCollection`, `ExamRecordModel`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/data/repositories/session_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/session_repository.dart test/unit/data/repositories/session_repository_test.dart
git commit -m "feat(session): compute and store sard/exam duration at write time"
```

---

### Task 6: Capture `startedAt` in the lesson/تلقين session state

Store the start instant in `ActiveSessionState` and forward it to the repository on completion.

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart` (`ActiveSessionState`, `startSession`, `completeSession`, `completeTalqeenSession`)
- Test: `test/unit/providers/teacher_provider_test.dart` (add tests)

**Interfaces:**
- Consumes: `createSessionRecord(..., startedAt:)`, `createTalqeenRecord(..., startedAt:)` (Task 4).
- Produces: `ActiveSessionState` gains `final DateTime? startedAt;` (constructor param + `copyWith`). `startSession` sets `startedAt: DateTime.now()`. `completeSession`/`completeTalqeenSession` pass `startedAt: state!.startedAt` to the repository.

- [ ] **Step 1: Write the failing test**

Locate how the existing test builds a container and reads `activeSessionProvider` (search the file for `activeSessionProvider`). Mirror that setup. Add:

```dart
    test('startSession stamps a start time', () async {
      // Arrange: mirror the existing container/seed setup used by other
      // activeSessionProvider tests in this file.
      await container.read(activeSessionProvider.notifier).startSession('s1');
      expect(container.read(activeSessionProvider)!.startedAt, isNotNull);
    });

    test('completeSession records a non-null duration', () async {
      // Arrange: seed the unit + student + current user exactly as the existing
      // completeSession test does, then:
      await container.read(activeSessionProvider.notifier).startSession('s1');
      final record =
          await container.read(activeSessionProvider.notifier).completeSession();
      expect(record, isNotNull);
      expect(record!.duration, isNotNull);
    });
```

Note: the exact duration is asserted in Task 4 via the `now` seam; here we only prove `startedAt` is set and is forwarded (so `duration` comes back non-null).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/teacher_provider_test.dart -N startSession`
Expected: FAIL — `startedAt` getter undefined.

- [ ] **Step 3: Write minimal implementation**

In `ActiveSessionState`:
- Add field: `final DateTime? startedAt;`
- Add constructor param `this.startedAt,` (after `this.meeting,`).
- Add to `copyWith`: param `DateTime? startedAt,` and `startedAt: startedAt ?? this.startedAt,`.

In `startSession`:
```dart
  Future<void> startSession(String studentId) async {
    state = ActiveSessionState(studentId: studentId, startedAt: DateTime.now());
    await _loadMeetingBeingTaught(studentId);
  }
```

In `completeSession`, add `startedAt: state!.startedAt,` to the `sessionRepo.createSessionRecord(...)` call (read it before the `state = state!.copyWith(...)` mutations — the existing code already saves `studentId` early; `state!.startedAt` is still valid at the `createSessionRecord` call site).

In `completeTalqeenSession`, add `startedAt: state!.startedAt,` to the `sessionRepo.createTalqeenRecord(...)` call.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/providers/teacher_provider_test.dart`
Expected: PASS (talqeen provider test in `teacher_provider_talqeen_test.dart` also still green).

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/providers/teacher_provider.dart test/unit/providers/teacher_provider_test.dart
git commit -m "feat(session): capture session start time and forward it on completion"
```

---

### Task 7: `SessionTimer` widget

A dumb, self-contained ticking display. Given `startedAt` and an optional `target`, it recomputes elapsed every second and renders `mm:ss` (or `mm:ss / mm:ss` with a target), colored by `LiveTimerLevel`.

**Files:**
- Create: `lib/shared/widgets/session_timer.dart`
- Test: `test/widget/session_timer_test.dart`

**Interfaces:**
- Consumes: `SessionDuration.formatClock`, `SessionDuration.liveTimerLevel`, `LiveTimerLevel` (Task 1); `AppColors`.
- Produces: `class SessionTimer extends StatefulWidget` with `const SessionTimer({super.key, required DateTime startedAt, Duration? target})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/session_timer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows elapsed against the target when one is given', (tester) async {
    final started = DateTime.now().subtract(const Duration(minutes: 5));
    await tester.pumpWidget(host(
      SessionTimer(startedAt: started, target: const Duration(minutes: 20)),
    ));
    // Elapsed ~05:00, target 20:00 → "05:00 / 20:00".
    expect(find.textContaining('/ 20:00'), findsOneWidget);
    expect(find.textContaining('05:0'), findsOneWidget);
  });

  testWidgets('shows elapsed only when there is no target', (tester) async {
    final started = DateTime.now().subtract(const Duration(minutes: 8));
    await tester.pumpWidget(host(SessionTimer(startedAt: started)));
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('08:0'), findsOneWidget);
  });

  testWidgets('advances as time passes', (tester) async {
    final started = DateTime.now();
    await tester.pumpWidget(host(SessionTimer(startedAt: started)));
    expect(find.text('00:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);
    // Let the periodic timer cancel cleanly.
    await tester.pumpWidget(host(const SizedBox()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/session_timer_test.dart`
Expected: FAIL — URI `session_timer.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/shared/widgets/session_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/session/session_duration.dart';

/// A live, once-a-second count-up shown in an active session's app bar.
///
/// Display-only: it recomputes elapsed from [startedAt] on each tick and never
/// writes anything. With a [target] it shows `elapsed / target` and colors
/// itself by [SessionDuration.liveTimerLevel] as a nudge to end the session;
/// without one (assessments) it shows elapsed alone in a neutral color.
class SessionTimer extends StatefulWidget {
  final DateTime startedAt;
  final Duration? target;

  const SessionTimer({super.key, required this.startedAt, this.target});

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _colorFor(LiveTimerLevel level) {
    switch (level) {
      case LiveTimerLevel.neutral:
        return AppColors.textOnPrimary;
      case LiveTimerLevel.warning:
        return AppColors.secondary;
      case LiveTimerLevel.danger:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final target = widget.target;
    final text = target == null
        ? SessionDuration.formatClock(elapsed)
        : '${SessionDuration.formatClock(elapsed)} / ${SessionDuration.formatClock(target)}';
    final color = _colorFor(SessionDuration.liveTimerLevel(elapsed, target));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

If `FontFeature` is unresolved, add `import 'dart:ui';` — or drop the `fontFeatures` line (cosmetic only).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/session_timer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/session_timer.dart test/widget/session_timer_test.dart
git commit -m "feat(session): add live in-session timer widget"
```

---

### Task 8: `ActiveLessonTimer` and wiring into lesson-flow app bars

One Riverpod-aware wrapper reads the active session's `startedAt` and the student's pace, so the four lesson-flow screens each drop in a single widget.

**Files:**
- Create: `lib/features/teacher/widgets/active_lesson_timer.dart`
- Modify: `lib/features/teacher/screens/new_memorization_screen.dart`
- Modify: `lib/features/teacher/screens/recitation_screen.dart`
- Modify: `lib/features/teacher/screens/session_summary_screen.dart`
- Modify: `lib/features/teacher/screens/talqeen_session_screen.dart`
- Test: `test/widget/active_lesson_timer_test.dart`

**Interfaces:**
- Consumes: `activeSessionProvider` (`ActiveSessionState.startedAt`), `studentProvider` (`.student.pace.multiplier`), `SessionTimer`, `SessionDuration.targetForPace`.
- Produces: `class ActiveLessonTimer extends ConsumerWidget` with `const ActiveLessonTimer({super.key, required String studentId})`. Renders `SessionTimer` with the pace target; renders `SizedBox.shrink()` when there is no active session.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/active_lesson_timer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/widgets/active_lesson_timer.dart';

void main() {
  testWidgets('renders nothing when there is no active session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ActiveLessonTimer(studentId: 's1')),
        ),
      ),
    );
    // No active session → collapses to an empty box, no timer text.
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining(':'), findsNothing);
  });
}
```

(Deeper wiring — that it shows the pace target — is covered indirectly by the `SessionTimer` test; a full active-session render needs the same seed harness as `teacher_provider_test.dart`, which is out of scope for this widget test.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/active_lesson_timer_test.dart`
Expected: FAIL — URI `active_lesson_timer.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/teacher/widgets/active_lesson_timer.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/session/session_duration.dart';
import '../../../shared/widgets/session_timer.dart';
import '../providers/teacher_provider.dart';

/// The live session timer for the lesson/تلقين flow: reads the start instant
/// from the active session and the target from the student's live pace, so
/// each in-session screen only has to drop this into its app bar.
class ActiveLessonTimer extends ConsumerWidget {
  final String studentId;

  const ActiveLessonTimer({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startedAt = ref.watch(activeSessionProvider)?.startedAt;
    if (startedAt == null) return const SizedBox.shrink();

    final pace =
        ref.watch(studentProvider(studentId)).valueOrNull?.student.pace.multiplier ?? 1;
    return SessionTimer(
      startedAt: startedAt,
      target: SessionDuration.targetForPace(pace),
    );
  }
}
```

Confirm the `studentProvider` value shape by grepping: the notifier resolves to an object exposing `.student.pace` (see `completeSession`, which reads `studentAsync.student` and `student.pace`). If the `AsyncValue` value is the student wrapper directly, `.valueOrNull?.student.pace.multiplier` is correct; adjust the accessor to match if the provider exposes the student differently.

Then wire the widget into each screen's `AppBar` via `actions: [ActiveLessonTimer(studentId: <id>)]`:

- `new_memorization_screen.dart` — `AppBar(title: const Text('الحفظ الجديد'))` → add `actions: [ActiveLessonTimer(studentId: studentId)]`. This is a `ConsumerWidget` whose `build` has `studentId` in scope (it's a field). Add the import `import '../widgets/active_lesson_timer.dart';`.
- `recitation_screen.dart` — `AppBar(title: Text(_partTitle))` → add `actions: [ActiveLessonTimer(studentId: widget.studentId)]`. Import as above.
- `session_summary_screen.dart` — the main `AppBar(title: const Text('ملخص الحلقة'))` at ~line 122 (not the loading-state one at ~107) → add `actions: [ActiveLessonTimer(studentId: widget.studentId)]`. Import.
- `talqeen_session_screen.dart` — `AppBar(title: const Text('تلقين'))` → add `actions: [ActiveLessonTimer(studentId: widget.studentId)]`. Import.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/active_lesson_timer_test.dart`
Then the existing screen widget tests still pass:
Run: `flutter test test/widget/new_memorization_screen_test.dart test/widget/talqeen_session_screen_test.dart test/widget/session_summary_screen_test.dart test/widget/recitation_screen_talqeen_guard_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/widgets/active_lesson_timer.dart lib/features/teacher/screens/new_memorization_screen.dart lib/features/teacher/screens/recitation_screen.dart lib/features/teacher/screens/session_summary_screen.dart lib/features/teacher/screens/talqeen_session_screen.dart test/widget/active_lesson_timer_test.dart
git commit -m "feat(session): show the live timer across the lesson and talqeen screens"
```

---

### Task 9: Time the سرد flow

Capture `startedAt` when the سرد session screen opens, show the live timer there, thread the start to the result screen through the router, and pass it to `createSardRecord`.

**Files:**
- Modify: `lib/features/teacher/screens/sard_session_screen.dart`
- Modify: `lib/features/teacher/screens/sard_result_screen.dart`
- Modify: `lib/routing/app_router.dart` (sardResult route)
- Test: `test/widget/sard_session_timer_test.dart`

**Interfaces:**
- Consumes: `SessionTimer` (Task 7); `createSardRecord(..., startedAt:)` (Task 5).
- Produces: `SardResultScreen` gains `final DateTime? startedAt;` constructor param. The `sardResult` route reads `extra` as `({int errorCount, DateTime startedAt})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/sard_session_timer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/screens/sard_session_screen.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

void main() {
  testWidgets('the sard session screen shows a live timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: SardSessionScreen(studentId: 's1')),
      ),
    );
    await tester.pump(); // let the async session provider settle to a frame
    expect(find.byType(SessionTimer), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // cancel the periodic timer
  });
}
```

If `SardSessionScreen` throws without a seeded student/session provider, override the providers it reads (mirror `sard_result_advance_warning_test.dart`'s setup) so the scaffold with the app bar builds. The assertion is only that a `SessionTimer` exists in the app bar, which renders regardless of the body's async state.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/sard_session_timer_test.dart`
Expected: FAIL — no `SessionTimer` in the tree.

- [ ] **Step 3: Write minimal implementation**

In `sard_session_screen.dart`:
- Add imports: `import '../../../shared/widgets/session_timer.dart';`
- Give the state a start instant:
```dart
class _SardSessionScreenState extends ConsumerState<SardSessionScreen> {
  int _errorCount = 0;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }
```
- Add the timer to the app bar:
```dart
      appBar: AppBar(
        title: const Text('السرد'),
        actions: [SessionTimer(startedAt: _startedAt)],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () { _showExitConfirmation(); },
        ),
      ),
```
- Change the push to carry both values:
```dart
                            context.push(
                              AppRoutes.sardResult.replaceFirst(
                                ':studentId',
                                widget.studentId,
                              ),
                              extra: (errorCount: _errorCount, startedAt: _startedAt),
                            );
```

In `sard_result_screen.dart`:
- Add `final DateTime? startedAt;` and constructor param `this.startedAt,`.
- In `_saveSard`, pass `startedAt: widget.startedAt,` (and, for testability parity, nothing else changes) to `sessionRepo.createSardRecord(...)`.

In `app_router.dart`, the `sardResult` builder:
```dart
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final args =
                      state.extra as ({int errorCount, DateTime startedAt})?;
                  return SardResultScreen(
                    studentId: studentId,
                    errorCount: args?.errorCount ?? 0,
                    startedAt: args?.startedAt,
                  );
                },
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/sard_session_timer_test.dart test/widget/sard_result_advance_warning_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/screens/sard_session_screen.dart lib/features/teacher/screens/sard_result_screen.dart lib/routing/app_router.dart test/widget/sard_session_timer_test.dart
git commit -m "feat(session): time the sard flow and show its live timer"
```

---

### Task 10: Time the اختبار flow

The same pattern for the supervisor's exam.

**Files:**
- Modify: `lib/features/supervisor/screens/exam_session_screen.dart`
- Modify: `lib/features/supervisor/screens/exam_result_screen.dart`
- Modify: `lib/routing/app_router.dart` (examResult route)
- Test: `test/widget/exam_session_timer_test.dart`

**Interfaces:**
- Consumes: `SessionTimer` (Task 7); `createExamRecord(..., startedAt:)` (Task 5).
- Produces: `ExamResultScreen` gains `final DateTime? startedAt;`. The `examResult` route reads `extra` as `({int errorCount, DateTime startedAt})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/exam_session_timer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_session_screen.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

void main() {
  testWidgets('the exam session screen shows a live timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ExamSessionScreen(studentId: 's1')),
      ),
    );
    await tester.pump();
    expect(find.byType(SessionTimer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
```

Mirror the provider overrides in `exam_session_overflow_test.dart` if the bare screen throws.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/exam_session_timer_test.dart`
Expected: FAIL — no `SessionTimer`.

- [ ] **Step 3: Write minimal implementation**

In `exam_session_screen.dart` (`_ExamSessionScreenState`): add `import '../../../shared/widgets/session_timer.dart';`, add `late final DateTime _startedAt;` set in `initState`, add `actions: [SessionTimer(startedAt: _startedAt)]` to the `AppBar`, and change the push:
```dart
                            context.push(
                              AppRoutes.examResult.replaceFirst(
                                ':studentId',
                                widget.studentId,
                              ),
                              extra: (errorCount: _errorCount, startedAt: _startedAt),
                            );
```
(Confirm the exam screen's error-count field name — it may differ from `_errorCount`; use whatever it already stores.)

In `exam_result_screen.dart`: add `final DateTime? startedAt;` + constructor param, and pass `startedAt: widget.startedAt,` to `createExamRecord(...)`.

In `app_router.dart`, the `examResult` builder:
```dart
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final args =
                      state.extra as ({int errorCount, DateTime startedAt})?;
                  return ExamResultScreen(
                    studentId: studentId,
                    errorCount: args?.errorCount ?? 0,
                    startedAt: args?.startedAt,
                  );
                },
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/exam_session_timer_test.dart test/widget/exam_session_overflow_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/supervisor/screens/exam_session_screen.dart lib/features/supervisor/screens/exam_result_screen.dart lib/routing/app_router.dart test/widget/exam_session_timer_test.dart
git commit -m "feat(session): time the exam flow and show its live timer"
```

---

### Task 11: Show duration and the over/under flag on the log card

`SessionRecordRow` gains an optional `SessionDuration`; both history screens build it from the record and pass it in.

**Files:**
- Modify: `lib/shared/widgets/session_record_row.dart`
- Modify: `lib/features/student/screens/session_history_screen.dart`
- Modify: `lib/features/teacher/screens/teacher_history_screen.dart`
- Test: `test/widget/session_record_row_duration_test.dart`

**Interfaces:**
- Consumes: `SessionDuration`, `DurationStatus` (Task 1); `SessionRecordModel.duration`, `.paceAtTime` (Task 2).
- Produces: `SessionRecordRow` gains `final SessionDuration? sessionDuration;` (optional). When non-null it renders a duration line (`المدة: <arabicMinutesLabel>`) and, when `status != none`, a small colored status pill.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/session_record_row_duration_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/session/session_duration.dart';
import 'package:al_rasikhoon/shared/widgets/session_record_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    home: Scaffold(body: child),
  );

  testWidgets('shows the duration and an over-target flag', (tester) async {
    await tester.pumpWidget(host(SessionRecordRow(
      title: 'أحمد',
      subtitleLines: const ['الحلقة ٥'],
      passed: true,
      date: DateTime(2026, 1, 1),
      sessionDuration: SessionDuration(
        elapsed: const Duration(minutes: 40),
        target: SessionDuration.targetForPace(1), // 20 min → 40 is over
      ),
    )));
    expect(find.textContaining('المدة'), findsOneWidget);
    expect(find.textContaining('أطول'), findsOneWidget); // over-target label
  });

  testWidgets('shows the duration but no flag for an assessment (no target)',
      (tester) async {
    await tester.pumpWidget(host(SessionRecordRow(
      title: 'أحمد',
      subtitleLines: const ['سرد'],
      passed: true,
      date: DateTime(2026, 1, 1),
      sessionDuration: SessionDuration(elapsed: const Duration(minutes: 18)),
    )));
    expect(find.textContaining('المدة'), findsOneWidget);
    expect(find.textContaining('أطول'), findsNothing);
    expect(find.textContaining('أقصر'), findsNothing);
    expect(find.textContaining('ضمن'), findsNothing);
  });

  testWidgets('renders no duration line when the record has no duration',
      (tester) async {
    await tester.pumpWidget(host(SessionRecordRow(
      title: 'أحمد',
      subtitleLines: const ['الحلقة ٥'],
      passed: true,
      date: DateTime(2026, 1, 1),
      // sessionDuration omitted → no duration line, no flag.
    )));
    expect(find.textContaining('المدة'), findsNothing);
  });
}
```

These assert: the duration line shows whenever a `sessionDuration` is given; the over/under label shows only when there is a target; and nothing renders when there is no duration.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/session_record_row_duration_test.dart`
Expected: FAIL — no named parameter `sessionDuration`.

- [ ] **Step 3: Write minimal implementation**

In `session_record_row.dart`:
- Add imports: `import '../../domain/session/session_duration.dart';`
- Add field + constructor param:
```dart
  /// The recorded length of the session, or null for records with no timing.
  /// When present the row shows the duration; when it also has a target
  /// (lessons/تلقين) it shows an over/under-target flag.
  final SessionDuration? sessionDuration;
```
```dart
    this.sessionDuration,
```
- Inside the `Column` of subtitle lines, after the date `Text(...)`, add the duration line and flag:
```dart
                if (sessionDuration != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'المدة: ${sessionDuration!.arabicMinutesLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (sessionDuration!.status != DurationStatus.none)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _DurationFlag(status: sessionDuration!.status),
                    ),
                ],
```
- Add the flag widget at the bottom of the file:
```dart
class _DurationFlag extends StatelessWidget {
  final DurationStatus status;
  const _DurationFlag({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (status) {
      case DurationStatus.under:
        color = AppColors.info;
        label = 'أقصر من المدة';
        break;
      case DurationStatus.onTarget:
        color = AppColors.success;
        label = 'ضمن المدة';
        break;
      case DurationStatus.over:
        color = AppColors.warning;
        label = 'أطول من المدة';
        break;
      case DurationStatus.none:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
```

In `session_history_screen.dart` and `teacher_history_screen.dart`, at each `SessionRecordRow(...)` call, add:
```dart
                  sessionDuration: record.duration == null
                      ? null
                      : SessionDuration(
                          elapsed: record.duration!,
                          target: SessionDuration.targetForPace(record.paceAtTime),
                        ),
```
Add `import '../../../domain/session/session_duration.dart';` to each screen (adjust the relative depth: both screens are at `lib/features/<area>/screens/`, so `../../../domain/session/session_duration.dart`). Confirm the loop variable is named `record`; in `teacher_history_screen.dart` it may be inline — use whatever `SessionRecordModel` variable is in scope at that call site.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/session_record_row_duration_test.dart test/widget/session_history_listing_test.dart test/widget/teacher_history_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/session_record_row.dart lib/features/student/screens/session_history_screen.dart lib/features/teacher/screens/teacher_history_screen.dart test/widget/session_record_row_duration_test.dart
git commit -m "feat(session): show duration and over/under flag on the log card"
```

---

### Task 12: Full-suite and analyzer green

A final gate — no new code, just verification across the whole feature.

**Files:** none.

- [ ] **Step 1: Run the analyzer**

Run: `flutter analyze`
Expected: No new issues in any touched file.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests pass (existing + the new duration/timer tests).

- [ ] **Step 3: Commit any fixes**

If the analyzer or a pre-existing test surfaced a wiring issue (an unadjusted `SessionRecordRow` call, a missing import), fix it and commit:
```bash
git add -A
git commit -m "chore(session): analyzer and full-suite fixes for duration timer"
```

---

## Notes for the implementer

- **Arabic numerals in tests:** `arabicMinutesLabel` renders Arabic-Indic digits (`٢٢`). If a test comparison fails on digit shape, verify the expected string is typed with the same Arabic-Indic digits, not Western ones.
- **`extra` as a record:** go_router passes `state.extra` as `Object?`; the `({int errorCount, DateTime startedAt})` record cast is null-safe via `as ...?`. A direct navigation without `extra` (deep link) yields `null` → `errorCount 0`, `startedAt null` → duration simply not recorded. That is the intended degrade.
- **Provider value shape:** `studentProvider(id)` resolves to a wrapper exposing `.student` (see `completeSession`). If `.valueOrNull?.student` doesn't resolve, grep the provider definition and match its actual value type before finishing Task 8.
- **Do not** change `firestore.indexes.json` — `duration_seconds` is never queried or ordered on.
```
