import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/curriculum_repository.dart';
import 'progress_bar.dart';

/// A student's progress through their level, fed from the levels CATALOG.
///
/// The denominator (`level.sessionCount`) is data — 210 sessions in level 1, 49
/// in level 10 — so it is read, never computed. While the catalog is loading, or
/// if it holds no entry for the level, the bar reports no progress instead of
/// falling back to a made-up denominator.
///
/// Rendered as a 5-rung "mastery ladder" (راسخ · متقن · حافظ · مجتهد · محب):
/// the fixed 1..10 level scale is split into 5 two-level bands, one per rung.
/// Bands fully below the student's level are lit solid; the band containing
/// the current level is lit in proportion to how far through it the student
/// is (including their in-level session progress); bands ahead stay unlit.
///
/// There is no "hizbs" bar: a hizb is a nullable LABEL of levels 1-2, not a
/// unit of progress, and levels 3-10 have none at all.
class StudentLevelProgress extends ConsumerWidget {
  /// The student's memorization level (1..10).
  final int level;

  /// Where the student stands within the level (1..levelSessionCount).
  final int orderInLevel;

  const StudentLevelProgress({
    super.key,
    required this.level,
    required this.orderInLevel,
  });

  /// The curriculum's fixed level scale, matched to the 5 grade rungs two
  /// levels at a time.
  static const int _totalLevels = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelModel = ref.watch(levelProvider(level)).value;
    final sessionCount = levelModel?.sessionCount ?? 0;
    final known = sessionCount > 0;

    final clampedLevel = level.clamp(1, _totalLevels);
    final sessionFraction = known
        ? ((orderInLevel - 1).clamp(0, sessionCount) / sessionCount)
        : 0.0;
    final overallFraction =
        ((clampedLevel - 1) + sessionFraction) / _totalLevels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الحلقات في المستوى',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              known ? '$orderInLevel/$sessionCount' : '—',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MasteryLadder(fraction: overallFraction),
      ],
    );
  }
}
