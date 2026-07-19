import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// Drives `ActiveSessionNotifier.completeTalqeenSession()` through a real
/// Riverpod container (TEST_CASES.md §5.2). A تلقين is teacher-led — the
/// teacher recites the new passage to the student — never graded, never
/// failed, never attempt-limited, and it must ALWAYS advance the student.
///
/// `SessionRepository` AND `CurriculumRepository` are the REAL
/// implementations backed by a fake Firestore (not mocks), so the record
/// assertions below prove an actual document was written with the right
/// shape — not just that a stub returned a canned value, and so
/// `completeTalqeenSession`'s meeting composition (which reads the level's
/// sessions from the curriculum) has real data to compose from.
/// `StudentRepository` is mocked, mocktail-style, exactly like
/// `teacher_provider_test.dart`'s `completeSession` tests, so the
/// advance/never-increment claims can be verified precisely.
void main() {
  late MockStudentRepository mockStudentRepository;
  late FakeFirebaseFirestore firestore;
  late SessionRepository sessionRepository;
  late CurriculumRepository curriculumRepository;

  setUp(() async {
    mockStudentRepository = MockStudentRepository();
    firestore = FakeFirebaseFirestore();
    sessionRepository = SessionRepository(firestore: firestore);
    curriculumRepository = CurriculumRepository(firestore: firestore);

    // The single curriculum session the student stands on — a تلقين at order
    // 7 of level 1. Its id is deliberately NOT of the `L{level}_J{juz}_S{n}`
    // shape a rebuild from level/juz/session/hizb numbers would produce, so
    // the test can tell "the record names the session the composer found at
    // the student's own order_in_level" apart from "reconstructed it".
    await firestore
        .collection('sessions')
        .doc('CUSTOM_SESSION_ID_NOT_REBUILT')
        .set({
          'level_id': 1,
          'juz_number': 30,
          'session_number': 1,
          'order_in_level': 7,
          'kind': 'talqeen',
          'hizb_number': 59,
        });
  });

  UserModel buildTeacher({String id = 'teacher-1'}) {
    return UserModel(
      id: id,
      username: 'teacher_one',
      email: 'teacher_one@alrasikhoon.local',
      name: 'معلم',
      role: UserRole.teacher,
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentModel buildStudent({
    String id = 'student-1',
    // Deliberately NOT of the `L{level}_J{juz}_S{n}` (or the old
    // `..._H{hizb}_S{n}`) shape a rebuild from level/juz/session/hizb numbers
    // would produce — so the test can tell "read the student's own id
    // verbatim" apart from "reconstructed it".
    String currentSessionId = 'CUSTOM_SESSION_ID_NOT_REBUILT',
    int currentAttempt = 1,
    // A distinctive non-default value (StudentModel defaults to 1) so a
    // record carrying the DEFAULT instead of the student's own value is
    // caught, not masked by a coincidental match.
    int currentOrderInLevel = 7,
  }) {
    return StudentModel(
      id: id,
      userId: 'user-1',
      instituteId: 'institute-1',
      teacherId: 'teacher-1',
      currentLevel: 1,
      currentJuz: 30,
      currentHizb: 59,
      currentSession: 1,
      currentAttempt: currentAttempt,
      currentSessionId: currentSessionId,
      currentOrderInLevel: currentOrderInLevel,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentWithUser buildStudentWithUser({
    String studentId = 'student-1',
    String currentSessionId = 'CUSTOM_SESSION_ID_NOT_REBUILT',
    int currentAttempt = 1,
    int currentOrderInLevel = 7,
  }) {
    return StudentWithUser(
      student: buildStudent(
        id: studentId,
        currentSessionId: currentSessionId,
        currentAttempt: currentAttempt,
        currentOrderInLevel: currentOrderInLevel,
      ),
      user: UserModel(
        id: 'user-1',
        username: 'pupil',
        email: 'pupil@alrasikhoon.local',
        name: 'طالب',
        role: UserRole.student,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  ProviderContainer makeContainer({UserModel? user}) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        studentRepositoryProvider.overrideWithValue(mockStudentRepository),
        sessionRepositoryProvider.overrideWithValue(sessionRepository),
        curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ActiveSessionNotifier.completeTalqeenSession', () {
    test(
      "writes a record against the student's OWN current_session_id, "
      'carrying both counts, zeroed grades and an unconditional pass',
      () async {
        when(
          () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
        ).thenAnswer((_) async => [buildStudentWithUser()]);
        when(
          () => mockStudentRepository.advanceStudentSession(
            'student-1',
            fromOrderInLevel: 7,
            batch: any(named: 'batch'),
          ),
        ).thenAnswer((_) async => StudentAdvanceOutcome.advanced);

        final container = makeContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.startSession('student-1');
        notifier.setRepetitionsWithTeacher(6);
        notifier.setHomeRepetitionsRequired(15);

        final record = await notifier.completeTalqeenSession();
        // The batch commit is fire-and-forget (offline support): drain the
        // event queue so the staged writes land before asserting on them.
        await pumpEventQueue();

        expect(record, isNotNull);
        expect(record!.curriculumSessionId, 'CUSTOM_SESSION_ID_NOT_REBUILT');
        expect(record.passed, isTrue);
        expect(record.grades.newMemorizationErrors, 0);
        expect(record.grades.recentReviewErrors, 0);
        expect(record.grades.distantReviewErrors, 0);
        expect(record.repetitionsWithTeacher, 6);
        expect(record.homeRepetitionsRequired, 15);
        // The student's OWN currentOrderInLevel (7, set by buildStudent) —
        // never a hardcoded or recomputed value.
        expect(record.toOrderInLevel, 7);

        // Not just the returned value — a real document, fetched back through
        // the (real, fake-Firestore-backed) repository.
        final stored = await sessionRepository.getSessionRecordById(record.id);
        expect(stored, isNotNull);
        expect(stored!.curriculumSessionId, 'CUSTOM_SESSION_ID_NOT_REBUILT');
        expect(stored.passed, isTrue);
        expect(stored.grades.totalErrors, 0);
        expect(stored.repetitionsWithTeacher, 6);
        expect(stored.homeRepetitionsRequired, 15);
        expect(stored.toOrderInLevel, 7);
      },
    );

    test(
      'ALWAYS advances the student — even one who has "attempted" this '
      'تلقين more than once — and NEVER increments the attempt counter',
      () async {
        when(
          () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
        ).thenAnswer((_) async => [buildStudentWithUser(currentAttempt: 3)]);
        when(
          () => mockStudentRepository.advanceStudentSession(
            'student-1',
            fromOrderInLevel: 7,
            batch: any(named: 'batch'),
          ),
        ).thenAnswer((_) async => StudentAdvanceOutcome.advanced);

        final container = makeContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.startSession('student-1');

        final record = await notifier.completeTalqeenSession();
        // The batch commit is fire-and-forget (offline support): drain the
        // event queue so the staged writes land before asserting on them.
        await pumpEventQueue();

        expect(record, isNotNull);
        verify(
          () => mockStudentRepository.advanceStudentSession(
            'student-1',
            fromOrderInLevel: 7,
            batch: any(named: 'batch'),
          ),
        ).called(1);
        verifyNever(() => mockStudentRepository.incrementStudentAttempt(any()));
        expect(
          container.read(activeSessionProvider)!.advanceOutcome,
          StudentAdvanceOutcome.advanced,
        );
      },
    );

    test('invalidates teacherStudentsProvider and studentProvider — the same '
        'providers completeSession() invalidates', () async {
      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer((_) async => [buildStudentWithUser()]);
      when(
        () => mockStudentRepository.advanceStudentSession(
          'student-1',
          fromOrderInLevel: 7,
          batch: any(named: 'batch'),
        ),
      ).thenAnswer((_) async => StudentAdvanceOutcome.advanced);

      final container = makeContainer(user: buildTeacher());

      // Warm both providers so they hold resolved AsyncData.
      await container.read(teacherStudentsProvider.future);
      await container.read(studentProvider('student-1').future);
      expect(container.read(teacherStudentsProvider), isA<AsyncData>());
      expect(container.read(studentProvider('student-1')), isA<AsyncData>());
      verify(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).called(1);

      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      await notifier.completeTalqeenSession();
      // The batch commit is fire-and-forget (offline support): drain the
      // event queue so the staged writes land before asserting on them.
      await pumpEventQueue();

      // An invalidated provider rebuilds on the very next read: reading it
      // synchronously right afterwards must catch it mid-refresh (Riverpod
      // keeps the previous value visible but flags `isLoading`), not still
      // quietly serving the pre-talqeen AsyncData as if nothing invalidated.
      expect(container.read(teacherStudentsProvider).isLoading, isTrue);
      expect(container.read(studentProvider('student-1')).isLoading, isTrue);

      // ...and the rebuild really re-fetches from the repository.
      await container.read(teacherStudentsProvider.future);
      verify(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).called(1);
    });
  });
}
