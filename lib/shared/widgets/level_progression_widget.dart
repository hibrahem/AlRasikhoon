import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import 'progress_bar.dart';

/// A student's standing across the curriculum's levels, rendered as a 5-rung
/// "mastery ladder" (راسخ · متقن · حافظ · مجتهد · محب).
///
/// [totalLevels] is split into 5 equal bands, one per rung; [completedLevels]
/// — the same source of truth the header's "X/total مكتمل" count is drawn
/// from — drives how far up the ladder is lit, so the two never disagree.
/// Bands fully below the completed count are solid; bands ahead stay unlit.
/// There is no per-level "in progress" signal available here (unlike
/// [StudentLevelProgress], which has session-level granularity), so
/// [currentLevel] does not contribute partial credit — it is treated the
/// same way a level that has just been started (no sessions done yet)
/// contributes zero to that widget's fraction.
/// [unlockedLevels] is accepted (unchanged public API) but the ladder motif
/// deliberately doesn't distinguish "unlocked" from "locked" per level — only
/// completed vs. not-yet-reached, at the band granularity.
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
        ? (completedLevels.length / totalLevels).clamp(0.0, 1.0)
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
        MasteryLadder(fraction: fraction),
      ],
    );
  }
}
