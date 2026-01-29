import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/grade_calculator.dart';

class GradeDisplay extends StatelessWidget {
  final int errorCount;
  final bool showStars;
  final bool showPassStatus;
  final bool isCompact;

  const GradeDisplay({
    super.key,
    required this.errorCount,
    this.showStars = true,
    this.showPassStatus = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculate(errorCount);

    if (isCompact) {
      return _buildCompact(context, gradeInfo);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gradeInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradeInfo.color, width: 2),
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
              color: gradeInfo.color,
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
                        ? AppColors.secondary
                        : AppColors.textSecondary.withOpacity(0.3),
                    size: 32,
                  ),
                );
              }),
            ),

          if (showStars && showPassStatus) const SizedBox(height: 16),

          // Pass status
          if (showPassStatus)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: gradeInfo.passed
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gradeInfo.passed
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: gradeInfo.passed
                        ? AppColors.success
                        : AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gradeInfo.passed ? 'ناجح' : 'راسب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: gradeInfo.passed
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Error count
          Text(
            '$errorCount أخطاء',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, GradeInfo gradeInfo) {
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
                    ? AppColors.secondary
                    : AppColors.textSecondary.withOpacity(0.3),
                size: 16,
              );
            }),
          ),
        if (showStars) const SizedBox(width: 8),
        // Grade chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: gradeInfo.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gradeInfo.color),
          ),
          child: Text(
            gradeInfo.nameAr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: gradeInfo.color,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: index < stars
              ? (activeColor ?? AppColors.secondary)
              : (inactiveColor ?? AppColors.textSecondary.withOpacity(0.3)),
          size: size,
        );
      }),
    );
  }
}

/// Grade badge for lists
class GradeBadge extends StatelessWidget {
  final int errorCount;

  const GradeBadge({
    super.key,
    required this.errorCount,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculate(errorCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: gradeInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradeInfo.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gradeInfo.passed ? Icons.check : Icons.close,
            size: 14,
            color: gradeInfo.color,
          ),
          const SizedBox(width: 4),
          Text(
            gradeInfo.nameAr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: gradeInfo.color,
            ),
          ),
        ],
      ),
    );
  }
}
