import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  group('StudentRepository.hardDeleteStudent', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseService firebaseService;
    late StudentRepository studentRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firebaseService = _MockFirebaseService();
      studentRepository = StudentRepository(
        firestore: fakeFirestore,
        firebaseService: firebaseService,
        userRepository: UserRepository(firestore: fakeFirestore),
        curriculumRepository: CurriculumRepository(firestore: fakeFirestore),
        sessionRepository: SessionRepository(firestore: fakeFirestore),
      );
    });

    test('permanent deletion goes through the server-side cascade gateway '
        '(never a client-side Firestore delete, which rules would deny and '
        'which could not remove the Auth account)', () async {
      when(
        () => firebaseService.hardDeleteStudent(
          studentId: any(named: 'studentId'),
        ),
      ).thenAnswer((_) async {});

      await studentRepository.hardDeleteStudent('student-1');

      verify(
        () => firebaseService.hardDeleteStudent(studentId: 'student-1'),
      ).called(1);
    });

    test('a failed cascade surfaces to the caller instead of being '
        'swallowed as a silent success', () async {
      when(
        () => firebaseService.hardDeleteStudent(
          studentId: any(named: 'studentId'),
        ),
      ).thenThrow(Exception('permission-denied'));

      await expectLater(
        studentRepository.hardDeleteStudent('student-1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
