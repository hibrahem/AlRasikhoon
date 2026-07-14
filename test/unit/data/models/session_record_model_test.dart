import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';

void main() {
  group('SessionGrades', () {
    group('totalErrors', () {
      test('sums all three parts', () {
        const grades = SessionGrades(
          newMemorizationErrors: 2,
          recentReviewErrors: 3,
          distantReviewErrors: 1,
        );

        expect(grades.totalErrors, 6);
      });

      test('returns 0 when all parts are 0', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grades.totalErrors, 0);
      });

      test('handles large error counts', () {
        const grades = SessionGrades(
          newMemorizationErrors: 50,
          recentReviewErrors: 30,
          distantReviewErrors: 20,
        );

        expect(grades.totalErrors, 100);
      });
    });

    // Session-level pass/fail (hibrahem/AlRasikhoon#24): FAILED if ANY one
    // component grades محب; passes only if none is محب. Level-based (#22) —
    // at level 1, base B = 0, so محب is reached at >= 4 mistakes; مجتهد is
    // the worst non-محب grade (exactly 3 mistakes).
    group('passesForLevel', () {
      test('passes when all parts have 0 errors', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grades.passesForLevel(1), true);
      });

      test(
        'passes at level 1 when worst part is مجتهد (3 errors, not محب)',
        () {
          const grades = SessionGrades(
            newMemorizationErrors: 3,
            recentReviewErrors: 3,
            distantReviewErrors: 3,
          );

          expect(grades.passesForLevel(1), true);
        },
      );

      test('fails when newMemorization is محب (4 errors at level 1)', () {
        const grades = SessionGrades(
          newMemorizationErrors: 4,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grades.passesForLevel(1), false);
      });

      test('fails when recentReview is محب (4 errors at level 1)', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 4,
          distantReviewErrors: 0,
        );

        expect(grades.passesForLevel(1), false);
      });

      test('fails when distantReview is محب (4 errors at level 1)', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 4,
        );

        expect(grades.passesForLevel(1), false);
      });

      test('fails when all parts are محب', () {
        const grades = SessionGrades(
          newMemorizationErrors: 5,
          recentReviewErrors: 7,
          distantReviewErrors: 10,
        );

        expect(grades.passesForLevel(1), false);
      });

      test('higher level is more lenient — 4 errors is not محب at level 9', () {
        // Level 9: B = (9 - 1) ~/ 2 = 4, so محب starts at >= B + 4 = 8.
        // 4 errors → مجتهد? Actually 4 == B → راسخ; محب only at 8+.
        const grades = SessionGrades(
          newMemorizationErrors: 4,
          recentReviewErrors: 4,
          distantReviewErrors: 4,
        );

        expect(grades.passesForLevel(9), true);
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final grades = SessionGrades.fromJson({
          'new_memorization_errors': 2,
          'recent_review_errors': 1,
          'distant_review_errors': 3,
        });

        expect(grades.newMemorizationErrors, 2);
        expect(grades.recentReviewErrors, 1);
        expect(grades.distantReviewErrors, 3);
      });

      test('defaults to 0 for null input', () {
        final grades = SessionGrades.fromJson(null);

        expect(grades.newMemorizationErrors, 0);
        expect(grades.recentReviewErrors, 0);
        expect(grades.distantReviewErrors, 0);
      });

      test('defaults to 0 for missing fields', () {
        final grades = SessionGrades.fromJson({});

        expect(grades.newMemorizationErrors, 0);
        expect(grades.recentReviewErrors, 0);
        expect(grades.distantReviewErrors, 0);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const grades = SessionGrades(
          newMemorizationErrors: 5,
          recentReviewErrors: 2,
          distantReviewErrors: 1,
        );

        final json = grades.toJson();

        expect(json['new_memorization_errors'], 5);
        expect(json['recent_review_errors'], 2);
        expect(json['distant_review_errors'], 1);
      });
    });
  });

  group('SessionRecordModel', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('fromFirestore', () {
      test('deserializes all fields correctly', () async {
        final date = DateTime(2024, 3, 15, 10, 0);
        await fakeFirestore.collection('session_records').doc('sr1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'cs1',
          'level_id': 2,
          'hizb_number': 57,
          'session_number': 10,
          'order_in_level': 12,
          'date': Timestamp.fromDate(date),
          'attempt_number': 2,
          'grades': {
            'new_memorization_errors': 1,
            'recent_review_errors': 2,
            'distant_review_errors': 0,
          },
          'passed': true,
          'repetitions_with_teacher': 3,
          'home_repetitions_required': 6,
          'notes': 'ممتاز',
          'created_at': Timestamp.fromDate(date),
        });

        final doc = await fakeFirestore
            .collection('session_records')
            .doc('sr1')
            .get();
        final record = SessionRecordModel.fromFirestore(doc);

        expect(record.id, 'sr1');
        expect(record.studentId, 'student1');
        expect(record.teacherId, 'teacher1');
        expect(record.levelId, 2);
        expect(record.hizbNumber, 57);
        expect(record.sessionNumber, 10);
        // Falls back to `order_in_level` (this record predates the span).
        expect(record.toOrderInLevel, 12);
        expect(record.fromOrderInLevel, 12);
        expect(record.coversSessionIds, ['cs1']);
        expect(record.paceAtTime, 1);
        expect(record.isBatched, isFalse);
        expect(record.attemptNumber, 2);
        expect(record.grades.newMemorizationErrors, 1);
        expect(record.grades.recentReviewErrors, 2);
        expect(record.grades.distantReviewErrors, 0);
        expect(record.passed, true);
        expect(record.repetitionsWithTeacher, 3);
        expect(record.homeRepetitionsRequired, 6);
        expect(record.notes, 'ممتاز');
      });

      test('handles missing optional fields', () async {
        await fakeFirestore.collection('session_records').doc('sr1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'cs1',
          'date': Timestamp.now(),
          'attempt_number': 1,
          'passed': false,
          'created_at': Timestamp.now(),
        });

        final doc = await fakeFirestore
            .collection('session_records')
            .doc('sr1')
            .get();
        final record = SessionRecordModel.fromFirestore(doc);

        expect(record.notes, isNull);
        expect(record.repetitionsWithTeacher, 0);
        expect(record.homeRepetitionsRequired, 0);
        expect(record.grades.totalErrors, 0);
        // A record written before `order_in_level` existed falls back to 1 —
        // never recomputed from sessionNumber.
        expect(record.toOrderInLevel, 1);
        expect(record.fromOrderInLevel, 1);
      });
    });

    group('toFirestore', () {
      test('serializes all fields', () {
        final now = DateTime.now();
        final record = SessionRecordModel(
          id: 'sr1',
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'cs1',
          levelId: 1,
          kind: SessionKind.lesson,
          juzNumber: 30,
          hizbNumber: 59,
          sessionNumber: 5,
          fromOrderInLevel: 5,
          toOrderInLevel: 5,
          coversSessionIds: const ['cs1'],
          paceAtTime: 1,
          date: now,
          attemptNumber: 1,
          grades: const SessionGrades(
            newMemorizationErrors: 1,
            recentReviewErrors: 2,
            distantReviewErrors: 3,
          ),
          passed: true,
          repetitionsWithTeacher: 5,
          homeRepetitionsRequired: 8,
          notes: 'test',
          createdAt: now,
        );

        final map = record.toFirestore();

        expect(map['student_id'], 'student1');
        expect(map['teacher_id'], 'teacher1');
        expect(map['level_id'], 1);
        expect(map['kind'], 'lesson');
        expect(map['juz_number'], 30);
        expect(map['hizb_number'], 59);
        expect(map['session_number'], 5);
        expect(map['from_order_in_level'], 5);
        expect(map['to_order_in_level'], 5);
        expect(map['order_in_level'], 5);
        expect(map['covers_session_ids'], ['cs1']);
        expect(map['pace_at_time'], 1);
        expect(map['attempt_number'], 1);
        expect(map['passed'], true);
        expect(map['repetitions_with_teacher'], 5);
        expect(map['home_repetitions_required'], 8);
        expect(map['notes'], 'test');
        expect((map['grades'] as Map)['new_memorization_errors'], 1);
      });
    });

    group('kind', () {
      test('a تلقين record is marked as such, not inferred from a number', () {
        final record = SessionRecordModel(
          id: 'r1',
          studentId: 's1',
          teacherId: 't1',
          curriculumSessionId: 'L1_J30_S1',
          levelId: 1,
          kind: SessionKind.talqeen,
          juzNumber: 30,
          fromOrderInLevel: 1,
          toOrderInLevel: 1,
          coversSessionIds: const ['L1_J30_S1'],
          date: DateTime(2026, 7, 14),
          attemptNumber: 1,
          grades: const SessionGrades(
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 0,
          ),
          passed: true,
          createdAt: DateTime(2026, 7, 14),
        );

        expect(record.kind, SessionKind.talqeen);
        expect(record.isTalqeen, isTrue);
        expect(record.toFirestore()['kind'], 'talqeen');
      });

      test('a lesson record is not a تلقين', () {
        final record = SessionRecordModel(
          id: 'r2',
          studentId: 's1',
          teacherId: 't1',
          curriculumSessionId: 'L1_J30_S5',
          levelId: 1,
          kind: SessionKind.lesson,
          juzNumber: 30,
          fromOrderInLevel: 5,
          toOrderInLevel: 5,
          coversSessionIds: const ['L1_J30_S5'],
          date: DateTime(2026, 7, 14),
          attemptNumber: 1,
          grades: const SessionGrades(
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 0,
          ),
          passed: true,
          createdAt: DateTime(2026, 7, 14),
        );

        expect(record.isTalqeen, isFalse);
      });

      test('a record written before `kind` existed falls back to a lesson — '
          'the only kind that could have been recorded before this field '
          'shipped', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('session_records').doc('old').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'cs1',
          'order_in_level': 1,
          'date': Timestamp.now(),
          'attempt_number': 1,
          'passed': true,
          'created_at': Timestamp.now(),
        });

        final doc = await fakeFirestore
            .collection('session_records')
            .doc('old')
            .get();
        final record = SessionRecordModel.fromFirestore(doc);

        expect(record.kind, SessionKind.lesson);
        expect(record.isTalqeen, isFalse);
      });
    });

    group('juzNumber', () {
      test('round-trips through Firestore, copied verbatim', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('session_records').doc('r1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'L1_J29_S1',
          'kind': 'talqeen',
          'juz_number': 29,
          'order_in_level': 67,
          'date': Timestamp.now(),
          'attempt_number': 1,
          'passed': true,
          'created_at': Timestamp.now(),
        });

        final doc = await fakeFirestore
            .collection('session_records')
            .doc('r1')
            .get();
        final record = SessionRecordModel.fromFirestore(doc);

        expect(record.juzNumber, 29);
      });

      // hibrahem/AlRasikhoon final-review finding #2: a record written
      // before `juz_number` shipped must read back as `juzNumber: null` —
      // never a sentinel like 0, which is not a real juz and reads as data.
      // A caller (e.g. `addPractice`) that falls back with
      // `lastRecord?.juzNumber ?? student.currentJuz` only works if this is
      // null; a leftover `?? 0` here would silently swallow that fallback.
      test(
        'reads back as null for a record written before this field existed',
        () async {
          final fakeFirestore = FakeFirebaseFirestore();
          await fakeFirestore.collection('session_records').doc('r2').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'L1_J29_S1',
            'kind': 'lesson',
            // No 'juz_number' at all — pre-migration data.
            'order_in_level': 67,
            'date': Timestamp.now(),
            'attempt_number': 1,
            'passed': true,
            'created_at': Timestamp.now(),
          });

          final doc = await fakeFirestore
              .collection('session_records')
              .doc('r2')
              .get();
          final record = SessionRecordModel.fromFirestore(doc);

          expect(record.juzNumber, isNull);
        },
      );
    });

    group('recitation counts', () {
      test(
        'a record carries what was recited together and what is owed at home',
        () {
          final record = SessionRecordModel(
            id: 'r1',
            studentId: 's1',
            teacherId: 't1',
            curriculumSessionId: 'L1_J30_S2',
            levelId: 1,
            kind: SessionKind.lesson,
            juzNumber: 30,
            sessionNumber: 2,
            fromOrderInLevel: 2,
            toOrderInLevel: 2,
            coversSessionIds: const ['L1_J30_S2'],
            date: DateTime(2026, 7, 14),
            attemptNumber: 1,
            grades: const SessionGrades(
              newMemorizationErrors: 0,
              recentReviewErrors: 0,
              distantReviewErrors: 0,
            ),
            passed: true,
            repetitionsWithTeacher: 5,
            homeRepetitionsRequired: 10,
            createdAt: DateTime(2026, 7, 14),
          );

          final json = record.toFirestore();
          expect(json['repetitions_with_teacher'], 5);
          expect(json['home_repetitions_required'], 10);
        },
      );
    });

    group('equality', () {
      test('records with same id are equal', () {
        final r1 = SessionRecordModel(
          id: 'sr1',
          studentId: 'a',
          teacherId: 'b',
          curriculumSessionId: 'c',
          kind: SessionKind.lesson,
          juzNumber: 30,
          fromOrderInLevel: 1,
          toOrderInLevel: 1,
          coversSessionIds: const ['c'],
          date: DateTime.now(),
          attemptNumber: 1,
          grades: const SessionGrades(
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 0,
          ),
          passed: true,
          createdAt: DateTime.now(),
        );
        final r2 = SessionRecordModel(
          id: 'sr1',
          studentId: 'x',
          teacherId: 'y',
          curriculumSessionId: 'z',
          kind: SessionKind.talqeen,
          juzNumber: 29,
          fromOrderInLevel: 9,
          toOrderInLevel: 9,
          coversSessionIds: const ['z'],
          date: DateTime.now(),
          attemptNumber: 2,
          grades: const SessionGrades(
            newMemorizationErrors: 5,
            recentReviewErrors: 5,
            distantReviewErrors: 5,
          ),
          passed: false,
          createdAt: DateTime.now(),
        );

        expect(r1, equals(r2));
      });
    });
  });

  group('a record spans the meeting it recorded', () {
    test(
      'a record written before paced curricula is a one-session meeting',
      () {
        final record = SessionRecordModel.fromJson('r1', {
          'student_id': 's1',
          'teacher_id': 't1',
          'curriculum_session_id': 'L1_J30_S5',
          'level_id': 1,
          'session_number': 5,
          'order_in_level': 5,
          'attempt_number': 1,
          'passed': true,
        });

        expect(record.fromOrderInLevel, 5);
        expect(record.toOrderInLevel, 5);
        expect(record.coversSessionIds, ['L1_J30_S5']);
        expect(record.paceAtTime, 1);
        expect(record.isBatched, isFalse);
      },
    );

    test('a doubled meeting records both sessions it discharged', () {
      final record = SessionRecordModel.fromJson('r1', {
        'student_id': 's1',
        'teacher_id': 't1',
        'curriculum_session_id': 'L1_J30_S6',
        'level_id': 1,
        'session_number': 6,
        'from_order_in_level': 5,
        'to_order_in_level': 6,
        'covers_session_ids': ['L1_J30_S5', 'L1_J30_S6'],
        'pace_at_time': 2,
        'attempt_number': 1,
        'passed': true,
      });

      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 6);
      expect(record.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(record.paceAtTime, 2);
      expect(record.isBatched, isTrue);
    });

    test(
      'a record keeps the pace it was recorded at, not the student\'s current one',
      () {
        // The student may be moved back to 1x tomorrow. History must not be
        // rewritten: this meeting really did cover two sessions.
        final record = SessionRecordModel.fromJson('r1', {
          'student_id': 's1',
          'teacher_id': 't1',
          'curriculum_session_id': 'L1_J30_S6',
          'level_id': 1,
          'session_number': 6,
          'from_order_in_level': 5,
          'to_order_in_level': 6,
          'covers_session_ids': ['L1_J30_S5', 'L1_J30_S6'],
          'pace_at_time': 2,
          'attempt_number': 1,
          'passed': true,
        });

        expect(record.toFirestore()['pace_at_time'], 2);
        // The compatibility mirror: old readers and the ordering query both
        // depend on order_in_level, which must equal the meeting's LAST session.
        expect(record.toFirestore()['order_in_level'], 6);
        expect(record.toFirestore()['to_order_in_level'], 6);
      },
    );
  });
}
