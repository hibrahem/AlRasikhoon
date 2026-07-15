import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/grade_display.dart';
import 'package:al_rasikhoon/shared/widgets/level_progression_widget.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('GradeDisplay renders in both themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    for (final b in Brightness.values) {
      await pumpInTheme(
        tester,
        brightness: b,
        child: const GradeDisplay(errorCount: 2),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('LevelProgressionWidget numbered grid renders in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    for (final b in Brightness.values) {
      await pumpInTheme(
        tester,
        brightness: b,
        child: const LevelProgressionWidget(
          currentLevel: 4,
          unlockedLevels: [1, 2, 3, 4],
          completedLevels: [1, 2, 3],
        ),
      );
      expect(tester.takeException(), isNull);
      // Real level NUMBERS, not grade terms: the tiles span 1..10 and none of
      // the mastery-ladder rungs (راسخ · متقن · …) appear.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('راسخ'), findsNothing);
      expect(find.text('متقن'), findsNothing);
    }
  });

  testWidgets('LevelProgressionWidget completed count matches completedLevels, '
      'never currentLevel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));

    // Nothing completed yet: the header reads "0/10 مكتمل" even though
    // currentLevel is 1 (currentLevel is not a completed level).
    await pumpInTheme(
      tester,
      child: const LevelProgressionWidget(
        currentLevel: 1,
        unlockedLevels: [1],
        completedLevels: [],
      ),
    );
    expect(find.text('0/10 مكتمل'), findsOneWidget);

    // 3 levels completed, currently working on level 4: the header reads
    // "3/10 مكتمل" — the current level does not count as completed.
    await pumpInTheme(
      tester,
      child: const LevelProgressionWidget(
        currentLevel: 4,
        unlockedLevels: [1, 2, 3, 4],
        completedLevels: [1, 2, 3],
      ),
    );
    expect(find.text('3/10 مكتمل'), findsOneWidget);
  });
}
