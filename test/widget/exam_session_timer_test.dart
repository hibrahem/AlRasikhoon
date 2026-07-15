import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_session_screen.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

void main() {
  testWidgets('the exam session screen shows a live timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ExamSessionScreen(studentId: 's1')),
      ),
    );
    await tester.pump();
    expect(find.byType(SessionTimer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
