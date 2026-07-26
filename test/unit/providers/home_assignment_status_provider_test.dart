import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/shared/providers/home_assignment_status_provider.dart';

/// A one-session meeting standing in for whatever `PacedSessionComposer`
/// would have produced — these tests exercise `homeAssignmentStatusProvider`,
/// not composition, so the content blocks are irrelevant and left empty.
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

/// Exercises `homeAssignmentStatusProvider` — the teacher/supervisor/admin
/// side of the student's `homeAssignmentProvider` — through a real Riverpod
/// container with repositories backed by a fake Firestore, so the assertions
/// prove the provider reads documents shaped the way the app writes them.
///
/// The two providers MUST agree on attribution (practices whose
/// `curriculumSessionId` equals the LATEST record's); this suite pins the
/// viewer side of that contract, plus what this side uniquely adds: the
/// per-submission dates.
void main() {
  late FakeFirebaseFirestore firestore;
  late SessionRepository sessionRepository;
  late HomePracticeRepository homePracticeRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    sessionRepository = SessionRepository(firestore: firestore);
    homePracticeRepository = HomePracticeRepository(firestore: firestore);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
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
    final container = makeContainer();

    final status = await container.read(
      homeAssignmentStatusProvider('student-1').future,
    );

    expect(status, isNull);
  });

  test('is null when the latest record assigned zero home repetitions',
      () async {
    await sessionRepository.createTalqeenRecord(
      studentId: 'student-1',
      teacherId: 'teacher-1',
      meeting: _meeting(id: 'L1_J30_S2', sessionNumber: 2, orderInLevel: 2),
      levelId: 1,
      hizbNumber: 59,
      repetitionsWithTeacher: 5,
      homeRepetitionsRequired: 0,
      pace: CurriculumPace.standard,
    );

    final container = makeContainer();
    final status = await container.read(
      homeAssignmentStatusProvider('student-1').future,
    );

    expect(status, isNull);
  });

  test('reports required vs done for the LATEST assignment only, carrying '
      "each submission's own date newest-first", () async {
    // A superseded assignment whose practices must never leak in.
    await sessionRepository.createTalqeenRecord(
      studentId: 'student-1',
      teacherId: 'teacher-1',
      meeting: _meeting(id: 'L1_J30_S1', sessionNumber: 1, orderInLevel: 1),
      levelId: 1,
      hizbNumber: 59,
      repetitionsWithTeacher: 5,
      homeRepetitionsRequired: 8,
      pace: CurriculumPace.standard,
      now: DateTime(2026, 1, 1),
    );
    await sessionRepository.createTalqeenRecord(
      studentId: 'student-1',
      teacherId: 'teacher-1',
      meeting: _meeting(id: 'L1_J30_S2', sessionNumber: 2, orderInLevel: 2),
      levelId: 1,
      hizbNumber: 59,
      repetitionsWithTeacher: 5,
      homeRepetitionsRequired: 10,
      pace: CurriculumPace.standard,
      now: DateTime(2026, 1, 2),
    );

    await homePracticeRepository.createHomePractice(
      studentId: 'student-1',
      curriculumSessionId: 'L1_J30_S1',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 1,
      repetitions: 100,
      practiceDate: DateTime(2026, 1, 1, 20),
    );
    await homePracticeRepository.createHomePractice(
      studentId: 'student-1',
      curriculumSessionId: 'L1_J30_S2',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 2,
      repetitions: 3,
      practiceDate: DateTime(2026, 1, 3),
    );
    await homePracticeRepository.createHomePractice(
      studentId: 'student-1',
      curriculumSessionId: 'L1_J30_S2',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 2,
      repetitions: 4,
      practiceDate: DateTime(2026, 1, 4),
    );

    final container = makeContainer();
    final status = await container.read(
      homeAssignmentStatusProvider('student-1').future,
    );

    expect(status, isNotNull);
    expect(status!.curriculumSessionId, 'L1_J30_S2');
    expect(status.repetitionsRequired, 10);
    // 3 + 4 — the 100 against superseded S1 must not count.
    expect(status.repetitionsDone, 7);
    expect(status.isComplete, isFalse);
    // The dates are the point of this provider: each submission keeps its
    // own practice date, newest first.
    expect(status.practices.map((p) => p.date), [
      DateTime(2026, 1, 4),
      DateTime(2026, 1, 3),
    ]);
    expect(status.practices.map((p) => p.repetitions), [4, 3]);
  });

  test('isComplete once the logged repetitions reach the requirement',
      () async {
    await sessionRepository.createTalqeenRecord(
      studentId: 'student-1',
      teacherId: 'teacher-1',
      meeting: _meeting(id: 'L1_J30_S2', sessionNumber: 2, orderInLevel: 2),
      levelId: 1,
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

    final container = makeContainer();
    final status = await container.read(
      homeAssignmentStatusProvider('student-1').future,
    );

    expect(status, isNotNull);
    expect(status!.isComplete, isTrue);
  });
}
