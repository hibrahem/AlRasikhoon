# Profile Screen + Clean Usernames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop showing the synthesized `@alrasikhoon.local` email anywhere user-facing, rename the account tab/screen to "الملف الشخصي" (Profile), and add a role-aware analytics block to it.

**Architecture:** A `displayUsername` getter on `UserModel` becomes the single user-visible identity string; display call sites swap `.email` for it. The account tab's nav label and app-bar title are relabeled across all shells. A new `SessionRepository.getSessionCountForTeacher` count query feeds a `teacherStatsProvider`; the existing `studentStatsProvider` feeds students. The settings screen renders a role-selected stats card built from a shared `_StatTile`.

**Tech Stack:** Flutter, Riverpod, Cloud Firestore (fake_cloud_firestore + mocktail for tests), Dart.

## Global Constraints

- Renamed label (nav + app bar), verbatim: `الملف الشخصي`
- Account tab icon: `Icons.person_outline` (inactive), `Icons.person` (active)
- Synthesized domain constant: `AppConstants.synthesizedEmailDomain` = `'alrasikhoon.local'` — never hardcode the literal
- Session records collection: `AppConstants.collectionSessionRecords` = `'session_records'`; teacher field `teacher_id`, date field `date`
- No new Firestore index (reuse the existing `teacher_id` + `date` index)
- DDD/Clean Architecture: count query in `SessionRepository` (data), `TeacherStats` + provider in teacher feature providers (application), widgets + role selection in the settings screen (presentation), `displayUsername` on `UserModel` (domain accessor)
- Run tests with `flutter test <path>`; run `flutter analyze` before each commit touching Dart
- Do NOT rename route paths or `settings_*` file names

---

### Task 1: `UserModel.displayUsername` getter

**Files:**
- Modify: `lib/data/models/user_model.dart`
- Test: `test/unit/data/models/user_model_test.dart`

**Interfaces:**
- Consumes: `AppConstants.synthesizedEmailDomain` (existing, `lib/core/constants/app_constants.dart`)
- Produces: `String UserModel.displayUsername` — the user-visible login name; never the synthesized auth email

- [ ] **Step 1: Write the failing tests**

Add this group inside the existing `group('UserModel', () { ... })` block in `test/unit/data/models/user_model_test.dart` (place it right after the `group('constructor', ...)` block):

```dart
group('displayUsername', () {
  UserModel userWith({String username = '', String email = ''}) => UserModel(
    id: 'u1',
    username: username,
    email: email,
    name: 'Test',
    role: UserRole.student,
    createdAt: DateTime(2024),
  );

  test('returns the stored username when present', () {
    final user = userWith(
      username: 'mohammed.a',
      email: 'mohammed.a@alrasikhoon.local',
    );

    expect(user.displayUsername, 'mohammed.a');
  });

  test('strips the synthesized domain for a legacy record with no username', () {
    final user = userWith(username: '', email: 'hassan@alrasikhoon.local');

    expect(user.displayUsername, 'hassan');
  });

  test('returns a non-synthesized email unchanged when there is no username', () {
    final user = userWith(username: '', email: 'real@example.com');

    expect(user.displayUsername, 'real@example.com');
  });

  test('returns empty string when both username and email are empty', () {
    final user = userWith(username: '', email: '');

    expect(user.displayUsername, '');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/data/models/user_model_test.dart --plain-name displayUsername`
Expected: FAIL — `The getter 'displayUsername' isn't defined for the type 'UserModel'`.

- [ ] **Step 3: Implement the getter**

In `lib/data/models/user_model.dart`, add the import at the top (with the other imports, after the `cloud_firestore` import):

```dart
import '../../core/constants/app_constants.dart';
```

Then add this getter inside the `UserModel` class, immediately after the `copyWith` method (before `toString`):

