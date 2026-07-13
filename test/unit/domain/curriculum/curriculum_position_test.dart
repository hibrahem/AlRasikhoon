import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

void main() {
  group('CurriculumPosition', () {
    test('the curriculum starts at level 1, juz 30, session 1', () {
      expect(CurriculumPosition.start.level, 1);
      expect(CurriculumPosition.start.juz, 30);
      expect(CurriculumPosition.start.session, 1);
    });

    test('a position names the curriculum session document it stands on', () {
      const position = CurriculumPosition(level: 1, juz: 30, session: 67);
      expect(position.sessionId, 'L1_J30_S67');
    });

    test('a position is identified by its level, juz and session', () {
      const a = CurriculumPosition(level: 1, juz: 30, session: 30);
      const b = CurriculumPosition(level: 1, juz: 30, session: 30);
      const differentJuz = CurriculumPosition(level: 1, juz: 29, session: 30);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(differentJuz)));
    });

    test('a position round-trips through its persisted map', () {
      const position = CurriculumPosition(level: 10, juz: 2, session: 12);

      expect(position.toMap(), {'level': 10, 'juz': 2, 'session': 12});
      expect(CurriculumPosition.fromMap(position.toMap()), position);
    });

    test('level 10 ascends through juz 1, 2, 3 and is a valid position', () {
      // سورة البقرة spans juz 1-3 and is memorized front to back, so the last
      // level ASCENDS. Any arithmetic deriving the juz from the level would
      // reject this — which is why the domain derives nothing.
      expect(
        CurriculumPosition.validated(level: 10, juz: 1, session: 1).juz,
        1,
      );
      expect(
        CurriculumPosition.validated(level: 10, juz: 3, session: 9).juz,
        3,
      );
    });

    test('a session beyond the old 36-session ceiling is a real position', () {
      // Juz 30 holds 68 sessions, juz 29 holds 69. The old domain rejected
      // anything above 36 and would have refused every juz-tier assessment.
      expect(
        CurriculumPosition.validated(level: 1, juz: 30, session: 68).sessionId,
        'L1_J30_S68',
      );
      expect(
        CurriculumPosition.validated(level: 1, juz: 29, session: 69).sessionId,
        'L1_J29_S69',
      );
    });

    group('validated', () {
      test('rejects a level outside the ten levels of the curriculum', () {
        expect(
          () => CurriculumPosition.validated(level: 0, juz: 30, session: 1),
          throwsArgumentError,
        );
        expect(
          () => CurriculumPosition.validated(level: 11, juz: 30, session: 1),
          throwsArgumentError,
        );
      });

      test("rejects a juz outside the thirty juz of the Qur'an", () {
        expect(
          () => CurriculumPosition.validated(level: 1, juz: 0, session: 1),
          throwsArgumentError,
        );
        expect(
          () => CurriculumPosition.validated(level: 1, juz: 31, session: 1),
          throwsArgumentError,
        );
      });

      test('rejects a session number below the first session', () {
        expect(
          () => CurriculumPosition.validated(level: 1, juz: 30, session: 0),
          throwsArgumentError,
        );
      });

      test(
        'does not judge whether a session exists — that is a data question',
        () {
          // Session counts vary per juz (68, 69, 67 in level 1). Whether juz 30
          // has a session 500 is answered by the curriculum data, not by
          // arithmetic here; the domain refuses only what could never be a
          // session at all.
          expect(
            CurriculumPosition.validated(
              level: 1,
              juz: 30,
              session: 500,
            ).session,
            500,
          );
        },
      );
    });
  });
}
