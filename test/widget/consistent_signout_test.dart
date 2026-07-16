import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/admin_dashboard_screen.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/shared/providers/current_student_provider.dart';
import 'package:al_rasikhoon/shared/providers/stats_provider.dart';
import 'package:al_rasikhoon/features/student/screens/student_dashboard_screen.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/supervisor_dashboard_screen.dart';
import 'package:al_rasikhoon/features/supervisor/screens/supervisor_students_screen.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

/// Records signOut() calls instead of touching Firebase, so tests can observe
/// whether the confirmation dialog's gate actually fired it. Mirrors the fake
/// used by settings_screen_test.dart so both entry points are held to the same
/// confirmed-only contract.
class FakeAuthRepository extends AuthRepository {
  int signOutCallCount = 0;

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

UserModel _student() => UserModel(
  id: 'u1',
  email: 'student@example.com',
  name: 'طالب',
  role: UserRole.student,
  createdAt: DateTime(2026),
);

void main() {
  group('dashboards no longer expose an unconfirmed AppBar logout', () {
    testWidgets('admin dashboard has no AppBar logout', (tester) async {
      // The admin Management hub (branch 0 of the 3-tab admin shell) no
      // longer carries a sign-out affordance of its own: sign-out now lives
      // exclusively in the Profile tab (SettingsScreen), whose own
      // confirmed-only gate is covered by settings_screen_test.dart. This
      // replaces the old "admin AppBar sign-out is confirmed, never one-tap"
      // group, which asserted an AppBar logout icon that this feature
      // removed from AdminDashboardScreen.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminStatsProvider.overrideWith((ref) async => const AdminStats()),
            authRepositoryProvider.overrideWith(FakeAuthRepository.new),
          ],
          child: const MaterialApp(home: AdminDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('supervisor dashboard has no AppBar logout', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supervisorStatsProvider.overrideWith(
              (ref) async => const SupervisorStats(),
            ),
            authRepositoryProvider.overrideWith(FakeAuthRepository.new),
          ],
          child: const MaterialApp(home: SupervisorDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('supervisor students screen has no AppBar logout', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supervisorStudentsProvider.overrideWith(
              (ref) async => const <StudentWithUser>[],
            ),
            authRepositoryProvider.overrideWith(FakeAuthRepository.new),
          ],
          child: const MaterialApp(home: SupervisorStudentsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('student dashboard has no AppBar logout', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_student()),
            currentStudentProvider.overrideWith((ref) async => null),
            studentStatsProvider.overrideWith(
              (ref) async => const StudentStats(),
            ),
            studentDashboardMeetingProvider.overrideWith((ref) async => null),
            homePracticeStatsProvider.overrideWith(
              (ref) async => const HomePracticeStats(),
            ),
            homeAssignmentProvider.overrideWith((ref) async => null),
            authRepositoryProvider.overrideWith(FakeAuthRepository.new),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: StudentDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsNothing);
    });
  });
}
