import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../../../shared/widgets/session_timer.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/supervisor_provider.dart';

class ExamSessionScreen extends ConsumerStatefulWidget {
  final String studentId;

  const ExamSessionScreen({super.key, required this.studentId});

  @override
  ConsumerState<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends ConsumerState<ExamSessionScreen> {
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
    final studentAsync = ref.watch(examStudentProvider(widget.studentId));
    // WHAT is being examined comes from the curriculum session the student
    // stands on — its verbatim label and its tier — never from a hizb: the
    // juz-30 اختبار covers a whole juz, and the level's اختبار covers three.
    final session = ref.watch(examSessionProvider(widget.studentId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاختبار'),
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
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }

          final student = studentWithUser.student;
          final user = studentWithUser.user;

          // The exam card, the counter and the button are taller than the
          // viewport the supervisor shell leaves on a phone, so the content
          // scrolls. SliverFillRemaining keeps the Spacer honest: when there IS
          // room, it still pushes "إنهاء الاختبار" to the bottom.
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      // Student and exam info
                      AppCard(
                        margin: const EdgeInsets.all(16),
                        backgroundColor: tokens.gold.withValues(alpha: 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: tokens.gold.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0] : '?',
                                    style: TextStyle(
                                      color: tokens.gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        'المستوى ${student.currentLevel}',
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
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Gold medallion: the exam's achievement
                                // identity, matching the leading-icon shape
                                // used across the design system.
                                IconMedallion(
                                  icon: Icons.quiz,
                                  accent: tokens.gold,
                                  size: 48,
                                  iconSize: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session?.titleAr ??
                                            'اختبار — الجزء ${student.currentJuz}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        session?.scopeAr ??
                                            'الجزء ${student.currentJuz}',
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
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tokens.card,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: tokens.gold,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    // Gold stays on the icon only — the
                                    // instruction text itself reads in sepia
                                    // for legibility.
                                    child: Text(
                                      session?.assessmentInstructionAr ??
                                          'يختبر المشرف الطالب في المقرر',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.sepia),
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
                          // Level-aware so the live grade agrees with the
                          // saved result (see ErrorCounter.level).
                          level: student.currentLevel,
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
                          text: 'إنهاء الاختبار',
                          onPressed: () {
                            context.push(
                              AppRoutes.examResult.replaceFirst(
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
                          backgroundColor: tokens.gold,
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
        // Deliberately NOT ErrorState here: ErrorState wraps its message in a
        // Column(mainAxisSize: min), which asserts a RenderFlex overflow if
        // the message is very long. examStudentProvider's real (unmocked)
        // failure is a Riverpod ProviderException whose message embeds the
        // full dependency chain and can run to thousands of characters —
        // exactly what exam_session_timer_test.dart and
        // exam_session_overflow_test.dart hit, since neither test mocks
        // Firebase. A bare Text in Center has no such column to overflow, so
        // the original bespoke widget is kept — with a short Arabic message;
        // the raw exception goes to the debug log only.
        error: (e, _) {
          debugPrint('examStudentProvider failed: $e');
          return const Center(child: Text('تعذر تحميل بيانات الطالب'));
        },
      ),
    );
  }

  void _showExitConfirmation() {
    final tokens = context.tokens;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الاختبار؟'),
        content: const Text('هل تريد إلغاء الاختبار الحالي؟'),
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
