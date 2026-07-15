import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/features/settings/providers/theme_mode_provider.dart';

Widget _harness() => Consumer(
  builder: (context, ref, _) => MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ref.watch(themeModeProvider),
    home: Builder(
      builder: (context) => Text(
        'x',
        key: const Key('probe'),
        style: TextStyle(color: Theme.of(context).colorScheme.surface),
      ),
    ),
  ),
);

void main() {
  testWidgets('themeMode provider drives brightness', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(() => _FixedMode(ThemeMode.dark)),
        ],
        child: _harness(),
      ),
    );
    final ctx = tester.element(find.byKey(const Key('probe')));
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });
}

class _FixedMode extends ThemeModeNotifier {
  _FixedMode(this._mode);
  final ThemeMode _mode;
  @override
  ThemeMode build() => _mode;
}
