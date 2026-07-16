import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/exam_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';

/// Direct unit tests for [ExamRecordModel] — the اختبار a student sat with the
/// supervisor (إدارة الحلقات). Unlike a سرد it carries a [supervisorId] and has
/// no attempt cap; these tests pin its serialization, tier scoping and value
/// semantics directly rather than through the exam repository.
void main() {
  group('ExamRecordModel', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    ExamRecordModel cumulative({
      String id = 'e1',
      Duration? duration,
      int attemptNumber = 4,
    }) => ExamRecordModel(
      id: id,
      studentId: 's1',
      supervisorId: 'sup1',
      curriculumSessionId: 'L1_J28_S67',
      tier: AssessmentTier.cumulative,
      juzNumbers: const [28, 29, 30],
      scopeLabelAr: 'اختبار في المستوى كاملًا الأجزاء 28 ــ 29 ــ 30',
      levelId: 1,
      date: DateTime(2026, 7, 13, 11),
      errorCount: 5,
      grade: 'مجتهد',
      passed: true,
      attemptNumber: attemptNumber,
      notes: 'اجتاز',
      createdAt: DateTime(2026, 7, 13, 12),
      duration: duration,
    );

    group('fromFirestore', () {
      test('deserializes every field from a stored document', () async {
        final date = DateTime(2026, 7, 13, 11, 0);
        await firestore.collection('exam_records').doc('e1').set({
          'student_id': 's1',
          'supervisor_id': 'sup1',
          'curriculum_session_id': 'L1_J28_S67',
          'tier': 'cumulative',
          'juz_numbers': [28, 29, 30],
          'hizb_number': null,
          'scope_label_ar': 'اختبار تراكمي',
          'level_id': 1,
          'date': Timestamp.fromDate(date),
          'error_count': 5,
          'grade': 'مجتهد',
          'passed': true,
          'attempt_number': 4,
          'notes': 'اجتاز',
          'created_at': Timestamp.fromDate(date),
          'duration_seconds': 1800,
        });

        final doc = await firestore.collection('exam_records').doc('e1').get();
        final record = ExamRecordModel.fromFirestore(doc);

        expect(record.id, 'e1');
        expect(record.studentId, 's1');
        expect(record.supervisorId, 'sup1');
        expect(record.curriculumSessionId, 'L1_J28_S67');
        expect(record.tier, AssessmentTier.cumulative);
        expect(record.juzNumbers, [28, 29, 30]);
        expect(record.hizbNumber, isNull);
        expect(record.scopeLabelAr, 'اختبار تراكمي');
        expect(record.levelId, 1);
        expect(record.date, date);
        expect(record.errorCount, 5);
        expect(record.grade, 'مجتهد');
        expect(record.passed, true);
        expect(record.attemptNumber, 4);
        expect(record.notes, 'اجتاز');
        expect(record.duration, const Duration(minutes: 30));
      });

      test(
        'falls back to safe defaults when optional fields are absent',
        () async {
          await firestore.collection('exam_records').doc('e2').set({
            'tier': 'juz',
            'date': Timestamp.now(),
            'created_at': Timestamp.now(),
          });

          final doc = await firestore
              .collection('exam_records')
              .doc('e2')
              .get();
          final record = ExamRecordModel.fromFirestore(doc);

          expect(record.studentId, '');
          expect(record.supervisorId, '');
          expect(record.curriculumSessionId, '');
          expect(record.juzNumbers, isEmpty);
          expect(record.hizbNumber, isNull);
          expect(record.scopeLabelAr, '');
          expect(record.levelId, 1);
          expect(record.errorCount, 0);
          expect(record.grade, '');
          expect(record.passed, false);
          expect(record.attemptNumber, 1);
          expect(record.notes, isNull);
          expect(record.duration, isNull);
        },
      );

      test('rejects an unknown tier rather than guessing a scope', () async {
        await firestore.collection('exam_records').doc('bad').set({
          'tier': 'section',
          'date': Timestamp.now(),
          'created_at': Timestamp.now(),
        });

        final doc = await firestore.collection('exam_records').doc('bad').get();

        expect(() => ExamRecordModel.fromFirestore(doc), throwsArgumentError);
      });
    });

    group('toFirestore', () {
      test('serializes every field, including the supervisor', () {
        final map = cumulative(
          duration: const Duration(minutes: 30),
        ).toFirestore();

        expect(map['student_id'], 's1');
        expect(map['supervisor_id'], 'sup1');
        expect(map['curriculum_session_id'], 'L1_J28_S67');
        expect(map['tier'], 'cumulative');
        expect(map['juz_numbers'], [28, 29, 30]);
        expect(map['hizb_number'], isNull);
        expect(
          map['scope_label_ar'],
          'اختبار في المستوى كاملًا الأجزاء 28 ــ 29 ــ 30',
        );
        expect(map['level_id'], 1);
        expect(map['date'], isA<Timestamp>());
        expect(map['error_count'], 5);
        expect(map['grade'], 'مجتهد');
        expect(map['passed'], true);
        expect(map['attempt_number'], 4);
        expect(map['notes'], 'اجتاز');
        expect(map['created_at'], isA<Timestamp>());
        expect(map['duration_seconds'], 30 * 60);
      });

      test('an اختبار with no duration stores null seconds', () {
        expect(cumulative().toFirestore()['duration_seconds'], isNull);
      });

      test(
        'records an attempt past the سرد cap — exams have no retry limit',
        () {
          // A سرد is capped at 3 attempts; an اختبار is not. The model must
          // faithfully store whatever attempt number it is given.
          expect(
            cumulative(attemptNumber: 7).toFirestore()['attempt_number'],
            7,
          );
        },
      );
    });

    group('round-trip', () {
      test('a cumulative اختبار survives a write and read unchanged', () async {
        final original = cumulative(duration: const Duration(minutes: 25));

        await firestore
            .collection('exam_records')
            .doc('e1')
            .set(original.toFirestore());
        final doc = await firestore.collection('exam_records').doc('e1').get();
        final round = ExamRecordModel.fromFirestore(doc);

        expect(round.tier, AssessmentTier.cumulative);
        expect(round.juzNumbers, [28, 29, 30]);
        expect(round.supervisorId, 'sup1');
        expect(round.attemptNumber, 4);
        expect(round.duration, const Duration(minutes: 25));
      });
    });

    group('questionErrors', () {
      test('per-question error tallies survive a write and read '
          'unchanged', () async {
        final original = cumulative().copyWith(
          questionErrors: const [
            RecitationErrorTally(tanbeehat: 3, tajweed: 5),
            RecitationErrorTally(talqeenat: 2, tashkeel: 1),
            RecitationErrorTally.empty,
            RecitationErrorTally.empty,
            RecitationErrorTally(tajweed: 4),
          ],
        );

        await firestore
            .collection('exam_records')
            .doc('q1')
            .set(original.toFirestore());
        final doc = await firestore.collection('exam_records').doc('q1').get();
        final round = ExamRecordModel.fromFirestore(doc);

        expect(round.questionErrors, hasLength(5));
        expect(round.questionErrors[0].tanbeehat, 3);
        expect(round.questionErrors[0].tajweed, 5);
        expect(round.questionErrors[1].talqeenat, 2);
        expect(round.questionErrors[1].tashkeel, 1);
        expect(round.questionErrors[4].tajweed, 4);
      });

      test('a legacy record with no question_errors field reads back '
          'empty', () async {
        await firestore.collection('exam_records').doc('legacy').set({
          'tier': 'unit',
          'date': Timestamp.now(),
          'created_at': Timestamp.now(),
        });

        final doc = await firestore
            .collection('exam_records')
            .doc('legacy')
            .get();

        expect(ExamRecordModel.fromFirestore(doc).questionErrors, isEmpty);
      });
    });

    group('copyWith', () {
      test('updates only the named field and preserves the rest', () {
        final record = cumulative();

        final amended = record.copyWith(passed: false, grade: 'محب');

        expect(amended.passed, false);
        expect(amended.grade, 'محب');
        expect(amended.id, record.id);
        expect(amended.supervisorId, record.supervisorId);
        expect(amended.juzNumbers, record.juzNumbers);
        expect(amended.attemptNumber, record.attemptNumber);
      });
    });

    group('equality', () {
      test('two records with the same id are equal regardless of content', () {
        final a = cumulative(id: 'same');
        final b = cumulative(
          id: 'same',
        ).copyWith(passed: false, errorCount: 40);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('records with different ids are not equal', () {
        expect(cumulative(id: 'a'), isNot(equals(cumulative(id: 'b'))));
      });
    });
  });
}
