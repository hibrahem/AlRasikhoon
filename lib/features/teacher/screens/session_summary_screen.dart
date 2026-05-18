import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/grade_display.dart';
import '../providers/teacher_provider.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final String studentId;

  const SessionSummaryScreen({super.key, required this.studentId});

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  bool _isSaving = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSession() async {
    setState(() => _isSaving = true);

    try {
      // Set notes
      ref
          .read(activeSessionProvider.notifier)
          .setNotes(_notesController.text.trim());

      // Complete session
      final record = await ref
          .read(activeSessionProvider.notifier)
          .completeSession();

      if (record != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.passed ? 'تم حفظ الحلقة - ناجح' : 'تم حفظ الحلقة - راسب',
            ),
            backgroundColor: record.passed
                ? AppColors.success
                : AppColors.warning,
          ),
        );

        // Navigate back to students list
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    final studentAsync = ref.watch(studentProvider(widget.studentId));

    if (activeSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملخص الحلقة')),
        body: const Center(child: Text('لا توجد جلسة نشطة')),
      );
    }

    final sessionGrade = GradeCalculator.calculateSessionGrade(
      newMemorizationErrors: activeSession.part1Errors,
      recentReviewErrors: activeSession.part2Errors,
      distantReviewErrors: activeSession.part3Errors,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص الحلقة'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info
            studentAsync.when(
              data: (studentWithUser) {
                if (studentWithUser == null) return const SizedBox();

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          studentWithUser.user.name.isNotEmpty
                              ? studentWithUser.user.name[0]
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentWithUser.user.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              'الحلقة ${studentWithUser.student.currentSession}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),

            // Overall grade
            Center(
              child: GradeDisplay(
                errorCount: activeSession.totalErrors,
                gradeInfo: sessionGrade,
                showStars: true,
                showPassStatus: true,
              ),
            ),
            const SizedBox(height: 24),

            // Part-by-part results
            Text(
              'تفاصيل الأجزاء',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            _PartResultCard(
              title: 'الحفظ الجديد',
              errors: activeSession.part1Errors,
            ),
            const SizedBox(height: 8),
            _PartResultCard(
              title: 'المراجعة القريبة',
              errors: activeSession.part2Errors,
            ),
            const SizedBox(height: 8),
            _PartResultCard(
              title: 'المراجعة البعيدة',
              errors: activeSession.part3Errors,
            ),

            const SizedBox(height: 24),

            // Notes
            Text(
              'ملاحظات (اختياري)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'أضف ملاحظات عن أداء الطالب...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            AppButton(
              text: 'حفظ وإنهاء الحلقة',
              onPressed: _saveSession,
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'العودة للتعديل',
              onPressed: () => context.pop(),
              type: AppButtonType.outline,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PartResultCard extends StatelessWidget {
  final String title;
  final int errors;

  const _PartResultCard({required this.title, required this.errors});

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculate(errors);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            gradeInfo.passed ? Icons.check_circle : Icons.cancel,
            color: gradeInfo.passed ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$errors أخطاء',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: gradeInfo.color,
                ),
              ),
              Text(
                gradeInfo.nameAr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: gradeInfo.color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
