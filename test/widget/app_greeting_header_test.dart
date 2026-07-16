import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/shared/widgets/app_greeting_header.dart';

void main() {
  testWidgets('AppGreetingHeader shows greeting, title, trailing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AppGreetingHeader(
              greeting: 'السلام عليكم',
              title: 'محمد الأحمد',
              trailing: Icon(Icons.person),
            ),
          ),
        ),
      ),
    );

    expect(find.text('السلام عليكم'), findsOneWidget);
    expect(find.text('محمد الأحمد'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
