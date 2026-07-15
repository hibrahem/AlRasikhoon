import 'package:flutter/material.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

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
    final tokens = context.tokens;
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
                      color: progressColor ?? tokens.green,
                    ),
                  ),
              ],
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? tokens.surfaceVariant,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: clampedProgress),
                duration: AppMotion.of(context, AppMotion.base),
                curve: Curves.easeOut,
                builder: (context, animatedProgress, child) {
                  return FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: animatedProgress,
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor ?? tokens.green,
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
/// session counts vary per juz (70 in juz 30 of level 1, 71 in juz 29) and per
/// level (210 in level 1, 49 in level 10). The numerator is the session's
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

/// A horizontal 5-rung indicator of the grade scale — راسخ · متقن · حافظ ·
/// مجتهد · محب — this app's "mastery ladder" motif. [fraction] (0..1) is how
/// far up the ladder to light: rungs fully below it are solid, the rung it
/// falls within is partially lit, rungs above stay unlit.
class MasteryLadder extends StatelessWidget {
  final double fraction;

  const MasteryLadder({super.key, required this.fraction});

  static const _labels = ['راسخ', 'متقن', 'حافظ', 'مجتهد', 'محب'];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rungColors = [
      tokens.gradeRasikh,
      tokens.gradeMutqin,
      tokens.gradeHafiz,
      tokens.gradeMujtahid,
      tokens.gradeMuhib,
    ];
    final clamped = fraction.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(_labels.length, (i) {
            final rungFill = (clamped * _labels.length - i).clamp(0.0, 1.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Container(color: tokens.hairline),
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: rungFill,
                          child: Container(color: rungColors[i]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(_labels.length, (i) {
            return Expanded(
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
              ),
            );
          }),
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
    final tokens = context.tokens;
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
              backgroundColor: backgroundColor ?? tokens.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor ?? tokens.green,
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
