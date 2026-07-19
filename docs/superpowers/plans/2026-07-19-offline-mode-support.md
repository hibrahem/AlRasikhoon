# Offline Mode Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app usable with no connectivity — all roles browse last-fetched data offline; teachers save memorization/تلقين/سرد sessions and supervisors save exams offline, atomically, with automatic sync and visible pending state.

**Architecture:** Firestore's built-in offline persistence is the offline store and write queue (spec: `docs/superpowers/specs/2026-07-19-offline-mode-design.md`, Approach A). We (1) enable persistence explicitly, (2) prime the cache per role, (3) convert the offline-capable saves to a single `WriteBatch` committed fire-and-forget, (4) surface connectivity + pending-write state in the UI, (5) gate online-only actions.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod` 3.x), `cloud_firestore` 6.x, `connectivity_plus` 7.x, `fake_cloud_firestore` for tests. Tracked as beads issue `al_rasikhoon-15s`.

## Global Constraints

- Follow existing hybrid layered structure: repos in `lib/data/repositories/`, services in `lib/data/services/`, shared providers in `lib/shared/providers/`, shared widgets in `lib/shared/widgets/`.
- All user-facing copy is Arabic. Offline banner copy: `أنت غير متصل — سيتم الحفظ محليًا والمزامنة لاحقًا`. Pending chip: `بانتظار المزامنة`. Gating message: `هذا الإجراء يتطلب اتصالًا بالإنترنت`. Offline save confirmation suffix: `— ستتم المزامنة عند عودة الاتصال`.
- Never `await` a Firestore write's server acknowledgement on an offline-capable save path; commit batches with `unawaited(...)`.
- Existing tests must keep passing: `flutter test test/unit test/widget` green after every task.
- `flutter analyze` clean after every task.
- Commit after every task (project convention: commit per workable milestone).

---

### Task 1: Explicit Firestore persistence configuration

**Files:**
- Modify: `lib/main.dart` (after `FirebaseEmulatorConfig.configureEmulators()`, ~line 44)

**Interfaces:**
- Consumes: nothing new.
- Produces: guaranteed disk persistence + unlimited cache for every repository.

- [x] **Step 1: Add settings assignment**

In `lib/main.dart` add import `package:cloud_firestore/cloud_firestore.dart`, then after `await FirebaseEmulatorConfig.configureEmulators();`:

```dart
  // Offline mode rests on Firestore's disk cache (see
  // docs/superpowers/specs/2026-07-19-offline-mode-design.md). Persistence is
  // the platform default on mobile but is pinned here so it can never silently
  // regress, and the cache is unbounded so LRU eviction cannot drop the
  // curriculum catalog a teacher needs in a halaqa with no connectivity.
  FirebaseFirestore.instance.settings = FirebaseFirestore.instance.settings
      .copyWith(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
```

`copyWith` (not a fresh `Settings(...)`) so emulator host/port settings applied by `configureEmulators()` survive. Check `lib/core/config/firebase_emulator_config.dart` first: if it assigns `.settings` itself, ensure this runs AFTER it and still preserves its fields.

- [x] **Step 2: Verify**

Run: `flutter analyze lib/main.dart` → no issues. Run: `flutter test test/unit` → all pass.

- [x] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(offline): pin Firestore persistence + unlimited cache"
```

---

### Task 2: Pending-sync flag on record models and history entries

**Files:**
- Modify: `lib/data/models/session_record_model.dart` (constructor + `fromFirestore` ~line 202)
- Modify: `lib/data/models/sard_record_model.dart` (constructor + `fromFirestore` ~line 75)
- Modify: `lib/data/models/exam_record_model.dart` (constructor + `fromFirestore` ~line 74)
- Modify: `lib/domain/session/student_history_entry.dart`
- Modify: `lib/data/repositories/session_repository.dart` (`getStudentHistory`, ~line 602)
- Test: `test/unit/repositories/session_repository_pending_sync_test.dart` (create)

**Interfaces:**
- Produces: `bool isPendingSync` (default `false`) on `SessionRecordModel`, `SardRecordModel`, `ExamRecordModel`, `StudentHistoryEntry`. NOT written by `toFirestore()`/`toJson()` — it is snapshot metadata, not data.

- [x] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';

void main() {
  test('history entries carry the record pending-sync flag', () async {
    // Constructed directly: fake_cloud_firestore cannot simulate a pending
    // write, so the propagation contract is asserted at the type level and
    // the mapping is asserted through the repository below.
    const entry = StudentHistoryEntry(
      id: 'r1',
      kind: StudentHistoryKind.lesson,
      levelId: 1,
      passed: true,
      date: null, // replace with DateTime(2026, 1, 1) — see model
      isPendingSync: true,
    );
    expect(entry.isPendingSync, isTrue);
  });

  test('synced records read back as not pending sync', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = SessionRepository(firestore: firestore);
    // Write any record through the fake, then read history.
    await firestore.collection('session_records').doc('r1').set({
      'student_id': 's1',
      'date': DateTime(2026, 1, 1),
      // ...minimum fields SessionRecordModel.fromFirestore requires — copy
      // the field set used by existing session_repository tests.
    });
    final history = await repo.getStudentHistory('s1');
    expect(history.single.isPendingSync, isFalse);
  });
}
```

