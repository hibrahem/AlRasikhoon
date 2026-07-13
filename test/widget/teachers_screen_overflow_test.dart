import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/teacher_detail_screen.dart';
import 'package:al_rasikhoon/features/admin/screens/teachers_screen.dart';

/// Widget tests for the admin teacher list — al_rasikhoon-ib7.
///
/// A teacher card lays the contact line (phone, or the synthesized
/// `username@…` email when no phone was given) beside an avatar, a status
/// badge and a chevron. On a phone-width screen the contact line gets ~180
/// logical pixels, so a long email overflowed the row instead of ellipsizing.

UserModel _teacher({
  required String id,
  required String name,
  required String email,
  String? phone,
}) {
  return UserModel(
    id: id,
    username: id,
    email: email,
    phone: phone,
    name: name,
    role: UserRole.teacher,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Pumps the teachers list at a phone width (360 logical px), which is what
/// squeezes the contact line hard enough to expose the overflow.
Future<void> _pumpAtPhoneWidth(
  WidgetTester tester,
  List<UserModel> teachers,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [allTeachersProvider.overrideWith((ref) async => teachers)],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: TeachersScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a teacher with no phone shows a long email without overflowing',
    (tester) async {
      await _pumpAtPhoneWidth(tester, [
        _teacher(
          id: 'abdulrahman_almuhaisin',
          name: 'عبد الرحمن المحيسن',
          // No phone: the card falls back to the synthesized login email, which
          // is as long as the username the admin chose.
          email: 'abdulrahman_almuhaisin@alrasikhoon.local',
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(
        find.text('abdulrahman_almuhaisin@alrasikhoon.local'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a teacher with a long name does not overflow', (tester) async {
    await _pumpAtPhoneWidth(tester, [
      _teacher(
        id: 't2',
        name: 'عبد الرحمن بن عبد العزيز بن محمد المحيسن الشهري',
        email: 't2@alrasikhoon.local',
        phone: '+966501234567',
      ),
    ]);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the teacher detail header shows a long email without overflowing',
    (tester) async {
      const teacherId = 'abdulrahman_almuhaisin';
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherProvider(teacherId).overrideWith(
              (ref) async => _teacher(
                id: teacherId,
                name: 'عبد الرحمن المحيسن',
                email: 'abdulrahman_almuhaisin@alrasikhoon.local',
              ),
            ),
            institutesForTeacherProvider(
              teacherId,
            ).overrideWith((ref) async => []),
            studentsForTeacherAdminProvider(
              teacherId,
            ).overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: TeacherDetailScreen(teacherId: teacherId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every teacher in a long list renders without overflowing', (
    tester,
  ) async {
    await _pumpAtPhoneWidth(tester, [
      for (var i = 0; i < 12; i++)
        _teacher(
          id: 'teacher_number_$i',
          name: 'المعلم رقم $i',
          email: 'teacher_number_${i}_almuhaisin@alrasikhoon.local',
          // Half have a phone, half fall back to the long email.
          phone: i.isEven ? null : '+96650123456$i',
        ),
    ]);

    expect(tester.takeException(), isNull);
  });
}
