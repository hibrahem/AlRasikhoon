import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_provider.dart';
import '../widgets/active_lesson_timer.dart';
import '../widgets/recitation_counts_card.dart';

/// A تلقين session: the teacher recites the new passage TO the student and
/// repeats it with him until he reads it correctly.
///
/// The student memorizes nothing here and recites nothing alone. There are no
/// errors to count, no grade, and no way to fail — the session always advances.
/// What the teacher records is how many times they read it through together,
/// and how many repetitions the student owes at home.
class TalqeenSessionScreen extends ConsumerStatefulWidget {
  final String studentId;

  const TalqeenSessionScreen({super.key, required this.studentId});

  @override
  ConsumerState<TalqeenSessionScreen> createState() =>
      _TalqeenSessionScreenState();
}

class _TalqeenSessionScreenState extends ConsumerState<TalqeenSessionScreen> {
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final record = await ref
          .read(activeSessionProvider.notifier)
          .completeTalqeenSession();

      final advanceOutcome = ref.read(activeSessionProvider)?.advanceOutcome;
      final progressNotAdvanced =
          advanceOutcome == StudentAdvanceOutcome.curriculumDataMissing ||
          advanceOutcome == StudentAdvanceOutcome.studentNotFound;

      if (record != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              progressNotAdvanced
                  ? 'تم حفظ التلقين، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
                        'تالية في المنهج.'
                  : 'تم حفظ التلقين',
            ),
            backgroundColor: progressNotAdvanced
                ? AppColors.error
                : AppColors.success,
          ),
        );
        context.go(AppRoutes.teacherStudents);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(
      studentCurrentMeetingProvider(widget.studentId),
    );
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تلقين'),
        automaticallyImplyLeading: false,
        actions: [ActiveLessonTimer(studentId: widget.studentId)],
      ),
      body: meetingAsync.when(
        data: (meeting) {
          if (meeting == null || !meeting.first.isTalqeen) {
            return const Center(child: Text('لا توجد بيانات للتلقين'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المقطع الجديد',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meeting.newContentAr,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الجزء ${meeting.first.juzNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'اقرأ المقطع على الطالب وردده معه حتى يقرأه قراءة صحيحة. '
                        'لا يسمّع الطالب في هذه الحلقة.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('التكرار', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                RecitationCountsCard(
                  repetitionsWithTeacher:
                      activeSession?.repetitionsWithTeacher ?? 0,
                  homeRepetitionsRequired:
                      activeSession?.homeRepetitionsRequired ?? 0,
                  onRepetitionsWithTeacherChanged: ref
                      .read(activeSessionProvider.notifier)
                      .setRepetitionsWithTeacher,
                  onHomeRepetitionsRequiredChanged: ref
                      .read(activeSessionProvider.notifier)
                      .setHomeRepetitionsRequired,
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'حفظ وإنهاء التلقين',
                  onPressed: _save,
                  isLoading: _isSaving,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