Adjust the seeded map to the exact minimum `fromFirestore` needs — copy from an existing test in `test/unit` that seeds `session_records` (grep `session_records` under `test/`). Fix the `date:` placeholder to a real `DateTime`.

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/repositories/session_repository_pending_sync_test.dart`
Expected: FAIL — `isPendingSync` not defined.

- [x] **Step 3: Implement**

Each of the three models: add `final bool isPendingSync;` + constructor param `this.isPendingSync = false,`; in `fromFirestore` add `isPendingSync: doc.metadata.hasPendingWrites,`. If the model has `copyWith`, thread the field through. Do NOT touch `toFirestore`.

`StudentHistoryEntry`: add `final bool isPendingSync;` + `this.isPendingSync = false,`.

`SessionRepository.getStudentHistory`: add `isPendingSync: r.isPendingSync,` to all three entry mappings.

- [x] **Step 4: Run tests**

Run: `flutter test test/unit` → all pass (new + existing).

- [x] **Step 5: Commit**

```bash
git add lib/data/models lib/domain/session/student_history_entry.dart lib/data/repositories/session_repository.dart test/unit/repositories/session_repository_pending_sync_test.dart
git commit -m "feat(offline): expose hasPendingWrites as isPendingSync on records and history entries"
```

---

### Task 3: Offline-tolerant counts

**Files:**
- Modify: `lib/data/repositories/session_repository.dart` — `getAttemptCount` (~310), `getSardAttemptCount` (~406), `getExamAttemptCount` (~524), `getSessionCountForTeacher` (~546)
- Test: `test/unit/repositories/session_repository_offline_counts_test.dart` (create)

**Interfaces:**
- Signatures unchanged. Behavior: aggregation `.count()` is server-only; on `FirebaseException` fall back to counting the same query from `Source.cache`.

- [x] **Step 1: Write the failing test**

The fake cannot force an aggregation failure, so extract the shared fallback into a visible-for-testing helper and test the helper's fallback arm directly:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';

void main() {
  test('count falls back to cached query size when aggregation is unavailable', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('sard_records').add({
      'student_id': 's1', 'curriculum_session_id': 'c1',
    });
    await firestore.collection('sard_records').add({
      'student_id': 's1', 'curriculum_session_id': 'c1',
    });
    final repo = SessionRepository(firestore: firestore);
    final query = firestore
        .collection('sard_records')
        .where('student_id', isEqualTo: 's1')
        .where('curriculum_session_id', isEqualTo: 'c1');
    // Simulate the offline path: primary throws, fallback counts the cache.
    final n = await repo.countWithCacheFallback(
      query,
      primary: () async => throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    expect(n, 2);
  });

  test('sard attempt count still counts normally', () async {
    final firestore = FakeFireBaseFirestoreTypoGuard(); // see note
  });
}
```

Note: second test is a normal-path regression — write two sard records, call `repo.getSardAttemptCount(studentId: 's1', curriculumSessionId: 'c1')`, expect 2 (fake_cloud_firestore supports `count()`). Write it properly; the snippet above marks intent, not literal code.

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/repositories/session_repository_offline_counts_test.dart`
Expected: FAIL — `countWithCacheFallback` not defined.

- [x] **Step 3: Implement**

In `SessionRepository`:

```dart
  /// Counts [query]'s results via [primary] (an aggregation `.count()`, which
  /// is SERVER-ONLY), falling back to the size of the cached result set when
  /// the server is unreachable. The cache may under-count — acceptable for
  /// attempt numbering (attempts are numbered, never capped) and for profile
  /// statistics, both of which self-correct once back online.
  @visibleForTesting
  Future<int> countWithCacheFallback(
    Query<Map<String, dynamic>> query, {
    required Future<int> Function() primary,
  }) async {
    try {
      return await primary();
    } on FirebaseException {
      final cached = await query.get(const GetOptions(source: Source.cache));
      return cached.docs.length;
    }
  }
```

(Import `package:flutter/foundation.dart` for `@visibleForTesting` if not present.)

Rewrite the four count methods to route through it, e.g.:

```dart
  Future<int> getSardAttemptCount({
    required String studentId,
    required String curriculumSessionId,
  }) {
    final query = _sardRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .where('curriculum_session_id', isEqualTo: curriculumSessionId);
    return countWithCacheFallback(
      query,
      primary: () async => (await query.count().get()).count ?? 0,
    );
  }
