import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/home_practice_model.dart';

/// Direct unit tests for [HomePracticeModel] — a student's self-reported
/// at-home repetition. The load-bearing detail is that practice is filed
/// against the session it was ASSIGNED in (not the student's current session),
/// and that [hizbNumber] is a nullable label, not an identifier.
void main() {
  group('HomePracticeModel', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    HomePracticeModel practice({
      String id = 'hp1',
      int? hizbNumber = 59,
      int repetitions = 5,
    }) => HomePracticeModel(
      id: id,
      studentId: 's1',
      curriculumSessionId: 'L1_J30_S2',
      levelId: 1,
      juzNumber: 30,
      hizbNumber: hizbNumber,
      sessionNumber: 2,
      repetitions: repetitions,
      notes: 'كررت في البيت',
      practiceDate: DateTime(2026, 7, 14, 18),
      createdAt: DateTime(2026, 7, 14, 18, 30),
    );

    group('fromFirestore', () {
      test('deserializes every field from a stored document', () async {
        final date = DateTime(2026, 7, 14, 18, 0);
        await firestore.collection('home_practice').doc('hp1').set({
          'student_id': 's1',
          'curriculum_session_id': 'L1_J30_S2',
          'level_id': 1,
          'juz_number': 30,
          'hizb_number': 59,
          'session_number': 2,
          'repetitions': 7,
          'notes': 'كررت في البيت',
          'practice_date': Timestamp.fromDate(date),
          'created_at': Timestamp.fromDate(date),
        });

        final doc = await firestore
            .collection('home_practice')
            .doc('hp1')
            .get();
        final record = HomePracticeModel.fromFirestore(doc);

        expect(record.id, 'hp1');
        expect(record.studentId, 's1');
        expect(record.curriculumSessionId, 'L1_J30_S2');
        expect(record.levelId, 1);
        expect(record.juzNumber, 30);
        expect(record.hizbNumber, 59);
        expect(record.sessionNumber, 2);
        expect(record.repetitions, 7);
        expect(record.notes, 'كررت في البيت');
        expect(record.practiceDate, date);
      });

      test(
        'falls back to safe defaults when optional fields are absent',
        () async {
          await firestore.collection('home_practice').doc('hp2').set({
            'practice_date': Timestamp.now(),
            'created_at': Timestamp.now(),
          });

          final doc = await firestore
              .collection('home_practice')
              .doc('hp2')
              .get();
          final record = HomePracticeModel.fromFirestore(doc);

          expect(record.studentId, '');
          expect(record.curriculumSessionId, '');
          expect(record.levelId, 1);
          expect(record.juzNumber, 30);
          expect(record.hizbNumber, isNull);
          expect(record.sessionNumber, 1);
          expect(record.repetitions, 0);
          expect(record.notes, isNull);
        },
      );

      test(
        'reads back hizb as null for a level-3+ practice that has no label',
        () async {
          // hizbNumber is a label present only in levels 1-2; above that it must
          // stay null and never be back-filled with a sentinel like 59.
          await firestore.collection('home_practice').doc('hp3').set({
            'student_id': 's1',
            'curriculum_session_id': 'L3_J1_S5',
            'level_id': 3,
            'juz_number': 1,
            'hizb_number': null,
            'session_number': 5,
            'repetitions': 3,
            'practice_date': Timestamp.now(),
            'created_at': Timestamp.now(),
          });

          final doc = await firestore
              .collection('home_practice')
              .doc('hp3')
              .get();
          final record = HomePracticeModel.fromFirestore(doc);

          expect(record.hizbNumber, isNull);
          expect(record.levelId, 3);
        },
      );
    });

    group('toFirestore', () {
      test('serializes every field to its stored key', () {
        final map = practice().toFirestore();

        expect(map['student_id'], 's1');
        expect(map['curriculum_session_id'], 'L1_J30_S2');
        expect(map['level_id'], 1);
        expect(map['juz_number'], 30);
        expect(map['hizb_number'], 59);
        expect(map['session_number'], 2);
        expect(map['repetitions'], 5);
        expect(map['notes'], 'كررت في البيت');
        expect(map['practice_date'], isA<Timestamp>());
        expect(map['created_at'], isA<Timestamp>());
      });

      test('files practice against the assigned session id, verbatim', () {
        // The assigned session, not the student's current one — the model must
        // store whatever session id it was handed without recomputing it.
        final map = practice()
            .copyWith(curriculumSessionId: 'L1_J30_S1')
            .toFirestore();
        expect(map['curriculum_session_id'], 'L1_J30_S1');
      });
    });

    group('round-trip', () {
      test('a practice survives a write and read unchanged', () async {
        final original = practice(repetitions: 12);

        await firestore
            .collection('home_practice')
            .doc('hp1')
            .set(original.toFirestore());
        final doc = await firestore
            .collection('home_practice')
            .doc('hp1')
            .get();
        final round = HomePracticeModel.fromFirestore(doc);

        expect(round.curriculumSessionId, 'L1_J30_S2');
        expect(round.repetitions, 12);
        expect(round.hizbNumber, 59);
        expect(round.sessionNumber, 2);
      });
    });

    group('copyWith', () {
      test('updates only the named field and preserves the rest', () {
        final record = practice();

        final amended = record.copyWith(repetitions: 20);

        expect(amended.repetitions, 20);
        expect(amended.id, record.id);
        expect(amended.studentId, record.studentId);
        expect(amended.curriculumSessionId, record.curriculumSessionId);
        expect(amended.hizbNumber, record.hizbNumber);
        expect(amended.sessionNumber, record.sessionNumber);
      });
    });

    group('equality', () {
      test('two records with the same id are equal regardless of content', () {
        final a = practice(id: 'same');
        final b = practice(id: 'same', repetitions: 99, hizbNumber: null);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('records with different ids are not equal', () {
        expect(practice(id: 'a'), isNot(equals(practice(id: 'b'))));
      });
    });
  });
}
