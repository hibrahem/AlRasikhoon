import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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

    group('allPartsPassed', () {
      test('returns true when all parts have 0 errors', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grades.allPartsPassed, true);
      });

      test('returns true when all parts have exactly 3 errors', () {
        const grades = SessionGrades(
          newMemorizationErrors: 3,
          recentReviewErrors: 3,
          distantReviewErrors: 3,
        );

        expect(grades.allPartsPassed, true);
      });

      test('returns false when newMemorization exceeds 3', () {
        const grades = SessionGrades(
          newMemorizationErrors: 4,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grades.allPartsPassed, false);
      });

      test('returns false when recentReview exceeds 3', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 4,
          distantReviewErrors: 0,
        );

        expect(grades.allPartsPassed, false);
      });

      test('returns false when distantReview exceeds 3', () {
        const grades = SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 4,
        );

        expect(grades.allPartsPassed, false);
      });

      test('returns false when all parts exceed 3', () {
        const grades = SessionGrades(
          newMemorizationErrors: 5,
          recentReviewErrors: 7,
          distantReviewErrors: 10,
        );

        expect(grades.allPartsPassed, false);
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
          'date': Timestamp.fromDate(date),
          'attempt_number': 2,
          'grades': {
            'new_memorization_errors': 1,
            'recent_review_errors': 2,
            'distant_review_errors': 0,
          },
          'passed': true,
          'repetitions': 3,
          'notes': 'ممتاز',
          'created_at': Timestamp.fromDate(date),
        });

        final doc =
            await fakeFirestore.collection('session_records').doc('sr1').get();
        final record = SessionRecordModel.fromFirestore(doc);

        expect(record.id, 'sr1');
        expect(record.studentId, 'student1');
        expect(record.teacherId, 'teacher1');
        expect(record.levelId, 2);
        expect(record.hizbNumber, 57);
        expect(record.sessionNumber, 10);
        expect(record.attemptNumber, 2);
        expect(record.grades.newMemorizationErrors, 1);
        expect(record.grades.recentReviewErrors, 2);
        expect(record.grades.distantReviewErrors, 0);
        expect(record.passed, true);
        expect(record.repetitions, 3);
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

        final doc =
            await fakeFirestore.collection('session_records').doc('sr1').get();
        final record = SessionRecordModel.fromFirestore(doc);

        expect(record.notes, isNull);
        expect(record.repetitions, 0);
        expect(record.grades.totalErrors, 0);
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
          hizbNumber: 59,
          sessionNumber: 5,
          date: now,
          attemptNumber: 1,
          grades: const SessionGrades(
            newMemorizationErrors: 1,
            recentReviewErrors: 2,
            distantReviewErrors: 3,
          ),
          passed: true,
          repetitions: 5,
          notes: 'test',
          createdAt: now,
        );

        final map = record.toFirestore();

        expect(map['student_id'], 'student1');
        expect(map['teacher_id'], 'teacher1');
        expect(map['level_id'], 1);
        expect(map['hizb_number'], 59);
        expect(map['session_number'], 5);
        expect(map['attempt_number'], 1);
        expect(map['passed'], true);
        expect(map['repetitions'], 5);
        expect(map['notes'], 'test');
        expect((map['grades'] as Map)['new_memorization_errors'], 1);
      });
    });

    group('equality', () {
      test('records with same id are equal', () {
        final r1 = SessionRecordModel(
          id: 'sr1',
          studentId: 'a',
          teacherId: 'b',
          curriculumSessionId: 'c',
          date: DateTime.now(),
          attemptNumber: 1,
          grades: const SessionGrades(
              newMemorizationErrors: 0,
              recentReviewErrors: 0,
              distantReviewErrors: 0),
          passed: true,
          createdAt: DateTime.now(),
        );
        final r2 = SessionRecordModel(
          id: 'sr1',
          studentId: 'x',
          teacherId: 'y',
          curriculumSessionId: 'z',
          date: DateTime.now(),
          attemptNumber: 2,
          grades: const SessionGrades(
              newMemorizationErrors: 5,
              recentReviewErrors: 5,
              distantReviewErrors: 5),
          passed: false,
          createdAt: DateTime.now(),
        );

        expect(r1, equals(r2));
      });
    });
  });
}
