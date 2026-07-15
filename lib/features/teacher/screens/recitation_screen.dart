import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
import '../providers/teacher_provider.dart';
import '../recitation_parts.dart';

class RecitationScreen extends ConsumerStatefulWidget {
  final String studentId;
  final int part;

  const RecitationScreen({
    super.key,
    required this.studentId,
    required this.part,
  });

  @override
  ConsumerState<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends ConsumerState<RecitationScreen> {
  int _errorCount = 0;

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(
      studentCurrentMeetingProvider(widget.studentId),
    );
    // Distinct accent per memorization mode (hibrahem/AlRasikhoon#25).
    // The Arabic label (recitationPartTitleAr) is always shown alongside, so
    // the mode is never communicated by color alone.
    final modeColor = AppColors.forMemorizationPart(widget.part);

    return Scaffold(
      appBar: AppBar(
        title: Text(recitationPartTitleAr(widget.part)),
        backgroundColor: modeColor,
        foregroundColor: AppColors.textOnPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showExitConfirmation();
          },
        ),
      ),
      body: meetingAsync.when(
        data: (meeting) {
          // A تلقين is never graded, failed, or attempt-limited — it has no
          // entry point to this screen in-app (session_overview_screen.dart
          // branches on isTalqeen before ever reaching the regular-session
          // card), but a hand-edited URL could still land here directly.
          // Mirror the guard in talqeen_session_screen.dart: refuse to run
          // the grading flow unless the student is actually on a lesson.
          //
          // A meeting batches lessons and nothing else, so its FIRST session
          // decides: if that is not a lesson, the meeting is a lone تلقين,
          // سرد or اختبار and has no business here.
          if (meeting == null || !meeting.first.isLesson) {
            return const Center(child: Text('لا توجد بيانات للتسميع'));
          }

          // A content block is legitimately absent on review-only lessons —
          // absence is data, and reads as an empty range, not a crash. A
          // batched meeting's stream may cover more than one session, which
          // is exactly why these are strings the meeting already merged
          // rather than a single session's own content block.
          String content;
          switch (widget.part) {
            case 1:
              content = meeting.newContentAr;
              break;
            case 2:
              content = meeting.recentReviewAr;
              break;
            case 3:
              content = meeting.distantReviewAr;
              break;
            default:
              content = '';
          }

          final presentParts = meeting.presentParts;
          final position = presentParts.indexOf(widget.part) + 1;
          final isLastPart = meeting.partAfter(widget.part) == null;

          // The content card, the error counter and the actions are taller than
          // the viewport the teacher shell leaves on a phone, so the content
          // scrolls. SliverFillRemaining keeps the Spacer honest: when there IS
          // room, it still pushes the actions to the bottom.
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      // Content card
                      AppCard(
                        margin: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: modeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'الجزء $position من ${presentParts.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: modeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              recitationPartTitleAr(widget.part),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.menu_book, color: modeColor),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      content.isNotEmpty
                                          ? content
                                          : 'لا يوجد محتوى',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Error counter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ErrorCounter(
                          errorCount: _errorCount,
                          onAddError: () {
                            setState(() => _errorCount++);
                          },
                          onUndoError: () {
                            if (_errorCount > 0) {
                              setState(() => _errorCount--);
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (widget.part > 1)
                              Expanded(
                                child: AppButton(
                                  text: 'السابق',
                                  onPressed: () {
                                    // Save current part errors
                                    ref
                                        .read(activeSessionProvider.notifier)
                                        .setPartErrors(
                                          widget.part,
                                          _errorCount,
                                        );

                                    context.pop();
                                  },
                                  type: AppButtonType.outline,
                                ),
                              ),
                            if (widget.part > 1) const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: AppButton(
                                text: isLastPart ? 'إنهاء التسميع' : 'التالي',
                                onPressed: () {
                                  // Save current part errors
                                  ref
                                      .read(activeSessionProvider.notifier)
                                      .setPartErrors(widget.part, _errorCount);

                                  // Navigate to result or next part
                                  context.push(
                                    AppRoutes.recitationResult
                                        .replaceFirst(
                                          ':studentId',
                                          widget.studentId,
                                        )
                                        .replaceFirst(
                                          ':part',
                                          '${widget.part}',
                                        ),
                                    extra: _errorCount,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الحلقة؟'),
        content: const Text('هل تريد إلغاء الحلقة الحالية؟ سيتم فقدان التقدم.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(activeSessionProvider.notifier).endSession();
              Navigator.pop(context);
              context.go(AppRoutes.teacherStudents);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }
}
