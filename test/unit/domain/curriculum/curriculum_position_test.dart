import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

void main() {
  group('CurriculumPosition', () {
    test('the default start is the first session of the curriculum', () {
      expect(CurriculumPosition.start.level, 1);
      expect(CurriculumPosition.start.juz, 30);
      expect(CurriculumPosition.start.hizb, 59);
      expect(CurriculumPosition.start.session, 1);
    });

    test('the juz is derived from the hizb', () {
      const position = CurriculumPosition(level: 2, hizb: 53, session: 12);
      expect(position.juz, 27);
    });

    // Validation lives in the named `validated` constructor: a const
    // constructor cannot throw, and positions from the UI or from Firestore
    // must be checked at that boundary.
    test('a position rejects a hizb that does not belong to its level', () {
      expect(
        () => CurriculumPosition.validated(level: 1, hizb: 53, session: 1),
        throwsArgumentError,
      );
    });

    test('a position rejects a session outside the hizb', () {
      expect(
        () => CurriculumPosition.validated(level: 1, hizb: 59, session: 0),
        throwsArgumentError,
      );
      expect(
        () => CurriculumPosition.validated(level: 1, hizb: 59, session: 37),
        throwsArgumentError,
      );
    });

    test('a position rejects a level outside the curriculum', () {
      expect(
        () => CurriculumPosition.validated(level: 11, hizb: 1, session: 1),
        throwsArgumentError,
      );
    });

    test('an earlier session in the same hizb comes before a later one', () {
      const earlier = CurriculumPosition(level: 1, hizb: 59, session: 5);
      const later = CurriculumPosition(level: 1, hizb: 59, session: 35);
      expect(earlier.isBefore(later), isTrue);
      expect(later.isBefore(earlier), isFalse);
    });

    test('ordering follows the teaching order, not the hizb number', () {
      // Hizb 60 is taught after hizb 59, and hizb 57 after both.
      const inHizb59 = CurriculumPosition(level: 1, hizb: 59, session: 36);
      const inHizb60 = CurriculumPosition(level: 1, hizb: 60, session: 1);
      const inHizb57 = CurriculumPosition(level: 1, hizb: 57, session: 1);

      expect(inHizb59.isBefore(inHizb60), isTrue);
      expect(inHizb60.isBefore(inHizb57), isTrue);
      expect(inHizb57.isBefore(inHizb59), isFalse);
    });

    test('an earlier level comes before a later one', () {
      const inLevel1 = CurriculumPosition(level: 1, hizb: 56, session: 36);
      const inLevel2 = CurriculumPosition(level: 2, hizb: 53, session: 1);
      expect(inLevel1.isBefore(inLevel2), isTrue);
    });

    test('a position is not before itself', () {
      const position = CurriculumPosition(level: 3, hizb: 47, session: 10);
      expect(position.isBefore(position), isFalse);
    });

    test('a position round-trips through a map', () {
      const position = CurriculumPosition(level: 2, hizb: 53, session: 35);
      final map = position.toMap();

      expect(map, {'level': 2, 'juz': 27, 'hizb': 53, 'session': 35});
      expect(CurriculumPosition.fromMap(map), position);
    });

    test('positions with the same coordinates are equal', () {
      const a = CurriculumPosition(level: 1, hizb: 59, session: 1);
      const b = CurriculumPosition(level: 1, hizb: 59, session: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
