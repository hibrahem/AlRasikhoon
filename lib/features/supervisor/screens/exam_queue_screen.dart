import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_large_top_bar.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/supervisor_provider.dart';

class ExamQueueScreen extends ConsumerWidget {
  const ExamQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final examQueueAsync = ref.watch(examQueueProvider);

    return Scaffold(
      // Large-title sliver bar; the refresh indicator wraps the whole scroll
      // view so pull-to-refresh also works from the loading/error states —
      // and from the empty queue: a supervisor waits on this screen for
      // students to become ready.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(examQueueProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const AppLargeTopBar(title: 'قائمة الاختبارات'),
            examQueueAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'لا يوجد طلاب بالانتظار',
                      message: 'جميع الاختبارات مكتملة',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final studentWithUser = students[index];
                      final student = studentWithUser.student;
                      final user = studentWithUser.user;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        onTap: () {
                          context.push(
                            AppRoutes.examSession.replaceFirst(
                              ':studentId',
                              student.id,
                            ),
                          );
                        },
                        child: Row(
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
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  // WHAT the supervisor is about to examine — the
                                  // curriculum's own label for the اختبار the student
                                  // stands on (this hizb, this juz, or the level so
                                  // far), not a hizb the assessment may not even have.
                                  Row(
                                    children: [
                                      _InfoBadge(
                                        icon: Icons.school,
                                        text: 'المستوى ${student.currentLevel}',
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _InfoBadge(
                                          icon: Icons.assignment,
                                          text:
                                              student.currentSessionLabelAr ??
                                              'الجزء ${student.currentJuz}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: tokens.gold),
                              ),
                              child: Text(
                                'اختبار',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              ),
              error: (e, _) {
                debugPrint('examQueueProvider failed: $e');
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: 'تعذر تحميل قائمة الاختبارات',
                    onRetry: () => ref.invalidate(examQueueProvider),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tokens.sepia),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
            ),
          ),
        ],
      ),
    );
  }
}
