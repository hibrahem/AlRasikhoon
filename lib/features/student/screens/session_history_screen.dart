import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/session/student_history_entry.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_large_top_bar.dart';
import '../../../shared/widgets/session_record_row.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(studentHistoryProvider);

    return Scaffold(
      // Large-title sliver bar; the refresh indicator wraps the whole scroll
      // view so pull-to-refresh works from the loading/error states too.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studentHistoryProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const AppLargeTopBar(title: 'سجل الحلقات'),
            historyAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.history,
                      title: 'لا توجد جلسات بعد',
                      message: 'ستظهر جلساتك هنا بعد أول تسميع',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final entry = records[index];
                      // Listing shows only binary pass/fail (نجح / رسب), never
                      // an average of the three component grades (#24). The
                      // per-component breakdown lives in the session detail
                      // view. Enforced by SessionRecordRow, shared with the
                      // teacher's history listing — which also owns the rule
                      // that a تلقين shows no outcome at all.
                      return SessionRecordRow(
                        isTalqeen: entry.isTalqeen,
                        title: entry.titleAr,
                        subtitleLines: entry.subtitleLines,
                        passed: entry.passed,
                        date: entry.date,
                        sessionDuration: entry.duration,
                        // The entry's kind decides the destination: lessons and
                        // تلقين open the session detail view, a سرد / اختبار
                        // the assessment detail view (al_rasikhoon-nyp). The
                        // enum's own name is the `:kind` path segment
                        // (`sard` / `exam`).
                        onTap: entry.isNavigable
                            ? () {
                                final template = switch (entry.kind) {
                                  StudentHistoryKind.sard ||
                                  StudentHistoryKind.exam =>
                                    AppRoutes.assessmentDetail.replaceFirst(
                                      ':kind',
                                      entry.kind.name,
                                    ),
                                  _ => AppRoutes.sessionDetail,
                                };
                                context.push(
                                  template.replaceFirst(
                                    ':recordId',
                                    entry.detailRecordId!,
                                  ),
                                );
                              }
                            : null,
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
                // The raw exception goes to the log, never onto the screen.
                debugPrint('studentHistoryProvider failed: $e');
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: 'تعذر تحميل سجل الحلقات',
                    onRetry: () => ref.invalidate(studentHistoryProvider),
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
