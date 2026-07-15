// test/unit/core/app_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';

void main() {
  test('light tokens carry the parchment palette', () {
    expect(AppTokens.light.page, const Color(0xFFF4EEE1));
    expect(AppTokens.light.ink, const Color(0xFF1C2A24));
    expect(AppTokens.light.gold, const Color(0xFFC9A227));
  });

  test('dark tokens carry the lamplight palette', () {
    expect(AppTokens.dark.page, const Color(0xFF14110B));
    expect(AppTokens.dark.ink, const Color(0xFFEDE4CE));
    expect(AppTokens.dark.gold, const Color(0xFFE0B84A));
  });

  test('lerp at t=0 returns the start tokens', () {
    final result = AppTokens.light.lerp(AppTokens.dark, 0);
    expect(result.page, AppTokens.light.page);
  });
}
