import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/sard_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';

/// Direct unit tests for [SardRecordModel] — the سرد a student recited to their
/// teacher. Coverage previously came only through the repositories that build
/// these records; these tests pin the model's own serialization, tier scoping
/// and value semantics.
void main() {
  group('SardRecordModel', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    SardRecordModel unit({
      String id = 'r1',
      Duration? duration,
      int? hizbNumber = 59,
    }) => SardRecordModel(
      id: id,
      studentId: 's1',
      teacherId: 't1',
      curriculumSessionId: 'L1_J30_S30',
      tier: AssessmentTier.unit,
      juzNumbers: const [30],
      hizbNumber: hizbNumber,
      scopeLabelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
      levelId: 1,
      date: DateTime(2026, 7, 13, 9, 30),
      errorCount: 0,
      grade: 'راسخ',
      passed: true,
      attemptNumber: 1,
      notes: 'ممتاز',
      createdAt: DateTime(2026, 7, 13, 10),
      duration: duration,
    );

    group('fromFirestore', () {
      test('deserializes every field from a stored document', () async {
        final date = DateTime(2026, 7, 13, 9, 0);
        await firestore.collection('sard_records').doc('r1').set({
          'student_id': 's1',
          'teacher_id': 't1',
          'curriculum_session_id': 'L1_J30_S67',
          'tier': 'juz',
          'juz_numbers': [30],
          'hizb_number': null,
          'scope_label_ar': 'سرد الجزء رقم 30 كاملًا',
          'level_id': 1,
          'date': Timestamp.fromDate(date),
          'error_count': 2,
          'grade': 'متقن',
          'passed': true,
          'attempt_number': 3,
          'notes': 'جيد',
          'created_at': Timestamp.fromDate(date),
          'duration_seconds': 900,
        });

        final doc = await firestore.collection('sard_records').doc('r1').get();
        final record = SardRecordModel.fromFirestore(doc);

        expect(record.id, 'r1');
        expect(record.studentId, 's1');
        expect(record.teacherId, 't1');
        expect(record.curriculumSessionId, 'L1_J30_S67');
        expect(record.tier, AssessmentTier.juz);
        expect(record.juzNumbers, [30]);
        expect(record.hizbNumber, isNull);
        expect(record.scopeLabelAr, 'سرد الجزء رقم 30 كاملًا');
        expect(record.levelId, 1);
        expect(record.date, date);
        expect(record.errorCount, 2);
        expect(record.grade, 'متقن');
        expect(record.passed, true);
        expect(record.attemptNumber, 3);
        expect(record.notes, 'جيد');
        expect(record.duration, const Duration(seconds: 900));
      });

      test(
        'falls back to safe defaults when optional fields are absent',
        () async {
          await firestore.collection('sard_records').doc('r2').set({
            'tier': 'unit',
            'date': Timestamp.now(),
            'created_at': Timestamp.now(),
          });

          final doc = await firestore
              .collection('sard_records')
              .doc('r2')
              .get();
          final record = SardRecordModel.fromFirestore(doc);

          expect(record.studentId, '');
          expect(record.teacherId, '');
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
        await firestore.collection('sard_records').doc('bad').set({
          'tier': 'chapter',
          'date': Timestamp.now(),
          'created_at': Timestamp.now(),
        });

        final doc = await firestore.collection('sard_records').doc('bad').get();

        expect(() => SardRecordModel.fromFirestore(doc), throwsArgumentError);
      });
    });

    group('toFirestore', () {
      test('serializes every field to its stored key', () {
        final map = unit(duration: const Duration(minutes: 15)).toFirestore();

        expect(map['student_id'], 's1');
        expect(map['teacher_id'], 't1');
        expect(map['curriculum_session_id'], 'L1_J30_S30');
        expect(map['tier'], 'unit');
        expect(map['juz_numbers'], [30]);
        expect(map['hizb_number'], 59);
        expect(
          map['scope_label_ar'],
          'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
        );
        expect(map['level_id'], 1);
        expect(map['date'], isA<Timestamp>());
        expect(map['error_count'], 0);
        expect(map['grade'], 'راسخ');
        expect(map['passed'], true);
        expect(map['attempt_number'], 1);
        expect(map['notes'], 'ممتاز');
        expect(map['created_at'], isA<Timestamp>());
        expect(map['duration_seconds'], 15 * 60);
      });

      test('a سرد with no duration stores null seconds', () {
        expect(unit().toFirestore()['duration_seconds'], isNull);
      });
    });

    group('round-trip', () {
      test('a juz-tier سرد survives a write and read unchanged', () async {
        final original = SardRecordModel(
          id: 'r3',
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
          duration: const Duration(minutes: 12),
        );

        await firestore
            .collection('sard_records')
            .doc('r3')
            .set(original.toFirestore());
        final doc = await firestore.collection('sard_records').doc('r3').get();
        final round = SardRecordModel.fromFirestore(doc);

        expect(round.tier, AssessmentTier.juz);
        expect(round.juzNumbers, [30]);
        expect(round.hizbNumber, isNull);
        expect(round.grade, 'متقن');
        expect(round.errorCount, 2);
        expect(round.duration, const Duration(minutes: 12));
      });
    });

    group('faceErrors', () {
      test(
        'per-face error tallies survive a write and read unchanged',
        () async {
          final original = unit().copyWith(
            faceErrors: const [
              RecitationErrorTally(tanbeehat: 5, tajweed: 8),
              RecitationErrorTally(talqeenat: 2, tashkeel: 1),
              RecitationErrorTally.empty,
            ],
          );

          await firestore
              .collection('sard_records')
              .doc('r4')
              .set(original.toFirestore());
          final doc = await firestore
              .collection('sard_records')
              .doc('r4')
              .get();
          final round = SardRecordModel.fromFirestore(doc);

          expect(round.faceErrors, hasLength(3));
          expect(round.faceErrors[0].tanbeehat, 5);
          expect(round.faceErrors[0].tajweed, 8);
          expect(round.faceErrors[1].talqeenat, 2);
          expect(round.faceErrors[1].tashkeel, 1);
          expect(round.faceErrors[2], RecitationErrorTally.empty);
        },
      );

      test(
        'a legacy record with no face_errors field reads back empty',
        () async {
          await firestore.collection('sard_records').doc('legacy').set({
            'tier': 'unit',
            'date': Timestamp.now(),
            'created_at': Timestamp.now(),
          });

          final doc = await firestore
              .collection('sard_records')
              .doc('legacy')
              .get();

          expect(SardRecordModel.fromFirestore(doc).faceErrors, isEmpty);
        },
      );
    });

    group('copyWith', () {
      test('updates only the named field and preserves the rest', () {
        final record = unit();

        final amended = record.copyWith(grade: 'متقن', errorCount: 1);

        expect(amended.grade, 'متقن');
        expect(amended.errorCount, 1);
        // Everything else is carried over untouched.
        expect(amended.id, record.id);
        expect(amended.studentId, record.studentId);
        expect(amended.tier, record.tier);
        expect(amended.hizbNumber, record.hizbNumber);
        expect(amended.passed, record.passed);
      });
    });

    group('equality', () {
      test('two records with the same id are equal regardless of content', () {
        final a = unit(id: 'same');
        final b = unit(
          id: 'same',
          hizbNumber: null,
        ).copyWith(grade: 'مجتهد', errorCount: 9);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('records with different ids are not equal', () {
        expect(unit(id: 'a'), isNot(equals(unit(id: 'b'))));
      });
    });
  });
}
