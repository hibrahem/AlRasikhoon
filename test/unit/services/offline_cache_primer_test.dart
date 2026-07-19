import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/institute_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/offline_cache_primer.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

class _ThrowingStudentRepository extends Mock implements StudentRepository {}

UserModel _user(UserRole role) => UserModel(
  id: 'u-role',
  username: 'someone',
  email: 'someone@alrasikhoon.local',
  name: 'مستخدم',
  role: role,
  authProvider: UserAuthProvider.emailPassword,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late FakeFirebaseFirestore firestore;
  late OfflineCachePrimer primer;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final userRepository = UserRepository(firestore: firestore);
    final curriculumRepository = CurriculumRepository(firestore: firestore);
    final sessionRepository = SessionRepository(firestore: firestore);
    final studentRepository = StudentRepository(
      firestore: firestore,
      firebaseService: _MockFirebaseService(),
      userRepository: userRepository,
      curriculumRepository: curriculumRepository,
      sessionRepository: sessionRepository,
    );
    primer = OfflineCachePrimer(
      studentRepository: studentRepository,
      curriculumRepository: curriculumRepository,
      sessionRepository: sessionRepository,
      instituteRepository: InstituteRepository(firestore: firestore),
      userRepository: userRepository,
    );

    await firestore.collection('users').doc('user-1').set({
      'username': 'pupil',
      'email': 'pupil@alrasikhoon.local',
      'name': 'طالب',
      'role': 'student',
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    await firestore.collection('students').doc('student-1').set({
      'user_id': 'user-1',
      'institute_id': 'institute-1',
      'teacher_id': 'u-role',
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
  });

  test('teacher priming completes over students, curriculum and history', () {
    // The fake cannot observe cache warmth; the contract is that the sweep
    // issues its reads and completes without throwing.
    expect(primer.prime(_user(UserRole.teacher)), completes);
  });

  test('every role primes without throwing on an empty backend', () async {
    for (final role in UserRole.values) {
      await expectLater(primer.prime(_user(role)), completes);
    }
  });

  test('priming swallows repository failures', () async {
    final throwing = _ThrowingStudentRepository();
    when(
      () => throwing.getStudentsForTeacher(any()),
    ).thenThrow(Exception('backend down'));
    final failingPrimer = OfflineCachePrimer(
      studentRepository: throwing,
      curriculumRepository: CurriculumRepository(firestore: firestore),
      sessionRepository: SessionRepository(firestore: firestore),
      instituteRepository: InstituteRepository(firestore: firestore),
      userRepository: UserRepository(firestore: firestore),
    );
    await expectLater(failingPrimer.prime(_user(UserRole.teacher)), completes);
  });
}