```dart
  /// The user-visible login name — never the synthesized auth email.
  ///
  /// Prefers the stored [username]; falls back to stripping the synthesized
  /// `@${AppConstants.synthesizedEmailDomain}` domain off legacy records that
  /// predate the username field. A genuinely non-synthesized email (or an
  /// empty one) is returned unchanged.
  String get displayUsername {
    if (username.isNotEmpty) return username;
    final suffix = '@${AppConstants.synthesizedEmailDomain}';
    if (email.endsWith(suffix)) {
      return email.substring(0, email.length - suffix.length);
    }
    return email;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/data/models/user_model_test.dart`
Expected: PASS (all groups, including the new `displayUsername` group).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/data/models/user_model.dart`
Expected: No issues.

```bash
git add lib/data/models/user_model.dart test/unit/data/models/user_model_test.dart
git commit -m "feat(user): add displayUsername that never exposes the synthesized email"
```

---

### Task 2: Rename the account tab and screen to "الملف الشخصي"

**Files:**
- Modify: `lib/shared/widgets/nav_destinations.dart` (three destinations: supervisor, teacher, student/guardian)
- Modify: `lib/features/settings/screens/settings_screen.dart` (app-bar title)
- Test: `test/unit/shared/nav_destinations_test.dart` (create)

**Interfaces:**
- Consumes: `destinationsFor(UserRole)` (existing)
- Produces: nav destinations whose account tab has `label: 'الملف الشخصي'`, `icon: Icons.person_outline`, `activeIcon: Icons.person`

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/nav_destinations_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

void main() {
  group('destinationsFor account tab', () {
    for (final role in [
      UserRole.teacher,
      UserRole.student,
      UserRole.guardian,
      UserRole.supervisor,
    ]) {
      test('$role has a الملف الشخصي tab with the person icon', () {
        final destinations = destinationsFor(role);
        final account = destinations.last;

        expect(account.label, 'الملف الشخصي');
        expect(account.icon, Icons.person_outline);
        expect(account.activeIcon, Icons.person);
      });
    }

    test('no destination is still labeled الإعدادات', () {
      for (final role in UserRole.values) {
        final labels = destinationsFor(role).map((d) => d.label);
        expect(labels, isNot(contains('الإعدادات')));
      }
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/shared/nav_destinations_test.dart`
Expected: FAIL — account tab label is still `'الإعدادات'` and icon is `Icons.settings_outlined`.

- [ ] **Step 3: Update the three account destinations**

In `lib/shared/widgets/nav_destinations.dart`, each of the three account `NavDestination`s currently reads:

```dart
        NavDestination(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'الإعدادات',
          rootPath: AppRoutes.supervisorSettings,
        ),
```

Change the three `icon`/`activeIcon`/`label` triples (leave each `rootPath` untouched — they differ per role: `supervisorSettings`, `teacherSettings`, `studentSettings`) so each reads:

```dart
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'الملف الشخصي',
```

- [ ] **Step 4: Update the app-bar title**

In `lib/features/settings/screens/settings_screen.dart`, change:

```dart
      appBar: AppBar(title: const Text('الإعدادات')),
```

to:

```dart
      appBar: AppBar(title: const Text('الملف الشخصي')),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/unit/shared/nav_destinations_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze lib/shared/widgets/nav_destinations.dart lib/features/settings/screens/settings_screen.dart`
Expected: No issues.

```bash
git add lib/shared/widgets/nav_destinations.dart lib/features/settings/screens/settings_screen.dart test/unit/shared/nav_destinations_test.dart
git commit -m "feat(profile): rename account tab and screen to الملف الشخصي"
```

---

### Task 3: Profile card shows the clean username

**Files:**
- Modify: `lib/features/settings/screens/settings_screen.dart` (`_ProfileCard`)
- Test: `test/widget/settings_screen_test.dart`

**Interfaces:**
- Consumes: `UserModel.displayUsername` (Task 1)

- [ ] **Step 1: Update the failing test**

In `test/widget/settings_screen_test.dart`, replace the `_user` helper so the fixture has a username and a synthesized email:

```dart
UserModel _user(UserRole role) => UserModel(
  id: 'u1',
  username: 'hassan',
  email: 'hassan@alrasikhoon.local',
  name: 'أستاذ حسن',
  role: role,
  createdAt: DateTime(2024),
);
```

