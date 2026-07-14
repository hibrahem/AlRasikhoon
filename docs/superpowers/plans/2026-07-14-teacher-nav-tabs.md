# Teacher Navigation Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `al_rasikhoon-256` — every button in the teacher bottom nav navigates, and it becomes structurally impossible to ship a tab that has no route behind it.

**Architecture:** Today the per-role nav items (`bottom_nav_bar.dart`) and the per-role shell branches (`app_router.dart`) are two lists in two files that agree only by convention; when they disagree, `RoleShell`'s bounds check swallows the tap silently. We introduce a single per-role `NavDestination` table that the nav bar renders from, drop the `الحلقة` tab (its only concrete job — picking an institute — is already the `الطلاب` tab), build the two screens that were missing (`السجل`, `الإعدادات`), wire their branches, and finish by turning the silent swallow into a debug assertion plus a test that compares destination count to real branch count for every role.

**Tech Stack:** Flutter, `go_router` ^17.0.1 (`StatefulShellRoute.indexedStack`), `flutter_riverpod` ^3.1.0, Firestore, `intl` for Arabic date formatting.

**Spec:** `docs/superpowers/specs/2026-07-14-teacher-nav-tabs-design.md`

## Global Constraints

- All user-facing copy is Arabic. The app is locale-locked to `ar` (`lib/app.dart:19`) — do not add a language or theme toggle.
- Do not add new pub dependencies. In particular there is no `package_info_plus`, so no app-version footer.
- Follow existing patterns: screens are `ConsumerWidget`/`ConsumerStatefulWidget`, lists use `AsyncValue.when` + `RefreshIndicator` + `AppCard`, colors come from `AppColors` (`lib/core/constants/app_colors.dart`).
- Dates are formatted with `DateFormat('yyyy/MM/dd', 'ar')`; any widget test that renders a date must call `await initializeDateFormatting('ar')` in `setUpAll`.
- Run tests with `flutter test`. Run `flutter analyze` before each commit; it must be clean.
- Task ordering matters: the guardrail assertion (Task 5) only holds once every branch exists (Tasks 3–4). Do not enable it early.

## File Structure

| File | Responsibility |
|---|---|
| `lib/shared/widgets/nav_destinations.dart` (create) | `NavDestination` type + `destinationsFor(UserRole)` — the single source of truth for what tabs a role has, in branch order. |
| `lib/shared/widgets/bottom_nav_bar.dart` (modify) | Renders exactly `destinationsFor(role)`. No per-role item lists of its own. |
| `lib/shared/widgets/role_shell.dart` (modify) | Asserts destinations and branches agree; keeps a release-mode bounds check. |
| `lib/features/teacher/providers/teacher_provider.dart` (modify) | Adds `TeacherHistoryEntry` + `teacherHistoryProvider`. |
| `lib/features/teacher/screens/teacher_history_screen.dart` (create) | `السجل` — the teacher's recitation history. |
| `lib/features/settings/screens/settings_screen.dart` (create) | `الإعدادات` — profile + sign-out. Shared by teacher, supervisor, student shells. |
| `lib/routing/app_router.dart` (modify) | New routes + branches. |

---

### Task 1: Single source of truth for nav destinations

Pure refactor plus one deletion: the nav bar stops owning per-role item lists, and the teacher's `الحلقة` tab — which will never have a branch — is removed. No assertion yet (branches don't exist until Tasks 3–4).

**Files:**
- Create: `lib/shared/widgets/nav_destinations.dart`
- Modify: `lib/shared/widgets/bottom_nav_bar.dart` (replace `_getItemsForRole`)
- Test: `test/unit/shared/nav_destinations_test.dart`

**Interfaces:**
- Consumes: `UserRole` from `lib/data/models/user_model.dart`.
- Produces: `class NavDestination {IconData icon; IconData activeIcon; String label; String rootPath;}` and `List<NavDestination> destinationsFor(UserRole role)`. Task 5 asserts against `destinationsFor`; Tasks 3–4 add the routes whose paths appear here.

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/nav_destinations_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

