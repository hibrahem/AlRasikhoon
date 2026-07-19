import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/connectivity_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/teacher_provider.dart';
import '../widgets/active_lesson_timer.dart';
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
    final tokens = context.tokens;
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
        final message = progressNotAdvanced
            ? 'تم حفظ النتيجة، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
                  'تالية في المنهج.'
            : (record.passed ? 'تم حفظ الحلقة - ناجح' : 'تم حفظ الحلقة - راسب');
        // Saved locally either way — but the teacher must not read an
        // unqualified "saved" as "reached the server" while offline.
        final isOnline = ref.read(isConnectedProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline ? message : '$message — ستتم المزامنة عند عودة الاتصال',
            ),
            // No manuscript token for "success"/"warning" — the primary
            // green already carries the positive/affirmative role and
            // maroon (the palette's rubrication/emphasis hue) already
            // carries error, so a failed-but-saved result reuses maroon too
            // (these three branches never render together).
            backgroundColor: progressNotAdvanced
                ? tokens.maroon
                : (record.passed ? tokens.green : tokens.maroon),
          ),
        );
        context.go(AppRoutes.teacherStudents);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: tokens.maroon,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The same exit contract as the recitation flow: this screen is the only
  /// place the session gets completed, so abandoning it discards the whole
  /// graded session — never without confirmation.
  void _showExitConfirmation() {
    final tokens = context.tokens;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحلقة؟'),
        content: const Text('هل تريد إلغاء الحلقة الحالية؟ سيتم فقدان التقدم.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(activeSessionProvider.notifier).endSession();
              Navigator.pop(dialogContext);
              context.go(AppRoutes.teacherStudents);
            },
            style: ElevatedButton.styleFrom(backgroundColor: tokens.maroon),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
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
        // A visible way out — the confirmed close the recitation flow has.
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'إلغاء الحلقة',
          onPressed: _showExitConfirmation,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passed == null)
              const LoadingState(lines: 1)
            else if (!passed)
              // Repeats the same session — recite the same new passage again.
              _PassageCard(
                studentId: widget.studentId,
                passage: active.meeting?.newContentAr ?? '',
              )
            else
              // Passed — preview the next meeting's new passage.
              ref
                  .watch(activeSessionNextMeetingProvider)
                  .when(
                    data: (next) => _PassageCard(
                      studentId: widget.studentId,
                      passage: (next != null && next.hasNewContent)
                          ? next.newContentAr
                          : '',
                    ),
                    loading: () => const LoadingState(lines: 1),
                    error: (_, _) =>
                        _PassageCard(studentId: widget.studentId, passage: ''),
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
  final String studentId;
  final String passage;

  const _PassageCard({required this.studentId, required this.passage});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasPassage = passage.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconMedallion(
                icon: Icons.record_voice_over,
                accent: tokens.green,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasPassage ? 'المقطع القادم للتلقين' : 'لا يوجد حفظ جديد',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              // The live session timer, shown as a filled status pill in the
              // content-card header exactly as on the recitation screen
              // (al_rasikhoon-8z6) — same widget, same treatment, so the
              // teacher sees elapsed time consistently across the flow.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ActiveLessonTimer(studentId: studentId),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          if (hasPassage) ...[
            Text(
              passage,
              // A Qur'an passage — set in Amiri, the manuscript face passages
              // carry across the design system, in ink (not an accent fill).
              style: GoogleFonts.amiri(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: tokens.ink,
              ),
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