```

Same shape for `getAttemptCount`, `getExamAttemptCount`, and `getSessionCountForTeacher` (keep its `startDate` filter on the query it builds). Leave `CurriculumRepository.getTotalSessionCount` alone — it has no callers in `lib/` outside the repo.

- [x] **Step 4: Run tests**

Run: `flutter test test/unit` → all pass.

- [x] **Step 5: Commit**

```bash
git add lib/data/repositories/session_repository.dart test/unit/repositories/session_repository_offline_counts_test.dart
git commit -m "feat(offline): count() aggregations fall back to cached query size offline"
```

---

### Task 4: WriteBatch support in SessionRepository create methods

**Files:**
- Modify: `lib/data/repositories/session_repository.dart` — `_writeSessionRecord` (~41), `createSessionRecord` (~70), `createTalqeenRecord` (~162), `createSardRecord` (~331), `createExamRecord` (~423)
- Test: `test/unit/repositories/session_repository_batch_test.dart` (create)

**Interfaces:**
- Produces: every create method gains optional `WriteBatch? batch`. With `batch`, the write is staged synchronously into the batch (nothing hits Firestore until the CALLER commits); without, behavior is unchanged. Return value is always the locally-built record.

- [x] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';

void main() {
  test('a batched sard record is staged, not written, until the batch commits', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = SessionRepository(firestore: firestore);
    final batch = firestore.batch();

    final record = await repo.createSardRecord(
      // copy a full valid argument set from an existing createSardRecord test
      // (grep createSardRecord under test/); pass batch: batch.
      batch: batch,
    );

    var docs = await firestore.collection('sard_records').get();
    expect(docs.docs, isEmpty, reason: 'staged writes must not land pre-commit');

    await batch.commit();
    docs = await firestore.collection('sard_records').get();
    expect(docs.docs.single.id, record.id);
  });
}
```

Add the mirror test for `createSessionRecord` (same pattern, `session_records` collection). Reuse argument sets from existing tests — `PacedSession`/`SardEvaluation` construction already appears in `test/unit`.

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/repositories/session_repository_batch_test.dart`
Expected: FAIL — no `batch` parameter.

- [x] **Step 3: Implement**

`_writeSessionRecord` gains `WriteBatch? batch`:

```dart
  Future<SessionRecordModel> _writeSessionRecord(
    SessionRecordModel Function(String id, DateTime writtenAt) build, {
    DateTime? now,
    WriteBatch? batch,
  }) async {
    final docRef = _sessionRecordsCollection.doc();
    final record = build(docRef.id, now ?? DateTime.now());
    if (batch != null) {
      // Staged into the caller's batch: nothing reaches Firestore (local
      // cache included) until the caller commits, which is what makes the
      // record + student-progress pair atomic under offline sync.
      batch.set(docRef, record.toFirestore());
    } else {
      await docRef.set(record.toFirestore());
    }
    return record;
  }
```

`createSessionRecord` and `createTalqeenRecord`: add `WriteBatch? batch,` parameter, pass `batch: batch` through to `_writeSessionRecord`.

`createSardRecord` / `createExamRecord`: add `WriteBatch? batch,`; replace `await docRef.set(record.toFirestore());` with the same `if (batch != null) { batch.set(docRef, record.toFirestore()); } else { await docRef.set(record.toFirestore()); }`.

- [x] **Step 4: Run tests**

Run: `flutter test test/unit` → all pass.

- [x] **Step 5: Commit**

```bash
git add lib/data/repositories/session_repository.dart test/unit/repositories/session_repository_batch_test.dart
git commit -m "feat(offline): session/sard/exam record creation can stage into a caller-owned WriteBatch"
```

---

### Task 5: WriteBatch support in StudentRepository progress writes

**Files:**
- Modify: `lib/data/repositories/student_repository.dart` — `advanceStudentSession` (~701), `incrementStudentAttempt` (~862)
- Test: `test/unit/repositories/student_repository_batch_test.dart` (create)

**Interfaces:**
- Produces: `advanceStudentSession(String studentId, {int? fromOrderInLevel, WriteBatch? batch})` and `incrementStudentAttempt(String studentId, {WriteBatch? batch})`. Reads (student, curriculum walk) still run inside the method; only the final `update` is staged when `batch` is given. Outcome enum is computed and returned exactly as today.

- [x] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';

void main() {
  test('a batched advance stages the position update until commit', () async {
    final firestore = FakeFirebaseFirestore();
    // Seed a student + a next curriculum session — copy the seeding helper
    // from the existing advanceStudentSession tests (grep advanceStudentSession
    // under test/unit).
    final repo = /* construct as the existing tests do */;
    final batch = firestore.batch();

    final outcome = await repo.advanceStudentSession('s1', batch: batch);
    expect(outcome, StudentAdvanceOutcome.advanced);

    var doc = await firestore.collection('students').doc('s1').get();
    expect(doc.data()!['current_order_in_level'], 1, reason: 'not yet committed');

    await batch.commit();
    doc = await firestore.collection('students').doc('s1').get();
    expect(doc.data()!['current_order_in_level'], 2);
  });

  test('a batched attempt increment stages until commit', () async {
    // Same shape with incrementStudentAttempt + current_attempt.
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/repositories/student_repository_batch_test.dart`
Expected: FAIL — no `batch` parameter.

