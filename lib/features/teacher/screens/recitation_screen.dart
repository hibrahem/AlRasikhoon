import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
import '../../../shared/widgets/hero_header.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/teacher_provider.dart';
import '../recitation_parts.dart';
import '../widgets/active_lesson_timer.dart';

/// The grading screen for one recitation part. Its hero wears the part's
/// ink (green / ochre / lapis — [AppTokens.forPart]) so the teacher knows
/// at a glance which part is being graded; the Arabic part title and the
/// per-part icon always accompany the ink, so the mode is never signalled
/// by color alone (hibrahemAlRasikhoon#25).
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

/// Hand-picked deep hero gradients per part — each dark enough for
/// [AppTokens.onHero] text at hero type sizes (≥ 3:1). The base part inks
/// themselves stay reserved for text/medallions on cards.
({Color top, Color bottom}) _heroColorsFor(int part, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  switch (part) {
    case 2: // ochre
      return dark
          ? (top: const Color(0xFF4A3B06), bottom: const Color(0xFF362B04))
          : (top: const Color(0xFF8A6D0C), bottom: const Color(0xFF6E5709));
    case 3: // lapis
      return dark
          ? (top: const Color(0xFF1D3055), bottom: const Color(0xFF15233F))
          : (top: const Color(0xFF31569B), bottom: const Color(0xFF274680));
    default: // green — the brand hero
      return dark
          ? (top: const Color(0xFF0F3D16), bottom: const Color(0xFF0A2C10))
          : (top: const Color(0xFF1E6923), bottom: const Color(0xFF14501B));
  }
}

class _RecitationScreenState extends ConsumerState<RecitationScreen> {
  int _errorCount = 0;

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(
      studentCurrentMeetingProvider(widget.studentId),
    );

    return Scaffold(
      body: meetingAsync.when(
        data: (meeting) {
          // A تلقين is never graded, failed, or attempt-limited — it has no
          // entry point to this screen in-app (student_profile_screen.dart
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
          // absence is data, and reads as an empty range, not a crash.
          final content = recitationPartContentAr(meeting, widget.part);

          // Reachable in-app only for present parts, but a hand-edited URL can
          // land on a part that is not in presentParts. Guard the derived
          // position and last-part flag so that never renders as "الجزء 0 من N"
          // or "إنهاء التسميع": fall back to the raw part number, and treat a
          // non-present part as not-last (partAfter also returns null for it).
          final presentParts = meeting.presentParts;
          final isPresentPart = presentParts.contains(widget.part);
          final position = isPresentPart
              ? presentParts.indexOf(widget.part) + 1
              : widget.part;
          final nextPart = meeting.partAfter(widget.part);
          final isLastPart = isPresentPart && nextPart == null;

          // The hero, the counter and the actions are taller than the
          // viewport the teacher shell leaves on a phone, so the content
          // scrolls. SliverFillRemaining keeps the Spacer honest: when there
          // IS room, it still pushes the actions to the bottom.
          return CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    _buildHero(context, presentParts, position),
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: _buildPassageCard(context, content),
                    ),

                    const Spacer(),

                    // Error counter
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
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
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        0,
                        16,
                        16,
                      ),
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
                                      .setPartErrors(widget.part, _errorCount);

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

                                // Go straight to the next evaluation screen —
                                // no intermediate per-part result screen — or
                                // to the session summary after the last part.
                                // Per-part grades are shown on the summary.
                                if (isLastPart) {
                                  context.push(
                                    AppRoutes.sessionSummary.replaceFirst(
                                      ':studentId',
                                      widget.studentId,
                                    ),
                                  );
                                } else {
                                  context.push(
                                    AppRoutes.recitation
                                        .replaceFirst(
                                          ':studentId',
                                          widget.studentId,
                                        )
                                        .replaceFirst(':part', '$nextPart'),
                                  );
                                }
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
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل الحلقة: $e'),
      ),
    );
  }

  /// The part hero: close action + live timer on the top row, then the part
  /// icon, position caption and title, then the step dots — the teacher's
  /// place in the meeting's present parts.
  Widget _buildHero(
    BuildContext context,
    List<int> presentParts,
    int position,
  ) {
    final tokens = context.tokens;
    final heroColors = _heroColorsFor(
      widget.part,
      Theme.of(context).brightness,
    );

    return HeroHeader(
      topColor: heroColors.top,
      bottomColor: heroColors.bottom,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 40),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: tokens.onHero),
                onPressed: _showExitConfirmation,
              ),
              const Spacer(),
              // The live session timer as a translucent pill on the hero —
              // its white/amber/red pace states keep their contrast on the
              // dark mode-colored field, as they did on the old colored bar.
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ActiveLessonTimer(studentId: widget.studentId),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.onHero.withValues(alpha: 0.12),
            ),
            child: Icon(
              recitationPartIcon(widget.part),
              size: 32,
              color: tokens.onHero,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'الجزء $position من ${presentParts.length}',
            style: GoogleFonts.cairo(fontSize: 13, color: tokens.onHeroMuted),
          ),
          Text(
            recitationPartTitleAr(widget.part),
            style: GoogleFonts.amiri(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: tokens.onHero,
            ),
          ),
          const SizedBox(height: 12),
          // Step dots: one per present part, the current one stretched into
          // a pill. Position within the meeting, at a glance.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < presentParts.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == position - 1 ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == position - 1
                        ? tokens.onHero
                        : tokens.onHero.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The passage to recite, front and center in the manuscript face.
  Widget _buildPassageCard(BuildContext context, String content) {
    final tokens = context.tokens;
    return AppCard(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المقطع',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(height: 6),
          Text(
            content.isNotEmpty ? content : 'لا يوجد محتوى',
            // A Qur'an range — set in Amiri, the manuscript face passages
            // carry across the design system.
            style: GoogleFonts.amiri(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tokens.ink,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    final tokens = context.tokens;
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
            style: ElevatedButton.styleFrom(backgroundColor: tokens.maroon),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }
}
