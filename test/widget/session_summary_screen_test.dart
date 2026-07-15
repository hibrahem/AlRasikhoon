import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/next_content_talqeen_screen.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_summary_screen.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// Drives `SessionSummaryScreen` end to end through the REAL wiring: pumps the
/// actual screen, taps the summary's hand-off button, then on the real
/// `NextContentTalqeenScreen` it navigates to (the summary no longer closes the
/// session itself — Task 6/7 — nor carries the counts) taps both repetition
/// steppers and completes the session, and reads the persisted session record
/// back out of a fake-Firestore-backed `SessionRepository`.
///
/// Nothing else exercised this integration: `grep -rn "RecitationCountsCard"
/// test/` only matched the standalone widget test, and there was no
/// `session_summary` test at all — so a regression that swapped the two
/// setters, or read a stale snapshot, would ship green. This test is proven
/// load-bearing below by sabotaging the wiring and confirming it goes red.
void main() {
  testWidgets(
    'tapping both steppers and saving persists the counts the teacher entered',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final sessionRepository = SessionRepository(firestore: firestore);
      final curriculumRepository = CurriculumRepository(firestore: firestore);
      final mockStudentRepository = MockStudentRepository();

      // The curriculum session the student stands on (order 7 of level 1) —
      // `completeSession` now composes a meeting from the curriculum before
      // writing anything, so this must exist for the composer to find.
      await firestore
          .collection('sessions')
          .doc('CUSTOM_SESSION_ID_NOT_REBUILT')
          .set({
            'level_id': 1,
            'juz_number': 30,
            'session_number': 1,
            'order_in_level': 7,
            'kind': 'lesson',
            'hizb_number': 59,
          });

      final teacher = UserModel(
        id: 'teacher-1',
        username: 'teacher_one',
        email: 'teacher_one@alrasikhoon.local',
        name: 'معلم',
        role: UserRole.teacher,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      );

      final student = StudentModel(
        id: 'student-1',
        userId: 'user-1',
        instituteId: 'institute-1',
        teacherId: 'teacher-1',
        currentLevel: 1,
        currentJuz: 30,
        currentHizb: 59,
        currentSession: 1,
        currentAttempt: 1,
        currentSessionId: 'CUSTOM_SESSION_ID_NOT_REBUILT',
        currentOrderInLevel: 7,
        createdAt: DateTime(2026, 1, 1),
      );
      final studentUser = UserModel(
        id: 'user-1',
        username: 'pupil',
        email: 'pupil@alrasikhoon.local',
        name: 'طالب',
        role: UserRole.student,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      );

      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer(
        (_) async => [StudentWithUser(student: student, user: studentUser)],
      );
      when(
        () => mockStudentRepository.advanceStudentSession(
          'student-1',
          fromOrderInLevel: 7,
        ),
      ).thenAnswer((_) async => StudentAdvanceOutcome.advanced);

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(teacher),
          studentRepositoryProvider.overrideWithValue(mockStudentRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);

      // Seed the active session BEFORE the first build — the screen renders
      // "لا توجد جلسة نشطة" when there is none.
      container.read(activeSessionProvider.notifier).startSession('student-1');

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const SessionSummaryScreen(studentId: 'student-1'),
          ),
          GoRoute(
            path: AppRoutes.nextContentTalqeen,
            builder: (context, state) {
              final studentId = state.pathParameters['studentId']!;
              return NextContentTalqeenScreen(studentId: studentId);
            },
          ),
          GoRoute(
            path: AppRoutes.teacherStudents,
            builder: (context, state) =>
                const Scaffold(body: Text('قائمة الطلاب')),
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

      // The summary no longer carries the counts or closes the session (Task 7
      // + the counts move) — it hands off to the talqeen step, which is now
      // where the teacher records the repetitions and ends the الحلقة.
      final nextButton = find.text('التالي: تلقين المقطع القادم');
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // On the talqeen screen: tap the increment stepper for "repetitions with
      // teacher" 3 times and for "home repetitions required" 5 times — two
      // DIFFERENT numbers so a swapped wiring (or a dropped setter) cannot pass
      // by coincidence.
      final withTeacherButton = find.byKey(
        const Key('increment_repetitions_with_teacher'),
      );
      final atHomeButton = find.byKey(
        const Key('increment_home_repetitions_required'),
      );
      // The steppers live inside a SingleChildScrollView — scroll them into
      // view before tapping so the tap isn't silently dropped for landing
      // outside the test viewport.
      await tester.ensureVisible(withTeacherButton);
      for (var i = 0; i < 3; i++) {
        await tester.tap(withTeacherButton);
        await tester.pump();
      }
      await tester.ensureVisible(atHomeButton);
      for (var i = 0; i < 5; i++) {
        await tester.tap(atHomeButton);
        await tester.pump();
      }

      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      final closeButton = find.text('إنهاء الحلقة');
      await tester.ensureVisible(closeButton);
      await tester.tap(closeButton);
      // Let the async save flow (record write, advance, SnackBar, navigation)
      // run to completion without waiting on the SnackBar's auto-dismiss.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Not the returned value — a real document, fetched back through the
      // (real, fake-Firestore-backed) repository, proving the wiring actually
      // reached the persisted record.
      final stored = await sessionRepository.getLatestSessionRecord(
        'student-1',
      );
      expect(stored, isNotNull);
      expect(stored!.repetitionsWithTeacher, 3);
      expect(stored.homeRepetitionsRequired, 5);
    },
  );
}
