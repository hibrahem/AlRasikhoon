// Renders the app-icon masters from the الراسخون lettermark painter.
// Not a test — a headless renderer that runs on the test harness:
//
//   flutter test tools/render_app_icon.dart
//
// Writes:
//   assets/branding/app_icon.png            1024×1024, hero-gradient bg
//   assets/branding/app_icon_foreground.png 1024×1024, transparent bg,
//                                           word inside the adaptive-icon
//                                           safe zone (central ~66%)
//
// Then regenerate the platform icons with:
//   dart run flutter_launcher_icons

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/core/theme/app_tokens.dart';
import 'package:al_rasikhoon/shared/widgets/splash/rooted_lettermark.dart';

Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  required String path,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 512, height: 512, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0); // 1024×1024
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  const tokens = AppTokens.light;

  testWidgets('render launcher icon masters', (tester) async {
    // Full icon: the finished lettermark on the hero gradient.
    await _render(
      tester,
      path: 'assets/branding/app_icon.png',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.heroTop, tokens.heroBottom],
          ),
        ),
        child: Center(
          child: RootedLettermark(
            progress: 1,
            width: 452,
            ink: tokens.onHero,
            earth: tokens.gold,
          ),
        ),
      ),
    );

    // Adaptive foreground: transparent, word within the central safe zone.
    await _render(
      tester,
      path: 'assets/branding/app_icon_foreground.png',
      child: Center(
        child: RootedLettermark(
          progress: 1,
          width: 300,
          ink: tokens.onHero,
          earth: tokens.gold,
        ),
      ),
    );
  });
}
