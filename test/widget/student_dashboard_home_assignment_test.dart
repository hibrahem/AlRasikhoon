import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/shared/providers/current_student_provider.dart';
import 'package:al_rasikhoon/shared/providers/stats_provider.dart';
import 'package:al_rasikhoon/features/student/screens/student_dashboard_screen.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';
import 'package:al_rasikhoon/shared/widgets/progress_bar.dart';

/// hibrahem/AlRasikhoon final-review finding #5: the spec (§5) says the
/// student's DASHBOARD and the home-practice screen both show what he owes.
///
/// The dashboard redesign (al_rasikhoon-4gw) merged the standalone
/// `HomeAssignmentCard` into `HomePracticeCard` — one card, not two — so this
/// now pins the assignment's progress onto the dashboard via that merged
/// card instead of the old separate heading.
void main() {
  const lessonSession = SessionModel(
    id: 'L1_J30_S2',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 2,
    orderInLevel: 2,
    kind: SessionKind.lesson,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 11,
    ),
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentLevel: 1,
    currentJuz: 30,
    currentSession: 2,
    currentSessionId: 'L1_J30_S2',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 2,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, HomeAssignment? assignment) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          currentStudentProvider.overrideWith((ref) async => student),
          studentDashboardSessionProvider.overrideWith(
            (ref) async => lessonSession,
          ),
          studentStatsProvider.overrideWith(
            (ref) async => const StudentStats(
              currentLevel: 1,
              currentJuz: 30,
              currentSession: 2,
              currentOrderInLevel: 2,
            ),
          ),
          homePracticeStatsProvider.overrideWith(
            (ref) async => const HomePracticeStats(),
          ),
          homeAssignmentProvider.overrideWith((ref) async => assignment),
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
  }

  testWidgets('the dashboard shows the home assignment when one exists', (
    tester,
  ) async {
    await pump(
      tester,
      const HomeAssignment(
        curriculumSessionId: 'L1_J30_S1',
        repetitionsRequired: 10,
        repetitionsDone: 4,
      ),
    );

    expect(find.text('4 / 10'), findsOneWidget);
    expect(find.byType(ProgressBar), findsOneWidget);
  });

  testWidgets(
    'the dashboard renders nothing extra when there is no assignment',
    (tester) async {
      await pump(tester, null);

      expect(find.text('4 / 10'), findsNothing);
      expect(find.byType(ProgressBar), findsNothing);
    },
  );
}
