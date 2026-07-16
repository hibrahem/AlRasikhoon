// lib/core/theme/app_shadows.dart
import 'package:flutter/material.dart';

/// Warm-tinted shadow recipes. Shadows on parchment must never be pure
/// black — they are inked in the palette's own sepia/green. Dark mode drops
/// shadows entirely; callers draw a 1px [AppTokens.rewardDim] hairline
/// instead (tone steps + gold hairlines carry the depth at night).
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return const [
      BoxShadow(
        color: Color(0x144A3A1E), // warm umber @ 8%
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> hero(Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return const [
      BoxShadow(
        color: Color(0x4014501B), // deep green @ 25%
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ];
  }
}
