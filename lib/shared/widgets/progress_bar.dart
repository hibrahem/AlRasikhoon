import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  final Color? backgroundColor;
  final Color? progressColor;
  final double height;
  final bool showPercentage;
  final String? label;

  const ProgressBar({
    super.key,
    required this.progress,
    this.backgroundColor,
    this.progressColor,
    this.height = 8,
    this.showPercentage = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(label!, style: Theme.of(context).textTheme.bodySmall),
                if (showPercentage)
                  Text(
                    '${(clampedProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progressColor ?? AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: clampedProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor ?? AppColors.primary,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How far a student has come through their LEVEL.
///
/// The denominator is the level's real session count, read from the levels
/// catalog ([LevelModel.sessionCount]) — never `36`, and never `36 × hizbs`:
/// session counts vary per juz (68 in juz 30 of level 1, 69 in juz 29) and per
/// level (204 in level 1, 44 in level 10). The numerator is the session's
/// `order_in_level`, the only key that orders sessions across a juz boundary.
///
/// There is no "hizbs" bar: a hizb is a nullable LABEL of levels 1-2, not a
/// unit of progress, and levels 3-10 have none at all.
class LevelProgressBar extends StatelessWidget {
  /// Where the student stands within the level (1..levelSessionCount).
  final int currentOrderInLevel;

  /// The level's total sessions, from the catalog. Zero when the catalog has
  /// not resolved (or has no entry for the level): the bar then shows no
  /// progress rather than inventing a denominator.
  final int levelSessionCount;

  const LevelProgressBar({
    super.key,
    required this.currentOrderInLevel,
    required this.levelSessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final known = levelSessionCount > 0;
    // Sessions COMPLETED, which is the session before the one being worked on.
    final done = known
        ? (currentOrderInLevel - 1).clamp(0, levelSessionCount)
        : 0;
    final progress = known ? done / levelSessionCount : 0.0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الحلقات في المستوى',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              ProgressBar(progress: progress, height: 6),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          known ? '$currentOrderInLevel/$levelSessionCount' : '—',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class CircularProgress extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color? progressColor;
  final Widget? child;

  const CircularProgress({
    super.key,
    required this.progress,
    this.size = 100,
    this.strokeWidth = 8,
    this.backgroundColor,
    this.progressColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: backgroundColor ?? AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor ?? AppColors.primary,
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
