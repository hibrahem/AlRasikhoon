import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/stat_card.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('StatCard renders in dark mode without error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    await pumpInTheme(
      tester,
      brightness: Brightness.dark,
      child: const StatCard(
        title: 'الجلسات',
        value: '12',
        icon: Icons.menu_book,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('الجلسات'), findsOneWidget);
  });
}
