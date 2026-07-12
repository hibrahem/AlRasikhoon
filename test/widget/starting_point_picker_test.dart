import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
import 'package:al_rasikhoon/features/teacher/widgets/starting_point_picker.dart';

/// Seeds two levels' worth of curriculum: level 1 hizb 59 (sessions 1, 2, 35, 36)
/// and level 2 hizb 53 (sessions 1, 35).
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

  return firestore;
}

Future<void> _pumpPicker(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  void Function(CurriculumPosition) onChanged,
) async {
  var value = CurriculumPosition.start;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [firestoreProvider.overrideWithValue(firestore)],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: StartingPointPicker(
                value: value,
                onChanged: (position) {
                  onChanged(position);
                  setState(() => value = position);
                },
              ),
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
    await _pumpPicker(tester, firestore, (_) {});

    expect(find.textContaining('المستوى الأول'), findsOneWidget);
    expect(find.textContaining('الحزب 59'), findsWidgets);
  });

  testWidgets('lists the hizbs of a level in teaching order', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    final picker = tester.widget<StartingPointPicker>(
      find.byType(StartingPointPicker),
    );
    expect(picker.value, CurriculumPosition.start);

    // The hizb dropdown offers level 1's hizbs in teaching order: 59, 60, 57...
    await tester.tap(find.byKey(const Key('starting_point_hizb')));
    await tester.pumpAndSettle();

    // 'الحزب ' (with a trailing space) excludes the field's own label, which
    // is the bare word 'الحزب' with nothing after it and would otherwise be
    // the first (and wrong) match.
    final items = tester
        .widgetList<Text>(find.textContaining('الحزب '))
        .map((t) => t.data)
        .toList();
    expect(items.first, contains('59'));
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
}
