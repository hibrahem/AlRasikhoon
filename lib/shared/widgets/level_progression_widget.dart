import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// A student's standing across the curriculum's levels, rendered as a 5-rung
/// "mastery ladder" (راسخ · متقن · حافظ · مجتهد · محب).
///
/// [totalLevels] is split into 5 equal bands, one per rung; [currentLevel]
/// drives how far up the ladder is lit — bands fully below it are solid, the
/// band it falls within is partially lit, bands ahead stay unlit.
/// [unlockedLevels] is accepted (unchanged public API) but the ladder motif
/// deliberately doesn't distinguish "unlocked" from "locked" per level — only
/// completed vs. in-progress vs. not-yet-reached, at the band granularity.
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fraction = totalLevels > 0
        ? (currentLevel / totalLevels).clamp(0.0, 1.0)
        : 0.0;

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
        _MasteryLadder(fraction: fraction),
      ],
    );
  }
}

/// A horizontal 5-rung indicator of the grade scale — راسخ · متقن · حافظ ·
/// مجتهد · محب — this app's "mastery ladder" motif. [fraction] (0..1) is how
/// far up the ladder to light: rungs fully below it are solid, the rung it
/// falls within is partially lit, rungs above stay unlit.
class _MasteryLadder extends StatelessWidget {
  final double fraction;

  const _MasteryLadder({required this.fraction});

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
