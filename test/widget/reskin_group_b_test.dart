import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/grade_display.dart';
import 'package:al_rasikhoon/shared/widgets/level_progression_widget.dart';
import 'package:al_rasikhoon/shared/widgets/progress_bar.dart';
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

  testWidgets('LevelProgressionWidget mastery ladder renders in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
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
      expect(find.text('راسخ'), findsOneWidget);
      expect(find.text('محب'), findsOneWidget);
    }
  });

  testWidgets(
    'LevelProgressionWidget ladder fill fraction matches completedLevels, '
    'never currentLevel',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 300));

      // Nothing completed yet: the header reads "0/10 مكتمل", so the ladder
      // must show essentially no fill — even though currentLevel is 1 (a
      // naive currentLevel/totalLevels fraction would wrongly show 0.1).
      await pumpInTheme(
        tester,
        child: const LevelProgressionWidget(
          currentLevel: 1,
          unlockedLevels: [1],
          completedLevels: [],
        ),
      );
      var ladder = tester.widget<MasteryLadder>(find.byType(MasteryLadder));
      expect(ladder.fraction, closeTo(0.0, 1e-9));

      // 3 levels completed, currently working on level 4: the header reads
      // "3/10 مكتمل", so the fill must reflect 3 done — not 4 (a naive
      // currentLevel/totalLevels fraction would wrongly show 0.4).
      await pumpInTheme(
        tester,
        child: const LevelProgressionWidget(
          currentLevel: 4,
          unlockedLevels: [1, 2, 3, 4],
          completedLevels: [1, 2, 3],
        ),
      );
      ladder = tester.widget<MasteryLadder>(find.byType(MasteryLadder));
      expect(ladder.fraction, closeTo(0.3, 1e-9));
    },
  );
}
