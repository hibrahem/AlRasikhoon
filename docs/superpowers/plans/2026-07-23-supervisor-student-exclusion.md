# Supervisor Student Exclusion (مستبعد) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supervisors and admins can mark a student مستبعد (excluded from teaching) with an optional reason; excluded students vanish from teacher lists but stay visible (badged) to supervisors/admins, who can restore them.

**Architecture:** A new framework-free `StudentStatus` enum (`active`/`excluded`, extensible to `paused`) is persisted as a `status` string on the student document — missing/unknown reads back as `active`, so legacy documents need no migration. `StudentRepository.setStudentStatus` enforces authorization (admin anywhere; supervisor only within their `supervisor_institutes` membership) and batch-writes the student update together with an immutable `students/{id}/status_audit` entry. Teacher-facing queries post-filter excluded students (the `curriculum_completed` precedent); a shared dialog with an optional reason field drives the toggle from the supervisor and admin screens.

**Tech Stack:** Flutter, Riverpod, cloud_firestore, fake_cloud_firestore + mocktail for tests, Firestore security rules.

**Spec:** `docs/superpowers/specs/2026-07-23-supervisor-student-exclusion-design.md` — Beads issue **al_rasikhoon-zg1r**.

## Global Constraints

- Project uses beads (`bd`) for task tracking, NOT TodoWrite/markdown TODOs.
- All commands run from the repo worktree root: `/Users/hassanibrahim/Documents/Projects/AlRasikhoonProject/al_rasikhoon/.claude/worktrees/supervisor-student-exclusion-456cf5`.
- Domain layer (`lib/domain/`) must have zero framework imports (no cloud_firestore, no Flutter).
- Firestore field keys are snake_case: `status`, `status_reason`, `status_changed_at`, `status_changed_by`.
- Enum string values persisted to Firestore: `'active'`, `'excluded'`. Arabic labels: `نشط`, `مستبعد`.
- A missing or unknown `status` value MUST read back as `StudentStatus.active` (no migration; mirrors `curriculum_completed`).
- UI strings are inline Arabic literals (matching the existing supervisor/admin screens), NOT ARB keys.
- Test names use domain language (e.g. `test('an excluded student disappears from the teacher list', ...)`).
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` and reference `al_rasikhoon-zg1r`.
- The `is_active` soft-delete flag is NOT touched by this feature.

---

### Task 1: Domain — `StudentStatus` enum and authorization exception

**Files:**
- Create: `lib/domain/student/student_status.dart`
- Create: `lib/domain/student/student_status_exceptions.dart`
- Test: `test/unit/domain/student/student_status_test.dart`

**Interfaces:**
- Consumes: nothing (pure domain).
- Produces: `enum StudentStatus { active, excluded }`; extension `StudentStatusX` with `String get value`, `String get labelAr`, `String get labelEn`, and `static StudentStatus fromString(String? value)`; `class StudentStatusChangeNotAuthorizedException implements Exception` with `final String reason` and a `const` constructor.

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/student/student_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/student/student_status.dart';

void main() {
  group('StudentStatus', () {
    test('persists as the snake-case wire values active/excluded', () {
      expect(StudentStatus.active.value, 'active');
      expect(StudentStatus.excluded.value, 'excluded');
    });

    test('every status round-trips through its wire value', () {
      for (final status in StudentStatus.values) {
        expect(StudentStatusX.fromString(status.value), status);
      }
    });

    test('a student document without a status reads as active', () {
      expect(StudentStatusX.fromString(null), StudentStatus.active);
    });

    test('an unknown status value reads as active rather than crashing', () {
      // A newer app version may write a state (e.g. paused) this version
      // does not know; the safe reading is "not excluded".
      expect(StudentStatusX.fromString('paused'), StudentStatus.active);
      expect(StudentStatusX.fromString(''), StudentStatus.active);
    });

    test('carries the Arabic labels the UI shows', () {
      expect(StudentStatus.active.labelAr, 'نشط');
      expect(StudentStatus.excluded.labelAr, 'مستبعد');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/domain/student/student_status_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'al_rasikhoon/domain/student/student_status.dart'` (file does not exist).

- [ ] **Step 3: Write the implementation**

Create `lib/domain/student/student_status.dart`:

```dart
/// The student's TEACHING status (al_rasikhoon-zg1r) — orthogonal to the
/// `is_active` soft-delete flag, which means "this record exists at all".
///
/// - [active] (نشط): the normal state; the student appears in their teacher's
///   lists and queues.
/// - [excluded] (مستبعد): a supervisor or admin has stopped the student from
///   being taught. The student vanishes from every teacher-facing list but
///   stays visible — badged — to supervisors and admins, who may restore them
///   at any time. The student keeps their teacher assignment and their own
///   app access; exclusion hides, it does not detach.
///
/// Designed to grow: a future state (e.g. paused) is one more enum case, and
/// [StudentStatusX.fromString] already reads any value this version does not
/// know as [active] — "not excluded" is the only safe guess for an unknown
/// state written by a newer app.
enum StudentStatus { active, excluded }

extension StudentStatusX on StudentStatus {
  /// The snake-case wire value persisted in the student document's `status`
  /// field.
  String get value {
    switch (this) {
      case StudentStatus.active:
        return 'active';
      case StudentStatus.excluded:
        return 'excluded';
    }
  }

  String get labelAr {
    switch (this) {
      case StudentStatus.active:
        return 'نشط';
      case StudentStatus.excluded:
        return 'مستبعد';
    }
  }

  String get labelEn {
    switch (this) {
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.excluded:
        return 'Excluded';
    }
  }

  /// Reads a stored status. Null (legacy documents predate the field) and
  /// unknown values (written by a newer app version) both read as [active]:
  /// hiding a student from their teacher is an explicit act, never a guess —
  /// mirrors how a missing `curriculum_completed` reads as "not graduated".
  static StudentStatus fromString(String? value) {
    switch (value) {
      case 'excluded':
        return StudentStatus.excluded;
      default:
        return StudentStatus.active;
    }
  }
}
```

