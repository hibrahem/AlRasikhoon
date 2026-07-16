import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';

/// The student's home repetition, as one card. When the last session assigned
/// repetitions, the card shows that assignment's progress with a today/streak
/// caption; otherwise it shows the today/streak/total counters alone. This
/// replaces the two near-identical cards the dashboard used to stack.
class HomePracticeCard extends ConsumerWidget {
  const HomePracticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final assignmentAsync = ref.watch(homeAssignmentProvider);
    final statsAsync = ref.watch(homePracticeStatsProvider);

    return statsAsync.when(
      loading: () => const LoadingState(lines: 1),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final assignment = assignmentAsync.asData?.value;

        return AppCard(
          margin: EdgeInsets.zero,
          onTap: () => context.push(AppRoutes.homePractice),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'التكرار في المنزل',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (assignment != null)
                    Text(
                      // Capped at the target so an over-practising student sees
                      // '10 / 10', matching the bar, not an off '12 / 10'.
                      '${assignment.repetitionsDone.clamp(0, assignment.repetitionsRequired)}'
                      ' / ${assignment.repetitionsRequired}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: assignment.isComplete
                            ? tokens.green
                            : tokens.gold,
                      ),
                    ),
                ],
              ),
              if (assignment != null) ...[
                const SizedBox(height: 12),
                ProgressBar(
                  progress:
                      assignment.repetitionsDone /
                      assignment.repetitionsRequired,
                  height: 8,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'اليوم ${stats.todayRepetitions} · متتالية ${stats.streakDays} يوماً'
                ' · الإجمالي ${stats.totalRepetitions}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.homePractice),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('سجّل تكراراً'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
