import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
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

            // Overall pass/fail + per-part results — withheld until the real
            // level resolves so no grade is computed at a default level=1 (#36).
            studentAsync.when(
              data: (_) {
                // level is guaranteed non-null in the data state.
                final resolvedLevel = level!;
                final presentParts =
                    activeSession.meeting?.presentParts ?? const [1, 2, 3];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall result — the summary shows ONLY pass/fail
                    // (ناجح / راسب), never a per-grade category. The pass rule
                    // is the domain's (سرد fails on ANY محب component, #24), so
                    // this screen asks the session, it does not re-derive it.
                    Center(
                      child: _OverallResultCard(
                        passed: activeSession.passesForLevel(resolvedLevel),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Per-part results
                    Text(
                      'تفاصيل الأجزاء',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    for (final p in presentParts) ...[
                      _PartResultCard(
                        title: recitationPartTitleAr(p),
                        errors: recitationPartErrors(activeSession, p),
                        content: recitationPartContentAr(
                          activeSession.meeting,
                          p,
                        ),
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

/// The overall session outcome — pass/fail ONLY (al_rasikhoon-nzg). The
/// per-grade category (راسخ / متقن / حافظ …) deliberately does NOT appear here;
/// the summary states whether the الحلقة is ناجحة, and the granular grade lives
/// on each part card below.
class _OverallResultCard extends StatelessWidget {
  final bool passed;

  const _OverallResultCard({required this.passed});

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            passed ? 'ناجح' : 'راسب',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One part's detailed result: its own level-based grade AND the passage the
/// student recited for it (al_rasikhoon-nzg).
class _PartResultCard extends StatelessWidget {
  final String title;
  final int errors;
  final String content;
  final int level;

  const _PartResultCard({
    required this.title,
    required this.errors,
    required this.content,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculateForLevel(level, errors);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                gradeInfo.passed ? Icons.check_circle : Icons.cancel,
                color: gradeInfo.passed ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
          // The recited passage for this part. Hidden when the stream carries
          // no content (e.g. an empty الحفظ الجديد on a review-only lesson) so
          // the card never shows a dangling label with a blank range.
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    content,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
