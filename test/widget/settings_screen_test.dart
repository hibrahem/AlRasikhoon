import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/features/settings/screens/settings_screen.dart';
import 'package:al_rasikhoon/shared/providers/institute_provider.dart';
import 'package:al_rasikhoon/shared/providers/stats_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

UserModel _user(UserRole role) => UserModel(
  id: 'u1',
  username: 'hassan',
  email: 'hassan@alrasikhoon.local',
  name: 'أستاذ حسن',
  role: role,
  createdAt: DateTime(2024),
);

/// Records signOut() / updateOwnProfile() calls instead of touching
/// Firebase, so tests can observe whether the dialogs' gates actually
/// fired them.
class FakeAuthRepository extends AuthRepository {
  int signOutCallCount = 0;
  final List<({String name, String? phone})> profileUpdates = [];

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> updateOwnProfile({
    required String name,
    required String? phone,
  }) async {
    profileUpdates.add((name: name, phone: phone));
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required UserRole role,
  List<InstituteModel> institutes = const [],
  AuthRepository? authRepository,
  TeacherStats teacherStats = const TeacherStats(),
  StudentStats studentStats = const StudentStats(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user(role)),
        teacherInstitutesProvider.overrideWith((ref) async => institutes),
        teacherStatsProvider.overrideWith((ref) async => teacherStats),
        studentStatsProvider.overrideWith((ref) async => studentStats),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (authRepository != null)
          authRepositoryProvider.overrideWith(() => authRepository),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
}

/// The sign-out button sits at the bottom of a lazily-built ListView; scroll
/// it into view before tapping (the الحساب card pushed it off-screen).
Future<void> _tapSignOut(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('تسجيل الخروج'),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('تسجيل الخروج'));
}

void main() {
  testWidgets(
    'shows the name, clean username and role — never the .local email',
    (tester) async {
      await _pump(tester, role: UserRole.teacher);
      await tester.pumpAndSettle();

      expect(find.text('أستاذ حسن'), findsOneWidget);
      expect(find.text('hassan'), findsOneWidget);
      expect(find.text('hassan@alrasikhoon.local'), findsNothing);
      expect(find.text('معلم'), findsOneWidget);
      expect(
        find.text('الملف الشخصي'),
        findsOneWidget,
      ); // app-bar title (Task 2)
    },
  );

  testWidgets('cancelling the confirmation dialog does not sign out', (
    tester,
  ) async {
    final fakeAuth = FakeAuthRepository();
    await _pump(tester, role: UserRole.teacher, authRepository: fakeAuth);
    await tester.pumpAndSettle();

    await _tapSignOut(tester);
    await tester.pumpAndSettle();

    // The dialog is up, and nothing has happened yet.
    expect(find.text('هل تريد تسجيل الخروج؟'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsNothing);
    expect(fakeAuth.signOutCallCount, 0);
  });

  testWidgets('confirming the dialog signs out exactly once', (tester) async {
    final fakeAuth = FakeAuthRepository();
    await _pump(tester, role: UserRole.teacher, authRepository: fakeAuth);
    await tester.pumpAndSettle();

    await _tapSignOut(tester);
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'تسجيل الخروج'));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsNothing);
    expect(fakeAuth.signOutCallCount, 1);
  });

  testWidgets('dismissing the dialog via the barrier does not sign out', (
    tester,
  ) async {
    final fakeAuth = FakeAuthRepository();
    await _pump(tester, role: UserRole.teacher, authRepository: fakeAuth);
    await tester.pumpAndSettle();

    await _tapSignOut(tester);
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsOneWidget);

    // Tap far outside the dialog's bounds to hit the modal barrier. This is
    // the `confirmed == null` path — distinct from tapping إلغاء.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsNothing);
    expect(fakeAuth.signOutCallCount, 0);
  });

  group('profile self-service (al_rasikhoon-1nw)', () {
    testWidgets('edit affordance opens the profile dialog prefilled', (
      tester,
    ) async {
      await _pump(tester, role: UserRole.teacher);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('تعديل الملف الشخصي'));
      await tester.pumpAndSettle();

      expect(find.text('تعديل الملف الشخصي'), findsOneWidget);
      // Name prefilled: the dialog's field plus the profile card behind it.
      expect(find.text('أستاذ حسن'), findsNWidgets(2));
    });

    testWidgets('saving a valid edit calls updateOwnProfile and closes', (
      tester,
    ) async {
      final fakeAuth = FakeAuthRepository();
      await _pump(tester, role: UserRole.teacher, authRepository: fakeAuth);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('تعديل الملف الشخصي'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'أستاذ حسن'),
        'أستاذ حسن المحدث',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(fakeAuth.profileUpdates, hasLength(1));
      expect(fakeAuth.profileUpdates.single.name, 'أستاذ حسن المحدث');
      expect(fakeAuth.profileUpdates.single.phone, isNull);
      expect(find.text('تعديل الملف الشخصي'), findsNothing);
    });

    testWidgets('an empty name blocks the save with validation copy', (
      tester,
    ) async {
      final fakeAuth = FakeAuthRepository();
      await _pump(tester, role: UserRole.teacher, authRepository: fakeAuth);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('تعديل الملف الشخصي'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'أستاذ حسن'),
        '',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال الاسم'), findsOneWidget);
      expect(fakeAuth.profileUpdates, isEmpty);
    });

    testWidgets('the account card opens the change-password dialog', (
      tester,
    ) async {
      await _pump(tester, role: UserRole.student);
      await tester.pumpAndSettle();

      await tester.tap(find.text('تغيير كلمة المرور'));
      await tester.pumpAndSettle();

      expect(find.text('كلمة المرور الحالية'), findsOneWidget);
      expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور الجديدة'), findsOneWidget);
    });

    testWidgets('a mismatched confirmation blocks the password change', (
      tester,
    ) async {
      await _pump(tester, role: UserRole.student);
      await tester.pumpAndSettle();

      await tester.tap(find.text('تغيير كلمة المرور'));
      await tester.pumpAndSettle();

      // The dialog's three password fields are the only text fields on
      // screen: current, new, confirm — in declaration order.
      await tester.enterText(find.byType(TextFormField).at(0), 'current123');
      await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('كلمة المرور غير متطابقة'), findsOneWidget);
    });
  });

  testWidgets('a student does not see the institutes section', (tester) async {
    await _pump(tester, role: UserRole.student);
    await tester.pumpAndSettle();

    expect(find.text('المعاهد'), findsNothing);
  });

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
    expect(find.text('الجزء 30'), findsOneWidget);

    // A student never sees the teacher-only metrics.
    expect(find.text('عدد المعاهد'), findsNothing);
  });
}