void main() {
  group('destinationsFor', () {
    test('teacher has three tabs: students, history, settings', () {
      final destinations = destinationsFor(UserRole.teacher);

      expect(destinations.map((d) => d.label), [
        'الطلاب',
        'السجل',
        'الإعدادات',
      ]);
      expect(destinations.map((d) => d.rootPath), [
        AppRoutes.teacherStudents,
        AppRoutes.teacherHistory,
        AppRoutes.teacherSettings,
      ]);
    });

    test('teacher has no الحلقة tab', () {
      final labels = destinationsFor(UserRole.teacher).map((d) => d.label);

      expect(labels, isNot(contains('الحلقة')));
    });

    test('guardian sees the same destinations as student', () {
      expect(
        destinationsFor(UserRole.guardian).map((d) => d.rootPath),
        destinationsFor(UserRole.student).map((d) => d.rootPath),
      );
    });

    test('every role has at least one destination and no duplicate paths', () {
      for (final role in UserRole.values) {
        final paths = destinationsFor(role).map((d) => d.rootPath).toList();

        expect(paths, isNotEmpty, reason: '$role has no destinations');
        expect(
          paths.toSet().length,
          paths.length,
          reason: '$role has duplicate root paths',
        );
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/shared/nav_destinations_test.dart`
Expected: FAIL — compile error, `nav_destinations.dart` does not exist and `AppRoutes.teacherHistory` / `AppRoutes.teacherSettings` are undefined.

- [ ] **Step 3: Add the new route constants**

In `lib/routing/app_router.dart`, in the `AppRoutes` class, add the settings paths and the teacher history path. Each shell branch needs a distinct root location, so every role gets its own settings path.

Add to the `// Supervisor` block (after `sardResult`):

```dart
  static const String supervisorSettings = '/supervisor/settings';
```

Add to the `// Teacher` block (after `sessionSummary`):

```dart
  static const String teacherHistory = '/teacher/history';
  static const String teacherSettings = '/teacher/settings';
```

Add to the `// Student` block (after `homePractice`):

```dart
  static const String studentSettings = '/student/settings';
```

- [ ] **Step 4: Create the destination table**

Create `lib/shared/widgets/nav_destinations.dart`:

```dart
import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../routing/app_router.dart';

/// One bottom-nav destination for a role, in branch order.
///
/// This is the single source of truth for a role's tabs. The nav bar renders
/// exactly this list, and `RoleShell` asserts it matches the role's shell
/// branches — so a tab can never exist without a route behind it
/// (al_rasikhoon-256).
///
/// The Nth destination here MUST correspond to the Nth `StatefulShellBranch`
/// of that role's `StatefulShellRoute` in `app_router.dart`. `rootPath` is that
/// branch's initial location, and is what keeps the correspondence checkable.
@immutable
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String rootPath;

  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.rootPath,
  });
}

List<NavDestination> destinationsFor(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الرئيسية',
          rootPath: AppRoutes.adminDashboard,
        ),
        NavDestination(
          icon: Icons.account_balance_outlined,
          activeIcon: Icons.account_balance,
          label: 'المعاهد',
          rootPath: AppRoutes.institutes,
        ),
        NavDestination(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: 'المعلمون',
          rootPath: AppRoutes.teachers,
        ),
        NavDestination(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book,
          label: 'المنهج',
          rootPath: AppRoutes.curriculum,
        ),
      ];

    case UserRole.supervisor:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الرئيسية',
          rootPath: AppRoutes.supervisorDashboard,
        ),
        NavDestination(
          icon: Icons.quiz_outlined,
          activeIcon: Icons.quiz,
          label: 'الاختبارات',
          rootPath: AppRoutes.examQueue,
        ),
        NavDestination(
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          label: 'الطلاب',
          rootPath: AppRoutes.supervisorStudents,
        ),
        NavDestination(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'الإعدادات',
          rootPath: AppRoutes.supervisorSettings,
        ),
      ];

    // No الحلقة tab: picking an institute and then seeing that institute's
    // students is already what الطلاب does (the المعهد filter on
    // TeacherStudentsScreen), so the tab had no job of its own.
    case UserRole.teacher:
      return const [
        NavDestination(
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          label: 'الطلاب',
          rootPath: AppRoutes.teacherStudents,
        ),
        NavDestination(
          icon: Icons.history_outlined,
          activeIcon: Icons.history,
          label: 'السجل',
          rootPath: AppRoutes.teacherHistory,
        ),
        NavDestination(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'الإعدادات',
          rootPath: AppRoutes.teacherSettings,
        ),
      ];

    case UserRole.student:
    case UserRole.guardian:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الرئيسية',
          rootPath: AppRoutes.studentDashboard,
        ),
        NavDestination(
          icon: Icons.repeat_outlined,
          activeIcon: Icons.repeat,
          label: 'التكرار',
          rootPath: AppRoutes.homePractice,
        ),
        NavDestination(
          icon: Icons.history_outlined,
          activeIcon: Icons.history,
          label: 'السجل',
          rootPath: AppRoutes.sessionHistory,
        ),
        NavDestination(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'الإعدادات',
          rootPath: AppRoutes.studentSettings,
        ),
      ];
  }
}
```

- [ ] **Step 5: Render the nav bar from the table**

Replace the entire contents of `lib/shared/widgets/bottom_nav_bar.dart` (this deletes `_getItemsForRole` — the table replaces it):

```dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/user_model.dart';
import 'nav_destinations.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final UserRole role;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(role);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      items: [
        for (final destination in destinations)
          BottomNavigationBarItem(
            icon: Icon(destination.icon),
            activeIcon: Icon(destination.activeIcon),
            label: destination.label,
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run tests and analyzer**

Run: `flutter test test/unit/shared/nav_destinations_test.dart && flutter analyze`
Expected: PASS (4 tests), analyzer clean.

Then run the full suite to confirm nothing regressed: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/nav_destinations.dart lib/shared/widgets/bottom_nav_bar.dart lib/routing/app_router.dart test/unit/shared/nav_destinations_test.dart
git commit -m "refactor(al_rasikhoon-256): make nav destinations a single per-role table

The nav items and the shell branches were two lists in two files that
agreed only by convention. Give each role one ordered destination table
carrying the root path of its branch, and drop the teacher's الحلقة tab —
picking an institute and seeing its students is already what الطلاب does."
```

---

### Task 2: `teacherHistoryProvider`

The provider behind `السجل`. No new data layer: `SessionRepository.getSessionRecordsForTeacher` already exists (`lib/data/repositories/session_repository.dart:106`) and returns records newest-first.

A `SessionRecordModel` carries `studentId`, not a student name or an institute, so the provider joins each record against `teacherStudentsProvider` (already loaded for the students tab) to resolve both.

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart` (append)
- Test: `test/unit/providers/teacher_history_provider_test.dart`

**Interfaces:**
- Consumes: `currentUserProvider` (`lib/shared/providers/user_provider.dart`), `sessionRepositoryProvider` (`lib/data/repositories/session_repository.dart:382`), and from Task 0 (existing code) `teacherStudentsProvider` and `selectedTeacherInstituteFilterProvider`.
- Produces: `class TeacherHistoryEntry {SessionRecordModel record; String studentName; String instituteId;}` and `final teacherHistoryProvider = FutureProvider<List<TeacherHistoryEntry>>`. Task 3's screen renders this.

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/teacher_history_provider_test.dart`. Note the fake repository extends `SessionRepository` and overrides only the one method the provider calls — mirroring the style of `test/unit/providers/teacher_provider_test.dart`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

/// Records the teacher recorded, keyed by nothing — the fake just returns them
/// in the order the real repository would (date descending).
class _FakeSessionRepository implements SessionRepository {
  final List<SessionRecordModel> records;

  _FakeSessionRepository(this.records);

  @override
  Future<List<SessionRecordModel>> getSessionRecordsForTeacher(
    String teacherId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    return records.where((r) => r.teacherId == teacherId).toList();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _teacher(String id) => UserModel(
      id: id,
      email: '$id@example.com',
      name: 'المعلم',
      role: UserRole.teacher,
      createdAt: DateTime(2024),
    );

StudentWithUser _student({
  required String id,
  required String name,
  required String instituteId,
}) {
  return StudentWithUser(
    student: StudentModel(
      id: id,
      userId: id,
      instituteId: instituteId,
      teacherId: 'teacher1',
      createdAt: DateTime(2024),
    ),
    user: UserModel(
      id: id,
      email: '$id@example.com',
      name: name,
      role: UserRole.student,
      createdAt: DateTime(2024),
    ),
  );
}

SessionRecordModel _record({
  required String id,
  required String studentId,
  required DateTime date,
  String teacherId = 'teacher1',
}) {
  return SessionRecordModel(
    id: id,
    studentId: studentId,
    teacherId: teacherId,
    curriculumSessionId: 'cs1',
    levelId: 1,
    sessionNumber: 1,
    date: date,
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 0,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    passed: true,
    createdAt: date,
  );
}

ProviderContainer _container({
  required List<SessionRecordModel> records,
  required List<StudentWithUser> students,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_teacher('teacher1')),
      sessionRepositoryProvider.overrideWithValue(
        _FakeSessionRepository(records),
      ),
      teacherStudentsProvider.overrideWith((ref) async => students),
    ],
  );
}

void main() {
  final students = [
    _student(id: 's1', name: 'أحمد', instituteId: 'inst1'),
    _student(id: 's2', name: 'خالد', instituteId: 'inst2'),
  ];

  test('resolves each record to its student name', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries, hasLength(1));
    expect(entries.single.studentName, 'أحمد');
    expect(entries.single.record.id, 'r1');
    expect(entries.single.instituteId, 'inst1');
  });

  test('institute filter scopes history to that institute', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2)),
        _record(id: 'r2', studentId: 's2', date: DateTime(2024, 3, 1)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    container
        .read(selectedTeacherInstituteFilterProvider.notifier)
        .set('inst2');

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries.map((e) => e.record.id), ['r2']);
  });

  test('null filter means all institutes', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2)),
        _record(id: 'r2', studentId: 's2', date: DateTime(2024, 3, 1)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries.map((e) => e.record.id), ['r1', 'r2']);
  });

  test('drops records whose student is no longer with this teacher', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 'transferred', date: DateTime(2024, 3, 2)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/teacher_history_provider_test.dart`
Expected: FAIL — `teacherHistoryProvider` and `TeacherHistoryEntry` are undefined.

- [ ] **Step 3: Implement the provider**

Append to `lib/features/teacher/providers/teacher_provider.dart` (the file already imports `session_repository.dart`, `session_record_model.dart`, `student_repository.dart` and `user_provider.dart`):

```dart
/// One row of the teacher's history: the record, plus the student identity the
/// record itself does not carry.
class TeacherHistoryEntry {
  final SessionRecordModel record;
  final String studentName;
  final String instituteId;

  const TeacherHistoryEntry({
    required this.record,
    required this.studentName,
    required this.instituteId,
  });
}

/// Every recitation this teacher recorded, newest first.
///
/// Scoped by the SAME institute filter as the students list, so selecting a
/// معهد means one thing across the whole teacher shell.
final teacherHistoryProvider = FutureProvider<List<TeacherHistoryEntry>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(sessionRepositoryProvider);
  final records = await repo.getSessionRecordsForTeacher(currentUser.id);

  // Records carry a studentId only; the name and institute come from the
  // teacher's roster, which the students tab has already loaded.
  final students = await ref.watch(teacherStudentsProvider.future);
  final byStudentId = {for (final s in students) s.student.id: s};

  final filter = ref.watch(selectedTeacherInstituteFilterProvider);

  final entries = <TeacherHistoryEntry>[];
  for (final record in records) {
    final student = byStudentId[record.studentId];
    // A student who has since left this teacher's roster: we can no longer
    // name or scope the record, so it is not shown.
    if (student == null) continue;
    if (filter != null && student.student.instituteId != filter) continue;

    entries.add(
      TeacherHistoryEntry(
        record: record,
        studentName: student.user.name,
        instituteId: student.student.instituteId,
      ),
    );
  }
  return entries;
});
```

- [ ] **Step 4: Run tests and analyzer**

Run: `flutter test test/unit/providers/teacher_history_provider_test.dart && flutter analyze`
Expected: PASS (4 tests), analyzer clean.

If the fake repository trips an analyzer error for unimplemented members, replace `implements SessionRepository` with `extends SessionRepository` and keep only the `getSessionRecordsForTeacher` override, dropping the `noSuchMethod` stub.

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/providers/teacher_provider.dart test/unit/providers/teacher_history_provider_test.dart
git commit -m "feat(al_rasikhoon-256): add teacherHistoryProvider

Joins the teacher's session records against their roster to resolve the
student name and institute the record does not carry, and scopes the result
with the same institute filter the students list uses."
```

