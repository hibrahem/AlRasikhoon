import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/shared/widgets/app_large_top_bar.dart';

Widget _harness({required Widget sliverBar}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            sliverBar,
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (context, i) =>
                  SizedBox(height: 48, child: Text('عنصر $i')),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('large title renders once and stays while pinned after scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        sliverBar: const AppLargeTopBar(
          title: 'سجل الحلقات',
          actions: [Icon(Icons.search)],
        ),
      ),
    );

    // Exactly one title — the same Text collapses, so finders never see two.
    expect(find.text('سجل الحلقات'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    final expandedSize = tester.getRect(find.text('سجل الحلقات')).height;

    // Scroll far enough to fully collapse the bar.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Pinned: the title survives the scroll, smaller than when expanded.
    expect(find.text('سجل الحلقات'), findsOneWidget);
    final collapsedSize = tester.getRect(find.text('سجل الحلقات')).height;
    expect(collapsedSize, lessThan(expandedSize));
  });

  testWidgets('collapsed title clears a provided leading widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        sliverBar: const AppLargeTopBar(title: 'تفاصيل', leading: BackButton()),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // In RTL the leading BackButton sits at the right edge; the collapsed
    // title must start after it (further from the right edge), not under it.
    final titleRect = tester.getRect(find.text('تفاصيل'));
    final leadingRect = tester.getRect(find.byType(BackButton));
    expect(titleRect.right, lessThanOrEqualTo(leadingRect.left + 1));
  });
}
