import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';

void main() {
  // Uses testWidgets (not a bare `test`) because AppTheme builds its
  // TextTheme via GoogleFonts.cairoTextTheme(), which loads font assets
  // through the asset bundle and requires an initialized Flutter binding
  // (see test/unit/core/display_fonts_test.dart for the same pattern).
  testWidgets('lightTheme is light and carries light tokens', (tester) async {
    final t = AppTheme.lightTheme;
    expect(t.brightness, Brightness.light);
    expect(t.extension<AppTokens>()!.page, AppTokens.light.page);
    expect(t.scaffoldBackgroundColor, AppTokens.light.page);
  });

  testWidgets('darkTheme is genuinely dark and carries dark tokens', (
    tester,
  ) async {
    final t = AppTheme.darkTheme;
    expect(t.brightness, Brightness.dark);
    expect(t.extension<AppTokens>()!.page, AppTokens.dark.page);
    expect(t.scaffoldBackgroundColor, AppTokens.dark.page);
  });
}
