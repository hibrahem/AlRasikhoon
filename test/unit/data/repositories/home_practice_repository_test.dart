import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';

void main() {
  group('HomePracticeRepository', () {
    late FakeFirebaseFirestore firestore;
    late HomePracticeRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = HomePracticeRepository(firestore: firestore);
    });

    test(
      'a practice is attributed to the session it was assigned in',
      () async {
        // The student was told to repeat L1_J30_S2's passage 10 times at home,
        // and has since been advanced to S3. The practice belongs to S2.
        final id = await repository.createHomePractice(
          studentId: 'student1',
          curriculumSessionId: 'L1_J30_S2',
          levelId: 1,
          juzNumber: 30,
          hizbNumber: 59,
          sessionNumber: 2,
          repetitions: 4,
        );

        final stored = await firestore
            .collection('home_practices')
            .doc(id)
            .get();
        expect(stored.data()!['curriculum_session_id'], 'L1_J30_S2');

        final practices = await repository.getHomePracticesForStudent(
          'student1',
        );
        expect(practices.single.curriculumSessionId, 'L1_J30_S2');
        expect(practices.single.repetitions, 4);
      },
    );
  });
}
