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
import '../recitation_parts.dart';
import '../widgets/active_lesson_timer.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final String studentId;

  const SessionSummaryScreen({super.key, required this.studentId});

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    final studentAsync = ref.watch(studentProvider(widget.studentId));
    // Per-part + overall grades are level-based (hibrahem/AlRasikhoon#22). The
    // session-level overall grade is the worst component grade and fails on ANY
    // محب (#24) — no averaging. Grades are only computed once the student value
    // resolves — never from a default level=1 while loading, which would flash
    // a harsher grade (#36).
    final int? level = studentAsync.value?.student.currentLevel;

    if (activeSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملخص الحلقة')),
        body: const Center(child: Text('لا توجد جلسة نشطة')),
      );
    }

    final sessionGrade = level != null
        ? GradeCalculator.calculateSessionGrade(
            level: level,
            newMemorizationErrors: activeSession.part1Errors,
            recentReviewErrors: activeSession.part2Errors,
            distantReviewErrors: activeSession.part3Errors,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص الحلقة'),
        automaticallyImplyLeading: false,
        actions: [ActiveLessonTimer(studentId: widget.studentId)],
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
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
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

            // Overall grade + part-by-part results — withheld until the real
            // level resolves so no grade is computed at a default level=1 (#36).
            studentAsync.when(
              data: (_) {
                // level/sessionGrade are guaranteed non-null in the data state.
                final resolvedLevel = level!;
                final presentParts =
                    activeSession.meeting?.presentParts ?? const [1, 2, 3];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    for (final p in presentParts) ...[
                      _PartResultCard(
                        title: recitationPartTitleAr(p),
                        errors: recitationPartErrors(activeSession, p),
                        level: resolvedLevel,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('تعذّر تحميل النتيجة'),
                ),
              ),
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
              text: 'التالي: تلقين المقطع القادم',
              onPressed: () {
                // Notes and counts persist in the active-session provider, so
                // the talqeen step that follows can complete the session with
                // them. This screen no longer ends the session.
                ref
                    .read(activeSessionProvider.notifier)
                    .setNotes(_notesController.text.trim());
                context.push(
                  AppRoutes.nextContentTalqeen.replaceFirst(
                    ':studentId',
                    widget.studentId,
                  ),
                );
              },
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
  final int level;

  const _PartResultCard({
    required this.title,
    required this.errors,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculateForLevel(level, errors);

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