- [x] **Step 3: Implement**

Add a private write helper:

```dart
  /// Applies a `students/{id}` update directly, or stages it into [batch] so
  /// it lands atomically with the session record the caller is saving.
  Future<void> _updateStudent(
    String studentId,
    Map<String, dynamic> data,
    WriteBatch? batch,
  ) async {
    final doc = _studentsCollection.doc(studentId);
    if (batch != null) {
      batch.update(doc, data);
    } else {
      await doc.update(data);
    }
  }
```

`advanceStudentSession(String studentId, {int? fromOrderInLevel, WriteBatch? batch})`: replace both `await _studentsCollection.doc(studentId).update({...})` calls (the `_CurriculumCompleted` and `_Advanced` arms) with `await _updateStudent(studentId, {...}, batch);` — maps unchanged.

`incrementStudentAttempt(String studentId, {WriteBatch? batch})`: same replacement.

- [x] **Step 4: Run tests**

Run: `flutter test test/unit` → all pass.

- [x] **Step 5: Commit**

```bash
git add lib/data/repositories/student_repository.dart test/unit/repositories/student_repository_batch_test.dart
git commit -m "feat(offline): student progress writes can stage into a caller-owned WriteBatch"
```

---

### Task 6: Atomic, no-await teacher session saves

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart` — `completeSession` (~377), `completeTalqeenSession` (~459)
- Test: `test/unit/providers/teacher_provider_offline_save_test.dart` (create); existing `teacher_provider_test.dart` / `teacher_provider_talqeen_test.dart` must keep passing.

**Interfaces:**
- Consumes: Task 4's `createSessionRecord/createTalqeenRecord(batch:)`, Task 5's `advanceStudentSession/incrementStudentAttempt(batch:)`, `firestoreProvider` from `lib/data/services/firebase_service.dart`.
- Produces: `completeSession`/`completeTalqeenSession` return the record without awaiting server ack; record + progress land in ONE batch.

- [x] **Step 1: Write the failing test**

Use the existing `teacher_provider_test.dart` harness (ProviderContainer + FakeFirebaseFirestore overrides) as the template:

```dart
  test('completing a session lands record and advancement atomically via one batch', () async {
    // Arrange exactly as the existing completeSession pass-case test does.
    final record = await notifier.completeSession();
    // Both effects observable after the call (fake commits resolve
    // immediately); the atomicity contract is the single batch, asserted by
    // the repository batch tests — here we assert the wiring end-to-end:
    final recordDoc = await firestore.collection('session_records').doc(record!.id).get();
    expect(recordDoc.exists, isTrue);
    final studentDoc = await firestore.collection('students').doc(studentId).get();
    expect(studentDoc.data()!['current_order_in_level'], greaterThan(startOrder));
  });
```

The genuinely new assertion: `completeSession` must NOT await `batch.commit()`. Enforce by construction (code review of the diff) + a widget-independent timing test is impractical with the fake (commits are synchronous) — rely on the never-completing-commit repository test pattern only if `fake_cloud_firestore` allows injecting a hanging commit; otherwise the fire-and-forget property is guarded by the `unawaited(...)` lint (`unawaited_futures` is analyzer-enforced when the expression is awaited-typed) and the manual airplane-mode matrix.

- [x] **Step 2: Run to verify current behavior compiles the test**

Run: `flutter test test/unit/providers/teacher_provider_offline_save_test.dart`
Expected: PASS already (it tests outcome, not mechanism) — acceptable; it becomes the regression net for the rewrite.

- [x] **Step 3: Rewrite the save methods**

In `completeSession`, replace the sequential-await block (record create → advance/increment) with:

```dart
    final firestore = ref.read(firestoreProvider);
    final batch = firestore.batch();

    final record = await sessionRepo.createSessionRecord(
      /* existing args unchanged */
      batch: batch,
    );

    StudentAdvanceOutcome? advanceOutcome;
    if (record.passed) {
      advanceOutcome = await studentRepo.advanceStudentSession(
        student.id,
        fromOrderInLevel: meeting.toOrderInLevel,
        batch: batch,
      );
    } else {
      await studentRepo.incrementStudentAttempt(student.id, batch: batch);
    }

    // Commit fire-and-forget: Firestore applies the batch to the local cache
    // immediately and queues it for sync. Awaiting here would hang the save
    // UI forever offline — the Future only completes on server ack.
    unawaited(
      batch.commit().catchError((Object e, StackTrace s) {
        debugPrint('session save sync failed: $e');
      }),
    );
