import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';

class MockSessionRepository extends Mock implements SessionRepository {}

class MockHomePracticeRepository extends Mock
    implements HomePracticeRepository {}

/// Pins the bug this task fixes: a student practises at home AFTER their
/// teacher has already completed a session and advanced them to the next one.
/// The logged practice must be filed against the session that was completed
/// (and that carries the home assignment) — never against the student's
/// current position, which by then is already one session ahead.
void main() {
  late MockSessionRepository mockSessionRepository;
  late MockHomePracticeRepository mockHomePracticeRepository;

  setUp(() {
    mockSessionRepository = MockSessionRepository();
    mockHomePracticeRepository = MockHomePracticeRepository();
  });

  test(
    'addPractice attributes the practice to the session the teacher just '
    'completed (X), not the session the student was advanced to (Y)',
    () async {
      // The teacher completed L1_J30_S2 and advanced the student to
      // L1_J30_S3 — the student's CURRENT position is now S3.
      final student = StudentModel(
        id: 'student-1',
        userId: 'user-1',
        instituteId: 'institute-1',
        currentLevel: 1,
        currentJuz: 30,
        currentSession: 3,
        currentHizb: 59,
        currentSessionId: 'L1_J30_S3',
        createdAt: DateTime(2026, 1, 1),
      );

      // The record of the session that was just completed (X = S2), carrying
      // the home assignment.
      final completedRecord = SessionRecordModel(
        id: 'record-s2',
        studentId: 'student-1',
        teacherId: 'teacher-1',
        curriculumSessionId: 'L1_J30_S2',
        levelId: 1,
        hizbNumber: 59,
        sessionNumber: 2,
        orderInLevel: 2,
        date: DateTime(2026, 1, 1),
        attemptNumber: 1,
        grades: const SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        ),
        passed: true,
        repetitionsWithTeacher: 5,
        homeRepetitionsRequired: 10,
        createdAt: DateTime(2026, 1, 1),
      );

      when(
        () => mockSessionRepository.getLatestSessionRecord('student-1'),
      ).thenAnswer((_) async => completedRecord);

      when(
        () => mockHomePracticeRepository.createHomePractice(
          studentId: any(named: 'studentId'),
          curriculumSessionId: any(named: 'curriculumSessionId'),
          levelId: any(named: 'levelId'),
          juzNumber: any(named: 'juzNumber'),
          hizbNumber: any(named: 'hizbNumber'),
          sessionNumber: any(named: 'sessionNumber'),
          repetitions: any(named: 'repetitions'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => 'practice-1');

      final container = ProviderContainer(
        overrides: [
          currentStudentProvider.overrideWith((ref) async => student),
          sessionRepositoryProvider.overrideWithValue(mockSessionRepository),
          homePracticeRepositoryProvider.overrideWithValue(
            mockHomePracticeRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(homePracticeNotifierProvider.notifier)
          .addPractice(repetitions: 4);

      expect(ok, isTrue);

      // The practice must carry S2's identity (the session it was assigned
      // in) — never S3, the student's current position. A regression that
      // stamps `student.currentSession`/`student.currentSessionId` again
      // would fail these two assertions (sessionNumber would read 3, and
      // curriculumSessionId would read '' — createHomePractice has no way to
      // reconstruct 'L1_J30_S3' from the student model alone).
      final captured = verify(
        () => mockHomePracticeRepository.createHomePractice(
          studentId: 'student-1',
          curriculumSessionId: captureAny(named: 'curriculumSessionId'),
          levelId: any(named: 'levelId'),
          juzNumber: any(named: 'juzNumber'),
          hizbNumber: any(named: 'hizbNumber'),
          sessionNumber: captureAny(named: 'sessionNumber'),
          repetitions: 4,
          notes: any(named: 'notes'),
        ),
      ).captured;

      expect(captured[0], 'L1_J30_S2');
      expect(captured[1], 2);
    },
  );
}
