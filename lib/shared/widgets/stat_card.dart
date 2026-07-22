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

class StatCardCompact extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  const StatCardCompact({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? tokens.green).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        // Dark mode: same rewardDim hairline as the sibling cards, since
        // shadows carry no weight on a dark surface.
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? tokens.green, size: 18),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color ?? tokens.green,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final List<StatItem> items;

  const StatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.color ?? tokens.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class StatItem {
  final String label;
  final String value;
  final Color? color;

  const StatItem({required this.label, required this.value, this.color});
}
