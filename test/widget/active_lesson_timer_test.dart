import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/widgets/active_lesson_timer.dart';

void main() {
  testWidgets('renders nothing when there is no active session', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ActiveLessonTimer(studentId: 's1')),
        ),
      ),
    );
    // No active session → collapses to an empty box, no timer text.
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining(':'), findsNothing);
  });
}
