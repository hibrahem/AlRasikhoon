import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_provider.dart';
import '../widgets/recitation_counts_card.dart';

/// The talqeen step that closes a session: before ending the الحلقة, the
/// teacher recites the passage the student will memorize next TO the student.
///
/// A PASSED session previews the NEXT meeting's new passage. A FAILED session
/// does not advance — the student repeats the same الحلقة — so it previews the
/// SAME (current) meeting's new passage. When there is no new passage to recite
/// (the next session is a سرد/اختبار, the current level has ended, or a failed
/// review-only lesson), a short note stands in. This screen is the ONLY place
/// the session is completed.
class NextContentTalqeenScreen extends ConsumerStatefulWidget {
  final String studentId;

  const NextContentTalqeenScreen({super.key, required this.studentId});

  @override
  ConsumerState<NextContentTalqeenScreen> createState() =>
      _NextContentTalqeenScreenState();
}

class _NextContentTalqeenScreenState
    extends ConsumerState<NextContentTalqeenScreen> {
  bool _isSaving = false;

  Future<void> _closeSession() async {
    setState(() => _isSaving = true);
    try {
      final record = await ref
          .read(activeSessionProvider.notifier)
          .completeSession();

      final advanceOutcome = ref.read(activeSessionProvider)?.advanceOutcome;
      final progressNotAdvanced =
          record != null &&
          record.passed &&
          (advanceOutcome == StudentAdvanceOutcome.curriculumDataMissing ||
              advanceOutcome == StudentAdvanceOutcome.studentNotFound);

      if (record != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              progressNotAdvanced
                  ? 'تم حفظ النتيجة، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
                        'تالية في المنهج.'
                  : (record.passed
                        ? 'تم حفظ الحلقة - ناجح'
                        : 'تم حفظ الحلقة - راسب'),
            ),
            backgroundColor: progressNotAdvanced
                ? AppColors.error
                : (record.passed ? AppColors.success : AppColors.warning),
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
    final active = ref.watch(activeSessionProvider);
    final studentAsync = ref.watch(studentProvider(widget.studentId));
    final level = studentAsync.value?.student.currentLevel;

    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تلقين المقطع القادم')),
        body: const Center(child: Text('لا توجد جلسة نشطة')),
      );
    }

    // A failed session repeats the SAME meeting; a passed one moves on. Until
    // the level resolves we don't know which — hold the passage back rather
    // than guess.
    final passed = level != null ? active.passesForLevel(level) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تلقين المقطع القادم'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passed == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!passed)
              // Repeats the same session — recite the same new passage again.
              _PassageCard(passage: active.meeting?.newContentAr ?? '')
            else
              // Passed — preview the next meeting's new passage.
              ref
                  .watch(activeSessionNextMeetingProvider)
                  .when(
                    data: (next) => _PassageCard(
                      passage: (next != null && next.hasNewContent)
                          ? next.newContentAr
                          : '',
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => const _PassageCard(passage: ''),
                  ),

            const SizedBox(height: 24),

            // The two counts, recorded on the talqeen step right before the
            // الحلقة is ended: how many times teacher and student recited the
            // passage together, and how many repetitions the student owes at
            // home. `completeSession` reads them straight off the active
            // session, so they persist onto this session's record.
            Text('التكرار', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            RecitationCountsCard(
              repetitionsWithTeacher: active.repetitionsWithTeacher,
              homeRepetitionsRequired: active.homeRepetitionsRequired,
              onRepetitionsWithTeacherChanged: ref
                  .read(activeSessionProvider.notifier)
                  .setRepetitionsWithTeacher,
              onHomeRepetitionsRequiredChanged: ref
                  .read(activeSessionProvider.notifier)
                  .setHomeRepetitionsRequired,
            ),

            const SizedBox(height: 32),
            AppButton(
              text: 'إنهاء الحلقة',
              onPressed: _closeSession,
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }
}

/// The passage to recite, or the no-new-content note when [passage] is empty.
class _PassageCard extends StatelessWidget {
  final String passage;

  const _PassageCard({required this.passage});

  @override
  Widget build(BuildContext context) {
    final hasPassage = passage.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.record_voice_over,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPassage ? 'المقطع القادم للتلقين' : 'لا يوجد حفظ جديد',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          if (hasPassage) ...[
            Text(
              passage,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'اقرأ المقطع على الطالب وردده معه قبل إغلاق الحلقة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else
            Text(
              'لا يوجد مقطع جديد للتلقين قبل إغلاق الحلقة.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
