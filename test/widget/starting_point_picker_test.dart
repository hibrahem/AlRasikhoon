import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
import 'package:al_rasikhoon/features/teacher/widgets/starting_point_picker.dart';

/// Seeds a small but REAL-shaped curriculum:
///
/// - level 1 (juz 30, 29, 28 — descending, as the catalog says): juz 30 holds a
///   lesson (S1), the hizb-59 سرد (S30, unit tier), the juz-30 سرد (S67, juz
///   tier) and the juz-30 اختبار (S68, juz tier). Juz 29 holds one lesson. Juz
///   28 is deliberately left with NO sessions at all — it exercises the "this
///   juz has nothing to start at" path.
/// - level 10 (juz 1, 2, 3 — ASCENDING): one lesson in juz 1.
///
/// Note session 35 is not seeded as a سرد anywhere: the old `35 → سرد, 36 →
/// اختبار` rule is dead, and a session's kind comes from the data.
Future<FakeFirebaseFirestore> _seedCurriculum() async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'juz_numbers': [30, 29, 28],
    'session_count': 204,
    'order': 1,
  });
  await firestore.collection('levels').doc('level_10').set({
    'id': 10,
    'name_ar': 'المستوى العاشر',
    'name_en': 'Level 10',
    // Level 10 teaches its juz ASCENDING — the catalog says so, and nothing
    // computes it.
    'juz_numbers': [1, 2, 3],
    'session_count': 44,
    'order': 10,
  });

  Future<void> lesson(
    int level,
    int juz,
    int number,
    int orderInLevel, {
    int? hizb,
    String surah = 'النبأ',
  }) {
    return firestore
        .collection('sessions')
        .doc('L${level}_J${juz}_S$number')
        .set({
          'level_id': level,
          'juz_number': juz,
          'session_number': number,
          'order_in_level': orderInLevel,
          'kind': 'lesson',
          'hizb_number': hizb,
          'current_level_content': {
            'from_surah': surah,
            'from_verse': 1,
            'to_surah': surah,
            'to_verse': 11,
          },
        });
  }

  Future<void> assessment(
    int level,
    int juz,
    int number,
    int orderInLevel, {
    required String kind,
    required String tier,
    required String labelAr,
    int? hizb,
    List<int> juzNumbers = const [],
  }) {
    return firestore
        .collection('sessions')
        .doc('L${level}_J${juz}_S$number')
        .set({
          'level_id': level,
          'juz_number': juz,
          'session_number': number,
          'order_in_level': orderInLevel,
          'kind': kind,
          'hizb_number': hizb,
          'scope': {
            'tier': tier,
            'label_ar': labelAr,
            'hizb_number': hizb,
            'juz_numbers': juzNumbers,
          },
        });
  }

  await lesson(1, 30, 1, 1, hizb: 59);
  await assessment(
    1,
    30,
    30,
    30,
    kind: 'sard',
    tier: 'unit',
    labelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
    hizb: 59,
    juzNumbers: const [30],
  );
  await assessment(
    1,
    30,
    67,
    67,
    kind: 'sard',
    tier: 'juz',
    labelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
    juzNumbers: const [30],
  );
  await assessment(
    1,
    30,
    68,
    68,
    kind: 'exam',
    tier: 'juz',
    labelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
    juzNumbers: const [30],
  );
  await lesson(1, 29, 1, 69, hizb: 57, surah: 'الملك');
  await lesson(10, 1, 1, 1, surah: 'البقرة');

  return firestore;
}

/// A [CurriculumRepository] that delays `getSessionsForJuz` by a configurable
/// amount per juz, so tests can force one request to resolve after another that
/// started later — the exact race the picker must guard against.
class _RacyCurriculumRepository extends CurriculumRepository {
  _RacyCurriculumRepository(FakeFirebaseFirestore firestore, this._delays)
    : super(firestore: firestore);

  final Map<int, Duration> _delays;

  @override
  Future<List<SessionModel>> getSessionsForJuz({
    required int level,
    required int juz,
  }) async {
    final delay = _delays[juz];
    if (delay != null) await Future.delayed(delay);
    return super.getSessionsForJuz(level: level, juz: juz);
  }
}