---

### Task 3: `السجل` screen and its branch

**Files:**
- Create: `lib/features/teacher/screens/teacher_history_screen.dart`
- Modify: `lib/routing/app_router.dart` (teacher shell — add branch 1)
- Test: `test/widget/teacher_history_screen_test.dart`

**Interfaces:**
- Consumes: `teacherHistoryProvider`, `TeacherHistoryEntry` (Task 2); `AppRoutes.teacherHistory`, `AppRoutes.sessionOverview` (Task 1 / existing).
- Produces: `TeacherHistoryScreen` — a `ConsumerWidget` with a const constructor, built by the teacher shell's branch 1.

- [ ] **Step 1: Write the failing test**

Create `test/widget/teacher_history_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_history_screen.dart';

TeacherHistoryEntry _entry({
  required String id,
  required String studentName,
  required bool passed,
  required DateTime date,
}) {
  return TeacherHistoryEntry(
    studentName: studentName,
    instituteId: 'inst1',
    record: SessionRecordModel(
      id: id,
      studentId: 'student-$id',
      teacherId: 'teacher1',
      curriculumSessionId: 'cs1',
      levelId: 2,
      sessionNumber: 7,
      date: date,
      attemptNumber: 1,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 1,
        distantReviewErrors: 0,
      ),
      passed: passed,
      createdAt: date,
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<TeacherHistoryEntry> entries) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        teacherHistoryProvider.overrideWith((ref) async => entries),
      ],
      child: const MaterialApp(home: TeacherHistoryScreen()),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('each row names the student, the session, and the outcome',
      (tester) async {
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'أحمد',
        passed: true,
        date: DateTime(2024, 3, 15),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('الحلقة 7'), findsOneWidget);
    expect(find.text('المستوى 2'), findsOneWidget);
    expect(find.text('نجح'), findsOneWidget);
    expect(find.text('رسب'), findsNothing);
  });

  testWidgets('a failed record shows رسب', (tester) async {
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'خالد',
        passed: false,
        date: DateTime(2024, 3, 15),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('رسب'), findsOneWidget);
    expect(find.text('نجح'), findsNothing);
  });

  testWidgets('rows are listed newest first', (tester) async {
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'أحمد',
        passed: true,
        date: DateTime(2024, 3, 15),
      ),
      _entry(
        id: 'r2',
        studentName: 'خالد',
        passed: true,
        date: DateTime(2024, 3, 1),
      ),
    ]);
    await tester.pumpAndSettle();

    final newest = tester.getTopLeft(find.text('أحمد')).dy;
    final oldest = tester.getTopLeft(find.text('خالد')).dy;
    expect(newest, lessThan(oldest));
  });

  testWidgets('empty history shows the empty state', (tester) async {
    await _pump(tester, []);
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد سجل'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/teacher_history_screen_test.dart`
Expected: FAIL — compile error, `teacher_history_screen.dart` does not exist.

