import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/widgets/home_practice_card.dart';
import 'package:al_rasikhoon/shared/widgets/progress_bar.dart';

Future<void> _pump(
  WidgetTester tester, {
  required HomeAssignment? assignment,
  required HomePracticeStats stats,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeAssignmentProvider.overrideWith((ref) async => assignment),
        homePracticeStatsProvider.overrideWith((ref) async => stats),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: HomePracticeCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HomePracticeCard', () {
    testWidgets(
      'with an active assignment shows progress and the streak caption',
      (tester) async {
        await _pump(
          tester,
          assignment: const HomeAssignment(
            curriculumSessionId: 'L1_J30_S1',
            repetitionsRequired: 10,
            repetitionsDone: 7,
          ),
          stats: const HomePracticeStats(
            todayRepetitions: 3,
            streakDays: 12,
            totalRepetitions: 50,
          ),
        );
        expect(find.textContaining('التكرار في المنزل'), findsOneWidget);
        expect(find.textContaining('7 / 10'), findsOneWidget);
        expect(find.byType(ProgressBar), findsOneWidget);
        expect(find.textContaining('اليوم 3'), findsOneWidget);
        expect(find.textContaining('متتالية 12'), findsOneWidget);
      },
    );

    testWidgets('with no assignment shows the counters and no progress bar', (
      tester,
    ) async {
      await _pump(
        tester,
        assignment: null,
        stats: const HomePracticeStats(
          todayRepetitions: 3,
          streakDays: 12,
          totalRepetitions: 50,
        ),
      );
      expect(find.textContaining('التكرار في المنزل'), findsOneWidget);
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.textContaining('اليوم 3'), findsOneWidget);
      expect(find.textContaining('متتالية 12'), findsOneWidget);
      expect(find.textContaining('الإجمالي 50'), findsOneWidget);
    });
  });
}
