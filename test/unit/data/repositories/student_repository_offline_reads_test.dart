import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/firestore_read_source.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

/// The offline read path (al_rasikhoon-gy4): with a read source that reports
/// offline, list loads still resolve — including the per-student user-doc
/// fan-out, which now runs concurrently instead of one awaited get per
/// student.
void main() {
  test(
    'students-for-institutes resolves with an offline read source',
    () async {
      final firestore = FakeFirebaseFirestore();
      final offline = FirestoreReadSource(isOnline: () => false);
      final userRepository = UserRepository(
        firestore: firestore,
        readSource: offline,
      );
      final repo = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: userRepository,
        curriculumRepository: CurriculumRepository(
          firestore: firestore,
          readSource: offline,
        ),
        sessionRepository: SessionRepository(
          firestore: firestore,
          readSource: offline,
        ),
        readSource: offline,
      );

      for (var i = 0; i < 3; i++) {
        await firestore.collection('users').doc('user-$i').set({
          'username': 'pupil$i',
          'email': 'pupil$i@alrasikhoon.local',
          'name': 'طالب $i',
          'role': 'student',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await firestore.collection('students').doc('student-$i').set({
          'user_id': 'user-$i',
          'institute_id': 'i1',
          'current_level': 1,
          'current_juz': 30,
          'current_session': 1,
          'current_order_in_level': 1,
          'current_session_id': 'L1_J30_S1',
          'current_session_kind': 'lesson',
          'current_attempt': 1,
          'completed_levels': const <int>[],
          'unlocked_levels': const [1],
          'is_active': true,
          'created_at': Timestamp.now(),
        });
      }

      final students = await repo.getStudentsForInstitutes(['i1']);
      expect(students, hasLength(3));
      expect(students.every((s) => s.user.name.startsWith('طالب')), isTrue);
    },
  );
}
