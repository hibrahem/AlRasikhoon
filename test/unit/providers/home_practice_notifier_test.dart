import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/shared/providers/current_student_provider.dart';

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
        kind: SessionKind.lesson,
        juzNumber: 30,
        hizbNumber: 59,
        sessionNumber: 2,
        fromOrderInLevel: 2,
        toOrderInLevel: 2,
        coversSessionIds: const ['L1_J30_S2'],
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

  // hibrahem/AlRasikhoon final-review finding #4: the student finishes juz
  // 30's last lesson, the teacher advances him into juz 29, and only THEN
  // does he log home practice. The juz must come from the completed
  // session's OWN record — never the student's CURRENT juz, which by then is
  // already 29 and would file the practice under a session that does not
  // exist ('L1_J30_S66' logged with juz_number: 29).
  test(
    'addPractice takes the juz from the completed record, not the student\'s '
    'CURRENT juz, across a juz boundary',
    () async {
      // The teacher completed the LAST session of juz 30 and advanced the
      // student into juz 29 — the student's CURRENT juz is already 29.
      final student = StudentModel(
        id: 'student-1',
        userId: 'user-1',
        instituteId: 'institute-1',
        currentLevel: 1,
        currentJuz: 29,
        currentSession: 1,
        currentHizb: 57,
        currentSessionId: 'L1_J29_S1',
        createdAt: DateTime(2026, 1, 1),
      );

      // The record of the session that was just completed — still juz 30.
      final completedRecord = SessionRecordModel(
        id: 'record-j30-last',
        studentId: 'student-1',
        teacherId: 'teacher-1',
        curriculumSessionId: 'L1_J30_S66',
        levelId: 1,
        kind: SessionKind.lesson,
        juzNumber: 30,
        hizbNumber: 60,
        sessionNumber: 66,
        fromOrderInLevel: 66,
        toOrderInLevel: 66,
        coversSessionIds: const ['L1_J30_S66'],
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

      // 30, from the record — NOT 29, the student's current juz. A
      // regression that reads `student.currentJuz` again would fail this
      // with 29 instead.
      final captured = verify(
        () => mockHomePracticeRepository.createHomePractice(
          studentId: 'student-1',
          curriculumSessionId: any(named: 'curriculumSessionId'),
          levelId: any(named: 'levelId'),
          juzNumber: captureAny(named: 'juzNumber'),
          hizbNumber: any(named: 'hizbNumber'),
          sessionNumber: any(named: 'sessionNumber'),
          repetitions: 4,
          notes: any(named: 'notes'),
        ),
      ).captured;

      expect(captured.single, 30);
    },
  );

  // hibrahem/AlRasikhoon final-review finding #2: a record written before
  // `juz_number` shipped reads back with `juzNumber: null` (never a sentinel
  // like 0, which is not a real juz). `addPractice` must fall back to the
  // student's OWN current juz in that case — a regression that reads
  // `lastRecord?.juzNumber ?? student.currentJuz` while `juzNumber` still
  // defaulted to 0 in the model would never hit this fallback at all, since
  // 0 is not null, and would file the practice under a juz that does not
  // exist.
  test('addPractice falls back to the student\'s OWN currentJuz when the last '
      'record predates the juz_number field', () async {
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

    // A pre-migration record: written before `juz_number` existed, so it
    // carries no juz at all.
    final preMigrationRecord = SessionRecordModel(
      id: 'record-pre-migration',
      studentId: 'student-1',
      teacherId: 'teacher-1',
      curriculumSessionId: 'L1_J30_S2',
      levelId: 1,
      kind: SessionKind.lesson,
      juzNumber: null,
      hizbNumber: 59,
      sessionNumber: 2,
      fromOrderInLevel: 2,
      toOrderInLevel: 2,
      coversSessionIds: const ['L1_J30_S2'],
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
    ).thenAnswer((_) async => preMigrationRecord);

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

    // 30, the student's OWN current juz — never 0, and never null.
    final captured = verify(
      () => mockHomePracticeRepository.createHomePractice(
        studentId: 'student-1',
        curriculumSessionId: any(named: 'curriculumSessionId'),
        levelId: any(named: 'levelId'),
        juzNumber: captureAny(named: 'juzNumber'),
        hizbNumber: any(named: 'hizbNumber'),
        sessionNumber: any(named: 'sessionNumber'),
        repetitions: 4,
        notes: any(named: 'notes'),
      ),
    ).captured;

    expect(captured.single, 30);
  });

  test('addPractice falls back to the student\'s OWN currentSessionId — never '
      "'' — when there is no session record yet", () async {
    final student = StudentModel(
      id: 'student-1',
      userId: 'user-1',
      instituteId: 'institute-1',
      currentLevel: 1,
      currentJuz: 30,
      currentSession: 1,
      currentHizb: 59,
      currentSessionId: 'L1_J30_S1',
      createdAt: DateTime(2026, 1, 1),
    );

    // No session record yet — a brand-new student who hasn't had a single
    // session with their teacher.
    when(
      () => mockSessionRepository.getLatestSessionRecord('student-1'),
    ).thenAnswer((_) async => null);

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

    // Every field must come from the student's CURRENT position, and the
    // session id must be the student's real `currentSessionId` — not ''.
    // An empty id would make the document internally inconsistent (level,
    // hizb and session number would say 'L1_J30_S1' while the id said
    // nothing) and could never match `homeAssignmentProvider`'s equality
    // filter, silently hiding the practice from the student's own
    // assignment view.
    verify(
      () => mockHomePracticeRepository.createHomePractice(
        studentId: 'student-1',
        curriculumSessionId: 'L1_J30_S1',
        levelId: 1,
        juzNumber: 30,
        hizbNumber: 59,
        sessionNumber: 1,
        repetitions: 4,
        notes: any(named: 'notes'),
      ),
    ).called(1);
  });
}
