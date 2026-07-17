import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/routing/app_router.dart';

/// Regression for al_rasikhoon-b75: the teacher-only Sard guard must block
/// exactly the teacher Sard SESSION routes (`/teacher/session/:studentId/sard`
/// and `.../sard/result`) — nothing else.
///
/// The `:kind` segment of every assessment-detail route is literally `sard`
/// (e.g. `/student/assessment/sard/:recordId`), so a guard that matches any
/// `/sard` path segment bounced a student tapping a سرد record in their own
/// history back to their dashboard (home) instead of opening the detail view.
/// Supervisors and admins opening a سرد record from a student's progress view
/// were bounced the same way.
void main() {
  String? redirectFor(UserRole role, String location) => guardRedirect(
    isAuthenticated: true,
    userRole: role,
    matchedLocation: location,
  );

  group('viewing a past سرد record is allowed for every role', () {
    test('student opens a سرد record from their own history', () {
      expect(
        redirectFor(UserRole.student, '/student/assessment/sard/rec1'),
        isNull,
        reason:
            'a student tapping a سرد record in سجل الحلقات must reach the '
            'assessment detail, not be bounced home (al_rasikhoon-b75)',
      );
    });

    test('supervisor opens a سرد record from a student progress view', () {
      expect(
        redirectFor(
          UserRole.supervisor,
          '/supervisor/students/assessment/sard/rec1',
        ),
        isNull,
      );
    });

    test('admin opens a سرد record from a student progress view', () {
      expect(
        redirectFor(
          UserRole.superAdmin,
          '/admin/students/assessment/sard/rec1',
        ),
        isNull,
      );
    });

    test('teacher opens a سرد record from the embedded profile history', () {
      expect(
        redirectFor(UserRole.teacher, '/teacher/assessment/sard/rec1'),
        isNull,
      );
    });
  });

  group('conducting a Sard session stays teacher-only (al_rasikhoon-801)', () {
    test('teacher may enter the Sard session and its result', () {
      expect(redirectFor(UserRole.teacher, '/teacher/session/s1/sard'), isNull);
      expect(
        redirectFor(UserRole.teacher, '/teacher/session/s1/sard/result'),
        isNull,
      );
    });

    test(
      'non-teachers crafting a Sard session URL bounce to their dashboard',
      () {
        expect(
          redirectFor(UserRole.supervisor, '/teacher/session/s1/sard'),
          AppRoutes.supervisorDashboard,
        );
        expect(
          redirectFor(UserRole.student, '/teacher/session/s1/sard/result'),
          AppRoutes.studentDashboard,
        );
        expect(
          redirectFor(UserRole.superAdmin, '/teacher/session/s1/sard'),
          AppRoutes.adminDashboard,
        );
      },
    );
  });

  test(
    'a student doc id merely starting with "sard" never trips the guard',
    () {
      // Pins the false positive the original segment-anchored regex excluded.
      expect(
        redirectFor(UserRole.supervisor, '/supervisor/students/sardOoPs123'),
        isNull,
      );
    },
  );
}
