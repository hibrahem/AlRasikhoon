import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// One level's standing in the student's journey through the curriculum.
enum LevelStatus { locked, unlocked, current, completed }

/// A student's standing across the curriculum's levels, rendered as a grid of
/// numbered tiles (1..totalLevels) — the level NUMBER is the label, never a
/// grade term. Each tile is styled by its [LevelStatus]:
/// completed · current · unlocked · locked.
///
/// The header's "X/total مكتمل" count and the tiles are both driven by
/// [completedLevels], so they can never disagree. A level is "current" only
/// when it equals [currentLevel]; "unlocked" when it is in [unlockedLevels] but
/// not yet completed; otherwise "locked".
///
/// This is deliberately NOT the grade-scale mastery ladder (راسخ · متقن · …):
/// a grade names how well a session was recited, which is a different axis from
/// which of the ten levels a student has reached.
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

  LevelStatus _statusOf(int level) {
    if (completedLevels.contains(level)) return LevelStatus.completed;
    if (level == currentLevel) return LevelStatus.current;
    if (unlockedLevels.contains(level)) return LevelStatus.unlocked;
    return LevelStatus.locked;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المستويات', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${completedLevels.length}/$totalLevels مكتمل',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
          itemBuilder: (context, index) =>
              _LevelTile(level: index + 1, status: _statusOf(index + 1)),
        ),
        const SizedBox(height: 12),
        const _Legend(),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final LevelStatus status;

  const _LevelTile({required this.level, required this.status});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (background, border, foreground, icon) = _style(tokens);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
          width: status == LevelStatus.current ? 2.5 : 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
          if (icon != null)
            PositionedDirectional(
              top: 4,
              start: 4,
              child: Icon(icon, size: 14, color: foreground),
            ),
        ],
      ),
    );
  }

  /// (background, border, foreground, corner icon) for this tile's status,
  /// drawn from the manuscript tokens: green = done, gold = current.
  (Color, Color, Color, IconData?) _style(AppTokens tokens) {
    switch (status) {
      case LevelStatus.completed:
        return (
          tokens.green.withValues(alpha: 0.15),
          tokens.green,
          tokens.green,
          Icons.check,
        );
      case LevelStatus.current:
        return (
          tokens.gold.withValues(alpha: 0.15),
          tokens.gold,
          tokens.gold,
          Icons.play_arrow,
        );
      case LevelStatus.unlocked:
        return (tokens.surfaceVariant, tokens.hairline, tokens.ink, null);
      case LevelStatus.locked:
        return (
          tokens.surfaceVariant,
          tokens.hairline,
          tokens.sepia.withValues(alpha: 0.5),
          Icons.lock,
        );
    }
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendItem(color: tokens.green, label: 'مكتمل', icon: Icons.check),
        _LegendItem(
          color: tokens.gold,
          label: 'الحالي',
          icon: Icons.play_arrow,
        ),
        _LegendItem(
          color: tokens.hairline,
          label: 'متاح',
          icon: Icons.lock_open,
        ),
        _LegendItem(
          color: tokens.sepia.withValues(alpha: 0.5),
          label: 'مغلق',
          icon: Icons.lock,
        ),
      ],
    );
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
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
        ),
      ],
    );
  }
}
