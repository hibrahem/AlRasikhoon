import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/level_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_progress.dart';

/// Builds a level's JSON the way `data/curriculum/levels.json` carries it, with
/// each juz's `first_order_in_level` computed from the running session total.
Map<String, dynamic> _levelJson(int id, List<int> juz, List<int> juzSessions) {
  var first = 1;
  final juzList = <Map<String, dynamic>>[];
  for (var i = 0; i < juz.length; i++) {
    juzList.add({
      'juz_number': juz[i],
      'session_count': juzSessions[i],
      'first_order_in_level': first,
    });
    first += juzSessions[i];
  }
  return {
    'id': id,
    'name_ar': '',
    'name_en': '',
    'order': id,
    'juz_numbers': juz,
    'session_count': juzSessions.fold<int>(0, (a, b) => a + b),
    'juz': juzList,
  };
}

List<LevelModel> _catalog(List<Map<String, dynamic>> jsons) => [
  for (final j in jsons) LevelModel.fromJson('level_${j['id']}', j),
];

/// A full 10-level catalog: levels 1-9 each teach three juz descending, level
/// 10 teaches juz 1,2,3 ascending. Session counts are illustrative but the
/// juz *count* per level (3) and level 10's ascending order are what matter.
List<LevelModel> _fullCatalog() => _catalog([
  _levelJson(1, [30, 29, 28], [70, 71, 69]),
  _levelJson(2, [27, 26, 25], [53, 49, 52]),
  _levelJson(3, [24, 23, 22], [35, 30, 35]),
  _levelJson(4, [21, 20, 19], [32, 33, 29]),
  _levelJson(5, [18, 17, 16], [22, 26, 23]),
  _levelJson(6, [15, 14, 13], [26, 26, 30]),
  _levelJson(7, [12, 11, 10], [17, 19, 24]),
  _levelJson(8, [9, 8, 7], [16, 26, 25]),
  _levelJson(9, [6, 5, 4], [23, 22, 22]),
  _levelJson(10, [1, 2, 3], [16, 19, 15]),
]);

void main() {
  group('CurriculumProgress.of', () {
    test(
      'a brand-new student has memorized no juz and 0% of the curriculum',
      () {
        final p = CurriculumProgress.of(
          currentLevel: 1,
          currentOrderInLevel: 1,
          curriculumCompleted: false,
          levels: _catalog([
            _levelJson(1, [30, 29, 28], [70, 71, 69]),
          ]),
        );
        expect(p.juzMemorized, 0);
        expect(p.sessionsCompleted, 0);
        expect(p.percent, 0);
        expect(p.fraction, 0);
      },
    );

    test('mid first juz: sessions count up but no juz is memorized yet', () {
      final p = CurriculumProgress.of(
        currentLevel: 1,
        currentOrderInLevel: 40, // inside juz 30's block (orders 1..70)
        curriculumCompleted: false,
        levels: _catalog([
          _levelJson(1, [30, 29, 28], [70, 71, 69]),
        ]),
      );
      expect(p.juzMemorized, 0);
      expect(p.sessionsCompleted, 39);
    });

    test('crossing a juz boundary banks exactly one juz', () {
      final p = CurriculumProgress.of(
        currentLevel: 1,
        currentOrderInLevel: 71, // juz 30 (last order 70) is now fully behind
        curriculumCompleted: false,
        levels: _catalog([
          _levelJson(1, [30, 29, 28], [70, 71, 69]),
        ]),
      );
      expect(p.juzMemorized, 1);
    });

    test(
      'standing at the start of level 2 means all of level 1 is memorized',
      () {
        final p = CurriculumProgress.of(
          currentLevel: 2,
          currentOrderInLevel: 1,
          curriculumCompleted: false,
          levels: _catalog([
            _levelJson(1, [30, 29, 28], [70, 71, 69]),
            _levelJson(2, [27, 26, 25], [53, 49, 52]),
          ]),
        );
        expect(p.juzMemorized, 3);
        expect(p.sessionsCompleted, 210); // 70+71+69
      },
    );

    test(
      'level 10 ascends: order 1 means 27 juz memorized, not 30 - currentJuz',
      () {
        final p = CurriculumProgress.of(
          currentLevel: 10,
          currentOrderInLevel: 1, // juz 1 not yet finished
          curriculumCompleted: false,
          levels: _fullCatalog(),
        );
        // Levels 1-9 = 27 juz; none of level 10's juz banked yet.
        expect(p.juzMemorized, 27);
      },
    );

    test('level 10: finishing juz 1 banks the 28th juz', () {
      final p = CurriculumProgress.of(
        currentLevel: 10,
        currentOrderInLevel: 17, // juz 1 block is orders 1..16
        curriculumCompleted: false,
        levels: _fullCatalog(),
      );
      expect(p.juzMemorized, 28);
    });

    test(
      'a flexibly-enrolled student credits lower levels without completedLevels',
      () {
        final p = CurriculumProgress.of(
          currentLevel: 4,
          currentOrderInLevel: 1,
          curriculumCompleted: false,
          levels: _catalog([
            _levelJson(1, [30, 29, 28], [70, 71, 69]),
            _levelJson(2, [27, 26, 25], [53, 49, 52]),
            _levelJson(3, [24, 23, 22], [35, 30, 35]),
            _levelJson(4, [21, 20, 19], [32, 33, 29]),
          ]),
        );
        expect(p.juzMemorized, 9); // levels 1-3
        expect(p.sessionsCompleted, 210 + 154 + 100);
      },
    );

    test('a graduated student is 30 juz / 100% regardless of position', () {
      final p = CurriculumProgress.of(
        currentLevel: 10,
        currentOrderInLevel: 44,
        curriculumCompleted: true,
        levels: _fullCatalog(),
      );
      expect(p.juzMemorized, 30);
      expect(p.percent, 100);
      expect(p.sessionsCompleted, p.totalSessions);
    });

    test(
      'an unresolved (empty) catalog reports zero, never a fabricated denominator',
      () {
        final p = CurriculumProgress.of(
          currentLevel: 3,
          currentOrderInLevel: 20,
          curriculumCompleted: false,
          levels: const [],
        );
        expect(p.totalSessions, 0);
        expect(p.juzMemorized, 0);
        expect(p.fraction, 0);
        expect(p.percent, 0);
      },
    );
  });
}
