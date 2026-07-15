import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/session/session_duration.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/session_record_row.dart';
import '../providers/teacher_provider.dart';

/// The teacher's recitation history, newest first: "who did I hear?" — so each
/// row is labelled by student. A row is still a record of one past session, and
/// tapping it opens that session's detail; the student's live session overview
/// is reached from الطلاب, not from a record of a session already heard.
class TeacherHistoryScreen extends ConsumerWidget {
  const TeacherHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(teacherHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('السجل')),
      body: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teacherHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final record = entry.record;
                // Listing shows only binary pass/fail (نجح / رسب), never an
                // average of the three component grades (#24). The
                // per-component breakdown lives in the session detail view.
                // Enforced by SessionRecordRow, shared with the student's
                // history listing.
                return SessionRecordRow(
                  isTalqeen: record.isTalqeen,
                  title: entry.studentName,
                  subtitleLines: [
                    record.isTalqeen
                        ? 'تلقين'
                        : 'الحلقة ${record.sessionNumber}',
                    'المستوى ${record.levelId}',
                  ],
                  passed: record.passed,
                  date: record.date,
                  sessionDuration: record.duration == null
                      ? null
                      : SessionDuration(
                          elapsed: record.duration!,
                          target: SessionDuration.targetForPace(
                            record.paceAtTime,
                          ),
                        ),
                  onTap: () {
                    context.push(
                      AppRoutes.teacherSessionDetail.replaceFirst(
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا الحلقات التي سمعتها',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
