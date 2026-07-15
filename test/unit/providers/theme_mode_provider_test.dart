// test/unit/providers/theme_mode_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/features/settings/providers/theme_mode_provider.dart';

ProviderContainer _containerWith(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _containerWith(prefs);
    expect(c.read(themeModeProvider), ThemeMode.system);
  });

  test('reads a persisted mode on init', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    final c = _containerWith(prefs);
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });

  test('setThemeMode updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _containerWith(prefs);
    c.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);
    expect(prefs.getString('theme_mode'), 'light');
  });
}
