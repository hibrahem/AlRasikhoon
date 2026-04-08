import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';

void main() {
  group('SessionRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SessionRepository sessionRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      sessionRepository = SessionRepository(firestore: fakeFirestore);
    });

    group('createSessionRecord', () {
      test('creates record with passing grades', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'cs1',
          levelId: 1,
          hizbNumber: 59,
          sessionNumber: 5,
          attemptNumber: 1,
          newMemorizationErrors: 2,
          recentReviewErrors: 1,
          distantReviewErrors: 0,
        );

        expect(record.studentId, 'student1');
        expect(record.teacherId, 'teacher1');
        expect(record.sessionNumber, 5);
        expect(record.grades.newMemorizationErrors, 2);
        expect(record.grades.recentReviewErrors, 1);
        expect(record.grades.distantReviewErrors, 0);
        expect(record.passed, true); // All parts <= 3 errors
      });

      test('creates record with failing grades when any part exceeds 3 errors',
          () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'cs1',
          levelId: 1,
          hizbNumber: 59,
          sessionNumber: 5,
          attemptNumber: 1,
          newMemorizationErrors: 4, // Exceeds 3
          recentReviewErrors: 1,
          distantReviewErrors: 2,
        );

        expect(record.passed, false);
      });

      test('creates record with all parts at exactly 3 errors as passing',
          () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'cs1',
          levelId: 1,
          hizbNumber: 59,
          sessionNumber: 5,
          attemptNumber: 1,
          newMemorizationErrors: 3,
          recentReviewErrors: 3,
          distantReviewErrors: 3,
        );

        expect(record.passed, true);
      });

      test('persists record to Firestore', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'cs1',
          levelId: 1,
          hizbNumber: 59,
          sessionNumber: 5,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          notes: 'ممتاز',
        );

        final doc = await fakeFirestore
            .collection('session_records')
            .doc(record.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['student_id'], 'student1');
        expect(doc.data()?['notes'], 'ممتاز');
      });

      test('stores repetitions count', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'cs1',
          levelId: 1,
          hizbNumber: 59,
          sessionNumber: 5,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitions: 5,
        );

        expect(record.repetitions, 5);
      });
    });

    group('getSessionRecordsForStudent', () {
      setUp(() async {
        for (int i = 1; i <= 5; i++) {
          await fakeFirestore.collection('session_records').doc('sr$i').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'cs$i',
            'level_id': 1,
            'hizb_number': 59,
            'session_number': i,
            'date': Timestamp.fromDate(DateTime(2024, 1, i)),
            'attempt_number': 1,
            'grades': {
              'new_memorization_errors': i,
              'recent_review_errors': 0,
              'distant_review_errors': 0,
            },
            'passed': i <= 3,
            'repetitions': 0,
            'created_at': Timestamp.now(),
          });
        }
        // Another student's record
        await fakeFirestore.collection('session_records').doc('sr-other').set({
          'student_id': 'student2',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'cs1',
          'date': Timestamp.now(),
          'attempt_number': 1,
          'grades': {
            'new_memorization_errors': 0,
            'recent_review_errors': 0,
            'distant_review_errors': 0,
          },
          'passed': true,
          'created_at': Timestamp.now(),
        });
      });

      test('returns only records for specified student', () async {
        final records =
            await sessionRepository.getSessionRecordsForStudent('student1');

        expect(records.length, 5);
        expect(records.every((r) => r.studentId == 'student1'), true);
      });

      test('returns records ordered by date descending', () async {
        final records =
            await sessionRepository.getSessionRecordsForStudent('student1');

        for (int i = 0; i < records.length - 1; i++) {
          expect(
            records[i].date.isAfter(records[i + 1].date) ||
                records[i].date.isAtSameMomentAs(records[i + 1].date),
            true,
          );
        }
      });

      test('respects limit parameter', () async {
        final records = await sessionRepository.getSessionRecordsForStudent(
          'student1',
          limit: 2,
        );

        expect(records.length, 2);
      });

      test('returns empty list for unknown student', () async {
        final records =
            await sessionRepository.getSessionRecordsForStudent('nonexistent');

        expect(records, isEmpty);
      });
    });

    group('createSardRecord', () {
      test('creates record with passing grade (0 errors)', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          hizbNumber: 59,
          juzNumber: 30,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
        );

        expect(record.passed, true);
        expect(record.grade, 'راسخ');
        expect(record.errorCount, 0);
      });

      test('creates record with failing grade (7+ errors)', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          hizbNumber: 59,
          juzNumber: 30,
          levelId: 1,
          attemptNumber: 2,
          errorCount: 8,
        );

        expect(record.passed, false);
        expect(record.grade, 'محب');
      });

      test('persists sard record to Firestore', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          hizbNumber: 59,
          juzNumber: 30,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 3,
          notes: 'جيد',
        );

        final doc = await fakeFirestore
            .collection('sard_records')
            .doc(record.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['notes'], 'جيد');
        expect(doc.data()?['error_count'], 3);
      });
    });

    group('getSardRecordsForStudent', () {
      test('returns sard records for student', () async {
        await fakeFirestore.collection('sard_records').doc('sard1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'hizb_number': 59,
          'juz_number': 30,
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 2,
          'grade': 'متقن',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final records =
            await sessionRepository.getSardRecordsForStudent('student1');

        expect(records.length, 1);
        expect(records.first.studentId, 'student1');
      });
    });

    group('createExamRecord', () {
      test('creates exam record with passing grade', () async {
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          hizbNumber: 59,
          juzNumber: 30,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 2,
        );

        expect(record.passed, true);
        expect(record.supervisorId, 'supervisor1');
        expect(record.errorCount, 2);
      });

      test('creates exam record with failing grade', () async {
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          hizbNumber: 59,
          juzNumber: 30,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 10,
        );

        expect(record.passed, false);
      });

      test('persists exam record to Firestore', () async {
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          hizbNumber: 59,
          juzNumber: 30,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
          notes: 'ممتاز',
        );

        final doc = await fakeFirestore
            .collection('exam_records')
            .doc(record.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['supervisor_id'], 'supervisor1');
      });
    });

    group('getExamRecordsForStudent', () {
      test('returns exam records for student', () async {
        await fakeFirestore.collection('exam_records').doc('exam1').set({
          'student_id': 'student1',
          'supervisor_id': 'supervisor1',
          'hizb_number': 59,
          'juz_number': 30,
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final records =
            await sessionRepository.getExamRecordsForStudent('student1');

        expect(records.length, 1);
        expect(records.first.passed, true);
      });
    });

    group('getStudentStatistics', () {
      test('calculates statistics correctly', () async {
        // 3 session records: 2 passed, 1 failed
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('session_records').doc('sr$i').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'cs$i',
            'date': Timestamp.now(),
            'attempt_number': 1,
            'grades': {
              'new_memorization_errors': i <= 2 ? 1 : 5,
              'recent_review_errors': 0,
              'distant_review_errors': 0,
            },
            'passed': i <= 2,
            'created_at': Timestamp.now(),
          });
        }

        // 1 sard record: passed
        await fakeFirestore.collection('sard_records').doc('sard1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'hizb_number': 59,
          'juz_number': 30,
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        // 1 exam record: failed
        await fakeFirestore.collection('exam_records').doc('exam1').set({
          'student_id': 'student1',
          'supervisor_id': 'supervisor1',
          'hizb_number': 59,
          'juz_number': 30,
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 10,
          'grade': 'محب',
          'passed': false,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final stats =
            await sessionRepository.getStudentStatistics('student1');

        expect(stats['total_sessions'], 3);
        expect(stats['passed_sessions'], 2);
        expect(stats['session_pass_rate'], closeTo(0.667, 0.01));
        expect(stats['total_sards'], 1);
        expect(stats['passed_sards'], 1);
        expect(stats['total_exams'], 1);
        expect(stats['passed_exams'], 0);
      });

      test('returns zero rates for student with no records', () async {
        final stats =
            await sessionRepository.getStudentStatistics('new-student');

        expect(stats['total_sessions'], 0);
        expect(stats['passed_sessions'], 0);
        expect(stats['session_pass_rate'], 0);
        expect(stats['total_sards'], 0);
        expect(stats['total_exams'], 0);
      });
    });
  });
}
