import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

/// A one-session meeting standing in for whatever `PacedSessionComposer`
/// would have produced — these tests exercise batch staging, not
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
  test(
    'a batched session record is staged, not written, until the batch commits',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SessionRepository(firestore: firestore);
      final batch = firestore.batch();

      final record = await repo.createSessionRecord(
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
        batch: batch,
      );

      var docs = await firestore.collection('session_records').get();
      expect(
        docs.docs,
        isEmpty,
        reason: 'staged writes must not land pre-commit',
      );

      await batch.commit();
      docs = await firestore.collection('session_records').get();
      expect(docs.docs.single.id, record.id);
    },
  );

  test(
    'a batched sard record is staged, not written, until the batch commits',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = SessionRepository(firestore: firestore);
      final batch = firestore.batch();

      final record = await repo.createSardRecord(
        studentId: 's1',
        teacherId: 't1',
        curriculumSessionId: 'cs-1',
        tier: AssessmentTier.unit,
        levelId: 1,
        attemptNumber: 1,
        evaluation: SardEvaluation(const [RecitationErrorTally()]),
        batch: batch,
      );

      var docs = await firestore.collection('sard_records').get();
      expect(
        docs.docs,
        isEmpty,
        reason: 'staged writes must not land pre-commit',
      );

      await batch.commit();
      docs = await firestore.collection('sard_records').get();
      expect(docs.docs.single.id, record.id);
    },
  );
}
