import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

class MockSessionRepository extends Mock implements SessionRepository {}

/// Tests for the teacher-facing Riverpod providers (TEST_CASES.md §5.2):
/// `teacherStudentsProvider` and the `activeSessionProvider`
/// (`ActiveSessionState` / `ActiveSessionNotifier`) — error tracking,
/// pass detection, and `completeSession` advance-on-pass /
/// increment-on-fail behaviour.
void main() {
  late MockStudentRepository mockStudentRepository;
  late MockSessionRepository mockSessionRepository;

  setUp(() {
    mockStudentRepository = MockStudentRepository();
    mockSessionRepository = MockSessionRepository();
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
    String userId = 'user-1',
    String instituteId = 'institute-1',
    int currentLevel = 1,
    int currentJuz = 30,
    int currentHizb = 59,
    int currentSession = 5,
    int currentAttempt = 1,
  }) {
    return StudentModel(
      id: id,
      userId: userId,
      instituteId: instituteId,
      teacherId: 'teacher-1',
      currentLevel: currentLevel,
      currentJuz: currentJuz,
      currentHizb: currentHizb,
      currentSession: currentSession,
      currentAttempt: currentAttempt,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentWithUser buildStudentWithUser({String studentId = 'student-1'}) {
    return StudentWithUser(
      student: buildStudent(id: studentId),
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

  SessionRecordModel buildRecord({required bool passed}) {
    return SessionRecordModel(
      id: 'record-1',
      studentId: 'student-1',
      teacherId: 'teacher-1',
      curriculumSessionId: 'L1_J30_H59_S5',
      date: DateTime(2026, 1, 2),
      attemptNumber: 1,
      grades: SessionGrades(
        newMemorizationErrors: passed ? 1 : 5,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: passed,
      createdAt: DateTime(2026, 1, 2),
    );
  }

  ProviderContainer makeContainer({UserModel? user}) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        studentRepositoryProvider.overrideWithValue(mockStudentRepository),
        sessionRepositoryProvider.overrideWithValue(mockSessionRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('teacherStudentsProvider', () {
    test('returns the students assigned to the teacher', () async {
      final students = [
        buildStudentWithUser(studentId: 's-1'),
        buildStudentWithUser(studentId: 's-2'),
      ];
      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer((_) async => students);

      final container = makeContainer(user: buildTeacher());

      final result = await container.read(teacherStudentsProvider.future);

      expect(result, hasLength(2));
      verify(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).called(1);
    });

    test('returns empty list when no user is authenticated', () async {
      final container = makeContainer(user: null);

      final result = await container.read(teacherStudentsProvider.future);

      expect(result, isEmpty);
      verifyNever(() => mockStudentRepository.getStudentsForTeacher(any()));
    });
  });

  group('ActiveSessionState', () {
    test('starts null and is populated by startSession', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      expect(container.read(activeSessionProvider), isNull);

      notifier.startSession('student-1');

      final state = container.read(activeSessionProvider);
      expect(state, isNotNull);
      expect(state!.studentId, 'student-1');
      expect(state.currentPart, 1);
      expect(state.totalErrors, 0);
    });

    test('tracks per-part error counts as they are recorded', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 2);
      notifier.setPartErrors(2, 1);
      notifier.setPartErrors(3, 0);

      final state = container.read(activeSessionProvider)!;
      expect(state.part1Errors, 2);
      expect(state.part2Errors, 1);
      expect(state.part3Errors, 0);
      expect(state.totalErrors, 3);
    });

    test('errorsForPart reflects the current part', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 4);
      expect(container.read(activeSessionProvider)!.errorsForPart, 4);

      notifier.nextPart();
      notifier.setPartErrors(2, 7);
      expect(container.read(activeSessionProvider)!.currentPart, 2);
      expect(container.read(activeSessionProvider)!.errorsForPart, 7);
    });

    test('allPartsPassed is true when every part has <= 3 errors', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 3);
      notifier.setPartErrors(2, 3);
      notifier.setPartErrors(3, 3);

      expect(container.read(activeSessionProvider)!.allPartsPassed, isTrue);
    });

    test('allPartsPassed is false when any part exceeds 3 errors', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 3);
      notifier.setPartErrors(2, 4);
      notifier.setPartErrors(3, 0);

      expect(container.read(activeSessionProvider)!.allPartsPassed, isFalse);
    });

    test('nextPart caps at part 3', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.nextPart();
      notifier.nextPart();
      notifier.nextPart();
      notifier.nextPart();

      expect(container.read(activeSessionProvider)!.currentPart, 3);
    });

    test('endSession clears the active state', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      expect(container.read(activeSessionProvider), isNotNull);

      notifier.endSession();
      expect(container.read(activeSessionProvider), isNull);
    });
  });

  group('ActiveSessionNotifier.completeSession', () {
    test('advances the student session when the record passes', () async {
      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer((_) async => [buildStudentWithUser()]);
      when(
        () => mockSessionRepository.createSessionRecord(
          studentId: any(named: 'studentId'),
          teacherId: any(named: 'teacherId'),
          curriculumSessionId: any(named: 'curriculumSessionId'),
          levelId: any(named: 'levelId'),
          hizbNumber: any(named: 'hizbNumber'),
          sessionNumber: any(named: 'sessionNumber'),
          attemptNumber: any(named: 'attemptNumber'),
          newMemorizationErrors: any(named: 'newMemorizationErrors'),
          recentReviewErrors: any(named: 'recentReviewErrors'),
          distantReviewErrors: any(named: 'distantReviewErrors'),
          repetitions: any(named: 'repetitions'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => buildRecord(passed: true));
      when(
        () => mockStudentRepository.advanceStudentSession('student-1'),
      ).thenAnswer((_) async {});

      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 1);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);

      final record = await notifier.completeSession();

      expect(record, isNotNull);
      expect(record!.passed, isTrue);
      verify(
        () => mockStudentRepository.advanceStudentSession('student-1'),
      ).called(1);
      verifyNever(
        () => mockStudentRepository.incrementStudentAttempt(any()),
      );
      expect(container.read(activeSessionProvider)!.isComplete, isTrue);
    });

    test('increments the attempt when the record fails', () async {
      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer((_) async => [buildStudentWithUser()]);
      when(
        () => mockSessionRepository.createSessionRecord(
          studentId: any(named: 'studentId'),
          teacherId: any(named: 'teacherId'),
          curriculumSessionId: any(named: 'curriculumSessionId'),
          levelId: any(named: 'levelId'),
          hizbNumber: any(named: 'hizbNumber'),
          sessionNumber: any(named: 'sessionNumber'),
          attemptNumber: any(named: 'attemptNumber'),
          newMemorizationErrors: any(named: 'newMemorizationErrors'),
          recentReviewErrors: any(named: 'recentReviewErrors'),
          distantReviewErrors: any(named: 'distantReviewErrors'),
          repetitions: any(named: 'repetitions'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => buildRecord(passed: false));
      when(
        () => mockStudentRepository.incrementStudentAttempt('student-1'),
      ).thenAnswer((_) async {});

      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 5);

      final record = await notifier.completeSession();

      expect(record, isNotNull);
      expect(record!.passed, isFalse);
      verify(
        () => mockStudentRepository.incrementStudentAttempt('student-1'),
      ).called(1);
      verifyNever(
        () => mockStudentRepository.advanceStudentSession(any()),
      );
    });

    test('returns null when there is no active session state', () async {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      final record = await notifier.completeSession();

      expect(record, isNull);
    });

    test('returns null when no user is authenticated', () async {
      final container = makeContainer(user: null);
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');

      final record = await notifier.completeSession();

      expect(record, isNull);
      verifyNever(
        () => mockStudentRepository.advanceStudentSession(any()),
      );
    });
  });
}