```

Imports: `dart:async` (unawaited), `package:flutter/foundation.dart` (debugPrint) — check what's already imported.

Only-if-advance-succeeded subtlety: with a `curriculumDataMissing`/`studentNotFound` outcome nothing was staged for the student — the batch still commits the record alone, which is exactly today's behavior (record saved, progress untouched, caller warned via `advanceOutcome`).

Same rewrite in `completeTalqeenSession` (`createTalqeenRecord` + unconditional `advanceStudentSession`).

- [x] **Step 4: Run tests**

Run: `flutter test test/unit` → all pass (including existing provider tests).

- [x] **Step 5: Commit**

```bash
git add lib/features/teacher/providers/teacher_provider.dart test/unit/providers/teacher_provider_offline_save_test.dart
git commit -m "feat(offline): teacher session saves commit one batch, never await server ack"
```

---

### Task 7: Atomic, no-await sard & exam saves with offline-aware confirmation

**Files:**
- Modify: `lib/features/teacher/screens/sard_result_screen.dart` — `_saveSard` (~49)
- Modify: `lib/features/supervisor/screens/exam_result_screen.dart` — `_saveExam` (~59)

**Interfaces:**
- Consumes: Tasks 3–5 (`getSardAttemptCount`/`getExamAttemptCount` now offline-tolerant; `createSardRecord/createExamRecord(batch:)`; `advanceStudentSession/incrementStudentAttempt(batch:)`), `firestoreProvider`, `isConnectedProvider` from `lib/shared/providers/connectivity_provider.dart`.

- [x] **Step 1: Rewrite both save handlers**

Same batch pattern as Task 6, applied to `_saveSard` and `_saveExam`:

```dart
      final batch = ref.read(firestoreProvider).batch();
      final record = await sessionRepo.createSardRecord(
        /* existing args */, batch: batch,
      );
      StudentAdvanceOutcome? advanceOutcome;
      if (record.passed) {
        advanceOutcome = await studentRepo.advanceStudentSession(student.id, batch: batch);
      } else {
        await studentRepo.incrementStudentAttempt(student.id, batch: batch);
      }
      unawaited(
        batch.commit().catchError((Object e, StackTrace s) {
          debugPrint('sard save sync failed: $e');
        }),
      );
```

Then adapt the success snackbar copy: read `final isOnline = ref.read(isConnectedProvider);` and when `!isOnline`, append the offline suffix to the chosen message, e.g. `'$message — ستتم المزامنة عند عودة الاتصال'`. Apply to all success branches in both screens (not the failure/`catch` branch).

- [x] **Step 2: Widget tests still pass**

Run: `flutter test test/widget test/unit` → all pass. (No existing widget test drives these two save paths end-to-end; the repository/provider tests cover the mechanics.)

- [x] **Step 3: Commit**

```bash
git add lib/features/teacher/screens/sard_result_screen.dart lib/features/supervisor/screens/exam_result_screen.dart
git commit -m "feat(offline): sard and exam saves batch atomically and confirm offline saves honestly"
```

---

### Task 8: Global offline banner

**Files:**
- Create: `lib/shared/widgets/offline_banner.dart`
- Modify: `lib/app.dart` (builder, ~line 33)
- Test: `test/widget/offline_banner_test.dart` (create)

**Interfaces:**
- Consumes: `isConnectedProvider`.
- Produces: `OfflineBannerHost({required Widget child})` — wraps the app content; shows a slim top banner when offline.

- [x] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/providers/connectivity_provider.dart';
import 'package:al_rasikhoon/shared/widgets/offline_banner.dart';

void main() {
  Widget host({required bool online}) => ProviderScope(
        overrides: [isConnectedProvider.overrideWithValue(online)],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: OfflineBannerHost(child: Scaffold(body: Text('محتوى'))),
          ),
        ),
      );

  testWidgets('banner shows offline', (tester) async {
    await tester.pumpWidget(host(online: false));
    expect(find.textContaining('أنت غير متصل'), findsOneWidget);
  });

  testWidgets('banner hidden online', (tester) async {
    await tester.pumpWidget(host(online: true));
    expect(find.textContaining('أنت غير متصل'), findsNothing);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/offline_banner_test.dart`
Expected: FAIL — `offline_banner.dart` doesn't exist.

