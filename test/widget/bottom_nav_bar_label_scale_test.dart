import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/widgets/bottom_nav_bar.dart';

/// The bottom nav is chrome: its labels are fixed short strings sized to fit
/// one line per tab. Flutter's NavigationBar renders each label with no
/// maxLines, so once the device font size scales it up past the tab's width
/// the label wraps ("الملف / الشخصي") and spills below the themed 72px bar.
/// The bar therefore keeps its labels at their designed size regardless of
/// the device font setting — same convention as iOS tab bars.
void main() {
  /// The width [text] takes on ONE unconstrained line, using the exact
  /// resolved style and scale of its rendered paragraph — self-calibrating
  /// to whatever font the test environment serves.
  double singleLineHeight(WidgetTester tester, Finder finder, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    final painter = TextPainter(
      text: TextSpan(text: text, style: paragraph.text.style),
      textDirection: TextDirection.rtl,
      textScaler: paragraph.textScaler,
    )..layout();
    final height = painter.size.height;
    painter.dispose();
    return height;
  }

  testWidgets('tab labels stay on one line at the largest device font size', (
    tester,
  ) async {
    // Each supervisor tab gets 48px — wide enough for the longest label
    // (الملف الشخصي) at its designed size, too narrow once the device font
    // setting scales it up. (The test font renders Arabic much narrower than
    // the real Cairo face, so the viewport is proportionally narrower than
    // the real phone this was reported on; the bracket is what matters.)
    tester.view.physicalSize = const Size(192, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: AppNavBar(
              currentIndex: 0,
              onTap: (_) {},
              role: UserRole.supervisor,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // A wrapped label overflows the bar's fixed height.
    expect(tester.takeException(), isNull);

    const longestLabel = 'الملف الشخصي';
    final label = find.text(longestLabel);
    expect(label, findsOneWidget);
    expect(
      tester.getSize(label).height,
      moreOrLessEquals(
        singleLineHeight(tester, label, longestLabel),
        epsilon: 1.0,
      ),
      reason: '$longestLabel wrapped onto more than one line',
    );
  });
}
