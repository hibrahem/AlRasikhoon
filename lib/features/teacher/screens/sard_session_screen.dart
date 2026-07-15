import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
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
  int _errorCount = 0;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

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
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: tokens.maroon.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.record_voice_over,
                                    color: tokens.maroon,
                                  ),
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
                                borderRadius: BorderRadius.circular(8),
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
                                errorCount: _errorCount,
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
        error: (e, _) => ErrorState(message: 'تعذر تحميل السرد: $e'),
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
