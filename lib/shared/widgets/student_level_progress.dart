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
/// Rendered as a plain session progress bar with an `orderInLevel/sessionCount`
/// count — never the grade-scale mastery ladder (راسخ · متقن · …), which names
/// how well a session was recited, not how far through the level the student
/// is. The two are different axes and must not share one indicator.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelModel = ref.watch(levelProvider(level)).value;
    final sessionCount = levelModel?.sessionCount ?? 0;
    final known = sessionCount > 0;

    // Sessions COMPLETED is the session before the one being worked on.
    final sessionFraction = known
        ? ((orderInLevel - 1).clamp(0, sessionCount) / sessionCount)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexed so a large system font wraps the label between words
            // instead of overflowing the row against the count.
            Expanded(
              child: Text(
                'الحلقات في المستوى',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              known ? '$orderInLevel/$sessionCount' : '—',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(progress: sessionFraction, height: 8),
      ],
    );
  }
}
