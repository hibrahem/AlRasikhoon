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
                  Text(
                    label!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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

class LevelProgressBar extends StatelessWidget {
  final int currentSession;
  final int totalSessions;
  final int completedHizbs;
  final int totalHizbs;

  const LevelProgressBar({
    super.key,
    required this.currentSession,
    required this.totalSessions,
    this.completedHizbs = 0,
    this.totalHizbs = 6,
  });

  @override
  Widget build(BuildContext context) {
    final sessionProgress = totalSessions > 0
        ? currentSession / totalSessions
        : 0.0;
    final hizbProgress = totalHizbs > 0
        ? completedHizbs / totalHizbs
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session progress
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الحلقات',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  ProgressBar(
                    progress: sessionProgress,
                    height: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$currentSession/$totalSessions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Hizb progress
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الأحزاب',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  ProgressBar(
                    progress: hizbProgress,
                    progressColor: AppColors.secondary,
                    height: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$completedHizbs/$totalHizbs',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
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
