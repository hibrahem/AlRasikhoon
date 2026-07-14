import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';

/// A one-session meeting standing in for whatever `PacedSessionComposer`
/// would have produced — these tests exercise `homeAssignmentProvider`, not
/// composition, so the content blocks are irrelevant and left empty.
PacedSession _meeting({
  required String id,
  required int sessionNumber,
  required int orderInLevel,
  int levelId = 1,
}) {
  final session = SessionModel(
    id: id,
    levelId: levelId,
    juzNumber: 30,
    sessionNumber: sessionNumber,
    orderInLevel: orderInLevel,
    kind: SessionKind.talqeen,
  );
  return PacedSession(
    sessions: [session],
    newContent: const [],
    recentReview: const [],
    distantReview: const [],
  );
}

/// Exercises `homeAssignmentProvider` through a real Riverpod container with
/// `SessionRepository` and `HomePracticeRepository` backed by a fake
/// Firestore (not mocks) — so the assertions below prove the provider reads
/// documents shaped the way the app actually writes them, not that a stub
/// returned a canned value.
///
/// The assignment always comes from the student's LATEST session record, and
/// `repetitionsDone` must sum ONLY the home practices attributed to that
/// record's `curriculumSessionId` — never practices logged against an OLDER,
/// superseded assignment. That equality filter is the whole point of this
/// provider: without it, a student who was re-taught (a new record for a
/// later session) would see a "completed" assignment made up of repetitions
/// they logged against a session that no longer matters.
void main() {
  late FakeFirebaseFirestore firestore;
  late SessionRepository sessionRepository;
  late HomePracticeRepository homePracticeRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    sessionRepository = SessionRepository(firestore: firestore);
    homePracticeRepository = HomePracticeRepository(firestore: firestore);
  });

  StudentModel buildStudent() {
    return StudentModel(
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
  }

  ProviderContainer makeContainer(StudentModel? student) {
    final container = ProviderContainer(
      overrides: [
        currentStudentProvider.overrideWith((ref) async => student),
        sessionRepositoryProvider.overrideWithValue(sessionRepository),
        homePracticeRepositoryProvider.overrideWithValue(
          homePracticeRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('is null when the student has no session record at all', () async {
    final container = makeContainer(buildStudent());

    final assignment = await container.read(homeAssignmentProvider.future);

    expect(assignment, isNull);
  });

  test(
    'is null when the latest session record assigned zero home repetitions',
    () async {
      await sessionRepository.createTalqeenRecord(
        studentId: 'student-1',
        teacherId: 'teacher-1',
        meeting: _meeting(id: 'L1_J30_S2', sessionNumber: 2, orderInLevel: 2),
        levelId: 1,
        kind: SessionKind.talqeen,
        juzNumber: 30,
        hizbNumber: 59,
        repetitionsWithTeacher: 5,
        homeRepetitionsRequired: 0,
        pace: CurriculumPace.standard,
      );

      final container = makeContainer(buildStudent());
      final assignment = await container.read(homeAssignmentProvider.future);

      expect(assignment, isNull);
    },
  );

  test('sums repetitionsDone only from practices attributed to the LATEST '
      "record's curriculumSessionId, excluding practices logged against an "
      'older, superseded assignment', () async {
    // The OLD assignment — a session the student has already been
    // re-taught past. Its own home_repetitions_required (8) and a huge
    // practice count (100) logged against it must NEVER leak into the
    // current assignment's numbers.
    await sessionRepository.createTalqeenRecord(
      studentId: 'student-1',
      teacherId: 'teacher-1',
      meeting: _meeting(id: 'L1_J30_S1', sessionNumber: 1, orderInLevel: 1),
      levelId: 1,
      kind: SessionKind.talqeen,
      juzNumber: 30,
      hizbNumber: 59,
      repetitionsWithTeacher: 5,
      homeRepetitionsRequired: 8,
      pace: CurriculumPace.standard,
      now: DateTime(2026, 1, 1),
    );

    // The CURRENT, latest assignment.
    await sessionRepository.createTalqeenRecord(
      studentId: 'student-1',
      teacherId: 'teacher-1',
      meeting: _meeting(id: 'L1_J30_S2', sessionNumber: 2, orderInLevel: 2),
      levelId: 1,
      kind: SessionKind.talqeen,
      juzNumber: 30,
      hizbNumber: 59,
      repetitionsWithTeacher: 5,
      homeRepetitionsRequired: 10,
      pace: CurriculumPace.standard,
      now: DateTime(2026, 1, 2),
    );

    // Practice logged against the OLD, superseded assignment.
    await homePracticeRepository.createHomePractice(
      studentId: 'student-1',
      curriculumSessionId: 'L1_J30_S1',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 1,
      repetitions: 100,
    );

    // Practices logged against the CURRENT assignment.
    await homePracticeRepository.createHomePractice(
      studentId: 'student-1',
      curriculumSessionId: 'L1_J30_S2',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 2,
      repetitions: 3,
    );
    await homePracticeRepository.createHomePractice(
      studentId: 'student-1',
      curriculumSessionId: 'L1_J30_S2',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 2,
      repetitions: 4,
    );

    final container = makeContainer(buildStudent());
    final assignment = await container.read(homeAssignmentProvider.future);

    expect(assignment, isNotNull);
    expect(assignment!.curriculumSessionId, 'L1_J30_S2');
    expect(assignment.repetitionsRequired, 10);
    // 3 + 4 = 7 — the 100 logged against the superseded S1 assignment must
    // NOT be counted here. If the equality filter were removed (summing
    // every practice regardless of session), this would read 107 and
    // isComplete would wrongly read true — a student would see a
    // completed assignment they never actually did.
    expect(assignment.repetitionsDone, 7);
    expect(assignment.isComplete, isFalse);
  });

  test(
    'isComplete is true once repetitionsDone reaches repetitionsRequired',
    () async {
      await sessionRepository.createTalqeenRecord(
        studentId: 'student-1',
        teacherId: 'teacher-1',
        meeting: _meeting(id: 'L1_J30_S2', sessionNumber: 2, orderInLevel: 2),
        levelId: 1,
        kind: SessionKind.talqeen,
        juzNumber: 30,
        hizbNumber: 59,
        repetitionsWithTeacher: 5,
        homeRepetitionsRequired: 5,
        pace: CurriculumPace.standard,
      );

      await homePracticeRepository.createHomePractice(
        studentId: 'student-1',
        curriculumSessionId: 'L1_J30_S2',
        levelId: 1,
        juzNumber: 30,
        hizbNumber: 59,
        sessionNumber: 2,
        repetitions: 5,
      );

      final container = makeContainer(buildStudent());
      final assignment = await container.read(homeAssignmentProvider.future);

      expect(assignment, isNotNull);
      expect(assignment!.repetitionsDone, 5);
      expect(assignment.repetitionsRequired, 5);
      expect(assignment.isComplete, isTrue);
    },
  );
}
