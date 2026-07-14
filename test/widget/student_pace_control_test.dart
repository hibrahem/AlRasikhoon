import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_overview_screen.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// Pins the pace control (Task 10): either a teacher or a supervisor may set
/// a student's pace directly on the session-overview screen — no approval
/// workflow, no history, just a segmented `1x / 2x / 3x` that calls
/// `StudentRepository.setStudentPace` and widens the pending meeting
/// immediately by invalidating the student provider.
void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumPace.standard);
  });

  final regularSession = SessionModel(
    id: 'L1_J30_S1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    orderInLevel: 1,
    kind: SessionKind.lesson,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 5,
    ),
  );

  PacedSession meetingFor(SessionModel session) => PacedSession(
    sessions: [session],
    newContent: [
      if (session.currentLevelContent != null) session.currentLevelContent!,
    ],
    recentReview: const [],
    distantReview: const [],
  );

  UserModel user() => UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  /// [pace] seeds the student's stored pace — `null` means "never set",
  /// which must render as 1x, not blank and not an error.
  StudentModel student({CurriculumPace? pace}) => StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S1',
    currentSessionKind: SessionKind.lesson,
    pace: pace,
    createdAt: DateTime(2026),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionOverviewScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a teacher can double a student\'s pace', (tester) async {
    final studentRepo = MockStudentRepository();
    when(
      () => studentRepo.setStudentPace(any(), any()),
    ).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        // A real Firestore access here (via StudentLevelProgress's
        // levelProvider) would error against no initialized Firebase app and
        // trip Riverpod's automatic retry — route it at an empty fake
        // instance instead, same as the other screen tests.
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        studentRepositoryProvider.overrideWithValue(studentRepo),
        studentProvider('s1').overrideWith(
          (ref) async => StudentWithUser(student: student(), user: user()),
        ),
        studentCurrentMeetingProvider(
          's1',
        ).overrideWith((ref) async => meetingFor(regularSession)),
      ],
    );
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();

    verify(() => studentRepo.setStudentPace('s1', CurriculumPace(2))).called(1);
  });

  testWidgets('a student\'s pace shows as 1x when none was ever set', (
    tester,
  ) async {
    final studentRepo = MockStudentRepository();
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        studentRepositoryProvider.overrideWithValue(studentRepo),
        studentProvider('s1').overrideWith(
          // No pace was ever stored for this student.
          (ref) async => StudentWithUser(student: student(), user: user()),
        ),
        studentCurrentMeetingProvider(
          's1',
        ).overrideWith((ref) async => meetingFor(regularSession)),
      ],
    );
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    expect(find.text('1x'), findsOneWidget);
  });

  testWidgets(
    'changing the pace invalidates the student so the meeting recomposes',
    (tester) async {
      final studentRepo = MockStudentRepository();
      when(
        () => studentRepo.setStudentPace(any(), any()),
      ).thenAnswer((_) async {});

      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          studentRepositoryProvider.overrideWithValue(studentRepo),
          studentProvider('s1').overrideWith((ref) async {
            // The first read reports pace 1x (nothing set yet); every read
            // after an invalidate reports 2x — proving a stale student is
            // never served after the write.
            reads += 1;
            return StudentWithUser(
              student: student(pace: reads == 1 ? null : CurriculumPace(2)),
              user: user(),
            );
          }),
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meetingFor(regularSession)),
        ],
      );
      addTearDown(container.dispose);
      await pumpScreen(tester, container);
      expect(find.text('1x'), findsOneWidget);

      await tester.tap(find.text('2x'));
      await tester.pumpAndSettle();

      // The control now reads the re-fetched (post-invalidate) student, which
      // reports pace 2x — this only happens if setting the pace invalidated
      // `studentProvider('s1')` rather than leaving the old snapshot cached.
      expect(reads, greaterThan(1));
      expect(find.text('2x'), findsWidgets);
    },
  );
}
