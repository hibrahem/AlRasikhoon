import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF4C8C4A);
  static const Color primaryDark = Color(0xFF003300);

  // Secondary colors
  static const Color secondary = Color(0xFFFFB300);
  static const Color secondaryLight = Color(0xFFFFE54C);
  static const Color secondaryDark = Color(0xFFC68400);

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F0F0);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFF212121);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Grade colors
  static const Color gradeRasikh = Color(0xFF1B5E20);   // 5 stars - excellent
  static const Color gradeMutqin = Color(0xFF388E3C);   // 4 stars - very good
  static const Color gradeHafiz = Color(0xFF66BB6A);    // 3 stars - good
  static const Color gradeMujtahid = Color(0xFFFFB300); // 2 stars - pass
  static const Color gradeMuhib = Color(0xFFE53935);    // 1 star - fail

  // Divider and border
  static const Color divider = Color(0xFFBDBDBD);
  static const Color border = Color(0xFFE0E0E0);

  // Shadow
  static const Color shadow = Color(0x1A000000);

  // Card backgrounds for different roles
  static const Color adminCard = Color(0xFFE8F5E9);
  static const Color supervisorCard = Color(0xFFFFF8E1);
  static const Color teacherCard = Color(0xFFE3F2FD);
  static const Color studentCard = Color(0xFFF3E5F5);

  // ---------------------------------------------------------------------------
  // Memorization-mode accent colors (hibrahem/AlRasikhoon#25)
  //
  // Each of the three session modes gets its own distinct, consistent accent so
  // the user can instantly tell which mode they're in. Used wherever a mode is
  // shown: the recitation session screen header/accents, the per-part result
  // screen, and the part tiles in the session overview.
  //
  // Palette is chosen from the color-blind-safe Okabe–Ito family (teal /
  // vermilion / purple — distinguishable under protan/deutan/tritan vision).
  // All three meet WCAG AA (>= 4.5:1) for WHITE text/icons on the accent, so
  // they are safe to use as a filled background behind `textOnPrimary`:
  //   kNewColor  teal   #00695C  -> 6.61:1
  //   kNearColor orange #C8460E  -> 4.84:1
  //   kFarColor  purple #5E35B1  -> 8.02:1
  // NOTE: color is never the only signal — the Arabic mode label always
  // accompanies the accent (see RecitationScreen / SessionOverviewScreen).
  // Specific hexes are a design call and may be adjusted by the designer.
  static const Color kNewColor = Color(0xFF00695C); // الجديد — new memorization
  static const Color kNearColor = Color(0xFFC8460E); // القريب — near review
  static const Color kFarColor = Color(0xFF5E35B1); // البعيد — far review

  /// Returns the accent color for a memorization-session part.
  ///
  /// Parts map to modes: 1 = الجديد (new), 2 = القريب (near), 3 = البعيد (far).
  /// Any other value falls back to [primary] (e.g. sard / exam / unknown).
  static Color forMemorizationPart(int part) {
    switch (part) {
      case 1:
        return kNewColor;
      case 2:
        return kNearColor;
      case 3:
        return kFarColor;
      default:
        return primary;
    }
  }
}
