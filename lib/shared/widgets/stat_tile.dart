import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_tokens.dart';

/// A bento stat tile: tinted icon medallion, big tabular numeral, sepia
/// caption. One tile per screen may carry [accentCorner] — the single
/// expressive asymmetric corner (top-start, so it flips correctly in RTL).
///
/// [accent] follows the palette rule: gold = achievement, green = action,
/// maroon = attention.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final bool accentCorner;

  /// Optional strip rendered between the numeral and the label (e.g. the
  /// streak tile's [DayBeads]).
  final Widget? footer;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.accentCorner = false,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final radius = accentCorner
        ? const BorderRadiusDirectional.only(
            topStart: Radius.circular(AppDimens.radiusAccentCorner),
            topEnd: Radius.circular(AppDimens.radiusCard),
            bottomStart: Radius.circular(AppDimens.radiusCard),
            bottomEnd: Radius.circular(AppDimens.radiusCard),
          )
        : const BorderRadiusDirectional.all(
            Radius.circular(AppDimens.radiusCard),
          );

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: radius,
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 10),
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
          if (footer != null) ...[
            const SizedBox(height: 6),
            // The footer (e.g. a 7-bead DayBeads strip) can outgrow a narrow
            // tile; scale it down rather than overflow.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: footer!,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }
}
