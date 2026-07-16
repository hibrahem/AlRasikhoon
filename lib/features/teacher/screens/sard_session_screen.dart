import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/assessment/assessment_evaluation.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/assessment_error_counters.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../../../shared/widgets/session_timer.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/teacher_provider.dart';

class SardSessionScreen extends ConsumerStatefulWidget {
  final String studentId;

  const SardSessionScreen({super.key, required this.studentId});

  @override
  ConsumerState<SardSessionScreen> createState() => _SardSessionScreenState();
}

class _SardSessionScreenState extends ConsumerState<SardSessionScreen> {
  // A سرد is judged face by face (وجه): the curriculum sheet allows each face
  // 5 تنبيهات / 2 تلقينات / 1 تشكيل / 8 تجويد, and ONE face past its allowance
  // fails the whole سرد. The teacher steps through the faces as the student
  // recites; each face keeps its own tally.
  final List<RecitationErrorTally> _faces = [RecitationErrorTally.empty];
  int _currentFace = 0;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  bool get _passesSoFar => SardEvaluation(_faces).passed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // سرد is conducted by the TEACHER (al_rasikhoon-801). The student resolves
    // through the teacher-scoped studentProvider, the same lookup the rest of
    // the teacher's session flow uses.
    //
    // WHAT is being recited comes from the curriculum session the student
    // stands on: its verbatim label and its tier. A juz-tier سرد covers a whole
    // juz and a cumulative one the whole level, so neither can be called "the
    // hizb".
    final sessionAsync = ref.watch(
      studentCurrentSessionProvider(widget.studentId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('السرد'),
        actions: [
          SessionTimer(key: ValueKey(_startedAt), startedAt: _startedAt),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showExitConfirmation();
          },
        ),
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null || !session.isSard) {
            return const Center(
              child: Text('لا توجد بيانات للسرد في هذه الحلقة'),
            );
          }

          // The info card, the error counter and the action are taller than the
          // viewport the teacher shell leaves on a phone, so the content scrolls.
          // SliverFillRemaining keeps the Spacer honest: when there IS room, it
          // still pushes "إنهاء السرد" to the bottom.
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      // Info card. No manuscript token maps directly to the
                      // old "info" blue, so — matching the same سرد card on
                      // the student dashboard (student_dashboard_screen.dart)
                      // — this uses tokens.maroon, the palette's
                      // rubrication/emphasis hue, as its own distinct accent.
                      AppCard(
                        margin: const EdgeInsets.all(16),
                        backgroundColor: tokens.maroon.withValues(alpha: 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconMedallion(
                                  icon: Icons.record_voice_over,
                                  accent: tokens.maroon,
                                  size: 48,
                                  iconSize: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // The curriculum's own words for this سرد.
                                      Text(
                                        session.titleAr,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      // And what it covers: this hizb, this juz, or the
                                      // level so far.
                                      Text(
                                        session.scopeAr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: tokens.sepia),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tokens.card,
                                // 12 is the inner inset-panel radius (the
                                // card itself carries radiusCard).
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // Same tokens.maroon as the card's own icon
                              // above — this instruction is still part of
                              // the same سرد identity, not a separate accent.
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: tokens.maroon,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      session.assessmentInstructionAr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.maroon),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Which face is being recited, and the running verdict.
                      // The teacher advances face by face; a new face starts
                      // with a clean tally.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _FaceNavigator(
                          currentFace: _currentFace,
                          faceCount: _faces.length,
                          passesSoFar: _passesSoFar,
                          onPrevious: _currentFace > 0
                              ? () => setState(() => _currentFace--)
                              : null,
                          onNext: () => setState(() {
                            if (_currentFace == _faces.length - 1) {
                              _faces.add(RecitationErrorTally.empty);
                            }
                            _currentFace++;
                          }),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // The current face's error board: the four curriculum
                      // error types, each against its per-face allowance.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AssessmentErrorCounters(
                          tally: _faces[_currentFace],
                          limits: SardEvaluation.limits,
                          onChanged: (tally) =>
                              setState(() => _faces[_currentFace] = tally),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: AppButton(
                          text: 'إنهاء السرد',
                          onPressed: () {
                            context.push(
                              AppRoutes.sardResult.replaceFirst(
                                ':studentId',
                                widget.studentId,
                              ),
                              extra: (
                                faces: List<RecitationErrorTally>.unmodifiable(
                                  _faces,
                                ),
                                startedAt: _startedAt,
                              ),
                            );
                          },
                          isFullWidth: true,
                          size: AppButtonSize.large,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) {
          // The raw exception goes to the log, never onto the screen.
          debugPrint('studentCurrentSessionProvider failed: $e');
          return ErrorState(
            message: 'تعذر تحميل السرد',
            onRetry: () =>
                ref.invalidate(studentCurrentSessionProvider(widget.studentId)),
          );
        },
      ),
    );
  }

  void _showExitConfirmation() {
    final tokens = context.tokens;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء السرد؟'),
        content: const Text('هل تريد إلغاء السرد الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: tokens.maroon),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }
}

/// Steps through the faces of the سرد and shows the running verdict: which
/// face the student is on, and whether any face so far has already broken its
/// allowance (which decides the whole سرد).
class _FaceNavigator extends StatelessWidget {
  final int currentFace;
  final int faceCount;
  final bool passesSoFar;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  const _FaceNavigator({
    required this.currentFace,
    required this.faceCount,
    required this.passesSoFar,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final verdictColor = passesSoFar ? tokens.green : tokens.maroon;

    return Row(
      children: [
        IconButton(
          // Directional: in RTL "previous" points to the reading start.
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: onPrevious,
          color: tokens.sepia,
          tooltip: 'الوجه السابق',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'الوجه ${currentFace + 1} من $faceCount',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                passesSoFar ? 'موفق حتى الآن' : 'غير موفق',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: verdictColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: onNext,
          color: tokens.maroon,
          tooltip: currentFace == faceCount - 1 ? 'وجه جديد' : 'الوجه التالي',
        ),
      ],
    );
  }
}