- [x] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// Wraps the whole app (mounted in [AlRasikhoonApp]'s builder) and shows a
/// slim banner while the device has no network. Every role sees it — offline
/// browsing is app-wide, and the offline-capable saves tell the user their
/// work syncs later.
class OfflineBannerHost extends ConsumerWidget {
  final Widget child;
  const OfflineBannerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isConnectedProvider);
    return Column(
      children: [
        if (!isOnline)
          Material(
            color: /* use the design system's warning hue — context.tokens.gold
                      per existing usage in exam_result_screen; import the
                      tokens extension the way that screen does */,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'أنت غير متصل — سيتم الحفظ محليًا والمزامنة لاحقًا',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
```

Resolve the token color/text style against `lib/core/theme/app_tokens.dart` (match how `context.tokens` is accessed elsewhere; pick gold background with a readable on-gold text color from the tokens). In `lib/app.dart`:

```dart
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SplashOverlay(child: OfflineBannerHost(child: child!)),
        );
      },
```

- [x] **Step 4: Run tests**

Run: `flutter test test/widget/offline_banner_test.dart` → PASS. `flutter test test/widget` → all pass.

- [x] **Step 5: Commit**

```bash
git add lib/shared/widgets/offline_banner.dart lib/app.dart test/widget/offline_banner_test.dart
git commit -m "feat(offline): global offline banner for all roles"
```

---

### Task 9: Pending-sync chip in history and summary confirmation

**Files:**
- Modify: `lib/shared/screens/student_progress_screen.dart` (renders `StudentHistoryEntry` rows — locate the row widget and add the chip)
- Modify: `lib/features/teacher/screens/session_summary_screen.dart` (`_saveSession` success message)
- Test: `test/widget/history_pending_chip_test.dart` (create)

**Interfaces:**
- Consumes: Task 2's `StudentHistoryEntry.isPendingSync`, `isConnectedProvider`.

- [x] **Step 1: Write the failing widget test**

Pump the history row widget (extract the row into a small public widget if it is currently inline and untestable — prefer the smallest extraction that lets the test pump one row) with an entry where `isPendingSync: true`; expect `find.text('بانتظار المزامنة')` → one widget; with `false` → none.

- [x] **Step 2: Run test to verify it fails**, implement the chip

A small `Chip`/container next to the row's date or status, shown only when `entry.isPendingSync`, styled from tokens (muted/secondary, not alarming). Label: `بانتظار المزامنة`.

- [x] **Step 3: Session summary confirmation copy**

In `session_summary_screen.dart`'s save handler, mirror Task 7: when `!ref.read(isConnectedProvider)`, append ` — ستتم المزامنة عند عودة الاتصال` to the success snackbar/message.

- [x] **Step 4: Run tests**

Run: `flutter test test/widget test/unit` → all pass.

- [x] **Step 5: Commit**

```bash
git add lib/shared/screens/student_progress_screen.dart lib/features/teacher/screens/session_summary_screen.dart test/widget/history_pending_chip_test.dart
git commit -m "feat(offline): pending-sync chip on history rows and offline-aware save confirmation"
```

---

### Task 10: Role-aware cache primer and reconnect controller

**Files:**
- Create: `lib/data/services/offline_cache_primer.dart`
- Create: `lib/shared/providers/offline_sync_provider.dart`
- Modify: `lib/app.dart` (activate the controller)
- Test: `test/unit/services/offline_cache_primer_test.dart` (create)

**Interfaces:**
- Consumes: `StudentRepository` (`getStudentsForTeacher`, `getStudentsForInstitutes`, `getStudentsReadyForExam`, `getAllStudents`, `getStudentByUserId`), `CurriculumRepository` (`getLevels`, `getSessionsForLevel`), `SessionRepository` (`getLatestSessionRecord`, `getStudentHistory`, `getExamRecordsForSupervisor`), `InstituteRepository` (`getInstitutes`, `getInstitutesForSupervisor`), `UserRepository` (`getTeachers`, `getSupervisors`), `UserModel.role` (`UserRole` enum: `superAdmin, supervisor, teacher, student, guardian`), `currentUserProvider` (`lib/shared/providers/user_provider.dart`), `isConnectedProvider`.
- Produces: `OfflineCachePrimer.prime(UserModel user)`; `offlineSyncControllerProvider` (a `Provider<void>` watched once in `app.dart`).

- [x] **Step 1: Write the failing test**

```dart
  test('teacher priming touches students, curriculum, and recent history', () async {
    final firestore = FakeFirebaseFirestore();
    // Seed: one teacher user, one active student on level 1, a level-1 and
    // level-2 curriculum session, one session record. Copy seeding helpers
    // from existing repository tests.
    final primer = OfflineCachePrimer(
      studentRepository: ..., curriculumRepository: ...,
      sessionRepository: ..., instituteRepository: ..., userRepository: ...,
    );
    await primer.prime(teacherUser);
    // The fake can't observe cache warmth; the contract under test is that
    // priming completes without throwing and issues the reads for the
    // student's own and next level.
  });

  test('priming never throws, even when reads fail', () async {
    // Construct with a firestore seeded with nothing / a repo that throws
    // (e.g. missing composite data) and assert prime() completes normally.
    await expectLater(primer.prime(user), completes);
  });
```

- [x] **Step 2: Run test to verify it fails**, implement

```dart
/// Warms Firestore's disk cache with the data each role needs offline
/// (spec §2). Purely opportunistic: every read is best-effort, failures are
/// swallowed — an unprimed cache degrades to the screens' own empty states.
class OfflineCachePrimer {
  final StudentRepository _studentRepository;
  final CurriculumRepository _curriculumRepository;
  final SessionRepository _sessionRepository;
  final InstituteRepository _instituteRepository;
  final UserRepository _userRepository;

  OfflineCachePrimer({required ...}) : ...;

  Future<void> prime(UserModel user) async {
    try {
      switch (user.role) {
        case UserRole.teacher:
          await _primeTeacher(user.id);
        case UserRole.supervisor:
          await _primeSupervisor(user.id);
        case UserRole.superAdmin:
          await _primeAdmin();
        case UserRole.student:
        case UserRole.guardian:
          await _primeStudent(user.id);
      }
    } catch (_) {
      // Opportunistic by design — never surface priming failures.
    }
  }

  Future<void> _primeTeacher(String teacherId) async {
    final students = await _studentRepository.getStudentsForTeacher(teacherId);
    await _curriculumRepository.getLevels();
    final levels = <int>{
      for (final s in students) s.student.currentLevel,
      // The level ahead too, so an advancement crossing a level boundary
      // still resolves offline.
      for (final s in students)
        if (s.student.currentLevel < CurriculumPosition.totalLevels)
          s.student.currentLevel + 1,
    };
    for (final level in levels) {
      await _curriculumRepository.getSessionsForLevel(level: level);
    }
    for (final s in students) {
      await _sessionRepository.getLatestSessionRecord(s.student.id);
      await _sessionRepository.getStudentHistory(s.student.id, limit: 20);
    }
  }

  Future<void> _primeSupervisor(String supervisorId) async {
    final institutes =
        await _instituteRepository.getInstitutesForSupervisor(supervisorId);
    final ids = [for (final i in institutes) i.id];
    final students = await _studentRepository.getStudentsForInstitutes(ids);
    for (final id in ids) {
      await _studentRepository.getStudentsReadyForExam(id);
    }
    await _curriculumRepository.getLevels();
    final levels = <int>{for (final s in students) s.student.currentLevel};
    for (final level in levels) {
      await _curriculumRepository.getSessionsForLevel(level: level);
    }
    await _sessionRepository.getExamRecordsForSupervisor(supervisorId);
  }

  Future<void> _primeAdmin() async {
    await _instituteRepository.getInstitutes();
    await _studentRepository.getAllStudents();
    await _userRepository.getTeachers();
    await _userRepository.getSupervisors();
  }

  Future<void> _primeStudent(String userId) async {
    final student = await _studentRepository.getStudentByUserId(userId);
    if (student == null) return;
    await _curriculumRepository.getLevels();
    await _curriculumRepository.getSessionsForLevel(level: student.currentLevel);
    await _sessionRepository.getLatestSessionRecord(student.id);
    await _sessionRepository.getStudentHistory(student.id, limit: 50);
  }
}
```

(Check `getStudentsForInstitutes`'s exact parameter shape at ~`student_repository.dart:530` and `CurriculumPosition.totalLevels` import path before writing.) Guardian note: `_primeStudent(user.id)` primes a guardian only if `getStudentByUserId` resolves their child; if the guardian dashboard resolves the child another way (`currentStudentProvider` in `lib/features/student/providers/student_provider.dart`), mirror that resolution instead — check during implementation.

`offline_sync_provider.dart`:

```dart
final offlineCachePrimerProvider = Provider<OfflineCachePrimer>((ref) {
  return OfflineCachePrimer(
    studentRepository: ref.watch(studentRepositoryProvider),
    curriculumRepository: ref.watch(curriculumRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    instituteRepository: ref.watch(instituteRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});

/// Watched once from the app root. Primes the cache when a user is present
/// and online; re-primes and refreshes stale views on every offline→online
/// transition (also what clears the pending-sync chips, spec §4).
final offlineSyncControllerProvider = Provider<void>((ref) {
  void primeNow() {
    final user = ref.read(currentUserProvider);
    if (user != null && ref.read(isConnectedProvider)) {
      unawaited(ref.read(offlineCachePrimerProvider).prime(user));
    }
  }

  ref.listen(currentUserProvider, (previous, next) {
    if (previous?.id != next?.id && next != null) primeNow();
  });

  ref.listen(isConnectedProvider, (previous, next) {
    if (previous == false && next == true) {
      primeNow();
      // Refresh views that may show stale/pending records. Family-wide
      // invalidation: every member refetches.
      ref.invalidate(teacherStudentsProvider);
      ref.invalidate(studentProvider);
      ref.invalidate(teacherStudentSessionHistoryProvider);
      ref.invalidate(examQueueProvider);
      ref.invalidate(supervisorStudentSessionHistoryProvider);
      ref.invalidate(studentHistoryProvider);
    }
  });

  primeNow();
});
```

(Verify each invalidated provider's exact name/import; `supervisorStudentSessionHistoryProvider` lives in `lib/features/supervisor/providers/supervisor_provider.dart`, `studentHistoryProvider` in `lib/features/student/providers/student_provider.dart`.) In `lib/app.dart` `build`, add `ref.watch(offlineSyncControllerProvider);` before constructing the router.

- [x] **Step 3: Run tests**

Run: `flutter test test/unit` → all pass. `flutter analyze` → clean.

- [x] **Step 4: Commit**

```bash
git add lib/data/services/offline_cache_primer.dart lib/shared/providers/offline_sync_provider.dart lib/app.dart test/unit/services/offline_cache_primer_test.dart
git commit -m "feat(offline): role-aware cache priming on login and reconnect"
```

---

### Task 11: Online-only gating for management actions

**Files:**
- Create: `lib/shared/utils/connectivity_guard.dart`
- Modify: submit handlers in `lib/features/teacher/screens/add_student_screen.dart`, `lib/features/admin/screens/add_teacher_screen.dart`, `lib/features/admin/screens/add_supervisor_screen.dart`, `lib/features/admin/screens/create_institute_screen.dart`, `lib/features/admin/screens/edit_institute_screen.dart`
- Test: `test/unit/utils/connectivity_guard_test.dart` (create — or a widget test if the helper needs a BuildContext)

**Interfaces:**
- Produces: `bool ensureOnline(BuildContext context, WidgetRef ref)` — `true` when online; otherwise shows the gating snackbar and returns `false`.

- [x] **Step 1: Implement helper + failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// Guards an online-only action (spec §5: management writes and Cloud
/// Function calls). Call at the top of the submit handler:
/// `if (!ensureOnline(context, ref)) return;`
bool ensureOnline(BuildContext context, WidgetRef ref) {
  if (ref.read(isConnectedProvider)) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('هذا الإجراء يتطلب اتصالًا بالإنترنت')),
  );
  return false;
}
```

Widget test: a button whose onPressed calls `ensureOnline`; offline override → snackbar text appears and a probe flag stays false; online → flag true, no snackbar.

- [x] **Step 2: Apply to the five screens**

First line of each screen's save/submit handler: `if (!ensureOnline(context, ref)) return;` (locate each handler — grep `onPressed`/`_save`/`_submit` in each file; they are `ConsumerState` classes so `ref` is available).

- [x] **Step 3: Run tests, analyze**

Run: `flutter test test/widget test/unit` → all pass. `flutter analyze` → clean.

- [x] **Step 4: Commit**

```bash
git add lib/shared/utils/connectivity_guard.dart lib/features/teacher/screens/add_student_screen.dart lib/features/admin/screens test/
git commit -m "feat(offline): gate management actions on connectivity with a clear message"
```

---

### Task 12: Changelog, quality gates, close-out

**Files:**
- Modify: `CHANGELOG.md` (top `## Unreleased` section)

- [x] **Step 1: Changelog entry**

Add under `## Unreleased`:

```markdown
- The app now works without internet at the institute — everyone can browse
  the latest data offline, teachers can run memorization sessions, supervisors
  can run exams, and everything syncs automatically when the connection
  returns. A banner shows when you are offline, and unsynced sessions are
  marked "بانتظار المزامنة" until they reach the server.
```

- [x] **Step 2: Full quality gates**

Run: `flutter analyze` → clean. Run: `flutter test` → all pass (unit + widget; skip e2e/rules unless they run locally today — check how CI invokes them).

- [x] **Step 3: Manual verification matrix (from spec §8)**

If an emulator/device is available: online open → airplane mode → browse → run memorization + سرد → pending chips → reconnect → records in Firestore, chips cleared. Otherwise record in the beads issue that device verification is pending.

- [x] **Step 4: Close out**

```bash
bd close al_rasikhoon-15s
git add CHANGELOG.md
git commit -m "docs(changelog): offline mode support"
```

Then session close protocol: `git status` clean, `bd dolt pull`, merge/hand-off per worktree conventions.
