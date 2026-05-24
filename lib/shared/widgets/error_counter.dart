import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/grade_calculator.dart';

class ErrorCounter extends StatelessWidget {
  final int errorCount;
  final VoidCallback onAddError;
  final VoidCallback onUndoError;
  final bool showGrade;

  const ErrorCounter({
    super.key,
    required this.errorCount,
    required this.onAddError,
    required this.onUndoError,
    this.showGrade = true,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculate(errorCount);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
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
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 32),
              // Count display
              Column(
                children: [
                  Text(
                    '$errorCount',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: gradeInfo.color,
                    ),
                  ),
                  Text(
                    'أخطاء',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              // Add error button
              _CounterButton(
                icon: Icons.add,
                onPressed: onAddError,
                color: AppColors.error,
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
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                      size: 28,
                    );
                  }),
                ),
                const SizedBox(width: 16),
                // Grade name
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: gradeInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gradeInfo.color),
                  ),
                  child: Text(
                    gradeInfo.nameAr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: gradeInfo.color,
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
                  color: gradeInfo.passed ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  gradeInfo.passed ? 'ناجح' : 'راسب',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: gradeInfo.passed ? AppColors.success : AppColors.error,
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
    return Material(
      color: color.withValues(alpha: onPressed != null ? 0.1 : 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: errorCount > 0 ? onUndoError : null,
          color: AppColors.textSecondary,
        ),
        Container(
          width: 48,
          alignment: Alignment.center,
          child: Text(
            '$errorCount',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: GradeCalculator.getGradeColor(errorCount),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: onAddError,
          color: AppColors.error,
        ),
      ],
    );
  }
}
