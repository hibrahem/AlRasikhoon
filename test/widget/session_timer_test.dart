import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows elapsed against the target when one is given', (
    tester,
  ) async {
    final started = DateTime.now().subtract(const Duration(minutes: 5));
    await tester.pumpWidget(
      host(
        SessionTimer(startedAt: started, target: const Duration(minutes: 20)),
      ),
    );
    // Elapsed ~05:00, target 20:00 → "05:00 / 20:00".
    expect(find.textContaining('/ 20:00'), findsOneWidget);
    expect(find.textContaining('05:0'), findsOneWidget);
  });

  testWidgets('shows elapsed only when there is no target', (tester) async {
    final started = DateTime.now().subtract(const Duration(minutes: 8));
    await tester.pumpWidget(host(SessionTimer(startedAt: started)));
    expect(find.textContaining('/'), findsNothing);
    expect(find.textContaining('08:0'), findsOneWidget);
  });

  testWidgets('advances as time passes', (tester) async {
    final started = DateTime.now();
    await tester.pumpWidget(host(SessionTimer(startedAt: started)));
    expect(find.text('00:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);
    // Let the periodic timer cancel cleanly.
    await tester.pumpWidget(host(const SizedBox()));
  });
}
