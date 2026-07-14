import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

import 'curriculum_fixtures.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CurriculumRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CurriculumRepository(firestore: firestore);
  });

  group('getSessionByPosition', () {
    test('reads the session standing at a level, juz and session', () async {
      await seedLevelOneJuz30(firestore);

      final session = await repository.getSessionByPosition(
        level: 1,
        juz: 30,
        session: 31,
      );

      expect(session, isNotNull);
      expect(session!.id, 'L1_J30_S31');
      expect(session.kind, SessionKind.sard);
      expect(session.orderInLevel, 31);
    });

    test('reads the same session from a CurriculumPosition', () async {
      await seedLevelOneJuz30(firestore);

      final session = await repository.getSessionAt(
        const CurriculumPosition(level: 1, juz: 30, session: 70),
      );

      expect(session!.id, 'L1_J30_S70');
      expect(session.kind, SessionKind.exam);
      expect(session.scope!.tier, AssessmentTier.juz);
    });

    test('a position the curriculum does not hold reads back null', () async {
      await seedLevelOneJuz30(firestore);

      final session = await repository.getSessionByPosition(
        level: 1,
        juz: 30,
        session: 99,
      );

      expect(session, isNull);
    });
  });

  group('getSessionByOrderInLevel', () {
    test('reads the session at an order within the level', () async {
      await seedLevelOneJuz30(firestore);

      final session = await repository.getSessionByOrderInLevel(
        level: 1,
        orderInLevel: 69,
      );

      expect(session!.id, 'L1_J30_S69');
      expect(session.kind, SessionKind.sard);
      expect(
        session.scope!.labelAr,
        'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
      );
    });

    test('the order runs on across a juz boundary — order 71 of level 1 is the '
        'first session of juz 29, not of juz 30', () async {
      await seedLevelOneJuz30(firestore);
      await seedLevelOneJuz29(firestore);

      final session = await repository.getSessionByOrderInLevel(
        level: 1,
        orderInLevel: 71,
      );

      expect(session!.id, 'L1_J29_S1');
      expect(session.juzNumber, 29);
      expect(session.sessionNumber, 1);
    });

    test('an order the level does not reach reads back null', () async {
      await seedLevelOneJuz30(firestore);

      expect(
        await repository.getSessionByOrderInLevel(level: 1, orderInLevel: 999),
        isNull,
      );
    });
  });

  group('getSessionsForJuz / getSessionNumbersForJuz', () {
    test('returns every session of the juz, in teaching order', () async {
      await seedLevelOneJuz30(firestore);

      final sessions = await repository.getSessionsForJuz(level: 1, juz: 30);

      expect(sessions.map((s) => s.id), [
        'L1_J30_S1',
        'L1_J30_S2',
        'L1_J30_S3',
        'L1_J30_S31',
        'L1_J30_S32',
        'L1_J30_S33',
        'L1_J30_S69',
        'L1_J30_S70',
      ]);
      expect(sessions.map((s) => s.orderInLevel), [
        1,
        2,
        3,
        31,
        32,
        33,
        69,
        70,
      ], reason: 'ordered by order_in_level');
    });

    test('the picker sees the session numbers, ascending', () async {
      await seedLevelOneJuz30(firestore);

      final numbers = await repository.getSessionNumbersForJuz(
        level: 1,
        juz: 30,
      );

      expect(numbers, [1, 2, 3, 31, 32, 33, 69, 70]);
    });

    test(
      'assessments are listed like any other session — session 70 is the juz '
      'اختبار and it is offered, not filtered out',
      () async {
        await seedLevelOneJuz30(firestore);

        final sessions = await repository.getSessionsForJuz(level: 1, juz: 30);
        final exam = sessions.firstWhere((s) => s.sessionNumber == 70);

        expect(exam.kind, SessionKind.exam);
        expect(exam.scope!.tier, AssessmentTier.juz);
      },
    );

    test('a juz the level does not teach is empty', () async {
      await seedLevelOneJuz30(firestore);

      expect(await repository.getSessionsForJuz(level: 1, juz: 27), isEmpty);
    });
  });

  group('getSessionsForLevel', () {
    test('a level yields every one of its sessions, in teaching order', () async {
      // Level 1 runs juz 30 → 29. Ordering by juz would put 29 first; ordering
      // by order_in_level is the only rule that gets the teaching order right.
      await seedSession(firestore, level: 1, juz: 29, session: 1, order: 3);
      await seedSession(firestore, level: 1, juz: 30, session: 1, order: 1);
      await seedSession(firestore, level: 1, juz: 30, session: 2, order: 2);
      await seedSession(firestore, level: 2, juz: 27, session: 1, order: 1);

      final sessions = await repository.getSessionsForLevel(level: 1);

      expect(sessions.map((s) => s.orderInLevel), [1, 2, 3]);
      expect(sessions.map((s) => s.id), [
        'L1_J30_S1',
        'L1_J30_S2',
        'L1_J29_S1',
      ]);
    });

    test('returns the level in teaching order — juz 30 then juz 29, by '
        'order_in_level and never by juz number', () async {
      await seedLevelOneJuz29(firestore);
      await seedLevelOneJuz30(firestore);

      final sessions = await repository.getSessionsForLevel(level: 1);

      expect(sessions.map((s) => s.orderInLevel), isA<Iterable<int>>());
      expect(
        sessions.map((s) => s.juzNumber).toList(),
        [30, 30, 30, 30, 30, 30, 30, 30, 29, 29],
        reason:
            'juz 30 is taught before juz 29, though 29 < 30 — the order is '
            'data, not arithmetic',
      );
    });
  });

  group('the levels catalog', () {
    test('carries the per-juz session counts', () async {
      await seedLevels(firestore);

      final level = await repository.getLevelByNumber(1);

      expect(level!.sessionCount, 210);
      expect(level.juzEntry(30)!.sessionCount, 70);
      expect(level.juzEntry(29)!.sessionCount, 71);
      expect(level.juzEntry(28)!.sessionCount, 69);
      expect(level.juzEntry(29)!.firstOrderInLevel, 71);
    });

    test(
      'carries the teaching order of the juz — and level 10 ASCENDS',
      () async {
        await seedLevels(firestore);

        expect(await repository.getJuzTeachingOrder(1), [30, 29, 28]);
        expect(
          await repository.getJuzTeachingOrder(10),
          [1, 2, 3],
          reason: 'سورة البقرة spans juz 1-3 and is memorized front to back',
        );
      },
    );

    test('lists every level in order', () async {
      await seedLevels(firestore);

      final levels = await repository.getLevels();

      expect(levels.map((l) => l.levelNumber), [1, 2, 10]);
    });
  });
}
