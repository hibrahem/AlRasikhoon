import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';

void main() {
  group('StudentModel', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('default values', () {
      test('default level is 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.currentLevel, 1);
      });

      test('default juz is 30', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.currentJuz, 30);
      });

      test('default hizb is 59', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.currentHizb, 59);
      });

      test('default session is 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.currentSession, 1);
      });

      test('default attempt is 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.currentAttempt, 1);
      });

      test('default unlockedLevels contains only 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.unlockedLevels, [1]);
      });

      test('default completedLevels is empty', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.completedLevels, isEmpty);
      });

      test('default isActive is true', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student.isActive, true);
      });
    });

    group('canTakeSard', () {
      test('returns true only at session 35', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 35,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeSard, true);
      });

      test('returns false at session 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 1,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeSard, false);
      });

      test('returns false at session 34', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 34,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeSard, false);
      });

      test('returns false at session 36', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 36,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeSard, false);
      });
    });

    group('canTakeExam', () {
      test('returns true only at session 36', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 36,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeExam, true);
      });

      test('returns false at session 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 1,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeExam, false);
      });

      test('returns false at session 35', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 35,
          createdAt: DateTime.now(),
        );

        expect(student.canTakeExam, false);
      });
    });

    group('levelProgressPercentage', () {
      test('returns approximately 0% at session 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 1,
          createdAt: DateTime.now(),
        );

        expect(student.levelProgressPercentage, closeTo(0, 1));
      });

      test('returns approximately 50% at session 18', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 18,
          createdAt: DateTime.now(),
        );

        // (18-1) / 36 * 100 = 47.22%
        expect(student.levelProgressPercentage, closeTo(47.22, 1));
      });

      test('returns high percentage near session 35', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 35,
          createdAt: DateTime.now(),
        );

        // (35-1) / 36 * 100 = 94.44%
        expect(student.levelProgressPercentage, closeTo(94.44, 1));
      });
    });

    group('fromFirestore', () {
      test('deserializes all fields correctly', () async {
        final createdAt = DateTime(2024, 1, 15, 10, 30);

        await fakeFirestore.collection('students').doc('student123').set({
          'user_id': 'user123',
          'institute_id': 'institute123',
          'teacher_id': 'teacher123',
          'guardian_id': 'guardian123',
          'current_level': 2,
          'current_juz': 29,
          'current_hizb': 57,
          'current_session': 15,
          'current_attempt': 2,
          'completed_levels': [1],
          'unlocked_levels': [1, 2],
          'created_at': Timestamp.fromDate(createdAt),
          'is_active': true,
        });

        final doc =
            await fakeFirestore.collection('students').doc('student123').get();
        final student = StudentModel.fromFirestore(doc);

        expect(student.id, 'student123');
        expect(student.userId, 'user123');
        expect(student.instituteId, 'institute123');
        expect(student.teacherId, 'teacher123');
        expect(student.guardianId, 'guardian123');
        expect(student.currentLevel, 2);
        expect(student.currentJuz, 29);
        expect(student.currentHizb, 57);
        expect(student.currentSession, 15);
        expect(student.currentAttempt, 2);
        expect(student.completedLevels, [1]);
        expect(student.unlockedLevels, [1, 2]);
        expect(student.isActive, true);
      });

      test('handles missing optional fields', () async {
        await fakeFirestore.collection('students').doc('student123').set({
          'user_id': 'user123',
          'institute_id': 'institute123',
        });

        final doc =
            await fakeFirestore.collection('students').doc('student123').get();
        final student = StudentModel.fromFirestore(doc);

        expect(student.teacherId, isNull);
        expect(student.guardianId, isNull);
        expect(student.currentLevel, 1);
        expect(student.unlockedLevels, [1]);
        expect(student.completedLevels, isEmpty);
      });
    });

    group('toFirestore', () {
      test('serializes all fields correctly', () {
        final createdAt = DateTime(2024, 1, 15, 10, 30);
        final updatedAt = DateTime(2024, 1, 16, 14, 0);

        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          teacherId: 'teacher123',
          guardianId: 'guardian123',
          currentLevel: 3,
          currentJuz: 28,
          currentHizb: 55,
          currentSession: 20,
          currentAttempt: 1,
          completedLevels: [1, 2],
          unlockedLevels: [1, 2, 3],
          createdAt: createdAt,
          updatedAt: updatedAt,
          isActive: true,
        );

        final map = student.toFirestore();

        expect(map['user_id'], 'user123');
        expect(map['institute_id'], 'institute123');
        expect(map['teacher_id'], 'teacher123');
        expect(map['guardian_id'], 'guardian123');
        expect(map['current_level'], 3);
        expect(map['current_juz'], 28);
        expect(map['current_hizb'], 55);
        expect(map['current_session'], 20);
        expect(map['current_attempt'], 1);
        expect(map['completed_levels'], [1, 2]);
        expect(map['unlocked_levels'], [1, 2, 3]);
        expect(map['is_active'], true);
      });
    });

    group('copyWith', () {
      test('updates single field', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 5,
          createdAt: DateTime.now(),
        );

        final updated = student.copyWith(currentSession: 6);

        expect(updated.currentSession, 6);
        expect(updated.id, student.id);
        expect(updated.userId, student.userId);
      });

      test('updates attempt correctly', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 1,
          createdAt: DateTime.now(),
        );

        final updated = student.copyWith(currentAttempt: 2);

        expect(updated.currentAttempt, 2);
      });

      test('updates unlockedLevels correctly', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          unlockedLevels: [1],
          createdAt: DateTime.now(),
        );

        final updated = student.copyWith(unlockedLevels: [1, 2]);

        expect(updated.unlockedLevels, [1, 2]);
      });
    });

    group('hasReachedMaxAttempts', () {
      test('returns false at attempt 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 1,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxAttempts, false);
      });

      test('returns false at attempt 2', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 2,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxAttempts, false);
      });

      test('returns false at attempt 3', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 3,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxAttempts, false);
      });

      test('returns true at attempt 4 (exceeds max)', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 4,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxAttempts, true);
      });

      test('returns true at attempt 5', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 5,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxAttempts, true);
      });
    });

    group('canStartSession', () {
      test('returns true at attempt 1', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 1,
          createdAt: DateTime.now(),
        );

        expect(student.canStartSession, true);
      });

      test('returns true at attempt 3', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 3,
          createdAt: DateTime.now(),
        );

        expect(student.canStartSession, true);
      });

      test('returns false at attempt 4', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentAttempt: 4,
          createdAt: DateTime.now(),
        );

        expect(student.canStartSession, false);
      });
    });

    group('hasReachedMaxSardAttempts', () {
      test('returns true when at session 35 with attempt > 3', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 35,
          currentAttempt: 4,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxSardAttempts, true);
      });

      test('returns false when at session 35 with attempt <= 3', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 35,
          currentAttempt: 3,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxSardAttempts, false);
      });

      test('returns false when not at session 35', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 10,
          currentAttempt: 5,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxSardAttempts, false);
      });
    });

    group('hasReachedMaxExamAttempts', () {
      test('returns true when at session 36 with attempt > 3', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 36,
          currentAttempt: 4,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxExamAttempts, true);
      });

      test('returns false when at session 36 with attempt <= 3', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 36,
          currentAttempt: 3,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxExamAttempts, false);
      });

      test('returns false when not at session 36', () {
        final student = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          currentSession: 35,
          currentAttempt: 5,
          createdAt: DateTime.now(),
        );

        expect(student.hasReachedMaxExamAttempts, false);
      });
    });

    group('equality', () {
      test('students with same id are equal', () {
        final student1 = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        final student2 = StudentModel(
          id: 'student123',
          userId: 'user456',
          instituteId: 'institute456',
          createdAt: DateTime.now(),
        );

        expect(student1, equals(student2));
      });

      test('students with different ids are not equal', () {
        final student1 = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        final student2 = StudentModel(
          id: 'student456',
          userId: 'user123',
          instituteId: 'institute123',
          createdAt: DateTime.now(),
        );

        expect(student1, isNot(equals(student2)));
      });
    });
  });
}