Then replace the first test (`shows the current user name, email and role`) with:

```dart
  testWidgets('shows the name, clean username and role — never the .local email', (
    tester,
  ) async {
    await _pump(tester, role: UserRole.teacher);
    await tester.pumpAndSettle();

    expect(find.text('أستاذ حسن'), findsOneWidget);
    expect(find.text('hassan'), findsOneWidget);
    expect(find.text('hassan@alrasikhoon.local'), findsNothing);
    expect(find.text('معلم'), findsOneWidget);
    expect(find.text('الملف الشخصي'), findsOneWidget); // app-bar title (Task 2)
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/settings_screen_test.dart --plain-name "clean username"`
Expected: FAIL — the card still renders `hassan@alrasikhoon.local`, so `find.text('hassan')` finds nothing and the `.local` matcher finds a widget.

- [ ] **Step 3: Update the profile card**

In `lib/features/settings/screens/settings_screen.dart`, in `_ProfileCard.build`, replace:

```dart
    final contact = user.email.isNotEmpty ? user.email : (user.phone ?? '');
```

with:

```dart
    // The person's own login name is the identity worth showing here; fall
    // back to a phone only when there is genuinely no username to show.
    final contact = user.displayUsername.isNotEmpty
        ? user.displayUsername
        : (user.phone ?? '');
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/settings_screen_test.dart`
Expected: PASS (all tests in the file).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/features/settings/screens/settings_screen.dart`
Expected: No issues.

```bash
git add lib/features/settings/screens/settings_screen.dart test/widget/settings_screen_test.dart
git commit -m "feat(profile): show clean username on the profile card"
```

---

### Task 4: Admin teacher lists show the clean username

**Files:**
- Modify: `lib/features/admin/screens/teacher_detail_screen.dart`
- Modify: `lib/features/admin/screens/teachers_screen.dart`
- Modify: `lib/features/admin/screens/institute_detail_screen.dart` (two occurrences)

**Interfaces:**
- Consumes: `UserModel.displayUsername` (Task 1)

No new test: these are display-only swaps of the identical expression, and the getter's behavior is already covered by Task 1's unit tests. Verification is `flutter analyze` plus the full suite.

- [ ] **Step 1: Swap the expression in each file**

In each of the three files, replace every occurrence of:

```dart
teacher.phone ?? teacher.email
```

with:

```dart
teacher.phone ?? teacher.displayUsername
```

Expected occurrence count: `teacher_detail_screen.dart` (1), `teachers_screen.dart` (1), `institute_detail_screen.dart` (2). Verify none remain:

Run: `grep -rn "teacher.phone ?? teacher.email" lib/features/admin`
Expected: no output.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/admin/screens/teacher_detail_screen.dart lib/features/admin/screens/teachers_screen.dart lib/features/admin/screens/institute_detail_screen.dart`
Expected: No issues.

- [ ] **Step 3: Run any existing admin widget tests + the model test**

