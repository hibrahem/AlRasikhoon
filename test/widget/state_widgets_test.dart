// test/widget/state_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/states/empty_state.dart';
import 'package:al_rasikhoon/shared/widgets/states/error_state.dart';
import 'package:al_rasikhoon/shared/widgets/states/loading_state.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('EmptyState shows title and action', (tester) async {
    await pumpInTheme(
      tester,
      child: EmptyState(
        icon: Icons.menu_book,
        title: 'لا توجد جلسات بعد',
        action: FilledButton(onPressed: () {}, child: const Text('ابدأ')),
      ),
    );
    expect(find.text('لا توجد جلسات بعد'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
  });

  testWidgets('ErrorState retry fires callback', (tester) async {
    var tapped = false;
    await pumpInTheme(
      tester,
      child: ErrorState(message: 'تعذر التحميل', onRetry: () => tapped = true),
    );
    await tester.tap(find.text('إعادة المحاولة'));
    expect(tapped, isTrue);
  });

  testWidgets('LoadingState renders without error', (tester) async {
    await pumpInTheme(tester, child: const LoadingState());
    expect(tester.takeException(), isNull);
  });
}
