import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
import 'package:al_rasikhoon/features/teacher/widgets/starting_point_picker.dart';

/// Seeds three hizbs' worth of curriculum: level 1 hizb 59 (sessions 1, 2,
/// 35, 36), level 2 hizb 53 (sessions 1, 35) and level 2 hizb 54 (session
/// 2). Level 1 hizb 60 is deliberately left with no sessions at all — it
/// exercises the "this hizb has nothing to start at" path.
Future<FakeFirebaseFirestore> _seedCurriculum() async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'juz_numbers': [30, 29, 28],
    'total_sessions': 219,
    'hizb_count': 6,
    'order': 1,
  });
  await firestore.collection('levels').doc('level_2').set({
    'id': 2,
    'name_ar': 'المستوى الثاني',
    'name_en': 'Level 2',
    'juz_numbers': [27, 26, 25],
    'total_sessions': 150,
    'hizb_count': 6,
    'order': 2,
  });

  Future<void> session(int level, int hizb, int number, String type) {
    final juz = (hizb + 1) ~/ 2;
    return firestore
        .collection('sessions')
        .doc('L${level}_J${juz}_H${hizb}_S$number')
        .set({
          'session_number': number,
          'level_id': level,
          'juz_number': juz,
          'hizb_number': hizb,
          'session_type': type,
        });
  }

  await session(1, 59, 1, 'regular');
  await session(1, 59, 2, 'regular');
  await session(1, 59, 35, 'sard');
  await session(1, 59, 36, 'exam');
  await session(2, 53, 1, 'regular');
  await session(2, 53, 35, 'sard');
  await session(2, 54, 2, 'regular');

  return firestore;
}

/// A [CurriculumRepository] that delays `getSessionNumbersForHizb` by a
/// configurable amount per hizb, so tests can force one request to resolve
/// after another that started later — the exact race the picker must guard
/// against (finding 5).
class _RacyCurriculumRepository extends CurriculumRepository {
  _RacyCurriculumRepository(FakeFirebaseFirestore firestore, this._delays)
    : super(firestore: firestore);

  final Map<int, Duration> _delays;

  @override
  Future<List<int>> getSessionNumbersForHizb({
    required int level,
    required int hizb,
  }) async {
    final delay = _delays[hizb];
    if (delay != null) await Future.delayed(delay);
    return super.getSessionNumbersForHizb(level: level, hizb: hizb);
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
              value: CurriculumPosition.start,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to the first session of the curriculum', (
    tester,
  ) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    expect(find.textContaining('المستوى الأول'), findsOneWidget);
    expect(find.textContaining('الحزب 59'), findsWidgets);
    // The default position must actually be reported to the parent, not
    // just displayed — otherwise a parent that trusts onChanged would think
    // no starting point had been chosen yet.
    expect(reported, const CurriculumPosition(level: 1, hizb: 59, session: 1));
  });

  testWidgets('lists the hizbs of a level in teaching order', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    // Read the dropdown's own item list straight from the widget tree,
    // rather than scraping rendered Text — the closed dropdown button also
    // renders its selected value as text, which would otherwise be
    // mistaken for the first (and wrong) menu item if the item order were
    // ever broken.
    final hizbDropdown = tester.widget<DropdownButton<int>>(
      find.byKey(const Key('starting_point_hizb')),
    );
    final order = hizbDropdown.items!.map((item) => item.value).toList();

    expect(order, [59, 60, 57, 58, 55, 56]);
  });

  testWidgets('choosing a session reports the position to the parent', (
    tester,
  ) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_session')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السرد').last);
    await tester.pumpAndSettle();

    expect(reported, const CurriculumPosition(level: 1, hizb: 59, session: 35));
  });

  testWidgets('Exam is selectable as a starting point', (tester) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_session')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الاختبار').last);
    await tester.pumpAndSettle();

    expect(reported, const CurriculumPosition(level: 1, hizb: 59, session: 36));
  });

  testWidgets('changing the level resets the hizb and session', (tester) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_level')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('المستوى الثاني').last);
    await tester.pumpAndSettle();

    expect(reported?.level, 2);
    expect(reported?.hizb, 53); // first hizb of level 2 in teaching order
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
    'a hizb with no sessions in the curriculum reports no valid position, '
    'not an invented one',
    (tester) async {
      final firestore = await _seedCurriculum();
      final reports = <CurriculumPosition?>[];
      await _pumpPicker(tester, firestore, reports.add);

      // Hizb 60 (level 1) has no seeded sessions at all.
      await tester.tap(find.byKey(const Key('starting_point_hizb')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('الحزب 60').last);
      await tester.pumpAndSettle();

      expect(reports.last, isNull);

      final sessionDropdown = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('starting_point_session')),
      );
      expect(sessionDropdown.items, isEmpty);
      expect(find.text('اختر الحلقة'), findsOneWidget);

      expect(
        find.textContaining('لا توجد حلقات لهذا الحزب في المنهج'),
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
    'a slower response from an earlier hizb selection does not overwrite '
    'a faster response from a later one',
    (tester) async {
      final firestore = await _seedCurriculum();
      // Selecting hizb 53 (auto-selected when level 2 is chosen) is slow;
      // selecting hizb 54 right after it is fast. The fast, later request
      // must win even though its response arrives first in wall-clock
      // terms while the slow, earlier request is still in flight.
      final repo = _RacyCurriculumRepository(firestore, {
        53: const Duration(seconds: 2),
        54: const Duration(milliseconds: 30),
      });
      CurriculumPosition? reported;
      await _pumpPicker(
        tester,
        firestore,
        (position) => reported = position,
        curriculumRepository: repo,
      );

      // Select level 2 -> auto-selects hizb 53, whose fetch is slow.
      await tester.tap(find.byKey(const Key('starting_point_level')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('المستوى الثاني').last);
      await tester.pump(const Duration(milliseconds: 20));

      // Before hizb 53's fetch resolves, switch to hizb 54, whose fetch is
      // fast and should resolve well before hizb 53's does.
      await tester.tap(find.byKey(const Key('starting_point_hizb')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('الحزب 54').last);
      await tester.pump(const Duration(milliseconds: 100));

      // Now let hizb 53's slow, stale response arrive.
      await tester.pump(const Duration(seconds: 2));

      expect(reported?.hizb, 54);
      expect(reported?.session, 2);
    },
  );
}
