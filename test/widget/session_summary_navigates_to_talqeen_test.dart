import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_summary_screen.dart';
import 'package:al_rasikhoon/routing/app_router.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

void main() {
  testWidgets('summary button navigates to talqeen without completing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        studentProvider.overrideWith(
          (ref, id) async => StudentWithUser(
            student: StudentModel(
              id: 'student-1',
              userId: 'user-1',
              instituteId: 'i1',
              teacherId: 't1',
              currentLevel: 1,
              currentJuz: 30,
              currentHizb: 59,
              currentSession: 1,
              currentAttempt: 1,
              currentOrderInLevel: 2,
              createdAt: DateTime(2026, 1, 1),
            ),
            user: UserModel(
              id: 'user-1',
              username: 'pupil',
              email: 'pupil@x.local',
              name: 'طالب',
              role: UserRole.student,
              authProvider: UserAuthProvider.emailPassword,
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(activeSessionProvider.notifier)
        .seedForTest(
          ActiveSessionState(
            studentId: 'student-1',
            part1Errors: 0,
            meeting: PacedSession(
              sessions: [
                SessionModel(
                  id: 'L1_S2',
                  levelId: 1,
                  juzNumber: 30,
                  sessionNumber: 2,
                  orderInLevel: 2,
                  kind: SessionKind.lesson,
                ),
              ],
              newContent: [_c('النبأ', 1, 11)],
              recentReview: const [],
              distantReview: const [],
            ),
          ),
        );

    final router = GoRouter(
      initialLocation: '/teacher/session/student-1/summary',
      routes: [
        GoRoute(
          path: AppRoutes.sessionSummary,
          builder: (_, _) => const SessionSummaryScreen(studentId: 'student-1'),
        ),
        GoRoute(
          path: AppRoutes.nextContentTalqeen,
          builder: (_, _) => const Scaffold(body: Text('TALQEEN_STUB')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The button sits below the fold on the default test viewport — scroll
    // it into view before tapping so the tap isn't silently dropped for
    // landing outside the visible area.
    final nextButton = find.text('التالي: تلقين المقطع القادم');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('TALQEEN_STUB'), findsOneWidget);
    // The session is NOT completed by the summary.
    expect(container.read(activeSessionProvider)?.isComplete, isFalse);
  });
}
