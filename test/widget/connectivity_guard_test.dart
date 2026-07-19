import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/providers/connectivity_provider.dart';
import 'package:al_rasikhoon/shared/utils/connectivity_guard.dart';

void main() {
  Widget host({required bool online, required VoidCallback onAllowed}) =>
      ProviderScope(
        overrides: [isConnectedProvider.overrideWithValue(online)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () {
                  if (!ensureOnline(context, ref)) return;
                  onAllowed();
                },
                child: const Text('إرسال'),
              ),
            ),
          ),
        ),
      );

  testWidgets('an online-only action is blocked offline with a message', (
    tester,
  ) async {
    var allowed = false;
    await tester.pumpWidget(
      host(online: false, onAllowed: () => allowed = true),
    );
    await tester.tap(find.text('إرسال'));
    await tester.pump();
    expect(allowed, isFalse);
    expect(find.text('هذا الإجراء يتطلب اتصالًا بالإنترنت'), findsOneWidget);
  });

  testWidgets('the same action proceeds silently online', (tester) async {
    var allowed = false;
    await tester.pumpWidget(
      host(online: true, onAllowed: () => allowed = true),
    );
    await tester.tap(find.text('إرسال'));
    await tester.pump();
    expect(allowed, isTrue);
    expect(find.text('هذا الإجراء يتطلب اتصالًا بالإنترنت'), findsNothing);
  });
}
