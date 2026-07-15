import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

void main() {
  group('destinationsFor', () {
    test('teacher has two tabs: students, settings', () {
      final destinations = destinationsFor(UserRole.teacher);

      expect(destinations.map((d) => d.label), ['الطلاب', 'الملف الشخصي']);
      expect(destinations.map((d) => d.rootPath), [
        AppRoutes.teacherStudents,
        AppRoutes.teacherSettings,
      ]);
    });

    test('teacher has no الحلقة tab', () {
      final labels = destinationsFor(UserRole.teacher).map((d) => d.label);

      expect(labels, isNot(contains('الحلقة')));
    });

    test('teacher has no dedicated السجل tab: history lives in the profile '
        '(al_rasikhoon-pb7)', () {
      final labels = destinationsFor(UserRole.teacher).map((d) => d.label);

      expect(labels, isNot(contains('السجل')));
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
