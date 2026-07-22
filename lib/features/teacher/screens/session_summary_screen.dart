import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/grade_color_tokens.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
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
    final tokens = context.tokens;
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
        appBar: AppBar(title: const Text('ملخص التسميع')),
        body: const Center(child: Text('لا توجد جلسة نشطة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص التسميع'),
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
                        backgroundColor: tokens.green.withValues(alpha: 0.1),
                        child: Text(
                          studentWithUser.user.name.isNotEmpty
                              ? studentWithUser.user.name[0]
                              : '?',
                          style: TextStyle(
                            color: tokens.green,
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
                                  ?.copyWith(color: tokens.sepia),
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
                        part: p,
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
              loading: () => const LoadingState(lines: 1),
              error: (e, _) {
                // The raw exception goes to the log, never onto the screen.
                debugPrint('studentProvider failed: $e');
                return ErrorState(
                  message: 'تعذّر تحميل النتيجة',
                  // studentProvider is derived from the teacher's cached
                  // roster, so the source list must be invalidated too.
                  onRetry: () {
                    ref.invalidate(teacherStudentsProvider);
                    ref.invalidate(studentProvider(widget.studentId));
                  },
                );
              },
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
    final tokens = context.tokens;
    // No manuscript token for "success" — the primary green already
    // carries the positive/affirmative role, and maroon (the palette's
    // rubrication/emphasis hue) already carries error.
    final color = passed ? tokens.green : tokens.maroon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
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
            style: GoogleFonts.cairo(
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
  final int part;
  final int errors;
  final String content;
  final int level;

  const _PartResultCard({
    required this.part,
    required this.errors,
    required this.content,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final gradeInfo = GradeCalculator.calculateForLevel(level, errors);
    // Leading identity is the PART (its ink + icon, tokens.forPart); the
    // OUTCOME lives on the trailing side in the grade palette — two
    // signals, two sides, no collision. Mirrors the student's own
    // session-detail part card.
    final accent = tokens.forPart(part);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(recitationPartIcon(part), size: 16, color: accent),
              ),
              const SizedBox(width: 12),
              // Title and outcome share the leftover width in a Wrap: the
              // outcome column drops to its own line when a large system font
              // would otherwise squeeze the part title into a sliver.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      recitationPartTitleAr(part),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: accent),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$errors أخطاء',
                          // Data numeral: Cairo bold with tabular figures so
                          // error counts align across the part cards.
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontFeatures: [const FontFeature.tabularFigures()],
                            color: tokens.colorForGrade(gradeInfo.grade),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              gradeInfo.passed
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 14,
                              color: gradeInfo.passed
                                  ? tokens.green
                                  : tokens.maroon,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              gradeInfo.nameAr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: tokens.colorForGrade(
                                      gradeInfo.grade,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
                Icon(Icons.menu_book, size: 16, color: tokens.sepia),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
