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

  testWidgets('sign out asks for confirmation before signing out', (
    tester,
  ) async {
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