Run: `flutter test test/unit/data/models/user_model_test.dart`
Expected: PASS. (This confirms the getter the swaps rely on is intact; there are no dedicated widget tests for these admin screens.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin/screens/teacher_detail_screen.dart lib/features/admin/screens/teachers_screen.dart lib/features/admin/screens/institute_detail_screen.dart
git commit -m "feat(admin): show clean username instead of the synthesized email"
```

---

### Task 5: `SessionRepository.getSessionCountForTeacher`

**Files:**
- Modify: `lib/data/repositories/session_repository.dart`
- Test: `test/unit/data/repositories/session_repository_test.dart`

**Interfaces:**
- Produces: `Future<int> getSessionCountForTeacher(String teacherId, {DateTime? startDate})` — count of `session_records` with `teacher_id == teacherId`, optionally filtered to `date >= startDate`

- [ ] **Step 1: Write the failing tests**

Add this group inside the existing `group('SessionRepository', () { ... })` block in `test/unit/data/repositories/session_repository_test.dart` (after the last existing group, before its closing `});`):

```dart
    group('getSessionCountForTeacher', () {
      Future<void> seedRecord({
        required String teacherId,
        required DateTime date,
      }) async {
        await fakeFirestore.collection('session_records').add({
          'teacher_id': teacherId,
          'date': Timestamp.fromDate(date),
        });
      }

      test('counts all records for the teacher when no startDate is given', () async {
        await seedRecord(teacherId: 't1', date: DateTime(2026, 1, 10));
        await seedRecord(teacherId: 't1', date: DateTime(2026, 7, 2));
        await seedRecord(teacherId: 't2', date: DateTime(2026, 7, 2));

        final count = await sessionRepository.getSessionCountForTeacher('t1');

        expect(count, 2);
      });

      test('counts only records on or after startDate', () async {
        await seedRecord(teacherId: 't1', date: DateTime(2026, 6, 30));
        await seedRecord(teacherId: 't1', date: DateTime(2026, 7, 1));
        await seedRecord(teacherId: 't1', date: DateTime(2026, 7, 15));

        final count = await sessionRepository.getSessionCountForTeacher(
          't1',
          startDate: DateTime(2026, 7, 1),
        );

        expect(count, 2);
      });

      test('returns zero for a teacher with no records', () async {
        await seedRecord(teacherId: 't1', date: DateTime(2026, 7, 2));

        final count = await sessionRepository.getSessionCountForTeacher('none');

        expect(count, 0);
      });
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/data/repositories/session_repository_test.dart --plain-name getSessionCountForTeacher`
Expected: FAIL — `The method 'getSessionCountForTeacher' isn't defined for the type 'SessionRepository'`.

- [ ] **Step 3: Implement the method**

In `lib/data/repositories/session_repository.dart`, add this method inside the `// ==================== Statistics ====================` section, immediately before `getStudentStatistics`:

```dart
  /// How many session records this teacher has recorded — optionally only
  /// those on or after [startDate].
  ///
  /// A Firestore aggregation `.count()`, so it never downloads the records:
  /// the profile screen needs the number, not the rows. Reuses the same
  /// `(teacher_id, date)` composite index as [getSessionRecordsForTeacher],
  /// so it adds no index.
  Future<int> getSessionCountForTeacher(
    String teacherId, {
    DateTime? startDate,
  }) async {
    Query<Map<String, dynamic>> query = _sessionRecordsCollection.where(
      'teacher_id',
      isEqualTo: teacherId,
    );

    if (startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    final result = await query.count().get();
    return result.count ?? 0;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/data/repositories/session_repository_test.dart`
Expected: PASS (all groups, including the new one).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/data/repositories/session_repository.dart`
Expected: No issues.

```bash
git add lib/data/repositories/session_repository.dart test/unit/data/repositories/session_repository_test.dart
git commit -m "feat(session): add getSessionCountForTeacher count query"
```

---

### Task 6: `TeacherStats` + `teacherStatsProvider`

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart`
- Test: `test/unit/providers/teacher_stats_provider_test.dart` (create)

**Interfaces:**
- Consumes: `getSessionCountForTeacher` (Task 5), `teacherStudentsProvider`, `teacherInstitutesProvider`, `currentUserProvider`, `sessionRepositoryProvider`
- Produces:
  - `class TeacherStats { final int totalSessions; final int sessionsThisMonth; final int studentCount; final int instituteCount; const TeacherStats({this.totalSessions = 0, this.sessionsThisMonth = 0, this.studentCount = 0, this.instituteCount = 0}); }`
  - `final teacherStatsProvider = FutureProvider<TeacherStats>(...)`

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/teacher_stats_provider_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

UserModel _teacher() => UserModel(
  id: 't1',
  username: 'teacher_one',
  email: 'teacher_one@alrasikhoon.local',
  name: 'المعلم',
  role: UserRole.teacher,
  createdAt: DateTime(2024),
);

InstituteModel _institute(String id) => InstituteModel(
  id: id,
  name: 'معهد $id',
  createdAt: DateTime(2024),
);

void main() {
  test('teacherStatsProvider composes counts, roster size and institutes', () async {
    final fakeFirestore = FakeFirebaseFirestore();
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 5);
    final lastMonth = DateTime(now.year, now.month, 1).subtract(
      const Duration(days: 5),
    );

    // Two records this month, one earlier → total 3, this-month 2.
    for (final date in [thisMonth, thisMonth, lastMonth]) {
      await fakeFirestore.collection('session_records').add({
        'teacher_id': 't1',
        'date': Timestamp.fromDate(date),
      });
    }
    // A record for a different teacher must not be counted.
    await fakeFirestore.collection('session_records').add({
      'teacher_id': 't2',
      'date': Timestamp.fromDate(thisMonth),
    });

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_teacher()),
        sessionRepositoryProvider.overrideWithValue(
          SessionRepository(firestore: fakeFirestore),
        ),
        teacherStudentsProvider.overrideWith(
          (ref) async => <StudentWithUser>[],
        ),
        teacherInstitutesProvider.overrideWith(
          (ref) async => [_institute('a'), _institute('b')],
        ),
      ],
    );
    addTearDown(container.dispose);

    // Roster size is asserted independently of its element type, so an empty
    // roster (0 students) is the simplest correct fixture; institutes carry 2.
    final stats = await container.read(teacherStatsProvider.future);

    expect(stats.totalSessions, 3);
    expect(stats.sessionsThisMonth, 2);
    expect(stats.studentCount, 0);
    expect(stats.instituteCount, 2);
  });

  test('teacherStatsProvider returns empty stats when signed out', () async {
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    final stats = await container.read(teacherStatsProvider.future);

    expect(stats.totalSessions, 0);
    expect(stats.sessionsThisMonth, 0);
    expect(stats.studentCount, 0);
    expect(stats.instituteCount, 0);
  });
}
```

> Note: if `InstituteModel`'s constructor differs from `InstituteModel(id:, name:, createdAt:)`, open `lib/data/models/institute_model.dart` and match its required parameters — the test only needs two distinct instances.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/providers/teacher_stats_provider_test.dart`
Expected: FAIL — `Undefined name 'teacherStatsProvider'` / `TeacherStats`.

