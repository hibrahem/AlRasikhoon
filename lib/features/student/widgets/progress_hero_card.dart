import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/progress_bar.dart';

/// The dashboard's progress hero: a curriculum-percent ring headline, a
/// juz-memorized caption, and three supporting stats (level · streak · passed).
///
/// Every number is passed in already derived — the ring's [fraction] and
/// [percent] come from [CurriculumProgress], [juzMemorized] names the
/// milestone reached so far. This widget renders; it never computes
/// progress.
class ProgressHeroCard extends StatelessWidget {
  final int percent;
  final double fraction;
  final int juzMemorized;
  final int currentLevel;
  final int streakDays;
  final int passedSessions;

  const ProgressHeroCard({
    super.key,
    required this.percent,
    required this.fraction,
    required this.juzMemorized,
    required this.currentLevel,
    required this.streakDays,
    required this.passedSessions,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      margin: EdgeInsets.zero,
      backgroundColor: tokens.green.withValues(alpha: 0.05),
      child: Column(
        children: [
          CircularProgress(
            progress: fraction,
            size: 132,
            strokeWidth: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.green,
                  ),
                ),
                Text(
                  'من المنهج',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'حفظت $juzMemorized من 30 جزءاً',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: '$currentLevel',
                  label: 'المستوى',
                  color: tokens.green,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '$streakDays',
                  label: 'يوماً متتالية',
                  color: tokens.maroon,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '$passedSessions',
                  label: 'حلقة ناجحة',
                  color: tokens.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HeroStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        // The word shrinks to its third-of-the-card cell rather than
        // breaking mid-word at large font sizes.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
          ),
        ),
      ],
    );
  }
}
