import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/shared/widgets/app_text_field.dart';

/// A field plus a body beneath it — the shape of every form screen in the app.
Future<void> _pumpForm(WidgetTester tester, Widget field) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            field,
            const Expanded(
              child: ColoredBox(
                color: Color(0xFFFFFFFF),
                child: SizedBox.expand(key: Key('body')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _keyboardIsOpen(WidgetTester tester) => tester.testTextInput.isVisible;

Future<void> _focusThenTapAway(WidgetTester tester, Finder field) async {
  await tester.tap(field);
  await tester.pump();
  expect(_keyboardIsOpen(tester), isTrue, reason: 'field should take focus');

  await tester.tapAt(tester.getCenter(find.byKey(const Key('body'))));
  await tester.pump();
}

void main() {
  // Same trap as the search field (al_rasikhoon-gvoh): Flutter's default
  // tap-outside handler is a no-op for touch on Android/iOS, so a form whose
  // fields never release focus leaves the keyboard covering whatever sits at
  // the bottom of the screen — including the bottom nav bar.
  group('tapping outside a form field closes the keyboard', () {
    testWidgets('AppTextField', (tester) async {
      await _pumpForm(tester, const AppTextField(label: 'الاسم'));
      await _focusThenTapAway(tester, find.byType(TextFormField));
      expect(_keyboardIsOpen(tester), isFalse);
    });

    testWidgets('AppEmailField', (tester) async {
      await _pumpForm(tester, const AppEmailField());
      await _focusThenTapAway(tester, find.byType(TextFormField));
      expect(_keyboardIsOpen(tester), isFalse);
    });

    testWidgets('AppPasswordField', (tester) async {
      await _pumpForm(tester, const AppPasswordField());
      await _focusThenTapAway(tester, find.byType(TextFormField));
      expect(_keyboardIsOpen(tester), isFalse);
    });

    testWidgets('AppPhoneField', (tester) async {
      await _pumpForm(tester, const AppPhoneField());
      await _focusThenTapAway(tester, find.byType(TextFormField));
      expect(_keyboardIsOpen(tester), isFalse);
    });

    testWidgets('AppOtpField', (tester) async {
      await _pumpForm(tester, AppOtpField(onCompleted: (_) {}));
      await _focusThenTapAway(tester, find.byType(TextField).first);
      expect(_keyboardIsOpen(tester), isFalse);
    });
  });

  // TextFieldTapRegion groups every text field under `EditableText`, so a tap
  // that moves focus between two fields is never "outside". Pinned because a
  // hand-rolled unfocus-on-tap would close and reopen the keyboard here, which
  // is exactly the flicker this fix must not introduce on multi-field forms.
  testWidgets('moving focus between two fields keeps the keyboard open', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppTextField(key: Key('first'), label: 'الاسم'),
              AppTextField(key: Key('second'), label: 'الهاتف'),
            ],
          ),
        ),
      ),
    );

    Finder fieldIn(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextFormField),
    );

    await tester.tap(fieldIn('first'));
    await tester.pump();
    expect(_keyboardIsOpen(tester), isTrue);

    await tester.tap(fieldIn('second'));
    await tester.pump();

    expect(_keyboardIsOpen(tester), isTrue);
  });

  // Behaviour tests can only cover the fields they instantiate, and this trap
  // has now been hit twice. Every raw TextField/TextFormField in the app must
  // opt in, so a newly added one fails here rather than in a tester's hands.
  test('every text field in lib/ handles onTapOutside', () {
    // Excludes AppTextField( and friends — only the bare constructors.
    final constructor = RegExp(r'(?<![A-Za-z0-9_])TextF(ield|ormField)\(');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      final fields = constructor.allMatches(source).length;
      if (fields == 0) continue;
      final handled = 'onTapOutside:'.allMatches(source).length;
      if (handled < fields) {
        offenders.add('${entity.path}: $fields field(s), $handled handled');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These text fields never release focus, so the soft keyboard cannot '
          'be dismissed by tapping outside them (al_rasikhoon-gvoh). Pass '
          'onTapOutside: dismissKeyboardOnTapOutside from '
          'core/utils/keyboard_dismissal.dart:\n${offenders.join('\n')}',
    );
  });
}