- [ ] **Step 3: Implement `TeacherStats` and the provider**

In `lib/features/teacher/providers/teacher_provider.dart`, add at the end of the file:

```dart
/// A teacher's at-a-glance activity, shown on the profile screen.
class TeacherStats {
  final int totalSessions;
  final int sessionsThisMonth;
  final int studentCount;
  final int instituteCount;

  const TeacherStats({
    this.totalSessions = 0,
    this.sessionsThisMonth = 0,
    this.studentCount = 0,
    this.instituteCount = 0,
  });
}

/// Composes the signed-in teacher's profile stats: an all-time and a
/// this-month session count (cheap `.count()` queries), plus the roster and
/// institute sizes the students tab has already loaded.
final teacherStatsProvider = FutureProvider<TeacherStats>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const TeacherStats();

  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final students = await ref.watch(teacherStudentsProvider.future);
  final institutes = await ref.watch(teacherInstitutesProvider.future);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final totalSessions = await sessionRepo.getSessionCountForTeacher(
    currentUser.id,
  );
  final sessionsThisMonth = await sessionRepo.getSessionCountForTeacher(
    currentUser.id,
    startDate: monthStart,
  );

  return TeacherStats(
    totalSessions: totalSessions,
    sessionsThisMonth: sessionsThisMonth,
    studentCount: students.length,
    instituteCount: institutes.length,
  );
});
```

