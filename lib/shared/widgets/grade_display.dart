import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/grade_color_tokens.dart';
import '../../core/utils/grade_calculator.dart';

class GradeDisplay extends StatelessWidget {
  final int errorCount;
  final GradeInfo? gradeInfo;
  final bool showStars;
  final bool showPassStatus;
  final bool isCompact;

  const GradeDisplay({
    super.key,
    required this.errorCount,
    this.gradeInfo,
    this.showStars = true,
    this.showPassStatus = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = this.gradeInfo ?? GradeCalculator.calculate(errorCount);
    final tokens = context.tokens;

    if (isCompact) {
      return _buildCompact(context, gradeInfo);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.colorForGrade(gradeInfo.grade).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.colorForGrade(gradeInfo.grade),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grade name
          Text(
            gradeInfo.nameAr,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: tokens.colorForGrade(gradeInfo.grade),
            ),
          ),
          const SizedBox(height: 12),

          // Stars
          if (showStars)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    index < gradeInfo.stars ? Icons.star : Icons.star_border,
                    color: index < gradeInfo.stars
                        ? tokens.gold
                        : tokens.sepia.withValues(alpha: 0.3),
                    size: 32,
                  ),
                );
              }),
            ),

          if (showStars && showPassStatus) const SizedBox(height: 16),

          // Pass status
          if (showPassStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: gradeInfo.passed
                    ? tokens.green.withValues(alpha: 0.1)
                    : tokens.maroon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gradeInfo.passed ? Icons.check_circle : Icons.cancel,
                    color: gradeInfo.passed ? tokens.green : tokens.maroon,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gradeInfo.passed ? 'ناجح' : 'راسب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: gradeInfo.passed ? tokens.green : tokens.maroon,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Error count
          Text(
            '$errorCount أخطاء',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, GradeInfo gradeInfo) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stars
        if (showStars)
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < gradeInfo.stars ? Icons.star : Icons.star_border,
                color: index < gradeInfo.stars
                    ? tokens.gold
                    : tokens.sepia.withValues(alpha: 0.3),
                size: 16,
              );
            }),
          ),
        if (showStars) const SizedBox(width: 8),
        // Grade chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.colorForGrade(gradeInfo.grade).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.colorForGrade(gradeInfo.grade)),
          ),
          child: Text(
            gradeInfo.nameAr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.colorForGrade(gradeInfo.grade),
            ),
          ),
        ),
      ],
    );
  }
}

/// Stars-only display
class StarsDisplay extends StatelessWidget {
  final int stars;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const StarsDisplay({
    super.key,
    required this.stars,
    this.size = 20,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: index < stars
              ? (activeColor ?? tokens.gold)
              : (inactiveColor ?? tokens.sepia.withValues(alpha: 0.3)),
          size: size,
        );
      }),
    );
  }
}

/// Grade badge for lists
class GradeBadge extends StatelessWidget {
  final int errorCount;

  const GradeBadge({super.key, required this.errorCount});

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculate(errorCount);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.colorForGrade(gradeInfo.grade).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.colorForGrade(gradeInfo.grade)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gradeInfo.passed ? Icons.check : Icons.close,
            size: 14,
            color: tokens.colorForGrade(gradeInfo.grade),
          ),
          const SizedBox(width: 4),
          Text(
            gradeInfo.nameAr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.colorForGrade(gradeInfo.grade),
            ),
          ),
        ],
      ),
    );
  }
}
