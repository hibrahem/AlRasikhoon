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
