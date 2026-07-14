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
class StudentLevelProgress extends ConsumerWidget {
  final int level;
  final int orderInLevel;

  const StudentLevelProgress({
    super.key,
    required this.level,
    required this.orderInLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelModel = ref.watch(levelProvider(level)).value;

    return LevelProgressBar(
      currentOrderInLevel: orderInLevel,
      levelSessionCount: levelModel?.sessionCount ?? 0,
    );
  }
}
