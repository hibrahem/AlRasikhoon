import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/home_practice_screen.dart';

/// Proves `HomeAssignmentCard` is actually wired onto `HomePracticeScreen`,
/// and that it sits ABOVE the repetition entry — the point of its placement
/// is that the student sees what they owe before logging against it.
void main() {
  testWidgets(
    'HomePracticeScreen shows the home assignment above the repetition entry',
    (tester) async {
      final student = StudentModel(
        id: 'student-1',
        userId: 'user-1',
        instituteId: 'institute-1',
        currentLevel: 1,
        currentJuz: 30,
        currentSession: 2,
        currentHizb: 60,
        currentSessionId: 'L1_J30_S2',
        currentSessionKind: SessionKind.sard,
        currentSessionTier: AssessmentTier.unit,
        currentSessionLabelAr: 'سرد',
        currentOrderInLevel: 2,
        createdAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentProvider.overrideWith((ref) async => student),
            homePracticeStatsProvider.overrideWith(
              (ref) async => const HomePracticeStats(),
            ),
            studentHomePracticesProvider.overrideWith((ref) async => []),
            homeAssignmentProvider.overrideWith(
              (ref) async => const HomeAssignment(
                curriculumSessionId: 'L1_J30_S2',
                repetitionsRequired: 10,
                repetitionsDone: 4,
              ),
            ),
          ],
          child: const MaterialApp(home: HomePracticeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The card's content is actually on screen.
      expect(find.text('واجب التكرار في المنزل'), findsOneWidget);
      expect(find.text('4 / 10'), findsOneWidget);

      // And it appears ABOVE the repetition entry, not merely somewhere on
      // the screen — that ordering is the entire point of placing it there.
      final assignmentY = tester
          .getTopLeft(find.text('واجب التكرار في المنزل'))
          .dy;
      final repetitionEntryY = tester.getTopLeft(find.text('عدد التكرارات')).dy;

      expect(assignmentY, lessThan(repetitionEntryY));
    },
  );
}
