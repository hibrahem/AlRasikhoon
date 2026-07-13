import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/widgets/recitation_counts_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int withTeacher,
    required int atHome,
    required ValueChanged<int> onWithTeacher,
    required ValueChanged<int> onAtHome,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RecitationCountsCard(
              repetitionsWithTeacher: withTeacher,
              homeRepetitionsRequired: atHome,
              onRepetitionsWithTeacherChanged: onWithTeacher,
              onHomeRepetitionsRequiredChanged: onAtHome,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows both counts under their Arabic labels', (tester) async {
    await pump(
      tester,
      withTeacher: 4,
      atHome: 10,
      onWithTeacher: (_) {},
      onAtHome: (_) {},
    );

    expect(find.text('عدد مرات القراءة مع الطالب'), findsOneWidget);
    expect(find.text('عدد مرات التكرار في المنزل'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('incrementing a count reports the new value', (tester) async {
    int? reported;
    await pump(
      tester,
      withTeacher: 4,
      atHome: 10,
      onWithTeacher: (v) => reported = v,
      onAtHome: (_) {},
    );

    await tester.tap(
      find.byKey(const Key('increment_repetitions_with_teacher')),
    );
    expect(reported, 5);
  });

  testWidgets('a count never goes below zero', (tester) async {
    int? reported;
    await pump(
      tester,
      withTeacher: 0,
      atHome: 0,
      onWithTeacher: (v) => reported = v,
      onAtHome: (_) {},
    );

    await tester.tap(
      find.byKey(const Key('decrement_repetitions_with_teacher')),
    );
    expect(reported, isNull);
  });

  testWidgets('the home-repetitions count never goes below zero either', (
    tester,
  ) async {
    int? reported;
    await pump(
      tester,
      withTeacher: 0,
      atHome: 0,
      onWithTeacher: (_) {},
      onAtHome: (v) => reported = v,
    );

    await tester.tap(
      find.byKey(const Key('decrement_home_repetitions_required')),
    );
    expect(reported, isNull);
  });
}