Future<void> _pumpPicker(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  void Function(CurriculumPosition?) onChanged, {
  CurriculumRepository? curriculumRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        if (curriculumRepository != null)
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StartingPointPicker(
              initialValue: CurriculumPosition.start,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A minimal juz holding a تلقين followed immediately by the lesson it
/// introduces — both teaching the exact same range, exactly the scenario a
/// placing teacher must be able to tell apart.
Future<FakeFirebaseFirestore> _seedTalqeenThenLesson() async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'juz_numbers': [30],
    'session_count': 2,
    'order': 1,
  });

  Future<void> session(int number, int orderInLevel, String kind) {
    return firestore.collection('sessions').doc('L1_J30_S$number').set({
      'level_id': 1,
      'juz_number': 30,
      'session_number': number,
      'order_in_level': orderInLevel,
      'kind': kind,
      'current_level_content': {
        'from_surah': 'النبأ',
        'from_verse': 1,
        'to_surah': 'النبأ',
        'to_verse': 11,
      },
    });
  }

  await session(1, 1, 'talqeen');
  await session(2, 2, 'lesson');

  return firestore;
}

void main() {
  testWidgets(
    'a تلقين is offered distinguishably from the lesson it introduces, even '
    'though both teach the identical range',
    (tester) async {
      final firestore = await _seedTalqeenThenLesson();
      await _pumpPicker(tester, firestore, (_) {});

      await tester.tap(find.byKey(const Key('starting_point_session')));
      await tester.pumpAndSettle();

      // The تلقين reads as a تلقين, not as 'الحلقة 1' — the exact
      // misnaming that made it indistinguishable from the lesson beneath it.
      expect(find.textContaining('تلقين'), findsWidgets);
      expect(find.text('الحلقة 1 — النبأ: 1 - 11'), findsNothing);
      // The lesson it introduces is still offered as an ordinary lesson.
      expect(find.textContaining('الحلقة 2 — النبأ'), findsWidgets);
    },
  );

  testWidgets(
    'placing a student directly onto a تلقين states it as a تلقين in the '
    'consequence banner, not as a حلقة',
    (tester) async {
      final firestore = await _seedTalqeenThenLesson();
      await _pumpPicker(tester, firestore, (_) {});

      // The picker defaults to the first session in the juz — the تلقين.
      expect(find.textContaining('سيبدأ الطالب من تلقين'), findsOneWidget);
    },
  );

  testWidgets('defaults to the first session of the curriculum', (
    tester,
  ) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    expect(find.textContaining('المستوى الأول'), findsOneWidget);
    expect(find.textContaining('الجزء 30'), findsWidgets);
    // The default position must actually be reported to the parent, not just
    // displayed — otherwise a parent that trusts onChanged would think no
    // starting point had been chosen yet.
    expect(reported, const CurriculumPosition(level: 1, juz: 30, session: 1));
  });

  testWidgets('lists the juz of a level in TEACHING order', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    // Read the dropdown's own item list straight from the widget tree, rather
    // than scraping rendered Text — the closed dropdown button also renders its
    // selected value as text.
    final juzDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const Key('starting_point_juz')),
    );

    expect(juzDropdown.items!.map((item) => item.value).toList(), [30, 29, 28]);
  });

  testWidgets(
    'level 10 lists its juz ASCENDING (1 → 2 → 3), as the catalog says',
    (tester) async {
      final firestore = await _seedCurriculum();
      await _pumpPicker(tester, firestore, (_) {});

      await tester.tap(find.byKey(const Key('starting_point_level')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('المستوى العاشر').last);
      await tester.pumpAndSettle();

      final juzDropdown = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('starting_point_juz')),
      );

      // Any arithmetic rule (descend from the level's highest juz) gets this
      // wrong. The order is DATA.
      expect(juzDropdown.items!.map((item) => item.value).toList(), [1, 2, 3]);
    },
  );

  testWidgets('a lesson is offered by its Quran range', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    await tester.tap(find.byKey(const Key('starting_point_session')));
    await tester.pumpAndSettle();

    expect(find.textContaining('الحلقة 1 — النبأ'), findsWidgets);
  });

  testWidgets(
    'a unit-tier سرد is offered under the curriculum\'s own verbatim label',
    (tester) async {
      final firestore = await _seedCurriculum();
      CurriculumPosition? reported;
      await _pumpPicker(tester, firestore, (position) => reported = position);

      await tester.tap(find.byKey(const Key('starting_point_session')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('سرد الحزب رقم 59 كاملًا على المحفظ المتابع').last,
      );
      await tester.pumpAndSettle();

      // Session 30 — not 35. The number carries no meaning; the data does.
      expect(
        reported,
        const CurriculumPosition(level: 1, juz: 30, session: 30),
      );
    },
  );

  testWidgets(
    'a student may be placed directly onto a JUZ-tier سرد, which belongs to no '
    'hizb at all',
    (tester) async {
      final firestore = await _seedCurriculum();
      CurriculumPosition? reported;
      await _pumpPicker(tester, firestore, (position) => reported = position);

      await tester.tap(find.byKey(const Key('starting_point_session')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('سرد الجزء رقم 30 كاملًا على المحفظ المتابع').last,
      );
      await tester.pumpAndSettle();

      expect(
        reported,
        const CurriculumPosition(level: 1, juz: 30, session: 67),
      );
    },
  );

  testWidgets('a juz-tier اختبار is selectable as a starting point', (
    tester,
  ) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_session')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات').last,
    );
    await tester.pumpAndSettle();

    // Session 68 — the juz-30 اختبار of level 1. The old model could not even
    // name it (it insisted the exam was session 36).
    expect(reported, const CurriculumPosition(level: 1, juz: 30, session: 68));
  });

  testWidgets('changing the level resets the juz and session', (tester) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_level')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('المستوى العاشر').last);
    await tester.pumpAndSettle();

    expect(reported?.level, 10);
    expect(reported?.juz, 1); // the first juz level 10 TEACHES
    expect(reported?.session, 1); // its first existing session
  });

  testWidgets('states the consequence of the placement', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    expect(
      find.textContaining('ويُعتبر ما قبلها من المنهج محفوظًا ومعتمدًا'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a juz with no sessions in the curriculum reports no valid position, '
    'not an invented one',
    (tester) async {
      final firestore = await _seedCurriculum();
      final reports = <CurriculumPosition?>[];
      await _pumpPicker(tester, firestore, reports.add);

      // Juz 28 (level 1) has no seeded sessions at all.
      await tester.tap(find.byKey(const Key('starting_point_juz')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجزء 28').last);
      await tester.pumpAndSettle();

      expect(reports.last, isNull);

      final sessionDropdown = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('starting_point_session')),
      );
      expect(sessionDropdown.items, isEmpty);
      expect(find.text('اختر الحلقة'), findsOneWidget);

      expect(
        find.textContaining('لا توجد حلقات لهذا الجزء في المنهج'),
        findsOneWidget,
      );
      // The banner must not claim a starting point when there isn't one.
      expect(
        find.textContaining('ويُعتبر ما قبلها من المنهج محفوظًا ومعتمدًا'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a slower response from an earlier juz selection does not overwrite a '
    'faster response from a later one',
    (tester) async {
      final firestore = await _seedCurriculum();
      // Juz 30 (auto-selected for level 1) is slow; selecting juz 29 right after
      // it is fast. The fast, later request must win even though its response
      // arrives first in wall-clock terms while the slow, earlier request is
      // still in flight.
      final repo = _RacyCurriculumRepository(firestore, {
        30: const Duration(seconds: 2),
        29: const Duration(milliseconds: 30),
      });
      CurriculumPosition? reported;
      await _pumpPicker(
        tester,
        firestore,
        (position) => reported = position,
        curriculumRepository: repo,
      );

      // Before juz 30's fetch resolves, switch to juz 29, whose fetch is fast
      // and should resolve well before juz 30's does.
      await tester.tap(find.byKey(const Key('starting_point_juz')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجزء 29').last);
      await tester.pump(const Duration(milliseconds: 100));

      // Now let juz 30's slow, stale response arrive.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(reported?.juz, 29);
      expect(reported?.session, 1);
    },
  );

  testWidgets(
    'changing the juz reports null immediately, before the new sessions arrive, '
    'then reports the real position once they do',
    (tester) async {
      final firestore = await _seedCurriculum();
      // Juz 29's fetch is deliberately slow so the test can observe the picker's
      // state while the fetch is still in flight.
      final repo = _RacyCurriculumRepository(firestore, {
        29: const Duration(milliseconds: 300),
      });
      final reports = <CurriculumPosition?>[];
      await _pumpPicker(
        tester,
        firestore,
        reports.add,
        curriculumRepository: repo,
      );

      expect(
        reports.last,
        const CurriculumPosition(level: 1, juz: 30, session: 1),
      );

      // Switch to juz 29, whose sessions take 300ms to arrive.
      await tester.tap(find.byKey(const Key('starting_point_juz')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجزء 29').last);
      // Advance just enough to process the tap/selection itself, well short of
      // the 300ms fetch delay — the stale juz-30 position must not still be
      // reportable in this window.
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        reports.last,
        isNull,
        reason:
            'the parent must be told there is nothing valid to submit while '
            "juz 29's sessions are still loading, instead of being left holding "
            "juz 30's stale position",
      );

      // Let juz 29's fetch resolve.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        reports.last,
        const CurriculumPosition(level: 1, juz: 29, session: 1),
      );
    },
  );
}
