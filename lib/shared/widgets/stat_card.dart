import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_tokens.dart';

/// The bento grid the dashboards lay [StatCard]s in. Max-extent + fixed tile
/// height instead of crossAxisCount+aspectRatio: aspect-ratio tiles balloon
/// into squares on tablets, while a fixed extent keeps the tile compact at
/// any width. The extent tracks the system font size — a truly fixed 132
/// clipped the numeral off the bottom of every tile on large-font phones.
SliverGridDelegate statCardGridDelegate(BuildContext context) {
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 220,
    mainAxisExtent: 132 * textScale.clamp(1.0, 2.0),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
  );
}

/// A stat card in the bento language: circular tinted icon medallion, big
/// Cairo-bold tabular numeral, sepia caption. Warm shadow in light mode,
/// gold hairline in dark. Tappable cards double as navigation.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final accent = iconColor ?? tokens.green;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.1),
                        ),
                        child: Icon(icon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.bold,
                    color: tokens.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// StatCardCompact, StatRow and StatItem used to live here — nothing in the
// app ever instantiated them, so they were removed in the narrow-screen
// text-scale sweep (al_rasikhoon-rcn) rather than hardened.
