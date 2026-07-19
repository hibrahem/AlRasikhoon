import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';

import 'curriculum_fixtures.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late StudentRepository studentRepository;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    studentRepository = StudentRepository(
      firestore: fakeFirestore,
      firebaseService: _MockFirebaseService(),
      userRepository: UserRepository(firestore: fakeFirestore),
      curriculumRepository: CurriculumRepository(firestore: fakeFirestore),
      sessionRepository: SessionRepository(firestore: fakeFirestore),
    );
    await seedLevels(fakeFirestore);
    await seedLevelOneJuz30(fakeFirestore);
    await fakeFirestore.collection('students').doc('s1').set({
      'user_id': 'u1',
      'institute_id': 'i1',
      'current_level': 1,
      'current_juz': 30,
      'current_session': 1,
      'current_order_in_level': 1,
      'current_hizb': 59,
      'current_session_id': 'L1_J30_S1',
      'current_session_kind': 'lesson',
      'current_attempt': 1,
      'completed_levels': const <int>[],
      'unlocked_levels': const [1],
      'is_active': true,
      'created_at': Timestamp.now(),
    });
  });

  Future<Map<String, dynamic>> readStudent() async {
    final doc = await fakeFirestore.collection('students').doc('s1').get();
    return doc.data()!;
  }

  test('a batched advance stages the position update until commit', () async {
    final batch = fakeFirestore.batch();

    final outcome = await studentRepository.advanceStudentSession(
      's1',
      batch: batch,
    );
    expect(outcome, StudentAdvanceOutcome.advanced);

    var student = await readStudent();
    expect(student['current_order_in_level'], 1, reason: 'not yet committed');

    await batch.commit();
    student = await readStudent();
    expect(student['current_order_in_level'], 2);
  });

  test('a batched attempt increment stages until commit', () async {
    final batch = fakeFirestore.batch();

    await studentRepository.incrementStudentAttempt('s1', batch: batch);

    var student = await readStudent();
    expect(student['current_attempt'], 1, reason: 'not yet committed');

    await batch.commit();
    student = await readStudent();
    expect(student['current_attempt'], 2);
  });
}