Create `lib/domain/student/student_status_exceptions.dart`:

```dart
/// Business-rule violation raised when someone who is neither an admin nor a
/// supervisor of the student's institute tries to change the student's
/// teaching status (al_rasikhoon-zg1r).
///
/// The invariant is enforced in [StudentRepository.setStudentStatus] — the
/// authoritative path — because a stale UI must not be trusted to have
/// checked, mirroring [RepositionNotAuthorizedException].
class StudentStatusChangeNotAuthorizedException implements Exception {
  final String reason;

  const StudentStatusChangeNotAuthorizedException(this.reason);

  @override
  String toString() => 'StudentStatusChangeNotAuthorizedException: $reason';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/domain/student/student_status_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/student/ test/unit/domain/student/
git commit -m "feat(domain): StudentStatus enum for teaching status نشط/مستبعد (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Model — status fields on `StudentModel`

**Files:**
- Modify: `lib/data/models/student_model.dart`
- Test: `test/unit/data/models/student_model_test.dart` (append a group)

**Interfaces:**
- Consumes: `StudentStatus` / `StudentStatusX` from Task 1.
- Produces: `StudentModel.status` (`StudentStatus`, defaults `active`), `StudentModel.statusReason` (`String?`), `StudentModel.statusChangedAt` (`DateTime?`), `StudentModel.statusChangedBy` (`String?`), and getter `bool get isExcluded`. All four fields flow through the constructor, `fromJson`, `toFirestore`, and `copyWith`. Wire keys: `status`, `status_reason`, `status_changed_at`, `status_changed_by`.

- [ ] **Step 1: Write the failing tests**

Append this group inside `main()` at the end of `test/unit/data/models/student_model_test.dart` (before the closing `}` of `main`). If the existing file's imports lack `cloud_firestore` or `student_status.dart`, add them:

```dart
  group('teaching status (مستبعد)', () {
    Map<String, dynamic> baseJson() => {
      'user_id': 'u1',
      'institute_id': 'i1',
      'current_session_kind': 'lesson',
      'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
    };

    test('a student document without a status field reads as active', () {
      final student = StudentModel.fromJson('s1', baseJson());
      expect(student.status, StudentStatus.active);
      expect(student.isExcluded, isFalse);
      expect(student.statusReason, isNull);
      expect(student.statusChangedAt, isNull);
      expect(student.statusChangedBy, isNull);
    });

    test('an excluded student round-trips with reason, actor and time', () {
      final changedAt = DateTime(2026, 7, 23, 10, 30);
      final student = StudentModel.fromJson('s1', {
        ...baseJson(),
        'status': 'excluded',
        'status_reason': 'غياب متكرر',
        'status_changed_at': Timestamp.fromDate(changedAt),
        'status_changed_by': 'sup1',
      });

      expect(student.status, StudentStatus.excluded);
      expect(student.isExcluded, isTrue);
      expect(student.statusReason, 'غياب متكرر');
      expect(student.statusChangedAt, changedAt);
      expect(student.statusChangedBy, 'sup1');

      final written = student.toFirestore();
      expect(written['status'], 'excluded');
      expect(written['status_reason'], 'غياب متكرر');
      expect(written['status_changed_at'], Timestamp.fromDate(changedAt));
      expect(written['status_changed_by'], 'sup1');
    });

    test('a freshly constructed student is active and writes active', () {
      final student = StudentModel(
        id: 's1',
        userId: 'u1',
        instituteId: 'i1',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(student.status, StudentStatus.active);
      expect(student.toFirestore()['status'], 'active');
    });

    test('copyWith can exclude and restore', () {
      final student = StudentModel(
        id: 's1',
        userId: 'u1',
        instituteId: 'i1',
        createdAt: DateTime(2026, 1, 1),
      );
      final excluded = student.copyWith(
        status: StudentStatus.excluded,
        statusReason: 'سبب',
        statusChangedBy: 'sup1',
      );
      expect(excluded.isExcluded, isTrue);
      expect(excluded.statusReason, 'سبب');
      // Unrelated fields survive.
      expect(excluded.instituteId, 'i1');
    });
  });
```

Required imports at the top of the test file (add any that are missing):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:al_rasikhoon/domain/student/student_status.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/data/models/student_model_test.dart`
Expected: FAIL — compile errors: `No named parameter with the name 'status'` / undefined getter `status`.

- [ ] **Step 3: Implement the model fields**

In `lib/data/models/student_model.dart`:

3a. Add the import (with the other domain imports at the top):

```dart
import '../../domain/student/student_status.dart';
```

3b. Add fields after the `meetingsPerWeek` field declaration (~line 90):

```dart
  /// The student's teaching status (al_rasikhoon-zg1r): نشط or مستبعد.
  /// Orthogonal to [isActive] (soft-delete). An excluded student is hidden
  /// from every teacher-facing list but stays visible to supervisors and
  /// admins. Missing on legacy documents; reads back as [StudentStatus.active].
  final StudentStatus status;

  /// Why the status was last changed — the optional free-text the supervisor
  /// or admin typed. The full history lives in the `status_audit`
  /// subcollection; this is the latest word, denormalized for display.
  final String? statusReason;

  /// When the status last changed. Null until the first change.
  final DateTime? statusChangedAt;

  /// Who last changed the status (user id). Null until the first change.
  final String? statusChangedBy;
```

3c. Add constructor parameters (in the main constructor's parameter list, after `this.curriculumCompletedAt,`):

```dart
    this.status = StudentStatus.active,
    this.statusReason,
    this.statusChangedAt,
    this.statusChangedBy,
```

3d. In `fromJson`, after the `curriculumCompletedAt:` argument:

```dart
      // Absent on every document written before the exclusion feature; an
      // unknown value may be written by a NEWER app version. Both read as
      // active — hiding a student from their teacher is explicit, never
      // guessed (same discipline as curriculum_completed above).
      status: StudentStatusX.fromString(data['status'] as String?),
      statusReason: data['status_reason'] as String?,
      statusChangedAt: (data['status_changed_at'] as Timestamp?)?.toDate(),
      statusChangedBy: data['status_changed_by'] as String?,
```

3e. In `toFirestore()`, after the `'curriculum_completed_at':` entry:

```dart
      'status': status.value,
      'status_reason': statusReason,
      'status_changed_at': statusChangedAt != null
          ? Timestamp.fromDate(statusChangedAt!)
          : null,
      'status_changed_by': statusChangedBy,
```

3f. In `copyWith`, add parameters after `DateTime? curriculumCompletedAt,`:

```dart
    StudentStatus? status,
    String? statusReason,
    DateTime? statusChangedAt,
    String? statusChangedBy,
```

…and in the returned constructor call, after `curriculumCompletedAt: ...`:

```dart
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      statusChangedBy: statusChangedBy ?? this.statusChangedBy,
```

3g. Add the convenience getter next to `canTakeSard` (~line 349):

```dart
  /// Whether the student is مستبعد — hidden from every teacher-facing list.
  bool get isExcluded => status == StudentStatus.excluded;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/data/models/student_model_test.dart`
Expected: PASS (all groups, including the new one).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/student_model.dart test/unit/data/models/student_model_test.dart
git commit -m "feat(model): teaching-status fields on StudentModel (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Repository — `setStudentStatus` + teacher-facing filters

**Files:**
- Modify: `lib/data/repositories/student_repository.dart`
- Modify: `lib/features/admin/providers/admin_provider.dart` (line ~128, the teacher-roster call)
- Test: `test/unit/data/repositories/student_repository_test.dart` (append a group)

**Interfaces:**
- Consumes: `StudentStatus`/`StudentStatusX` (Task 1), `StudentStatusChangeNotAuthorizedException` (Task 1), `StudentModel.isExcluded` (Task 2), `AppConstants.collectionSupervisorInstitutes` (`'supervisor_institutes'`, membership doc id `'{supervisorId}_{instituteId}'` with `is_active` bool — see `InstituteRepository.assignSupervisorToInstitute`).
- Produces:
  - `Future<void> setStudentStatus({required String studentId, required StudentStatus status, String? reason, required UserModel actor})` on `StudentRepository`.
  - `getStudentsForTeacher(String teacherId, {bool includeExcluded = false})` — new named param; default hides excluded.
  - `streamStudentsForTeacher` and `getStudentsReadyForExam` silently drop excluded students.
  - Audit entries at `students/{id}/status_audit` with keys `from_status`, `to_status`, `reason`, `changed_by`, `changed_at`.

- [ ] **Step 1: Write the failing tests**

Append this group inside the top-level `group('StudentRepository', ...)` in `test/unit/data/repositories/student_repository_test.dart` (after the existing groups, before the closing braces). Add these imports to the top of the file if missing:

```dart
import 'package:al_rasikhoon/domain/student/student_status.dart';
import 'package:al_rasikhoon/domain/student/student_status_exceptions.dart';
```

Note the existing helpers in this file: `seedUser`, `seedStudent` (add an optional `String? teacherId` parameter to it — write `'teacher_id': teacherId,` into the map it sets), and `readStudent`.

```dart
    group('teaching status (مستبعد)', () {
      final admin = UserModel(
        id: 'admin1',
        email: 'admin@example.com',
        name: 'مدير',
        role: UserRole.superAdmin,
        createdAt: DateTime(2026),
      );
      final supervisor = UserModel(
        id: 'sup1',
        email: 'sup@example.com',
        name: 'مشرف',
        role: UserRole.supervisor,
        createdAt: DateTime(2026),
      );
      final teacher = UserModel(
        id: 't1',
        email: 'teacher@example.com',
        name: 'معلم',
        role: UserRole.teacher,
        createdAt: DateTime(2026),
      );

      Future<void> seedSupervisorMembership({
        String supervisorId = 'sup1',
        String instituteId = 'i1',
        bool isActive = true,
      }) async {
        await fakeFirestore
            .collection('supervisor_institutes')
            .doc('${supervisorId}_$instituteId')
            .set({
          'supervisor_id': supervisorId,
          'institute_id': instituteId,
          'is_active': isActive,
          'assigned_at': Timestamp.now(),
        });
      }

      Future<List<Map<String, dynamic>>> readAudit([String id = 's1']) async {
        final snap = await fakeFirestore
            .collection('students')
            .doc(id)
            .collection('status_audit')
            .get();
        return snap.docs.map((d) => d.data()).toList();
      }

      test('supervisor of the student\'s institute can exclude with a reason',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);
        await seedSupervisorMembership();

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          reason: 'غياب متكرر',
          actor: supervisor,
        );

        final data = await readStudent();
        expect(data['status'], 'excluded');
        expect(data['status_reason'], 'غياب متكرر');
        expect(data['status_changed_by'], 'sup1');
        expect(data['status_changed_at'], isNotNull);
      });

      test('excluding writes an immutable audit entry naming the transition',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);
        await seedSupervisorMembership();

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          reason: 'غياب متكرر',
          actor: supervisor,
        );

        final audit = await readAudit();
        expect(audit, hasLength(1));
        expect(audit.single['from_status'], 'active');
        expect(audit.single['to_status'], 'excluded');
        expect(audit.single['reason'], 'غياب متكرر');
        expect(audit.single['changed_by'], 'sup1');
        expect(audit.single['changed_at'], isNotNull);
      });

      test('admin can exclude a student of any institute without membership',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          actor: admin,
        );

        expect((await readStudent())['status'], 'excluded');
      });

      test('the reason is optional — an empty reason is stored as none',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          reason: '   ',
          actor: admin,
        );

        expect((await readStudent())['status_reason'], isNull);
        expect((await readAudit()).single['reason'], isNull);
      });

      test('supervisor of another institute cannot change the status',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);
        // Membership binds sup1 to i2, but the student is in i1.
        await seedSupervisorMembership(instituteId: 'i2');

        expect(
          () => studentRepository.setStudentStatus(
            studentId: 's1',
            status: StudentStatus.excluded,
            actor: supervisor,
          ),
          throwsA(isA<StudentStatusChangeNotAuthorizedException>()),
        );
      });

      test('a revoked (inactive) membership does not authorize', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);
        await seedSupervisorMembership(isActive: false);

        expect(
          () => studentRepository.setStudentStatus(
            studentId: 's1',
            status: StudentStatus.excluded,
            actor: supervisor,
          ),
          throwsA(isA<StudentStatusChangeNotAuthorizedException>()),
        );
      });

      test('a teacher cannot change a student\'s teaching status', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        expect(
          () => studentRepository.setStudentStatus(
            studentId: 's1',
            status: StudentStatus.excluded,
            actor: teacher,
          ),
          throwsA(isA<StudentStatusChangeNotAuthorizedException>()),
        );
      });

      test('re-requesting the current status is a silent no-op with no audit',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.active,
          actor: admin,
        );

        expect((await readStudent()).containsKey('status'), isFalse);
        expect(await readAudit(), isEmpty);
      });

      test('restoring returns the student and appends a second audit entry',
          () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          reason: 'غياب',
          actor: admin,
        );
        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.active,
          reason: 'عاد للانتظام',
          actor: admin,
        );

        final data = await readStudent();
        expect(data['status'], 'active');
        expect(data['status_reason'], 'عاد للانتظام');

        final audit = await readAudit();
        expect(audit, hasLength(2));
        final restore =
            audit.singleWhere((e) => e['to_status'] == 'active');
        expect(restore['from_status'], 'excluded');
      });

      test(
          'an excluded student disappears from the teacher\'s list '
          'but stays in the supervisor\'s and admin\'s lists', () async {
        await seedUser(id: 'u1');
        await seedStudent(
            id: 's1', level: 1, juz: 30, session: 1, order: 1,
            teacherId: 't1');
        await seedStudent(
            id: 's2', level: 1, juz: 30, session: 1, order: 1,
            teacherId: 't1');

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          actor: admin,
        );

        final teacherList =
            await studentRepository.getStudentsForTeacher('t1');
        expect(teacherList.map((s) => s.student.id), ['s2']);

        final supervisorList =
            await studentRepository.getStudentsForInstitutes(['i1']);
        expect(supervisorList.map((s) => s.student.id).toSet(),
            {'s1', 's2'});

        final adminList = await studentRepository.getAllStudents();
        expect(adminList.map((s) => s.student.id).toSet(), {'s1', 's2'});
      });

      test('the admin teacher-roster view can include excluded students',
          () async {
        await seedUser(id: 'u1');
        await seedStudent(
            id: 's1', level: 1, juz: 30, session: 1, order: 1,
            teacherId: 't1');

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          actor: admin,
        );

        final roster = await studentRepository.getStudentsForTeacher(
          't1',
          includeExcluded: true,
        );
        expect(roster.map((s) => s.student.id), ['s1']);
      });

      test('an excluded student leaves the exam-ready queue', () async {
        await seedUser(id: 'u1');
        await seedStudent(
            id: 's1', level: 1, juz: 30, session: 68, order: 68,
            kind: 'exam');

        await studentRepository.setStudentStatus(
          studentId: 's1',
          status: StudentStatus.excluded,
          actor: admin,
        );

        final queue =
            await studentRepository.getStudentsReadyForExam('i1');
        expect(queue, isEmpty);
      });
    });
```

Also modify the existing `seedStudent` helper in the same file: add `String? teacherId,` to its parameters and `'teacher_id': teacherId,` to the map it writes.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart`
Expected: FAIL — compile error: `The method 'setStudentStatus' isn't defined for the type 'StudentRepository'`.

- [ ] **Step 3: Implement the repository changes**

In `lib/data/repositories/student_repository.dart`:

3a. Add imports (next to the other domain imports):

```dart
import '../../domain/student/student_status.dart';
import '../../domain/student/student_status_exceptions.dart';
```

3b. Add the method after `assignTeacher` (~line 657):

```dart
  /// Sets the student's TEACHING status — نشط ⇄ مستبعد (al_rasikhoon-zg1r) —
  /// with an optional free-text reason.
  ///
  /// Authorization is enforced HERE, on the authoritative path, not in the
  /// UI: an admin may change any student; a supervisor only a student of an
  /// institute they hold an ACTIVE `supervisor_institutes` membership for
  /// (al_rasikhoon-3n6 — the membership docs, not `users.institute_id`, are
  /// the source of truth). Anyone else is rejected with
  /// [StudentStatusChangeNotAuthorizedException] — mirroring
  /// [repositionEnrolledStudent], because a stale UI must not be trusted.
  ///
  /// The student update and the append-only `status_audit` entry are written
  /// in one [WriteBatch] so the change and the record of who made it — and
  /// why — commit together or not at all. Requesting the status the student
  /// already holds is a silent no-op: nothing is written, no audit entry is
  /// appended (the trail records changes, not clicks).
  Future<void> setStudentStatus({
    required String studentId,
    required StudentStatus status,
    String? reason,
    required UserModel actor,
  }) async {
    final student = await getStudentById(studentId);
    if (student == null) {
      throw ArgumentError.value(studentId, 'studentId', 'No such student');
    }
    if (!student.isActive) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Cannot change the teaching status of a deleted student',
      );
    }

    if (actor.role == UserRole.supervisor) {
      // Membership doc id is '{supervisorId}_{instituteId}' — written by
      // InstituteRepository.assignSupervisorToInstitute; one existence check
      // against the student's own institute.
      final membership = await _read.getDoc(
        _firestore
            .collection(AppConstants.collectionSupervisorInstitutes)
            .doc('${actor.id}_${student.instituteId}'),
      );
      final membershipData = membership.data() as Map<String, dynamic>?;
      final isMember = membership.exists &&
          (membershipData?['is_active'] as bool? ?? false);
      if (!isMember) {
        throw const StudentStatusChangeNotAuthorizedException(
          'Supervisor is not scoped to this student\'s institute',
        );
      }
    } else if (actor.role != UserRole.superAdmin) {
      throw const StudentStatusChangeNotAuthorizedException(
        'Only a supervisor or an admin may change a student\'s '
        'teaching status',
      );
    }

    if (student.status == status) return;

    final trimmed = reason?.trim();
    final normalizedReason = (trimmed == null || trimmed.isEmpty)
        ? null
        : trimmed;

    final studentRef = _studentsCollection.doc(studentId);
    final auditRef = studentRef.collection('status_audit').doc();
    final batch = _firestore.batch();
    batch.update(studentRef, {
      'status': status.value,
      'status_reason': normalizedReason,
      'status_changed_at': FieldValue.serverTimestamp(),
      'status_changed_by': actor.id,
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(auditRef, {
      'from_status': student.status.value,
      'to_status': status.value,
      'reason': normalizedReason,
      'changed_by': actor.id,
      'changed_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
```

3c. Filter the teacher list — replace `getStudentsForTeacher` (~line 487) with:

```dart
  /// Get students for teacher.
  ///
  /// An excluded (مستبعد) student is dropped by default — the teacher must
  /// not see them (al_rasikhoon-zg1r). Applied as a POST-filter, not a
  /// `where` clause, for the same reason as `curriculum_completed` in
  /// [getStudentsReadyForExam]: legacy documents lack the field entirely, and
  /// an equality filter would silently drop every one of them. The admin's
  /// teacher-roster view passes [includeExcluded] to see the full roster.
  Future<List<StudentWithUser>> getStudentsForTeacher(
    String teacherId, {
    bool includeExcluded = false,
  }) async {
    final query = await _read.getQuery(_studentsCollection
        .where('teacher_id', isEqualTo: teacherId)
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        );

    final students = query.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .where((student) => includeExcluded || !student.isExcluded)
        .toList();

    // Get user data for each student
    return _withUsers(students);
  }
```

3d. Filter the teacher stream — in `streamStudentsForTeacher` (~line 891), change the `.map(...)` body to:

```dart
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              // Excluded students are invisible to their teacher
              // (al_rasikhoon-zg1r) — same post-filter as
              // getStudentsForTeacher.
              .where((student) => !student.isExcluded)
              .toList(),
        );
```

3e. Filter the exam queue — in `getStudentsReadyForExam` (~line 590), change the post-filter line to:

```dart
        .where((student) => !student.curriculumCompleted && !student.isExcluded)
```

…and append to that method's doc comment:

```dart
  /// An EXCLUDED (مستبعد) student is dropped the same way: they are not being
  /// taught, so they have no exam to sit (al_rasikhoon-zg1r).
```

3f. In `lib/features/admin/providers/admin_provider.dart` (~line 128), the admin teacher-roster provider call becomes:

```dart
      // The admin sees the teacher's FULL roster, excluded students included
      // (badged in the UI) — hiding is a teacher-view concern
      // (al_rasikhoon-zg1r).
      return repo.getStudentsForTeacher(teacherId, includeExcluded: true);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart`
Expected: PASS (all groups, including 12 new tests).

Then run the full unit suite to catch regressions from the filter changes:
Run: `flutter test test/unit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/student_repository.dart lib/features/admin/providers/admin_provider.dart test/unit/data/repositories/student_repository_test.dart
git commit -m "feat(repo): setStudentStatus with audit trail; hide مستبعد from teacher queries (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Firestore rules — admin student writes + immutable `status_audit`

**Files:**
- Modify: `firestore.rules`

**Interfaces:**
- Consumes: existing rule helpers `isSuperAdmin()`, `isSupervisorOfStudentInstitute(data)`, `canReadStudent(data)`; the `reposition_audit` block (~line 304) as the model.
- Produces: students `allow update` gains an `isSuperAdmin()` branch (the client-side admin exclude write is otherwise denied — the current rule only has teacher/supervisor/student branches); a `status_audit` sub-match readable by whoever reads the student, creatable by admin or institute supervisor, never updatable/deletable.

- [ ] **Step 1: Add the `isSuperAdmin()` branch to the students update rule**

In `firestore.rules`, find the students `allow update` (~line 293):

```
      allow update: if (isTeacherOfStudent(resource.data) &&
         isTeacherOfStudent(request.resource.data)) ||
        (isSupervisorOfStudentInstitute(resource.data) &&
         isSupervisorOfStudentInstitute(request.resource.data)) ||
```

Change to (adding the first line and a comment above the rule):

```
      // isSuperAdmin: the admin console edits any student — including the
      // teaching-status toggle (al_rasikhoon-zg1r), which writes status /
      // status_reason / status_changed_* directly from the admin's device.
      allow update: if isSuperAdmin() ||
        (isTeacherOfStudent(resource.data) &&
         isTeacherOfStudent(request.resource.data)) ||
        (isSupervisorOfStudentInstitute(resource.data) &&
         isSupervisorOfStudentInstitute(request.resource.data)) ||
```

(Keep the remaining student-claim branch and the comment block above the rule untouched.)

- [ ] **Step 2: Add the `status_audit` match block**

Directly after the closing `}` of the `match /reposition_audit/{auditId}` block (~line 317), still inside `match /students/{studentId}`, add:

```
      // Append-only audit of teaching-status changes — نشط ⇄ مستبعد
      // (al_rasikhoon-zg1r): who changed whom, from/to which status, and the
      // optional reason. An admin or a supervisor scoped to the student's
      // institute may append; the same roles that may read the student may
      // read its trail. Entries are immutable (no update/delete) so the trail
      // cannot be rewritten. Mirrors reposition_audit above.
      match /status_audit/{auditId} {
        function parentStudentDoc() {
          return get(/databases/$(database)/documents/students/$(studentId)).data;
        }
        allow read: if canReadStudent(parentStudentDoc());
        allow create: if isSuperAdmin() ||
          isSupervisorOfStudentInstitute(parentStudentDoc());
        allow update, delete: if false;
      }
```

- [ ] **Step 3: Validate the rules compile**

If the Firebase MCP tool `firebase_validate_security_rules` is available, validate `firestore.rules` with it. Otherwise run:

Run: `npx --yes firebase-tools@latest deploy --only firestore:rules --dry-run 2>&1 | tail -5` — OR, if that needs auth, at minimum confirm balanced braces by eye and rely on the emulator test suite in `test/rules/` (`cd test/rules && npm test`, requires the Firestore emulator; skip if the emulator is unavailable and say so).

Expected: rules compile without syntax errors.

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "feat(rules): admin student updates + immutable status_audit trail (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Note: rules deploy to production happens through the project's normal release flow (`firebase deploy --only firestore:rules`), not in this task.

---

### Task 5: Shared UI — `StudentStatusDialog` + مستبعد badge on `StudentCard`

**Files:**
- Create: `lib/shared/widgets/student_status_dialog.dart`
- Modify: `lib/shared/widgets/student_card.dart`
- Test: `test/widget/student_status_dialog_test.dart`

**Interfaces:**
- Consumes: `StudentRepository.setStudentStatus` (Task 3), `StudentModel.isExcluded`/`statusReason` (Task 2), `currentUserProvider` (`Provider<UserModel?>`, `lib/shared/providers/user_provider.dart`), `AppButton` (`lib/shared/widgets/app_button.dart`), `AppColors` (`lib/core/constants/app_colors.dart`).
- Produces: `StudentStatusDialog({required StudentModel student, required String studentDisplayName, required VoidCallback onChanged})` — a `ConsumerStatefulWidget` `AlertDialog` that toggles to the opposite status with an optional reason; callers supply `onChanged` to invalidate their own list provider (keeps the shared widget out of feature folders — al_rasikhoon-pz2). `StudentCard` shows a maroon «مستبعد» badge whenever `student.isExcluded`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/widget/student_status_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/student/student_status.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';
import 'package:al_rasikhoon/shared/widgets/app_button.dart';
import 'package:al_rasikhoon/shared/widgets/student_status_dialog.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// Pins the exclusion dialog (al_rasikhoon-zg1r): a supervisor or admin
/// toggles a student between نشط and مستبعد with an OPTIONAL free-text
/// reason; restoring shows the stored reason for context.
void main() {
  setUpAll(() {
    registerFallbackValue(StudentStatus.active);
    registerFallbackValue(UserModel(
      id: 'fallback',
      email: 'fallback@example.com',
      name: 'fallback',
      role: UserRole.supervisor,
      createdAt: DateTime(2026),
    ));
  });

  final supervisor = UserModel(
    id: 'sup1',
    email: 'sup@example.com',
    name: 'مشرف',
    role: UserRole.supervisor,
    createdAt: DateTime(2026),
  );

  StudentModel student({
    StudentStatus status = StudentStatus.active,
    String? reason,
  }) =>
      StudentModel(
        id: 's1',
        userId: 'u1',
        instituteId: 'i1',
        createdAt: DateTime(2026),
        status: status,
        statusReason: reason,
      );

  Future<MockStudentRepository> pumpDialog(
    WidgetTester tester,
    StudentModel s,
  ) async {
    final repo = MockStudentRepository();
    when(() => repo.setStudentStatus(
          studentId: any(named: 'studentId'),
          status: any(named: 'status'),
          reason: any(named: 'reason'),
          actor: any(named: 'actor'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWithValue(supervisor),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StudentStatusDialog(
              student: s,
              studentDisplayName: 'أحمد',
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    return repo;
  }

  testWidgets('excluding an active student sends excluded with the reason',
      (tester) async {
    final repo = await pumpDialog(tester, student());

    await tester.enterText(find.byType(TextField), 'غياب متكرر');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.setStudentStatus(
          studentId: captureAny(named: 'studentId'),
          status: captureAny(named: 'status'),
          reason: captureAny(named: 'reason'),
          actor: captureAny(named: 'actor'),
        )).captured;
    expect(captured[0], 's1');
    expect(captured[1], StudentStatus.excluded);
    expect(captured[2], 'غياب متكرر');
    expect((captured[3] as UserModel).id, 'sup1');
  });

  testWidgets('the reason is optional — an empty field still submits',
      (tester) async {
    final repo = await pumpDialog(tester, student());

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    verify(() => repo.setStudentStatus(
          studentId: any(named: 'studentId'),
          status: any(named: 'status'),
          reason: any(named: 'reason'),
          actor: any(named: 'actor'),
        )).called(1);
  });

  testWidgets(
      'restoring an excluded student shows the stored reason and sends active',
      (tester) async {
    final repo = await pumpDialog(
      tester,
      student(status: StudentStatus.excluded, reason: 'غياب متكرر'),
    );

    // The dialog surfaces WHY the student was excluded before undoing it.
    expect(find.textContaining('غياب متكرر'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.setStudentStatus(
          studentId: captureAny(named: 'studentId'),
          status: captureAny(named: 'status'),
          reason: captureAny(named: 'reason'),
          actor: captureAny(named: 'actor'),
        )).captured;
    expect(captured[1], StudentStatus.active);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/student_status_dialog_test.dart`
Expected: FAIL — `Couldn't resolve the package ... student_status_dialog.dart` (file does not exist).

- [ ] **Step 3: Implement the dialog**

Create `lib/shared/widgets/student_status_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/student/student_status.dart';
import '../providers/user_provider.dart';
import 'app_button.dart';

/// Supervisor/admin dialog that toggles a student's TEACHING status —
/// نشط ⇄ مستبعد (al_rasikhoon-zg1r) — with an OPTIONAL free-text reason.
///
/// The dialog always offers the OPPOSITE of the student's current status:
/// exclude an active student, restore an excluded one. When restoring, the
/// stored exclusion reason is shown so the decision is made in context.
///
/// Lives in shared/ because both the supervisor and the admin screens open
/// it; each passes [onChanged] to refresh its OWN list provider, so this
/// widget never reaches into a feature folder (al_rasikhoon-pz2).
/// Authorization is enforced by [StudentRepository.setStudentStatus], not
/// here — the dialog is a view, not a boundary.
class StudentStatusDialog extends ConsumerStatefulWidget {
  final StudentModel student;
  final String studentDisplayName;

  /// Called after a successful write — the caller invalidates its own list
  /// provider (supervisorStudentsProvider / allStudentsProvider).
  final VoidCallback onChanged;

  const StudentStatusDialog({
    super.key,
    required this.student,
    required this.studentDisplayName,
    required this.onChanged,
  });

  @override
  ConsumerState<StudentStatusDialog> createState() =>
      _StudentStatusDialogState();
}

class _StudentStatusDialogState extends ConsumerState<StudentStatusDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _isExcluding => !widget.student.isExcluded;

  StudentStatus get _targetStatus =>
      _isExcluding ? StudentStatus.excluded : StudentStatus.active;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isLoading) return;
    final actor = ref.read(currentUserProvider);
    if (actor == null) {
      setState(() => _error = 'حدث خطأ، يرجى المحاولة مرة أخرى');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Capture the messenger and navigator before the async gap so a
    // dismissed dialog never touches a defunct context (mirrors
    // AssignTeacherDialog's hardening).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(studentRepositoryProvider).setStudentStatus(
            studentId: widget.student.id,
            status: _targetStatus,
            reason: _reasonController.text,
            actor: actor,
          );
      widget.onChanged();
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isExcluding
                ? 'تم استبعاد ${widget.studentDisplayName} من التدريس'
                : 'تم إلغاء استبعاد ${widget.studentDisplayName}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('setStudentStatus failed: $e');
      if (!context.mounted) return;
      setState(() => _error = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storedReason = widget.student.statusReason;

    return AlertDialog(
      title: Text(
        _isExcluding
            ? 'استبعاد ${widget.studentDisplayName} من التدريس'
            : 'إلغاء استبعاد ${widget.studentDisplayName}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isExcluding
                ? 'لن يظهر الطالب في قوائم المعلم حتى يتم إلغاء الاستبعاد. '
                      'يبقى الطالب ظاهرًا للمشرف والمدير.'
                : 'سيعود الطالب للظهور في قوائم المعلم.',
          ),
          if (!_isExcluding && storedReason != null) ...[
            const SizedBox(height: 12),
            Text(
              'سبب الاستبعاد الحالي:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(storedReason),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'السبب (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        AppButton(
          text: _isExcluding ? 'استبعاد' : 'إلغاء الاستبعاد',
          onPressed: _handleConfirm,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add the badge to `StudentCard`**

In `lib/shared/widgets/student_card.dart`, directly after the `_TeacherlessBadge` block inside the name column (~line 124, after `if (student.teacherId == null) ...[...]`), add:

```dart
                          // A مستبعد student never reaches a teacher's list
                          // (repository post-filter), so this badge only ever
                          // renders in supervisor/admin views — where it is
                          // the signal that this student is not being taught
                          // (al_rasikhoon-zg1r).
                          if (student.isExcluded) ...[
                            const SizedBox(height: 4),
                            const _ExcludedBadge(),
                          ],
```

…and add the badge widget next to `_TeacherlessBadge` (~line 316):

```dart
/// Marks a مستبعد student (al_rasikhoon-zg1r) in supervisor/admin lists.
/// Maroon — the palette's attention/needs-review hue — because an excluded
/// student is actively not being taught. Text-based, not colour-only, for
/// accessibility.
class _ExcludedBadge extends StatelessWidget {
  const _ExcludedBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.maroon.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 12, color: tokens.maroon),
          const SizedBox(width: 4),
          Text(
            'مستبعد',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.maroon,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/widget/student_status_dialog_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/student_status_dialog.dart lib/shared/widgets/student_card.dart test/widget/student_status_dialog_test.dart
git commit -m "feat(ui): StudentStatusDialog with optional reason + مستبعد badge (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Screen wiring — supervisor and admin action sheets

**Files:**
- Modify: `lib/features/supervisor/screens/supervisor_students_screen.dart`
- Modify: `lib/features/admin/screens/all_students_screen.dart`

**Interfaces:**
- Consumes: `StudentStatusDialog` (Task 5), `StudentModel.isExcluded` (Task 2), `supervisorStudentsProvider`, `allStudentsProvider`.
- Produces: a «استبعاد من التدريس» / «إلغاء الاستبعاد» entry in both screens' `⋮` bottom sheets. No teacher-screen change (repository filter covers it).

- [ ] **Step 1: Wire the supervisor screen**

In `lib/features/supervisor/screens/supervisor_students_screen.dart`:

1a. Add the import:

```dart
import '../../../shared/widgets/student_status_dialog.dart';
```

1b. `_showStudentActions` needs `ref` for the invalidate — change its signature (~line 178) and both call sites (~lines 110 and 124):

```dart
  void _showStudentActions(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String userName,
    StudentModel student,
  ) {
```

Call sites become:

```dart
                              onLongPress: () => _showStudentActions(
                                context,
                                ref,
                                studentWithUser.user.id,
                                studentWithUser.user.name,
                                studentWithUser.student,
                              ),
```

```dart
                                  onPressed: () => _showStudentActions(
                                    context,
                                    ref,
                                    studentWithUser.user.id,
                                    studentWithUser.user.name,
                                    studentWithUser.student,
                                  ),
```

1c. Add the tile inside the sheet's `Column`, after the «تغيير خطة الحفظ» `ListTile` and before the «إعادة تعيين كلمة المرور» one:

```dart
            // Toggle the student's teaching status — نشط ⇄ مستبعد
            // (al_rasikhoon-zg1r). Maroon: excluding is an attention-heavy
            // act, matching the مستبعد badge on the card. Authorization is
            // enforced in StudentRepository.setStudentStatus.
            ListTile(
              leading: Icon(
                student.isExcluded
                    ? Icons.how_to_reg
                    : Icons.person_off_outlined,
                color: tokens.maroon,
              ),
              title: Text(
                student.isExcluded
                    ? 'إلغاء الاستبعاد'
                    : 'استبعاد من التدريس',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(
                  context: context,
                  builder: (_) => StudentStatusDialog(
                    student: student,
                    studentDisplayName: userName,
                    onChanged: () =>
                        ref.invalidate(supervisorStudentsProvider),
                  ),
                );
              },
            ),
```

- [ ] **Step 2: Wire the admin screen**

In `lib/features/admin/screens/all_students_screen.dart`:

2a. Add imports:

```dart
import '../../../data/repositories/student_repository.dart';
import '../../../shared/widgets/student_status_dialog.dart';
```

2b. `_showStudentActions` currently receives only the user — it needs the student too. Change the signature (~line 46):

```dart
  void _showStudentActions(
    BuildContext context,
    WidgetRef ref,
    StudentWithUser studentWithUser,
  ) {
    final user = studentWithUser.user;
    final student = studentWithUser.student;
```

…and the call site (~line 163):

```dart
                                onPressed: () => _showStudentActions(
                                  context,
                                  ref,
                                  studentWithUser,
                                ),
```

2c. Add the tile inside the sheet's `Column`, after the «إعادة تعيين كلمة المرور» `ListTile`:

```dart
            // Toggle the student's teaching status — نشط ⇄ مستبعد
            // (al_rasikhoon-zg1r). Same dialog the supervisor uses; the
            // admin refreshes the all-students list.
            ListTile(
              leading: Icon(
                student.isExcluded
                    ? Icons.how_to_reg
                    : Icons.person_off_outlined,
              ),
              title: Text(
                student.isExcluded
                    ? 'إلغاء الاستبعاد'
                    : 'استبعاد من التدريس',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(
                  context: context,
                  builder: (_) => StudentStatusDialog(
                    student: student,
                    studentDisplayName: user.name,
                    onChanged: () => ref.invalidate(allStudentsProvider),
                  ),
                );
              },
            ),
```

- [ ] **Step 3: Analyze and run the widget suite**

Run: `flutter analyze lib/features/supervisor/screens/supervisor_students_screen.dart lib/features/admin/screens/all_students_screen.dart`
Expected: No issues found.

Run: `flutter test test/widget`
Expected: PASS (no regressions — several widget tests pump these screens).

- [ ] **Step 4: Commit**

```bash
git add lib/features/supervisor/screens/supervisor_students_screen.dart lib/features/admin/screens/all_students_screen.dart
git commit -m "feat(screens): استبعاد/إلغاء الاستبعاد actions in supervisor and admin sheets (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Changelog, full verification, close out

**Files:**
- Modify: `CHANGELOG.md` (top `## Unreleased` section)

**Interfaces:**
- Consumes: everything above.
- Produces: a shippable branch — full test suite green, analyzer clean, stakeholder changelog bullet, beads issue closed.

- [ ] **Step 1: Add the stakeholder changelog bullet**

At the top of the `## Unreleased` section in `CHANGELOG.md` (as the first bullet), add:

```markdown
- يستطيع المشرف والمدير الآن استبعاد طالب من التدريس (مستبعد) مع ذكر سبب
  اختياري: الطالب المستبعد يختفي من قوائم المعلم لكنه يبقى ظاهرًا للمشرف
  والمدير مع شارة «مستبعد»، ويمكن إعادته للتدريس في أي وقت مع الاحتفاظ بسجل
  كامل لكل تغيير وسببه.
```

- [ ] **Step 2: Run the full suite and analyzer**

Run: `flutter analyze`
Expected: No issues found.

Run: `flutter test test/`
Expected: PASS — full unit + widget suite (this is exactly what CI runs).

- [ ] **Step 3: Close the beads issue and commit**

```bash
bd close al_rasikhoon-zg1r
git add CHANGELOG.md .beads/
git commit -m "docs(changelog): supervisor student exclusion feature (al_rasikhoon-zg1r)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Verify a clean tree**

Run: `git status`
Expected: nothing to commit, working tree clean.
