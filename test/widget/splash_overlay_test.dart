import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';
import 'package:al_rasikhoon/shared/widgets/splash/splash_overlay.dart';

Future<void> _pumpApp(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SplashOverlay(
          child: Scaffold(body: Center(child: Text('الشاشة الأولى'))),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('splash covers the first frame with the brand lockup', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byType(BrandSplashView), findsOneWidget);
    // The cream drop (same asset as the native splash) and the typed
    // Reem Kufi lockup.
    expect(
      find.image(const AssetImage('assets/brand/splash-logo-cream.png')),
      findsOneWidget,
    );
    expect(find.text('الراسخون'), findsOneWidget);
    expect(find.text('في حفظ كتاب الله'), findsOneWidget);
  });

  testWidgets('lockup text renders on a Material even above the Navigator', (
    tester,
  ) async {
    // In the app the overlay mounts from MaterialApp.builder, where no
    // Material exists yet — without its own, the wordmark would render the
    // no-Material fallback (double amber underlines). This harness has no
    // Material above SplashOverlay either, so it reproduces that tree.
    await _pumpApp(tester);

    expect(
      find.ancestor(of: find.text('الراسخون'), matching: find.byType(Material)),
      findsOneWidget,
    );
  });

  testWidgets('first animated frame is the flat native splash color', (
    tester,
  ) async {
    // The native splash (flutter_native_splash) is a flat heroTop field, no
    // logo. Frame 0 of the animated splash must be that exact flat color so
    // the OS→Flutter hand-off never jumps — the gradient eases in afterwards.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: BrandSplashView(progress: 0),
        ),
      ),
    );

    final heroTop = AppTokens.light.heroTop;
    final background = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(BrandSplashView),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>()
        .single;
    expect(background.colors, [heroTop, heroTop]);
  });

  testWidgets('splash dismisses itself and reveals the app', (tester) async {
    await _pumpApp(tester);

    // Choreography (1600ms) + hold/fade (750ms), with margin.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.byType(BrandSplashView), findsNothing);
    expect(find.text('الشاشة الأولى'), findsOneWidget);
  });

  testWidgets(
    'reduced motion skips the choreography and still reveals the app',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SplashOverlay(
                child: Scaffold(body: Center(child: Text('الشاشة الأولى'))),
              ),
            ),
          ),
        ),
      );

      // The finished mark shows immediately (no mid-animation frames), then
      // the short hold+fade runs.
      expect(find.byType(BrandSplashView), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.byType(BrandSplashView), findsNothing);
      expect(find.text('الشاشة الأولى'), findsOneWidget);
    },
  );
}
