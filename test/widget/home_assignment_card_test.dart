import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/widgets/home_assignment_card.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, HomeAssignment? assignment) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeAssignmentProvider.overrideWith((ref) async => assignment),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: HomeAssignmentCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the repetitions owed and those already done', (
    tester,
  ) async {
    await pump(
      tester,
      const HomeAssignment(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 10,
        repetitionsDone: 4,
      ),
    );

    expect(find.text('واجب التكرار في المنزل'), findsOneWidget);
    expect(find.text('4 / 10'), findsOneWidget);
  });

  testWidgets('says so when the assignment is done', (tester) async {
    await pump(
      tester,
      const HomeAssignment(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 10,
        repetitionsDone: 10,
      ),
    );

    expect(find.text('اكتمل الواجب'), findsOneWidget);
  });

  testWidgets('renders nothing when no repetitions were assigned', (
    tester,
  ) async {
    await pump(tester, null);

    // "Nothing" means no visible surface at all — not merely an absent
    // title on an otherwise-rendered empty card shell.
    expect(find.text('واجب التكرار في المنزل'), findsNothing);
    expect(find.byType(AppCard), findsNothing);
    expect(tester.getSize(find.byType(HomeAssignmentCard)), Size.zero);
  });

  testWidgets('caps the displayed count at the target when over-practised', (
    tester,
  ) async {
    await pump(
      tester,
      const HomeAssignment(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 10,
        repetitionsDone: 12,
      ),
    );

    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('12 / 10'), findsNothing);
    expect(find.text('اكتمل الواجب'), findsOneWidget);
  });
}
