import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/home_practice_screen.dart';

/// Regression test for the level-2 hizb-label contradiction.
///
/// Level 2's source workbooks contradict themselves: the file whose CONTENT is
/// hizb 53 carries marker text saying "سرد الحزب رقم 54" (and vice versa). The
/// student's denormalized `current_hizb` is the STRUCTURAL (filename) value,
/// which can disagree with the assessment's own verbatim `scope.labelAr`. The
/// home-practice header must never render an app-derived hizb number that can
/// contradict the source — it must speak only in terms the curriculum itself
/// gives (level / juz).
void main() {
  testWidgets(
    'home-practice header for a level-2 student does not render الحزب',
    (tester) async {
      final student = StudentModel(
        id: 'student-1',
        userId: 'user-1',
        instituteId: 'institute-1',
        currentLevel: 2,
        currentJuz: 27,
        currentSession: 24,
        // The structural hizb (54) contradicts the session's own verbatim
        // label, which says hizb 53 ('سرد الحزب رقم 53 كاملًا...').
        currentHizb: 54,
        currentSessionId: 'L2_J27_S24',
        currentSessionKind: SessionKind.sard,
        currentSessionTier: AssessmentTier.unit,
        currentSessionLabelAr: 'سرد الحزب رقم 53 كاملًا على المحفظ المتابع',
        currentOrderInLevel: 24,
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
          ],
          child: const MaterialApp(home: HomePracticeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('الحزب'), findsNothing);
      // The header still gives context via the level and juz the curriculum
      // actually carries.
      expect(find.textContaining('المستوى 2'), findsWidgets);
      expect(find.textContaining('الجزء 27'), findsWidgets);
    },
  );
}
