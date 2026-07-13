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
                    '${assignment.repetitionsDone} / '
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
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
