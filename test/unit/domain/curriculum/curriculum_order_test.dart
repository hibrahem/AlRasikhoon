import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_order.dart';

void main() {
  group('CurriculumOrder', () {
    test('a juz is its odd hizb then its even hizb', () {
      expect(CurriculumOrder.hizbsOfJuz(30), [59, 60]);
      expect(CurriculumOrder.hizbsOfJuz(1), [1, 2]);
      expect(CurriculumOrder.juzOfHizb(59), 30);
      expect(CurriculumOrder.juzOfHizb(60), 30);
      expect(CurriculumOrder.juzOfHizb(55), 28);
      expect(CurriculumOrder.juzOfHizb(1), 1);
    });

    test('a level owns three descending juz', () {
      expect(CurriculumOrder.juzOfLevel(1), [30, 29, 28]);
      expect(CurriculumOrder.juzOfLevel(2), [27, 26, 25]);
      expect(CurriculumOrder.juzOfLevel(10), [3, 2, 1]);
    });

    test('level one is taught as hizb 59, 60, 57, 58, 55, 56', () {
      expect(CurriculumOrder.hizbsOfLevel(1), [59, 60, 57, 58, 55, 56]);
      expect(CurriculumOrder.hizbsOfLevel(2), [53, 54, 51, 52, 49, 50]);
      expect(CurriculumOrder.hizbsOfLevel(10), [5, 6, 3, 4, 1, 2]);
    });

    test('a level begins at its first hizb and ends at its last', () {
      expect(CurriculumOrder.firstHizbOfLevel(1), 59);
      expect(CurriculumOrder.lastHizbOfLevel(1), 56);
      expect(CurriculumOrder.firstHizbOfLevel(2), 53);
      expect(CurriculumOrder.lastHizbOfLevel(10), 2);
    });

    test('every hizb belongs to exactly one level', () {
      expect(CurriculumOrder.levelOfHizb(60), 1);
      expect(CurriculumOrder.levelOfHizb(55), 1);
      expect(CurriculumOrder.levelOfHizb(54), 2);
      expect(CurriculumOrder.levelOfHizb(49), 2);
      expect(CurriculumOrder.levelOfHizb(1), 10);
    });

    test(
      'advancing walks a level in teaching order then enters the next level',
      () {
        expect(CurriculumOrder.nextHizb(59), 60);
        expect(CurriculumOrder.nextHizb(60), 57);
        expect(CurriculumOrder.nextHizb(58), 55);
        expect(CurriculumOrder.nextHizb(55), 56);
        // Leaving the last hizb of level 1 enters the first hizb of level 2.
        expect(CurriculumOrder.nextHizb(56), 53);
        expect(CurriculumOrder.levelOfHizb(53), 2);
      },
    );

    test('the curriculum ends after the last hizb of level ten', () {
      expect(CurriculumOrder.nextHizb(1), 2);
      expect(CurriculumOrder.nextHizb(2), isNull);
    });

    test('nextHizb terminates instead of descending below the curriculum', () {
      // The old buggy advancement code left legacy records at hizb -1
      // after level 10. nextHizb must not treat that as a valid hizb to
      // keep walking from (0 -> -3 -> -2 -> ... forever) — any hizb below
      // 1 is out of range and has no next hizb.
      expect(CurriculumOrder.nextHizb(0), isNull);
      expect(CurriculumOrder.nextHizb(-1), isNull);
      expect(CurriculumOrder.nextHizb(-3), isNull);
    });

    test('walking nextHizb from the start visits all sixty hizbs in order', () {
      final visited = <int>[];
      int? hizb = CurriculumOrder.firstHizbOfLevel(1);
      while (hizb != null) {
        visited.add(hizb);
        hizb = CurriculumOrder.nextHizb(hizb);
      }

      expect(visited.length, 60);
      expect(visited.toSet().length, 60);
      expect(visited.take(6), [59, 60, 57, 58, 55, 56]);
      expect(visited.last, 2);
    });

    test('order index increases monotonically along the teaching order', () {
      expect(
        CurriculumOrder.hizbOrderIndex(59) < CurriculumOrder.hizbOrderIndex(60),
        isTrue,
      );
      expect(
        CurriculumOrder.hizbOrderIndex(60) < CurriculumOrder.hizbOrderIndex(57),
        isTrue,
      );
      expect(
        CurriculumOrder.hizbOrderIndex(56) < CurriculumOrder.hizbOrderIndex(53),
        isTrue,
      );
      expect(CurriculumOrder.hizbOrderIndex(59), 0);
      expect(CurriculumOrder.hizbOrderIndex(2), 59);
    });
  });
}
