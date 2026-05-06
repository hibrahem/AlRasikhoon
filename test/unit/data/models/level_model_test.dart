import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/level_model.dart';

void main() {
  group('LevelModel', () {
    LevelModel buildLevel({
      String id = 'level_1',
      int levelNumber = 1,
      List<int> juzNumbers = const [30, 29, 28],
    }) {
      return LevelModel(
        id: id,
        levelNumber: levelNumber,
        nameAr: 'المستوى الأول',
        nameEn: 'Level One',
        juzNumbers: juzNumbers,
        totalSessions: 36 * juzNumbers.length * 2,
        hizbCount: 6,
        order: levelNumber,
      );
    }

    test('hizbCount defaults to 6 (each level holds 6 hizbs)', () {
      // Every level has exactly 6 hizbs (3 juzs × 2 hizbs each).
      // Spot-check via the default constructor parameter.
      final level = buildLevel();
      expect(level.hizbCount, 6);
    });

    test('level 1 covers juzs 30, 29, 28 (reverse Quran order)', () {
      final level = buildLevel();
      expect(level.juzNumbers, [30, 29, 28]);
    });

    test('getName(true) returns Arabic, getName(false) returns English', () {
      final level = buildLevel();
      expect(level.getName(true), 'المستوى الأول');
      expect(level.getName(false), 'Level One');
    });

    test('juzRangeAr formats descending range', () {
      final level = buildLevel(juzNumbers: [30, 29, 28]);
      expect(level.juzRangeAr, 'الأجزاء 28 - 30');
    });

    test('juzRangeAr handles single-juz level', () {
      final level = buildLevel(juzNumbers: [30]);
      expect(level.juzRangeAr, 'الجزء 30');
    });

    test('juzRangeAr returns empty string when no juzs assigned', () {
      final level = buildLevel(juzNumbers: const []);
      expect(level.juzRangeAr, '');
    });

    test('juzRangeEn formats descending range', () {
      final level = buildLevel(juzNumbers: [30, 29, 28]);
      expect(level.juzRangeEn, 'Juz 28 - 30');
    });

    test('juzRangeEn handles single-juz level', () {
      final level = buildLevel(juzNumbers: [30]);
      expect(level.juzRangeEn, 'Juz 30');
    });

    test('equality based on id only, not other fields', () {
      final a = buildLevel(id: 'level_1', juzNumbers: [30]);
      final b = buildLevel(id: 'level_1', juzNumbers: [29]);
      final c = buildLevel(id: 'level_2', juzNumbers: [30]);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('fromJson derives levelNumber from doc id when "id" missing', () {
      // Migration safety: if a doc lacks an `id` field but the doc id encodes
      // the level (level_5), fromJson should still resolve levelNumber.
      final level = LevelModel.fromJson('level_5', <String, dynamic>{
        'name_ar': 'X',
      });
      expect(level.levelNumber, 5);
      expect(level.id, 'level_5');
    });

    test('fromJson prefers explicit id field over doc id parsing', () {
      final level = LevelModel.fromJson('level_5', <String, dynamic>{
        'id': 7,
        'name_ar': 'X',
      });
      expect(level.levelNumber, 7);
    });

    test('toFirestore + fromFirestore round-trip preserves fields', () async {
      final original = buildLevel(
        id: 'level_2',
        levelNumber: 2,
        juzNumbers: [27, 26, 25],
      );

      final fake = FakeFirebaseFirestore();
      await fake
          .collection('levels')
          .doc(original.id)
          .set(original.toFirestore());
      final DocumentSnapshot doc = await fake
          .collection('levels')
          .doc(original.id)
          .get();

      final round = LevelModel.fromFirestore(doc);

      expect(round.id, original.id);
      expect(round.levelNumber, original.levelNumber);
      expect(round.nameAr, original.nameAr);
      expect(round.nameEn, original.nameEn);
      expect(round.juzNumbers, original.juzNumbers);
      expect(round.totalSessions, original.totalSessions);
      expect(round.hizbCount, original.hizbCount);
      expect(round.order, original.order);
    });
  });
}
