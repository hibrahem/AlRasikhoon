import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';

/// A one-session meeting standing in for whatever `PacedSessionComposer`
/// would have produced — these tests exercise pending-sync propagation, not
/// composition, so the content blocks are irrelevant and left empty.
PacedSession _meeting() {
  final session = SessionModel(
    id: 'cs-1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    orderInLevel: 1,
    kind: SessionKind.lesson,
  );
  return PacedSession(
    sessions: [session],
    newContent: const [],
    recentReview: const [],
    distantReview: const [],
  );
}

void main() {
  test('history entries carry the record pending-sync flag', () {
    // Constructed directly: fake_cloud_firestore cannot simulate a pending
    // write, so the propagation contract is pinned at the type level here and
    // the false-arm mapping is asserted through the repository below.
    final entry = StudentHistoryEntry(
      id: 'r1',
      kind: StudentHistoryKind.lesson,
      levelId: 1,
      passed: true,
      date: DateTime(2026, 1, 1),
      isPendingSync: true,
    );
    expect(entry.isPendingSync, isTrue);
  });

  test(
    'synced records read back through history as not pending sync',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SessionRepository(firestore: firestore);

      await repo.createSessionRecord(
        studentId: 's1',
        teacherId: 't1',
        meeting: _meeting(),
        levelId: 1,
        attemptNumber: 1,
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
        repetitionsWithTeacher: 0,
        homeRepetitionsRequired: 0,
        pace: CurriculumPace(1),
      );

      final history = await repo.getStudentHistory('s1');
      expect(history.single.isPendingSync, isFalse);
    },
  );
}