Confirm the file already imports `sessionRepositoryProvider` — it imports `../../../data/repositories/session_repository.dart` at the top (used by other providers). No new import is needed.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/providers/teacher_stats_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/features/teacher/providers/teacher_provider.dart`
Expected: No issues.

```bash
git add lib/features/teacher/providers/teacher_provider.dart test/unit/providers/teacher_stats_provider_test.dart
git commit -m "feat(teacher): add teacherStatsProvider for the profile screen"
```

---

### Task 7: Role-aware stats cards on the profile screen

**Files:**
- Modify: `lib/features/settings/screens/settings_screen.dart`
- Test: `test/widget/settings_screen_test.dart`

**Interfaces:**
- Consumes: `teacherStatsProvider` + `TeacherStats` (Task 6), `studentStatsProvider` + `StudentStats` (existing, `lib/features/student/providers/student_provider.dart`)

- [ ] **Step 1: Write the failing tests**

In `test/widget/settings_screen_test.dart`, add these imports at the top (with the existing imports):

```dart
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
```

Update the `_pump` helper so both stats providers are always overridden (this keeps the existing sign-out tests off Firestore now that the screen renders a stats card). Replace the whole `_pump` function with:

```dart
Future<void> _pump(
  WidgetTester tester, {
  required UserRole role,
  List<InstituteModel> institutes = const [],
  AuthRepository? authRepository,
  TeacherStats teacherStats = const TeacherStats(),
  StudentStats studentStats = const StudentStats(),
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user(role)),
        teacherInstitutesProvider.overrideWith((ref) async => institutes),
        teacherStatsProvider.overrideWith((ref) async => teacherStats),
        studentStatsProvider.overrideWith((ref) async => studentStats),
        if (authRepository != null)
          authRepositoryProvider.overrideWith(() => authRepository),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
}
```

Add these two tests inside `main()` (after the existing tests):

```dart
  testWidgets('a teacher sees their session and roster stats', (tester) async {
    await _pump(
      tester,
      role: UserRole.teacher,
      teacherStats: const TeacherStats(
        totalSessions: 42,
        sessionsThisMonth: 7,
        studentCount: 9,
        instituteCount: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إجمالي الجلسات'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('جلسات هذا الشهر'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('عدد الطلاب'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('عدد المعاهد'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a student sees their session and level stats', (tester) async {
    await _pump(
      tester,
      role: UserRole.student,
      studentStats: const StudentStats(
        currentLevel: 2,
        totalSessions: 20,
        passedSessions: 15,
        completedLevelsList: [1],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إجمالي الجلسات'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('نسبة النجاح'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('المستويات المكتملة'), findsOneWidget);
    expect(find.text('المستوى الحالي'), findsOneWidget);

    // A student never sees the teacher-only metrics.
    expect(find.text('عدد المعاهد'), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/widget/settings_screen_test.dart --plain-name stats`
Expected: FAIL — the stats labels are not rendered yet.

- [ ] **Step 3: Add the stat widgets and role wiring**

In `lib/features/settings/screens/settings_screen.dart`, add the import for the student provider at the top (with the other imports):

```dart
import '../../student/providers/student_provider.dart';
```

In `SettingsScreen.build`, insert a role-selected stats card into the `ListView` children, between `_ProfileCard` and the teacher-only institutes block. Replace:

```dart
        children: [
          _ProfileCard(user: user),
          if (user.role == UserRole.teacher) ...[
            const SizedBox(height: 16),
            const _InstitutesCard(),
          ],
          const SizedBox(height: 24),
          _SignOutButton(),
        ],
```

with:

```dart
        children: [
          _ProfileCard(user: user),
          if (user.role == UserRole.teacher) ...[
            const SizedBox(height: 16),
            const _TeacherStatsCard(),
            const SizedBox(height: 16),
            const _InstitutesCard(),
          ] else if (user.role == UserRole.student ||
              user.role == UserRole.guardian) ...[
            const SizedBox(height: 16),
            const _StudentStatsCard(),
          ],
          const SizedBox(height: 24),
          _SignOutButton(),
        ],
```

Then add these three widgets at the end of the file (after `_SignOutButton`):

```dart
/// One metric on a stats card: a big value over a small Arabic label.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-in teacher's at-a-glance activity.
class _TeacherStatsCard extends ConsumerWidget {
  const _TeacherStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherStatsProvider);

    return statsAsync.maybeWhen(
      data: (stats) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نشاطي', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(
                  icon: Icons.menu_book_outlined,
                  value: '${stats.totalSessions}',
                  label: 'إجمالي الجلسات',
                ),
                _StatTile(
                  icon: Icons.calendar_month_outlined,
                  value: '${stats.sessionsThisMonth}',
                  label: 'جلسات هذا الشهر',
                ),
                _StatTile(
                  icon: Icons.school_outlined,
                  value: '${stats.studentCount}',
                  label: 'عدد الطلاب',
                ),
                _StatTile(
                  icon: Icons.business_outlined,
                  value: '${stats.instituteCount}',
                  label: 'عدد المعاهد',
                ),
              ],
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The signed-in student's (or a guardian's child's) progress at a glance.
class _StudentStatsCard extends ConsumerWidget {
  const _StudentStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentStatsProvider);

    return statsAsync.maybeWhen(
      data: (stats) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تقدّمي', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(
                  icon: Icons.menu_book_outlined,
                  value: '${stats.totalSessions}',
                  label: 'إجمالي الجلسات',
                ),
                _StatTile(
                  icon: Icons.check_circle_outline,
                  value: '${(stats.passRate * 100).round()}%',
                  label: 'نسبة النجاح',
                ),
                _StatTile(
                  icon: Icons.workspace_premium_outlined,
                  value: '${stats.completedLevels}',
                  label: 'المستويات المكتملة',
                ),
                _StatTile(
                  icon: Icons.trending_up_outlined,
                  value: '${stats.currentLevel}',
                  label: 'المستوى الحالي',
                ),
              ],
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
```

Note: `SettingsScreen` already imports `ConsumerWidget`/`WidgetRef` (via `flutter_riverpod`), `AppCard`, and `AppColors`. The `_InstitutesCard` in the same file is already a `ConsumerWidget`, confirming the imports are present.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/widget/settings_screen_test.dart`
Expected: PASS (all tests, including the two new stats tests and the unchanged sign-out tests).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/features/settings/screens/settings_screen.dart`
Expected: No issues.

```bash
git add lib/features/settings/screens/settings_screen.dart test/widget/settings_screen_test.dart
git commit -m "feat(profile): show role-aware activity stats on the profile screen"
```

---

### Task 8: Full-suite green + analyze

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: No issues (no new warnings introduced by this work).

- [ ] **Step 3: If anything fails**

Fix the specific failure in its owning file, re-run the failing test file, then re-run `flutter test`. Do not proceed until both commands are clean. Commit any fix with a `fix(profile): ...` message describing exactly what broke.

---

## Self-Review

**Spec coverage:**
- Strip `@alrasikhoon.local` app-wide → Task 1 (getter), Task 3 (profile card), Task 4 (admin lists). ✓
- Rename to "الملف الشخصي" across shells → Task 2 (nav + app bar, all three account destinations). ✓
- Teacher analytics (total sessions, this month, students, institutes) → Task 5 (count query), Task 6 (provider), Task 7 (card). ✓
- Student analytics (total sessions + pass rate, completed levels + current level) → Task 7 (`_StudentStatsCard` off existing `studentStatsProvider`). ✓
- Supervisor/admin: no stats card → Task 7 role wiring renders a card only for teacher/student/guardian. ✓
- Layering, no new index, don't rename routes → Global Constraints; honored per task. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. The only conditional note (InstituteModel constructor shape in Task 6) tells the implementer exactly how to resolve it from the model file. ✓

**Type consistency:** `displayUsername` (String getter) used identically in Tasks 3–4. `getSessionCountForTeacher(String, {DateTime? startDate})` defined in Task 5, called with those exact names in Task 6. `TeacherStats` fields (`totalSessions`, `sessionsThisMonth`, `studentCount`, `instituteCount`) defined in Task 6, read in Task 7. `StudentStats` fields (`totalSessions`, `passRate`, `completedLevels`, `currentLevel`) are the existing provider's real members. Provider names `teacherStatsProvider`/`studentStatsProvider` consistent across Tasks 6–7. ✓
