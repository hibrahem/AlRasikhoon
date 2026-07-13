import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/level_model.dart';

/// Level 1 exactly as `data/curriculum/levels.json` carries it: juz 30 → 29 →
/// 28, of 68, 69 and 67 sessions — 204 in the level. Never `36 × juz × 2`.
final level1Json = <String, dynamic>{
  'id': 1,
  'name_ar': 'المستوى الأول',
  'name_en': 'Level 1',
  'order': 1,
  'juz_numbers': [30, 29, 28],
  'session_count': 204,
  'juz': [
    {
      'juz_number': 30,
      'session_count': 68,
      'unit_labels': [
        'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
        'سرد الحزب رقم 60 كاملًا على المحفظ المتابع',
      ],
      'hizb_numbers': [59, 60],
      'first_order_in_level': 1,
    },
    {
      'juz_number': 29,
      'session_count': 69,
      'unit_labels': [
        'سرد الحزب رقم 57 كاملًا على المحفظ المتابع',
        'سرد الحزب رقم 58 كاملًا على المحفظ المتابع',
      ],
      'hizb_numbers': [57, 58],
      'first_order_in_level': 69,
    },
    {
      'juz_number': 28,
      'session_count': 67,
      'unit_labels': [
        'سرد الحزب رقم 55 كاملًا على المحفظ المتابع',
        'سرد الحزب رقم 56 كاملًا على المحفظ المتابع',
      ],
      'hizb_numbers': [55, 56],
      'first_order_in_level': 138,
    },
  ],
};

/// Level 10 ASCENDS — سورة البقرة spans juz 1-3 and is memorized front to back —
/// and its units are surah groups, not hizbs.
final level10Json = <String, dynamic>{
  'id': 10,
  'name_ar': 'المستوى العاشر',
  'name_en': 'Level 10',
  'order': 10,
  'juz_numbers': [1, 2, 3],
  'session_count': 44,
  'juz': [
    {
      'juz_number': 1,
      'session_count': 16,
      'unit_labels': ['سرد المقرر من سورة البقرة على المحفظ المتابع'],
      'hizb_numbers': null,
      'first_order_in_level': 1,
    },
    {
      'juz_number': 2,
      'session_count': 19,
      'unit_labels': [
        'سرد المقرر من سورة البقرة من 142 : 202 على المحفظ المتابع',
      ],
      'hizb_numbers': null,
      'first_order_in_level': 17,
    },
    {
      'juz_number': 3,
      'session_count': 9,
      'unit_labels': ['سرد المقرر من سورة البقرة 253 : 286 على المحفظ المتابع'],
      'hizb_numbers': null,
      'first_order_in_level': 36,
    },
  ],
};

void main() {
  group('LevelModel', () {
    test('level 1 teaches juz 30, then 29, then 28', () {
      final level = LevelModel.fromJson('level_1', level1Json);
      expect(level.juzNumbers, [30, 29, 28]);
      expect(level.juz.map((j) => j.juzNumber), [30, 29, 28]);
    });

    test(
      'level 10 teaches juz 1, then 2, then 3 — the teaching order ascends',
      () {
        final level = LevelModel.fromJson('level_10', level10Json);
        expect(level.juzNumbers, [1, 2, 3]);
      },
    );

    test('a level knows its real session count, which is not 36 per hizb', () {
      final level1 = LevelModel.fromJson('level_1', level1Json);
      final level10 = LevelModel.fromJson('level_10', level10Json);

      expect(level1.sessionCount, 204);
      expect(level10.sessionCount, 44);
    });

    test('each juz carries its own session count and where it starts', () {
      final level = LevelModel.fromJson('level_1', level1Json);

      expect(level.juzEntry(30)!.sessionCount, 68);
      expect(level.juzEntry(29)!.sessionCount, 69);
      expect(level.juzEntry(28)!.sessionCount, 67);

      expect(level.juzEntry(30)!.firstOrderInLevel, 1);
      expect(level.juzEntry(29)!.firstOrderInLevel, 69);
      expect(level.juzEntry(28)!.firstOrderInLevel, 138);
      expect(level.juzEntry(28)!.lastOrderInLevel, 204);
    });

    test('a juz of levels 1-2 labels its units with hizbs', () {
      final level = LevelModel.fromJson('level_1', level1Json);
      final juz30 = level.juzEntry(30)!;

      expect(juz30.hizbNumbers, [59, 60]);
      expect(
        juz30.unitLabels.first,
        'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
      );
    });

    test(
      'a juz of level 10 has no hizb labels — its units are surah groups',
      () {
        final level = LevelModel.fromJson('level_10', level10Json);
        final juz1 = level.juzEntry(1)!;

        expect(juz1.hizbNumbers, isNull);
        expect(
          juz1.unitLabels.first,
          'سرد المقرر من سورة البقرة على المحفظ المتابع',
        );
      },
    );

    test('a juz the level does not teach has no catalog entry', () {
      final level = LevelModel.fromJson('level_1', level1Json);
      expect(level.juzEntry(1), isNull);
    });

    test(
      'progress through a level is measured against its real session count',
      () {
        final level = LevelModel.fromJson('level_1', level1Json);

        expect(level.progressPercentageAt(1), 0);
        expect(level.progressPercentageAt(103), closeTo(50, 0.5)); // 102 / 204
        expect(level.progressPercentageAt(204), closeTo(99.5, 0.5));
      },
    );

    test('getName(true) returns Arabic, getName(false) returns English', () {
      final level = LevelModel.fromJson('level_1', level1Json);
      expect(level.getName(true), 'المستوى الأول');
      expect(level.getName(false), 'Level 1');
    });

    test('juzRange reads numerically, whichever way the level is taught', () {
      expect(
        LevelModel.fromJson('level_1', level1Json).juzRangeAr,
        'الأجزاء 28 - 30',
      );
      expect(
        LevelModel.fromJson('level_10', level10Json).juzRangeAr,
        'الأجزاء 1 - 3',
      );
      expect(
        LevelModel.fromJson('level_10', level10Json).juzRangeEn,
        'Juz 1 - 3',
      );
    });

    test('levels are equal by their document id', () {
      final a = LevelModel.fromJson('level_1', level1Json);
      final b = LevelModel.fromJson('level_1', level10Json);
      final c = LevelModel.fromJson('level_10', level10Json);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('the catalog round-trips through Firestore', () async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('levels').doc('level_1').set(level1Json);
      final DocumentSnapshot doc = await fake
          .collection('levels')
          .doc('level_1')
          .get();

      final level = LevelModel.fromFirestore(doc);
      final round = LevelModel.fromJson(level.id, level.toFirestore());

      expect(round.juzNumbers, [30, 29, 28]);
      expect(round.sessionCount, 204);
      expect(round.juzEntry(29)!.sessionCount, 69);
      expect(round.juzEntry(29)!.hizbNumbers, [57, 58]);
      expect(round.juzEntry(29)!.firstOrderInLevel, 69);
    });
  });
}
