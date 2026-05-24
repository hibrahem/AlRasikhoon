import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum LevelStatus { locked, unlocked, current, completed }

class LevelProgressionWidget extends StatelessWidget {
  final int currentLevel;
  final List<int> unlockedLevels;
  final List<int> completedLevels;
  final int totalLevels;

  const LevelProgressionWidget({
    super.key,
    required this.currentLevel,
    required this.unlockedLevels,
    required this.completedLevels,
    this.totalLevels = 10,
  });

  LevelStatus _getLevelStatus(int level) {
    if (completedLevels.contains(level)) {
      return LevelStatus.completed;
    }
    if (level == currentLevel) {
      return LevelStatus.current;
    }
    if (unlockedLevels.contains(level)) {
      return LevelStatus.unlocked;
    }
    return LevelStatus.locked;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'المستويات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${completedLevels.length}/$totalLevels مكتمل',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: totalLevels,
          itemBuilder: (context, index) {
            final level = index + 1;
            final status = _getLevelStatus(level);
            return _LevelTile(level: level, status: status);
          },
        ),
        const SizedBox(height: 12),
        _buildLegend(context),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: AppColors.success,
          label: 'مكتمل',
          icon: Icons.check_circle,
        ),
        _LegendItem(
          color: AppColors.primary,
          label: 'الحالي',
          icon: Icons.play_circle_filled,
        ),
        _LegendItem(
          color: AppColors.secondary,
          label: 'متاح',
          icon: Icons.lock_open,
        ),
        _LegendItem(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          label: 'مغلق',
          icon: Icons.lock,
        ),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final LevelStatus status;

  const _LevelTile({
    required this.level,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, borderColor, textColor, icon) = _getStyleForStatus();

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: status == LevelStatus.current ? 2.5 : 1.5,
        ),
        boxShadow: status == LevelStatus.current
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (icon != null)
            Positioned(
              top: 4,
              left: 4,
              child: Icon(
                icon,
                size: 14,
                color: textColor,
              ),
            ),
        ],
      ),
    );
  }

  (Color, Color, Color, IconData?) _getStyleForStatus() {
    switch (status) {
      case LevelStatus.completed:
        return (
          AppColors.success.withValues(alpha: 0.15),
          AppColors.success,
          AppColors.success,
          Icons.check,
        );
      case LevelStatus.current:
        return (
          AppColors.primary.withValues(alpha: 0.15),
          AppColors.primary,
          AppColors.primary,
          Icons.play_arrow,
        );
      case LevelStatus.unlocked:
        return (
          AppColors.secondary.withValues(alpha: 0.1),
          AppColors.secondary,
          AppColors.secondaryDark,
          null,
        );
      case LevelStatus.locked:
        return (
          AppColors.surfaceVariant,
          AppColors.border,
          AppColors.textSecondary.withValues(alpha: 0.5),
          Icons.lock,
        );
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
