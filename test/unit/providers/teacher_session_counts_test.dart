import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';

import '../data/repositories/curriculum_fixtures.dart';

/// The provider itself needs a full Riverpod + auth container to drive, which
/// the integration tests cover. What must be pinned here is the CONTRACT the
/// provider relies on: completing a talqeen writes a passing, error-free record
/// carrying both counts, against the student's own current session id.
void main() {
  group('completing a talqeen session', () {
    late FakeFirebaseFirestore firestore;
    late SessionRepository sessions;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      sessions = SessionRepository(firestore: firestore);
    });

    test('writes a passing record with both counts and no errors', () async {
      final record = await sessions.createTalqeenRecord(
        studentId: 'student1',
        teacherId: 'teacher1',
        curriculumSessionId: 'L1_J30_S1',
        levelId: 1,
        hizbNumber: 59,
        sessionNumber: 1,
        repetitionsWithTeacher: 6,
        homeRepetitionsRequired: 15,
      );

      expect(record.curriculumSessionId, 'L1_J30_S1');
      expect(record.passed, isTrue);
      expect(record.grades.totalErrors, 0);
      expect(record.repetitionsWithTeacher, 6);
      expect(record.homeRepetitionsRequired, 15);
    });
  });
}
