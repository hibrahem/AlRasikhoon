import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/grade_color_tokens.dart';
import '../../core/utils/grade_calculator.dart';

class ErrorCounter extends StatelessWidget {
  final int errorCount;
  final VoidCallback onAddError;
  final VoidCallback onUndoError;
  final bool showGrade;

  /// The student's level. When known, the LIVE grade uses the same
  /// level-aware thresholds ([GradeCalculator.calculateForLevel]) as the
  /// summary/result screens — a level-9 student at 4 errors must not be
  /// shown راسب mid-recitation and ناجح afterwards. Null falls back to the
  /// level-agnostic mapping.
  final int? level;

  const ErrorCounter({
    super.key,
    required this.errorCount,
    required this.onAddError,
    required this.onUndoError,
    this.showGrade = true,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = level != null
        ? GradeCalculator.calculateForLevel(level!, errorCount)
        : GradeCalculator.calculate(errorCount);
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCardLg),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Column(
        children: [
          // Error count display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Undo button
              _CounterButton(
                icon: Icons.remove,
                onPressed: errorCount > 0 ? onUndoError : null,
                color: tokens.sepia,
              ),
              const SizedBox(width: 32),
              // Count display. Flexed and shrink-to-fit: the display numeral
              // grows past the fixed buttons and gaps at large system font
              // sizes and was overflowing the card.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    children: [
                      Text(
                        '$errorCount',
                        style: GoogleFonts.cairo(
                          fontSize: 64,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                          color: tokens.colorForGrade(gradeInfo.grade),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'أخطاء',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: tokens.sepia),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Add error button
              _CounterButton(
                icon: Icons.add,
                onPressed: onAddError,
                color: tokens.maroon,
              ),
            ],
          ),

          if (showGrade) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Grade display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < gradeInfo.stars ? Icons.star : Icons.star_border,
                      color: index < gradeInfo.stars
                          ? tokens.gold
                          : tokens.sepia,
                      size: 28,
                    );
                  }),
                ),
                const SizedBox(width: 16),
                // Grade name. Flexed beside the fixed-size star strip, with
                // the word shrinking inside the pill rather than overflowing
                // the card at large font sizes.
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens
                          .colorForGrade(gradeInfo.grade)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: tokens.colorForGrade(gradeInfo.grade),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        gradeInfo.nameAr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.colorForGrade(gradeInfo.grade),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pass/Fail indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  gradeInfo.passed ? Icons.check_circle : Icons.cancel,
                  color: gradeInfo.passed ? tokens.green : tokens.maroon,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  gradeInfo.passed ? 'ناجح' : 'راسب',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: gradeInfo.passed ? tokens.green : tokens.maroon,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _CounterButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Circular, like the home-practice stepper — the design system's one
    // tactile-counter shape.
    return Material(
      color: color.withValues(alpha: onPressed != null ? 0.1 : 0.05),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 32,
            color: onPressed != null ? color : color.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Compact version for inline use
class ErrorCounterCompact extends StatelessWidget {
  final int errorCount;
  final VoidCallback onAddError;
  final VoidCallback onUndoError;

  const ErrorCounterCompact({
    super.key,
    required this.errorCount,
    required this.onAddError,
    required this.onUndoError,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: errorCount > 0 ? onUndoError : null,
          color: tokens.sepia,
        ),
        Container(
          width: 48,
          alignment: Alignment.center,
          child: Text(
            '$errorCount',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: tokens.colorForGrade(
                GradeCalculator.calculate(errorCount).grade,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: onAddError,
          color: tokens.maroon,
        ),
      ],
    );
  }
}
