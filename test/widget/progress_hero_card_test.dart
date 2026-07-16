import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/student/widgets/progress_hero_card.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ProgressHeroCard(
            percent: 27,
            fraction: 0.27,
            juzMemorized: 8,
            currentLevel: 4,
            streakDays: 12,
            passedSessions: 36,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ProgressHeroCard', () {
    testWidgets('shows the curriculum percent in the ring', (tester) async {
      await _pump(tester);
      expect(find.textContaining('27%'), findsOneWidget);
      expect(find.textContaining('من المنهج'), findsOneWidget);
    });

    testWidgets('shows juz memorized in the caption', (tester) async {
      await _pump(tester);
      expect(find.textContaining('حفظت 8 من 30'), findsOneWidget);
    });

    testWidgets('shows the three supporting stats: level, streak, passed', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('4'), findsWidgets); // level
      expect(find.text('12'), findsWidgets); // streak days
      expect(find.text('36'), findsWidgets); // passed sessions
      expect(find.textContaining('المستوى'), findsOneWidget);
      expect(find.textContaining('متتالية'), findsOneWidget);
      expect(find.textContaining('ناجحة'), findsOneWidget);
    });
  });
}
