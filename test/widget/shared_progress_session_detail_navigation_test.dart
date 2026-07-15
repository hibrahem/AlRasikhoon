import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';

/// Pins the benign cross-shell behavior flagged by al_rasikhoon-e7o.
///
/// The shared [StudentProgressScreen] is opened by BOTH admin and supervisor.
/// Its session-history card taps through to the `sessionDetailRoute` INJECTED
/// by the router — al_rasikhoon-3hn made that route shell-local (the admin's
/// `/admin/students/history/:recordId`, the supervisor's
/// `/supervisor/students/history/:recordId`), NOT the student-shell route
/// `/student/history/:recordId`.
///
/// This test documents and LOCKS the current, verified-benign behavior so a
/// regression that turns it harmful fails here. It pins that tapping a history
/// record:
///   * opens the read-only تفاصيل الحلقة detail view,
///   * lands on the shell-LOCAL detail route the router injected — never the
///     student-shell route, and
///   * never crosses into the student shell (no student bottom nav bar) and
///     exposes no privileged action (no FAB/action button).
///
/// Option (b) from the issue (pin current behavior) was chosen over (a)
/// (restructure routing) to keep the change low-risk and out of `app_router`.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  // Stamped on a STUBBED student-shell scaffold registered at the STUDENT
  // route. Reaching it would mean the tap crossed shells — exactly the
  // regression we pin against. Its absence after the tap proves the tap stayed
  // in the injecting shell.
  const studentShellNavKey = Key('student-shell-nav-sentinel');

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S5',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 5,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  final meeting = PacedSession(
    sessions: const [
      SessionModel(
        id: 'L1_J30_S5',
        levelId: 1,
        juzNumber: 30,
        sessionNumber: 5,
        orderInLevel: 5,
        kind: SessionKind.lesson,
        currentLevelContent: QuranContent(
          fromSurah: 'النبأ',
          fromVerse: 31,
          toSurah: 'النبأ',
          toVerse: 37,
        ),
      ),
    ],
    newContent: const [
      QuranContent(
        fromSurah: 'النبأ',
        fromVerse: 31,
        toSurah: 'النبأ',
        toVerse: 37,
      ),
    ],
    recentReview: const [],
    distantReview: const [],
  );

  // One graded lesson record. Its history card reads 'الحلقة 5' — the tap
  // target.
  final record = SessionRecordModel(
    id: 'r1',
    studentId: 's1',
    teacherId: 'teacher1',
    curriculumSessionId: 'L1_J30_S5',
    levelId: 1,
    kind: SessionKind.lesson,
    juzNumber: 30,
    hizbNumber: 59,
    sessionNumber: 5,
    fromOrderInLevel: 5,
    toOrderInLevel: 5,
    coversSessionIds: const ['L1_J30_S5'],
    date: DateTime(2026, 7, 14),
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 0,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    passed: true,
    createdAt: DateTime(2026, 7, 14),
  );

  /// Drives the shared progress screen for one role and asserts the tap-through
  /// lands on the injected shell-local detail — never the student shell.
  Future<void> runFor(
    WidgetTester tester, {
    required FutureProviderFamily<StudentWithUser?, String> studentProvider,
    required FutureProviderFamily<PacedSession?, String> currentMeetingProvider,
    required FutureProviderFamily<List<SessionRecordModel>, String>
    sessionHistoryProvider,
    required String progressPath,
    required String progressLocation,
    required String injectedDetailRoute,
    required String expectedDetailLocation,
  }) async {
    final router = GoRouter(
      initialLocation: progressLocation,
      routes: [
        GoRoute(
          path: progressPath,
          builder: (context, state) => StudentProgressScreen(
            studentId: 's1',
            studentProvider: studentProvider,
            currentMeetingProvider: currentMeetingProvider,
            sessionHistoryProvider: sessionHistoryProvider,
            sessionDetailRoute: injectedDetailRoute,
          ),
        ),
        GoRoute(
          path: injectedDetailRoute,
          builder: (context, state) =>
              SessionDetailScreen(recordId: state.pathParameters['recordId']!),
        ),
        // Stubbed student shell: landing here means the tap crossed shells.
        GoRoute(
          path: AppRoutes.sessionDetail,
          builder: (context, state) => Scaffold(
            bottomNavigationBar: BottomNavigationBar(
              key: studentShellNavKey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'student',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'history',
                ),
              ],
            ),
            body: const Center(child: Text('STUDENT SHELL')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          currentMeetingProvider('s1').overrideWith((ref) async => meeting),
          sessionHistoryProvider('s1').overrideWith((ref) async => [record]),
          // Feeds the destination detail screen.
          sessionRecordByIdProvider(
            record.id,
          ).overrideWith((ref) async => record),
          curriculumSessionByIdProvider(
            record.curriculumSessionId,
          ).overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Precondition: we are on the shared progress screen, history card present.
    // The 'نجح' pass badge is unique to the history card ('الحلقة 5' also
    // appears on the current-session card, so it is not a safe tap target).
    expect(find.text('تقدم الطالب'), findsOneWidget);
    expect(find.text('سجل الحلقات'), findsOneWidget);
    expect(find.text('نجح'), findsOneWidget);

    await tester.ensureVisible(find.text('نجح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نجح'));
    await tester.pumpAndSettle();

    // The read-only detail view opened.
    expect(find.text('تفاصيل الحلقة'), findsOneWidget);

    // It used the shell-LOCAL route the router injected, not the student route.
    // The card calls `context.push`, so the pushed match is the LAST match in
    // the configuration (`uri` alone stays at the base progress location under
    // an imperative push).
    final location =
        router.routerDelegate.currentConfiguration.last.matchedLocation;
    expect(location, expectedDetailLocation);
    expect(location.contains('/student/'), isFalse);

    // No student shell was entered (no student bottom nav bar).
    expect(find.byKey(studentShellNavKey), findsNothing);
    expect(find.text('STUDENT SHELL'), findsNothing);

    // The detail view offers no privileged action.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  }

  testWidgets(
    'admin: tapping a history record opens the read-only detail in the ADMIN '
    'shell, not the student shell',
    (tester) async {
      await runFor(
        tester,
        studentProvider: adminStudentProvider,
        currentMeetingProvider: adminStudentCurrentMeetingProvider,
        sessionHistoryProvider: adminStudentSessionHistoryProvider,
        progressPath: AppRoutes.adminStudentProgress,
        progressLocation: '/admin/students/s1',
        injectedDetailRoute: AppRoutes.adminStudentSessionDetail,
        expectedDetailLocation: '/admin/students/history/r1',
      );
    },
  );

  testWidgets(
    'supervisor: tapping a history record opens the read-only detail in the '
    'SUPERVISOR shell, not the student shell',
    (tester) async {
      await runFor(
        tester,
        studentProvider: supervisorStudentProvider,
        currentMeetingProvider: supervisorStudentCurrentMeetingProvider,
        sessionHistoryProvider: supervisorStudentSessionHistoryProvider,
        progressPath: AppRoutes.supervisorStudentProgress,
        progressLocation: '/supervisor/students/s1',
        injectedDetailRoute: AppRoutes.supervisorStudentSessionDetail,
        expectedDetailLocation: '/supervisor/students/history/r1',
      );
    },
  );
}
