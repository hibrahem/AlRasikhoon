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

/// The search field plus a results area beneath it — the shape every list
/// screen that hosts the field actually has.
Future<void> _pumpWithResults(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            AppSearchField(onChanged: (_) {}),
            const Expanded(
              child: ColoredBox(
                color: Color(0xFFFFFFFF),
                child: SizedBox.expand(key: Key('results')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _fieldHasFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

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

  // On a phone the bottom nav bar sits BEHIND the soft keyboard (Scaffold
  // anchors `bottomNavigationBar` to the viewport bottom and only the body
  // avoids `viewInsets`), so a search field the user cannot dismiss traps them
  // on the screen. Flutter's default tap-outside handler is a no-op for touch
  // on Android/iOS, so the field has to release focus itself.
  testWidgets('tapping outside the field closes the keyboard', (tester) async {
    await _pumpWithResults(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(_fieldHasFocus(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tapAt(tester.getCenter(find.byKey(const Key('results'))));
    await tester.pump();

    expect(_fieldHasFocus(tester), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('the clear button does not close the keyboard', (tester) async {
    await _pumpWithResults(tester);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'هدى');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // Clearing is part of searching — the user keeps typing afterwards.
    expect(_fieldHasFocus(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