- [ ] **Step 3: Implement the screen**

Create `lib/features/teacher/screens/teacher_history_screen.dart`. It mirrors `lib/features/student/screens/session_history_screen.dart`, but rows are keyed by student (the teacher's question is "who did I hear?") and tapping opens that student's session overview.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_provider.dart';

class TeacherHistoryScreen extends ConsumerWidget {
  const TeacherHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(teacherHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('السجل')),
      body: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teacherHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _HistoryRow(entry: entries[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا الحلقات التي سمعتها',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final TeacherHistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    // Binary outcome only (نجح / رسب) — never an averaged grade and never the
    // per-component breakdown, same rule the student listing follows (#24).
    final passColor = record.passed ? AppColors.success : AppColors.error;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        context.push(
          AppRoutes.sessionOverview.replaceFirst(':studentId', record.studentId),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: passColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                record.passed ? Icons.check_circle : Icons.cancel,
                color: passColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.studentName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'الحلقة ${record.sessionNumber}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  'المستوى ${record.levelId}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  dateFormat.format(record.date),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: passColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: passColor),
            ),
            child: Text(
              record.passed ? 'نجح' : 'رسب',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: passColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/teacher_history_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Wire the branch**

In `lib/routing/app_router.dart`, add the import next to the other teacher screen imports:

```dart
import '../features/teacher/screens/teacher_history_screen.dart';
```

Then, in the teacher `StatefulShellRoute.indexedStack`, add a second `StatefulShellBranch` immediately after the existing Students branch (i.e. after the `],\n          ),` that closes it, before the `],` closing `branches:`). Also update the stale comment above the shell:

```dart
      // Teacher shell — Students / History / Settings
      StatefulShellRoute.indexedStack(
```

The new branch:

```dart
          // Branch 1: History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherHistory,
                builder: (context, state) => const TeacherHistoryScreen(),
              ),
            ],
          ),
```

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: PASS, analyzer clean.

- [ ] **Step 7: Commit**

```bash
git add lib/features/teacher/screens/teacher_history_screen.dart lib/routing/app_router.dart test/widget/teacher_history_screen_test.dart
git commit -m "feat(al_rasikhoon-256): add the teacher السجل tab

The teacher's recitation history, newest first, scoped by the selected
معهد, with each row tapping through to that student's session overview.
Wires it as the teacher shell's second branch."
```

---

### Task 4: `الإعدادات` screen and its branches

One screen, routed into three shells. Teacher, supervisor and student all render a `الإعدادات` nav item today and all three are dead; this task gives all three a real branch.

Logout **moves** here from the AppBar of `TeacherStudentsScreen`, and gains a confirmation dialog — today it fires a destructive action in one unconfirmed tap from a routine screen.

**Files:**
- Create: `lib/features/settings/screens/settings_screen.dart`
- Modify: `lib/routing/app_router.dart` (teacher branch 2, supervisor branch 3, student branch 3)
- Modify: `lib/features/teacher/screens/teacher_students_screen.dart:29-39` (remove the logout AppBar action)
- Test: `test/widget/settings_screen_test.dart`

**Interfaces:**
- Consumes: `currentUserProvider`, `UserRoleExtension.nameAr` (`lib/data/models/user_model.dart`), `authRepositoryProvider` (`lib/data/repositories/auth_repository.dart`, `.notifier.signOut()`), `teacherInstitutesProvider` (`lib/features/teacher/providers/teacher_provider.dart`), `AppRoutes.teacherSettings` / `supervisorSettings` / `studentSettings` (Task 1).
- Produces: `SettingsScreen` — a `ConsumerWidget` with a const constructor, built by all three settings branches.

- [ ] **Step 1: Write the failing test**

Create `test/widget/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/features/settings/screens/settings_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

UserModel _user(UserRole role) => UserModel(
      id: 'u1',
      email: 'teacher@example.com',
      name: 'أستاذ حسن',
      role: role,
      createdAt: DateTime(2024),
    );

Future<void> _pump(
  WidgetTester tester, {
  required UserRole role,
  List<InstituteModel> institutes = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user(role)),
        teacherInstitutesProvider.overrideWith((ref) async => institutes),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
}

void main() {
  testWidgets('shows the current user name, email and role', (tester) async {
    await _pump(tester, role: UserRole.teacher);
    await tester.pumpAndSettle();

    expect(find.text('أستاذ حسن'), findsOneWidget);
    expect(find.text('teacher@example.com'), findsOneWidget);
    expect(find.text('معلم'), findsOneWidget);
  });

  testWidgets('sign out asks for confirmation before signing out',
      (tester) async {
    await _pump(tester, role: UserRole.teacher);
    await tester.pumpAndSettle();

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();

    // The dialog is up, and nothing has happened yet.
    expect(find.text('هل تريد تسجيل الخروج؟'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsNothing);
  });

  testWidgets('a student does not see the institutes section', (tester) async {
    await _pump(tester, role: UserRole.student);
    await tester.pumpAndSettle();

    expect(find.text('المعاهد'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/settings_screen_test.dart`
Expected: FAIL — compile error, `settings_screen.dart` does not exist.

- [ ] **Step 3: Implement the screen**

Create `lib/features/settings/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../teacher/providers/teacher_provider.dart';

/// Account screen for the teacher, supervisor and student shells.
///
/// Deliberately small: it exists to give the account actions a home. There is
/// no language or theme toggle — the app is locale-locked to `ar`
/// (`lib/app.dart`) and has no theme mode, so a switch here would flip nothing.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(user: user),
          if (user.role == UserRole.teacher) ...[
            const SizedBox(height: 16),
            const _InstitutesCard(),
          ],
          const SizedBox(height: 24),
          _SignOutButton(),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final contact = user.email.isNotEmpty ? user.email : (user.phone ?? '');

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                if (contact.isNotEmpty)
                  Text(
                    contact,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 4),
                Text(
                  user.role.nameAr,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The institutes a teacher is assigned to. Teachers can work across several,
/// which is why the students list carries a المعهد filter at all.
class _InstitutesCard extends ConsumerWidget {
  const _InstitutesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutesAsync = ref.watch(teacherInstitutesProvider);

    return institutesAsync.maybeWhen(
      data: (institutes) {
        if (institutes.isEmpty) return const SizedBox.shrink();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المعاهد', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final institute in institutes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(institute.name)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text(
        'تسجيل الخروج',
        style: TextStyle(color: AppColors.error),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () => _confirmSignOut(context, ref),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authRepositoryProvider.notifier).signOut();
    }
  }
}
```

Note the import of `currentUserProvider`: it lives in `lib/shared/providers/user_provider.dart`. Add that import too:

```dart
import '../../../shared/providers/user_provider.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/settings_screen_test.dart`
Expected: PASS (3 tests).

The sign-out confirmation test taps `find.text('تسجيل الخروج')`. Once the dialog is open, that string appears twice (button and dialog action); the test only taps before the dialog exists and then taps `إلغاء`, so no ambiguity arises. If a later change makes it ambiguous, narrow the finder with `find.widgetWithText(OutlinedButton, 'تسجيل الخروج')`.

- [ ] **Step 5: Remove the logout icon from the students AppBar**

In `lib/features/teacher/screens/teacher_students_screen.dart`, replace the AppBar (lines 29-39) with:

```dart
      appBar: AppBar(title: const Text('طلابي')),
```

The `ref.watch(authRepositoryProvider)` on line 26 stays (the screen still watches auth state for reactivity), so the `auth_repository.dart` import is still needed.

- [ ] **Step 6: Wire the three branches**

In `lib/routing/app_router.dart`, add the import:

```dart
import '../features/settings/screens/settings_screen.dart';
```

Add as the **last** branch of the teacher shell (after the History branch from Task 3):

```dart
          // Branch 2: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
```

Add as the **last** branch of the supervisor shell:

```dart
          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supervisorSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
```

Add as the **last** branch of the student shell:

```dart
          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
```

Update the stale student-shell comment from `// Student shell — Home / Practice / History (Settings stub)` to `// Student shell — Home / Practice / History / Settings`.

- [ ] **Step 7: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: PASS, analyzer clean.

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings lib/routing/app_router.dart lib/features/teacher/screens/teacher_students_screen.dart test/widget/settings_screen_test.dart
git commit -m "feat(al_rasikhoon-256): add the الإعدادات tab for teacher, supervisor and student

All three roles rendered a dead الإعدادات nav item; one shared screen gives
all three a real branch. Logout moves here from the الطلاب AppBar, where it
fired destructively in a single unconfirmed tap, and now asks first."
```

---

### Task 5: The guardrail

Every branch now exists, so the two lists can finally be asserted equal. This is the task that makes the class of bug impossible rather than merely fixing this instance of it.

**Files:**
- Modify: `lib/shared/widgets/role_shell.dart`
- Test: `test/unit/routing/nav_branch_parity_test.dart`
- Test: `test/widget/role_shell_navigation_test.dart`

**Interfaces:**
- Consumes: `destinationsFor` (Task 1), the four shell routes in `app_router.dart` (Tasks 3–4).
- Produces: nothing new. Behavior change only.

- [ ] **Step 1: Write the failing parity test**

This is the test that would have caught `al_rasikhoon-256`. It reaches into the real router, finds each `StatefulShellRoute`, and compares its branch count and branch root paths against the destination table.

Create `test/unit/routing/nav_branch_parity_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

/// Every StatefulShellRoute in the app, keyed by the root path of its first
/// branch — which is also the first destination of the role that owns it.
List<StatefulShellRoute> _shellRoutes(GoRouter router) {
  return router.configuration.routes.whereType<StatefulShellRoute>().toList();
}

String _firstPathOf(StatefulShellBranch branch) {
  final route = branch.routes.first as GoRoute;
  return route.path;
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer();
    router = container.read(routerProvider);
  });

  tearDown(() => container.dispose());

  test('every role shell has one branch per nav destination', () {
    final shells = _shellRoutes(router);

    // Each role's shell is identified by the root path of its first branch.
    for (final role in UserRole.values) {
      final destinations = destinationsFor(role);
      final shell = shells.firstWhere(
        (s) => _firstPathOf(s.branches.first) == destinations.first.rootPath,
        orElse: () => throw StateError('no shell route for $role'),
      );

      expect(
        shell.branches.length,
        destinations.length,
        reason:
            '$role renders ${destinations.length} nav tabs but its shell has '
            '${shell.branches.length} branches — tabs beyond the branch count '
            'are silently dead (al_rasikhoon-256)',
      );

      // Order matters: the Nth tab must select the Nth branch.
      expect(
        shell.branches.map(_firstPathOf).toList(),
        destinations.map((d) => d.rootPath).toList(),
        reason: '$role nav order does not match its branch order',
      );
    }
  });
}
```

- [ ] **Step 2: Run the parity test**

Run: `flutter test test/unit/routing/nav_branch_parity_test.dart`
Expected: PASS — Tasks 1–4 have already brought the two lists into agreement. (Had you run this test before Task 1, it would have failed for teacher with "renders 4 nav tabs but its shell has 1 branch". If it fails now, a branch or a destination is missing or out of order — fix that, do not weaken the test.)

Note: `UserRole.student` and `UserRole.guardian` share one shell, so the loop checks that shell twice. That is intentional and harmless.

- [ ] **Step 3: Write the failing widget test**

Create `test/widget/role_shell_navigation_test.dart`. This asserts the user-visible property directly: every tab actually moves you.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/widgets/bottom_nav_bar.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

void main() {
  testWidgets('every teacher nav tab reports its own index when tapped',
      (tester) async {
    final tapped = <int>[];
    var currentIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                currentIndex: currentIndex,
                role: UserRole.teacher,
                onTap: (index) {
                  tapped.add(index);
                  setState(() => currentIndex = index);
                },
              ),
            );
          },
        ),
      ),
    );

    final destinations = destinationsFor(UserRole.teacher);
    for (final destination in destinations) {
      await tester.tap(find.text(destination.label));
      await tester.pumpAndSettle();
    }

    // Not just "the taps registered" — each tab reported a DISTINCT index, so
    // no two tabs collapse onto the same branch.
    expect(tapped, List.generate(destinations.length, (i) => i));
  });
}
```

- [ ] **Step 4: Run it**

Run: `flutter test test/widget/role_shell_navigation_test.dart`
Expected: PASS.

- [ ] **Step 5: Turn the silent swallow into a loud failure**

Replace `lib/shared/widgets/role_shell.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import 'bottom_nav_bar.dart';
import 'nav_destinations.dart';

/// Persistent shell that hosts a `StatefulNavigationShell` plus the role's
/// bottom navigation bar. Tab swaps are handled by `goBranch`, which performs
/// an `IndexedStack` swap with no transition and preserves each branch's
/// navigator state.
class RoleShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final UserRole role;

  const RoleShell({
    super.key,
    required this.navigationShell,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final branchCount = navigationShell.route.branches.length;

    // A tab with no branch behind it used to be swallowed silently: the button
    // simply did nothing, in production, with no error (al_rasikhoon-256). Fail
    // loudly in debug instead, the first time such a shell is built.
    assert(
      destinationsFor(role).length == branchCount,
      '$role renders ${destinationsFor(role).length} nav destinations but its '
      'shell declares $branchCount branches. Every destination in '
      'nav_destinations.dart needs a matching StatefulShellBranch, in the same '
      'order, in app_router.dart.',
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          // Release-mode safety net for the invariant asserted above.
          if (index >= branchCount) return;
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        role: role,
      ),
    );
  }
}
```

- [ ] **Step 6: Run the full suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: PASS, analyzer clean.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/role_shell.dart test/unit/routing/nav_branch_parity_test.dart test/widget/role_shell_navigation_test.dart
git commit -m "fix(al_rasikhoon-256): assert nav destinations match shell branches

RoleShell swallowed taps on any tab index past the shell's branch count, so
a tab with no branch did nothing at all, silently, in production. Assert the
two agree at build time and add a parity test over the real router, so the
mismatch fails in dev instead of shipping as a dead button."
```

---

### Task 6: Verify in the running app

The tests prove the wiring; this proves the app. `al_rasikhoon-256` was reported from the running app and should be closed from it.

**Files:** none — verification only.

- [ ] **Step 1: Run the app and sign in as a teacher**

Use the `/run` skill, or `flutter run` against the usual dev target.

- [ ] **Step 2: Tap every tab**

Confirm, for a teacher account:
- `الطلاب` shows the student list (with the المعهد filter if the teacher has 2+ institutes).
- `السجل` shows past recitations, newest first; selecting a معهد on `الطلاب` scopes `السجل` to it too.
- `الإعدادات` shows name/contact/role, the teacher's institutes, and a sign-out that asks before it acts.
- There is no `الحلقة` tab, and no tab does nothing.

- [ ] **Step 3: Spot-check the other roles**

Sign in as a supervisor and as a student and confirm `الإعدادات` now opens rather than doing nothing, and that no other tab regressed.

- [ ] **Step 4: Close the issue**

```bash
bd close al_rasikhoon-256
```

---

## Definition of Done

- Every tab in every role's bottom nav navigates. No dead buttons for teacher, supervisor, or student.
- `flutter test` and `flutter analyze` are clean.
- The parity test fails if anyone adds a nav destination without a branch, or reorders one against the other.
- `al_rasikhoon-256` closed, branch pushed.
