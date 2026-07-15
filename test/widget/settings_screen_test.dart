import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/features/settings/screens/settings_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

UserModel _user(UserRole role) => UserModel(
  id: 'u1',
  username: 'hassan',
  email: 'hassan@alrasikhoon.local',
  name: 'أستاذ حسن',
  role: role,
  createdAt: DateTime(2024),
);

/// Records signOut() calls instead of touching Firebase, so tests can
/// observe whether the confirmation dialog's gate actually fired it.
class FakeAuthRepository extends AuthRepository {
  int signOutCallCount = 0;

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required UserRole role,
  List<InstituteModel> institutes = const [],
  AuthRepository? authRepository,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user(role)),
        teacherInstitutesProvider.overrideWith((ref) async => institutes),
        if (authRepository != null)
          authRepositoryProvider.overrideWith(() => authRepository),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
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

    await tester.tap(find.text('تسجيل الخروج'));
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

    await tester.tap(find.text('تسجيل الخروج'));
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

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsOneWidget);

    // Tap far outside the dialog's bounds to hit the modal barrier. This is
    // the `confirmed == null` path — distinct from tapping إلغاء.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('هل تريد تسجيل الخروج؟'), findsNothing);
    expect(fakeAuth.signOutCallCount, 0);
  });

  testWidgets('a student does not see the institutes section', (tester) async {
    await _pump(tester, role: UserRole.student);
    await tester.pumpAndSettle();

    expect(find.text('المعاهد'), findsNothing);
  });
}
