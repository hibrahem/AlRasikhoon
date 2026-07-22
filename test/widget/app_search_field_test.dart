import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/shared/widgets/app_search_field.dart';

Future<void> _pump(WidgetTester tester, ValueChanged<String> onChanged) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AppSearchField(onChanged: onChanged)),
    ),
  );
}

void main() {
  testWidgets('typing reports the query through onChanged', (tester) async {
    final reported = <String>[];
    await _pump(tester, reported.add);

    await tester.enterText(find.byType(TextField), 'أحمد');

    expect(reported, ['أحمد']);
  });

  testWidgets(
    'clear button appears only when non-empty and empties the field',
    (tester) async {
      final reported = <String>[];
      await _pump(tester, reported.add);

      expect(find.byIcon(Icons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'هدى');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(reported, ['هدى', '']);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );
}
