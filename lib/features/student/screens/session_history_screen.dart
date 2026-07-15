import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/session/session_duration.dart';
import '../../../routing/app_router.dart';
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
      appBar: AppBar(title: const Text('سجل الحلقات')),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'لا توجد جلسات بعد',
              message: 'ستظهر جلساتك هنا بعد أول تسميع',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                // Listing shows only binary pass/fail (نجح / رسب), never an
                // average of the three component grades (#24). The
                // per-component breakdown lives in the session detail view.
                // Enforced by SessionRecordRow, shared with the teacher's
                // history listing — which also owns the rule that a تلقين
                // shows no outcome at all.
                return SessionRecordRow(
                  isTalqeen: record.isTalqeen,
                  title: record.isTalqeen
                      ? 'تلقين'
                      : 'الحلقة ${record.sessionNumber}',
                  // Never an app-derived hizb — `record.hizbNumber` is the
                  // denormalized structural value, which can disagree with a
                  // session's own verbatim label.
                  subtitleLines: ['المستوى ${record.levelId}'],
                  passed: record.passed,
                  date: record.date,
                  sessionDuration: SessionDuration.fromRecord(record),
                  onTap: () {
                    context.push(
                      AppRoutes.sessionDetail.replaceFirst(
                        ':recordId',
                        record.id,
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل سجل الحلقات: $e'),
      ),
    );
  }
}
