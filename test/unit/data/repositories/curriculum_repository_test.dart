import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';

void main() {
  group('CurriculumRepository.getSessionNumbersForHizb', () {
    late FakeFirebaseFirestore firestore;
    late CurriculumRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = CurriculumRepository(firestore: firestore);
    });

    Future<void> seedSession({
      required int level,
      required int juz,
      required int hizb,
      required int session,
      String type = 'regular',
    }) async {
      await firestore
          .collection('sessions')
          .doc('L${level}_J${juz}_H${hizb}_S$session')
          .set({
            'session_number': session,
            'level_id': level,
            'juz_number': juz,
            'hizb_number': hizb,
            'session_type': type,
          });
    }

    test('returns the sessions of the hizb in ascending order', () async {
      await seedSession(level: 1, juz: 30, hizb: 59, session: 12);
      await seedSession(level: 1, juz: 30, hizb: 59, session: 2);
      await seedSession(level: 1, juz: 30, hizb: 59, session: 35, type: 'sard');
      await seedSession(level: 1, juz: 30, hizb: 59, session: 36, type: 'exam');

      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 59,
      );

      expect(sessions, [2, 12, 35, 36]);
    });

    test(
      'the curriculum is sparse — missing session numbers are not invented',
      () async {
        await seedSession(level: 2, juz: 25, hizb: 49, session: 2);
        await seedSession(level: 2, juz: 25, hizb: 49, session: 18);
        await seedSession(
          level: 2,
          juz: 25,
          hizb: 49,
          session: 36,
          type: 'exam',
        );

        final sessions = await repository.getSessionNumbersForHizb(
          level: 2,
          hizb: 49,
        );

        expect(sessions, [2, 18, 36]);
      },
    );

    test('sessions whose juz contradicts their hizb are ignored', () async {
      // The seeded curriculum carries an extraction artefact: a hizb-59 session
      // filed under juz 29, though hizb 59 belongs to juz 30.
      await seedSession(level: 1, juz: 30, hizb: 59, session: 1);
      await seedSession(level: 1, juz: 29, hizb: 59, session: 2);

      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 59,
      );

      expect(sessions, [1]);
    });

    test('a session numbered zero is ignored', () async {
      await seedSession(level: 1, juz: 29, hizb: 58, session: 0);
      await seedSession(level: 1, juz: 29, hizb: 58, session: 1);

      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 58,
      );

      expect(sessions, [1]);
    });

    test('a hizb with no seeded sessions returns empty', () async {
      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 57,
      );

      expect(sessions, isEmpty);
    });
  });
}
