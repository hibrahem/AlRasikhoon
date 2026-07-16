import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/shared/widgets/app_top_bar.dart';

void main() {
  testWidgets('AppTopBar renders title and actions on a page-colored bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppTopBar(title: 'تفاصيل', actions: [Icon(Icons.search)]),
            body: SizedBox(),
          ),
        ),
      ),
    );

    expect(find.text('تفاصيل'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
