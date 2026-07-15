import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/screens/sard_session_screen.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

void main() {
  testWidgets('the sard session screen shows a live timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: SardSessionScreen(studentId: 's1')),
      ),
    );
    await tester.pump(); // let the async session provider settle to a frame
    expect(find.byType(SessionTimer), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // cancel the periodic timer
  });
}
