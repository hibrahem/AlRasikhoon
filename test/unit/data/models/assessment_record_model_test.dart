import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/exam_record_model.dart';
import 'package:al_rasikhoon/data/models/sard_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';

void main() {
  group('SardRecordModel', () {
    test(
      'a juz-tier سرد is recorded against the whole juz, not a hizb',
      () async {
        final record = SardRecordModel(
          id: 'r1',
          studentId: 's1',
          teacherId: 't1',
          curriculumSessionId: 'L1_J30_S67',
          tier: AssessmentTier.juz,
          juzNumbers: const [30],
          scopeLabelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
          levelId: 1,
          date: DateTime(2026, 7, 13),
          errorCount: 2,
          grade: 'متقن',
          passed: true,
          attemptNumber: 1,
          createdAt: DateTime(2026, 7, 13),
        );

        expect(record.hizbNumber, isNull);

        final firestore = FakeFirebaseFirestore();
        await firestore
            .collection('sard_records')
            .doc('r1')
            .set(record.toFirestore());
        final doc = await firestore.collection('sard_records').doc('r1').get();
        final round = SardRecordModel.fromFirestore(doc);

        expect(round.curriculumSessionId, 'L1_J30_S67');
        expect(round.tier, AssessmentTier.juz);
        expect(round.juzNumbers, [30]);
        expect(round.hizbNumber, isNull);
        expect(
          round.scopeLabelAr,
          'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
        );
      },
    );

    test('a unit-tier سرد keeps its hizb as a label', () {
      final record = SardRecordModel(
        id: 'r2',
        studentId: 's1',
        teacherId: 't1',
        curriculumSessionId: 'L1_J30_S30',
        tier: AssessmentTier.unit,
        juzNumbers: const [30],
        hizbNumber: 59,
        scopeLabelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
        levelId: 1,
        date: DateTime(2026, 7, 13),
        errorCount: 0,
        grade: 'راسخ',
        passed: true,
        attemptNumber: 1,
        createdAt: DateTime(2026, 7, 13),
      );

      expect(record.toFirestore()['hizb_number'], 59);
      expect(record.toFirestore()['tier'], 'unit');
    });
  });

  group('ExamRecordModel', () {
    test('a cumulative اختبار is recorded against every juz it covered', () async {
      final record = ExamRecordModel(
        id: 'e1',
        studentId: 's1',
        supervisorId: 'sup1',
        curriculumSessionId: 'L1_J28_S67',
        tier: AssessmentTier.cumulative,
        juzNumbers: const [28, 29, 30],
        scopeLabelAr:
            'اختبار في المستوى كاملًا  الأجزاء رقم 28 ــ  29 ــ 30 من قِبل إدارة الحلقات',
        levelId: 1,
        date: DateTime(2026, 7, 13),
        errorCount: 5,
        grade: 'مجتهد',
        passed: true,
        attemptNumber: 4, // assessments have no attempt cap
        createdAt: DateTime(2026, 7, 13),
      );

      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('exam_records')
          .doc('e1')
          .set(record.toFirestore());
      final doc = await firestore.collection('exam_records').doc('e1').get();
      final round = ExamRecordModel.fromFirestore(doc);

      expect(round.tier, AssessmentTier.cumulative);
      expect(round.juzNumbers, [28, 29, 30]);
      expect(round.hizbNumber, isNull);
      expect(round.attemptNumber, 4);
      expect(
        round.scopeLabelAr,
        'اختبار في المستوى كاملًا  الأجزاء رقم 28 ــ  29 ــ 30 من قِبل إدارة الحلقات',
      );
    });
  });
}
