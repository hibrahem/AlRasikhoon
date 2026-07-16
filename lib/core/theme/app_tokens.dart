// lib/core/theme/app_tokens.dart
import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color page;
  final Color card;
  final Color elevated;
  final Color surfaceVariant;
  final Color ink;
  final Color sepia;
  final Color green;
  final Color primaryContainer;
  final Color gold;
  final Color maroon;
  final Color hairline;
  final Color gradeRasikh;
  final Color gradeMutqin;
  final Color gradeHafiz;
  final Color gradeMujtahid;
  final Color gradeMuhib;

  // Hero surface (dashboard's full-bleed green header) and its ink.
  // Semantic rule: gold = achievement, green = action, maroon = attention —
  // never two of these as fills within one component.
  final Color heroTop;
  final Color heroBottom;
  final Color onHero;
  final Color onHeroMuted;

  /// Dimmed gold: ring tracks, day-bead outlines, dark-mode card hairlines.
  final Color rewardDim;

  /// Khatam lattice line color, painted only inside the hero.
  final Color latticeOnHero;

  // Recitation-part inks (hibrahem/AlRasikhoon#25, revisited): the classic
  // manuscript illumination triad, ordered as a time-distance metaphor —
  // fresh green (new memorization), warm ochre (recent review), distant
  // lapis (distant review). All three pass WCAG AA both as text on the
  // light card (4.6–7.4:1) and for white text on a solid fill (4.9–7.9:1);
  // the dark variants pass on the dark card (7.2–8.8:1). Color is never the
  // only signal: the Arabic part label and a distinct per-part icon always
  // accompany the ink (see recitation_parts.dart).
  final Color partNew;
  final Color partNear;
  final Color partFar;

  const AppTokens({
    required this.page,
    required this.card,
    required this.elevated,
    required this.surfaceVariant,
    required this.ink,
    required this.sepia,
    required this.green,
    required this.primaryContainer,
    required this.gold,
    required this.maroon,
    required this.hairline,
    required this.gradeRasikh,
    required this.gradeMutqin,
    required this.gradeHafiz,
    required this.gradeMujtahid,
    required this.gradeMuhib,
    required this.heroTop,
    required this.heroBottom,
    required this.onHero,
    required this.onHeroMuted,
    required this.rewardDim,
    required this.latticeOnHero,
    required this.partNew,
    required this.partNear,
    required this.partFar,
  });

  static const AppTokens light = AppTokens(
    page: Color(0xFFF4EEE1),
    card: Color(0xFFFBF7ED),
    elevated: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDE4D2),
    ink: Color(0xFF1C2A24),
    sepia: Color(0xFF6B5D46),
    green: Color(0xFF1B5E20),
    primaryContainer: Color(0xFFDCE9D8),
    gold: Color(0xFFC9A227),
    maroon: Color(0xFF7A3B2E),
    hairline: Color(0xFFE0D4BC),
    gradeRasikh: Color(0xFF1B5E20),
    gradeMutqin: Color(0xFF388E3C),
    gradeHafiz: Color(0xFF66BB6A),
    gradeMujtahid: Color(0xFFC9A227),
    gradeMuhib: Color(0xFF7A3B2E),
    heroTop: Color(0xFF1E6923),
    heroBottom: Color(0xFF14501B),
    onHero: Color(0xFFF6F0DF),
    onHeroMuted: Color(0xB3F6F0DF), // onHero @ 70%
    rewardDim: Color(0x33C9A227), // gold @ 20%
    latticeOnHero: Color(0x0DF6F0DF), // onHero @ 5%
    partNew: Color(0xFF1B5E20), // green — the brand action hue
    partNear: Color(0xFF8A6D0C), // deep ochre — gold family, AA-safe
    partFar: Color(0xFF31569B), // lapis — the manuscript blue
  );

  static const AppTokens dark = AppTokens(
    page: Color(0xFF14110B),
    card: Color(0xFF1E1A12),
    elevated: Color(0xFF2A2318),
    surfaceVariant: Color(0xFF2A2318),
    ink: Color(0xFFEDE4CE),
    sepia: Color(0xFFB8A681),
    green: Color(0xFF8FBF7F),
    primaryContainer: Color(0xFF25341F),
    gold: Color(0xFFE0B84A),
    maroon: Color(0xFFC98A6E),
    hairline: Color(0xFF3A3222),
    gradeRasikh: Color(0xFF8FBF7F),
    gradeMutqin: Color(0xFFA6CF98),
    gradeHafiz: Color(0xFFBFE0B0),
    gradeMujtahid: Color(0xFFE0B84A),
    gradeMuhib: Color(0xFFC98A6E),
    heroTop: Color(0xFF0F3D16),
    heroBottom: Color(0xFF0A2C10),
    onHero: Color(0xFFEDE6D4),
    onHeroMuted: Color(0xB3EDE6D4), // onHero @ 70%
    rewardDim: Color(0x33E0B84A), // gold @ 20%
    latticeOnHero: Color(0x14E0B84A), // gold @ 8%
    partNew: Color(0xFF8FBF7F),
    partNear: Color(0xFFD9B453),
    partFar: Color(0xFF8FA8D9),
  );

  @override
  AppTokens copyWith({
    Color? page,
    Color? card,
    Color? elevated,
    Color? surfaceVariant,
    Color? ink,
    Color? sepia,
    Color? green,
    Color? primaryContainer,
    Color? gold,
    Color? maroon,
    Color? hairline,
    Color? gradeRasikh,
    Color? gradeMutqin,
    Color? gradeHafiz,
    Color? gradeMujtahid,
    Color? gradeMuhib,
    Color? heroTop,
    Color? heroBottom,
    Color? onHero,
    Color? onHeroMuted,
    Color? rewardDim,
    Color? latticeOnHero,
    Color? partNew,
    Color? partNear,
    Color? partFar,
  }) {
    return AppTokens(
      page: page ?? this.page,
      card: card ?? this.card,
      elevated: elevated ?? this.elevated,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      ink: ink ?? this.ink,
      sepia: sepia ?? this.sepia,
      green: green ?? this.green,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      gold: gold ?? this.gold,
      maroon: maroon ?? this.maroon,
      hairline: hairline ?? this.hairline,
      gradeRasikh: gradeRasikh ?? this.gradeRasikh,
      gradeMutqin: gradeMutqin ?? this.gradeMutqin,
      gradeHafiz: gradeHafiz ?? this.gradeHafiz,
      gradeMujtahid: gradeMujtahid ?? this.gradeMujtahid,
      gradeMuhib: gradeMuhib ?? this.gradeMuhib,
      heroTop: heroTop ?? this.heroTop,
      heroBottom: heroBottom ?? this.heroBottom,
      onHero: onHero ?? this.onHero,
      onHeroMuted: onHeroMuted ?? this.onHeroMuted,
      rewardDim: rewardDim ?? this.rewardDim,
      latticeOnHero: latticeOnHero ?? this.latticeOnHero,
      partNew: partNew ?? this.partNew,
      partNear: partNear ?? this.partNear,
      partFar: partFar ?? this.partFar,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      sepia: Color.lerp(sepia, other.sepia, t)!,
      green: Color.lerp(green, other.green, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      gold: Color.lerp(gold, other.gold, t)!,
      maroon: Color.lerp(maroon, other.maroon, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      gradeRasikh: Color.lerp(gradeRasikh, other.gradeRasikh, t)!,
      gradeMutqin: Color.lerp(gradeMutqin, other.gradeMutqin, t)!,
      gradeHafiz: Color.lerp(gradeHafiz, other.gradeHafiz, t)!,
      gradeMujtahid: Color.lerp(gradeMujtahid, other.gradeMujtahid, t)!,
      gradeMuhib: Color.lerp(gradeMuhib, other.gradeMuhib, t)!,
      heroTop: Color.lerp(heroTop, other.heroTop, t)!,
      heroBottom: Color.lerp(heroBottom, other.heroBottom, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      onHeroMuted: Color.lerp(onHeroMuted, other.onHeroMuted, t)!,
      rewardDim: Color.lerp(rewardDim, other.rewardDim, t)!,
      latticeOnHero: Color.lerp(latticeOnHero, other.latticeOnHero, t)!,
      partNew: Color.lerp(partNew, other.partNew, t)!,
      partNear: Color.lerp(partNear, other.partNear, t)!,
      partFar: Color.lerp(partFar, other.partFar, t)!,
    );
  }
}

extension AppTokensParts on AppTokens {
  /// The ink for a recitation part: 1 = الحفظ الجديد, 2 = المراجعة القريبة,
  /// 3 = المراجعة البعيدة. Any other value falls back to [green]
  /// (سرد / اختبار / unknown), matching the old forMemorizationPart contract.
  Color forPart(int part) {
    switch (part) {
      case 1:
        return partNew;
      case 2:
        return partNear;
      case 3:
        return partFar;
      default:
        return green;
    }
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
