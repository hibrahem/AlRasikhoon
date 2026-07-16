import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/admin_dashboard_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminStatsProvider.overrideWith(
          (ref) async => const AdminStats(
            institutesCount: 2,
            teachersCount: 3,
            supervisorsCount: 1,
            studentsCount: 5,
          ),
        ),
      ],
      child: const MaterialApp(home: AdminDashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four management stat cards', (tester) async {
    await _pump(tester);

    expect(find.text('المعاهد'), findsOneWidget);
    expect(find.text('المعلمون'), findsOneWidget);
    expect(find.text('المشرفون'), findsOneWidget);
    expect(find.text('الطلاب'), findsOneWidget);
  });

  testWidgets('no longer shows the old quick-actions section', (tester) async {
    await _pump(tester);

    expect(find.text('الإجراءات السريعة'), findsNothing);
  });

  testWidgets('no longer shows a sign-out action in the AppBar', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byIcon(Icons.logout), findsNothing);
  });
}
