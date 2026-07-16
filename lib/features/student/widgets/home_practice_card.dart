import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
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
    final assignmentAsync = ref.watch(homeAssignmentProvider);
    final statsAsync = ref.watch(homePracticeStatsProvider);

    return statsAsync.when(
      loading: () => const LoadingState(lines: 1),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final assignment = assignmentAsync.asData?.value;

        return HomePracticeCardBody(
          assignmentDone: assignment?.repetitionsDone,
          assignmentRequired: assignment?.repetitionsRequired,
          assignmentComplete: assignment?.isComplete ?? false,
          todayRepetitions: stats.todayRepetitions,
          streakDays: stats.streakDays,
          totalRepetitions: stats.totalRepetitions,
          onLog: () => context.push(AppRoutes.homePractice),
        );
      },
    );
  }
}

/// Presentational body of [HomePracticeCard]: gold carries the assignment's
/// achievement (counter and bar); the log action stays green.
class HomePracticeCardBody extends StatelessWidget {
  final int? assignmentDone;
  final int? assignmentRequired;
  final bool assignmentComplete;
  final int todayRepetitions;
  final int streakDays;
  final int totalRepetitions;
  final VoidCallback? onLog;

  const HomePracticeCardBody({
    super.key,
    this.assignmentDone,
    this.assignmentRequired,
    this.assignmentComplete = false,
    required this.todayRepetitions,
    required this.streakDays,
    required this.totalRepetitions,
    this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final hasAssignment = assignmentDone != null && assignmentRequired != null;

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onLog,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
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
                  if (hasAssignment)
                    Text(
                      // Capped at the target so an over-practising student sees
                      // '10 / 10', matching the bar, not an off '12 / 10'.
                      '${assignmentDone!.clamp(0, assignmentRequired!)}'
                      ' / $assignmentRequired',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: assignmentComplete ? tokens.green : tokens.gold,
                      ),
                    ),
                ],
              ),
              if (hasAssignment) ...[
                const SizedBox(height: 12),
                ProgressBar(
                  progress: assignmentDone! / assignmentRequired!,
                  height: 8,
                  progressColor: tokens.gold,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'اليوم $todayRepetitions · متتالية $streakDays يوماً'
                ' · الإجمالي $totalRepetitions',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onLog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('سجّل تكراراً'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
