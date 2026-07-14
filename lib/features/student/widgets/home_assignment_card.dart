import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/student_provider.dart';

/// What the teacher told the student to repeat at home, and how far they have
/// got. Renders nothing when the last session assigned no repetitions.
class HomeAssignmentCard extends ConsumerWidget {
  const HomeAssignmentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(homeAssignmentProvider);

    return assignmentAsync.when(
      data: (assignment) {
        if (assignment == null) return const SizedBox.shrink();

        final progress =
            (assignment.repetitionsDone / assignment.repetitionsRequired).clamp(
              0.0,
              1.0,
            );

        // `HomeAssignment.repetitionsDone` is a true, uncapped count — the
        // domain object must stay honest about how much the student actually
        // logged. Display is a separate decision: this card caps the shown
        // count at the target so a student who over-practises sees '10 / 10'
        // (matching the progress bar, which is already capped at 100%) rather
        // than an inconsistent '12 / 10'. Over-delivery is still visible via
        // the "اكتمل الواجب" complete-state text, just not as a raw number
        // that would read as a typo or a bug against the capped bar.
        final displayedDone = assignment.repetitionsDone.clamp(
          0,
          assignment.repetitionsRequired,
        );

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'واجب التكرار في المنزل',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$displayedDone / '
                    '${assignment.repetitionsRequired}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: assignment.isComplete
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    assignment.isComplete
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ),
              if (assignment.isComplete) ...[
                const SizedBox(height: 8),
                Text(
                  'اكتمل الواجب',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.success),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      // This is a secondary card — a provider failure here should not block
      // the rest of the home-practice screen, so it stays visually silent.
      // But the codebase has no existing convention for a non-fatal provider
      // error in a silent branch (every other `error: (_, _) =>
      // SizedBox.shrink()`/`SizedBox()` in this app — e.g.
      // home_practice_screen.dart, student_dashboard_screen.dart,
      // session_summary_screen.dart — swallows without a trace, and the
      // rest use a visible `Text('Error: $e')` instead). Rather than repeat
      // that silent swallow, leave a debug trace so the failure is at least
      // discoverable in logs.
      error: (error, stackTrace) {
        debugPrint('homeAssignmentProvider failed: $error\n$stackTrace');
        return const SizedBox.shrink();
      },
    );
  }
}
