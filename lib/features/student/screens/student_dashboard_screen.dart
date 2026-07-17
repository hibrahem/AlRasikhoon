import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/curriculum_progress.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/providers/curriculum_progress_provider.dart';
import '../../../shared/providers/current_student_provider.dart';
import '../../../shared/providers/stats_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/completion_forecast_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';
import '../widgets/home_practice_card.dart';
import '../widgets/student_dashboard_view.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentUser = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(studentStatsProvider);
    final meetingAsync = ref.watch(studentDashboardMeetingProvider);
    final progressAsync = ref.watch(curriculumProgressProvider);

    // No AppBar and no top SafeArea: the HeroHeader owns the top edge and
    // bleeds behind the status bar. Sign-out still lives, confirmed, in
    // الإعدادات — never next to routine navigation.
    return Scaffold(
      body: RefreshIndicator(
        // The spinner draws over the green hero, so it wears hero colors.
        color: tokens.onHero,
        backgroundColor: tokens.heroTop,
        onRefresh: () async {
          // Invalidate all providers
          ref.invalidate(currentStudentProvider);
          ref.invalidate(studentStatsProvider);
          ref.invalidate(studentDashboardMeetingProvider);
          ref.invalidate(homePracticeStatsProvider);
          ref.invalidate(curriculumProgressProvider);

          // Wait for providers to reload
          await Future.wait([
            ref.read(studentStatsProvider.future),
            ref.read(studentDashboardMeetingProvider.future),
            ref.read(homePracticeStatsProvider.future),
            ref.read(curriculumProgressProvider.future),
          ]);
        },
        child: statsAsync.when(
          loading: () => const _ScrollableState(child: LoadingState()),
          error: (e, _) {
            // The raw exception goes to the log, never onto the screen.
            debugPrint('studentStatsProvider failed: $e');
            return _ScrollableState(
              child: ErrorState(
                message: 'تعذر تحميل التقدم',
                onRetry: () => ref.invalidate(studentStatsProvider),
              ),
            );
          },
          data: (stats) {
            if (progressAsync.isLoading) {
              return const _ScrollableState(child: LoadingState());
            }
            // A progress failure must not take the whole dashboard down with
            // it — the session card and stats are independent of it. Follow
            // the provider's own philosophy and fall back to all-zero
            // progress rather than a fabricated figure.
            final progress =
                progressAsync.asData?.value ??
                const CurriculumProgress(
                  sessionsCompleted: 0,
                  totalSessions: 0,
                  juzMemorized: 0,
                );
            final practice = ref.watch(homePracticeStatsProvider).asData?.value;
            final meeting = meetingAsync.asData?.value;
            final streakDays = practice?.streakDays ?? 0;
            // The forecast needs the student document itself (position, pace,
            // cadence). Its absence must not hold the dashboard hostage — the
            // card simply doesn't render until the student has loaded.
            final student = ref.watch(currentStudentProvider).asData?.value;

            return StudentDashboardView(
              data: StudentDashboardData(
                name: currentUser?.name ?? 'الطالب',
                percent: progress.percent,
                fraction: progress.fraction,
                juzMemorized: progress.juzMemorized,
                currentLevel: stats.currentLevel,
                streakDays: streakDays,
                // No per-day practice history is available client-side, so
                // the beads render the streak itself: the last N days,
                // today first, are lit.
                weekBeads: List.generate(7, (i) => i < streakDays),
                passedSessions: stats.passedSessions,
                totalSessions: stats.totalSessions,
                unlockedLevels: stats.unlockedLevelsList,
                completedLevels: stats.completedLevelsList,
                session: _sessionInfoOf(meeting),
              ),
              practiceCard: const HomePracticeCard(),
              forecastCard: student == null
                  ? null
                  : CompletionForecastCard(
                      student: student,
                      margin: EdgeInsets.zero,
                    ),
              leading: currentUser?.role == UserRole.guardian
                  ? const _GuardianChildSwitcher()
                  : null,
            );
          },
        ),
      ),
    );
  }

  /// The student's current meeting, as the curriculum describes it. What the
  /// meeting IS comes from the `kind` of the session it starts on — a batch is
  /// all lessons, so they agree — and an assessment is named by the
  /// curriculum's own label — never `'سرد الحزب $hizb'`, which cannot name a
  /// juz- or level-tier سرد at all.
  ///
  /// The تلقين branch MUST come before isExam/isSard and the regular lesson
  /// fallthrough (see student_profile_screen.dart's identical ordering): a
  /// تلقين is neither graded nor new memorization for the student to recite
  /// alone, and falling through to the lesson card would tell him to memorize
  /// a passage the teacher has not yet read to him.
  DashboardSessionInfo? _sessionInfoOf(PacedSession? meeting) {
    if (meeting == null) return null;
    final session = meeting.first;

    if (session.isTalqeen) {
      return DashboardSessionInfo(
        kind: DashboardSessionKind.talqeen,
        title: 'تلقين',
        subtitle: 'الجزء ${session.juzNumber}',
        passage: meeting.newContentAr,
        note:
            'سيقرأ المعلّم هذا المقطع معك ويكرره معك. لا حفظ عليك ولا '
            'تسميع ولا تقييم في هذه الحلقة.',
      );
    }

    if (session.isExam) {
      return DashboardSessionInfo(
        kind: DashboardSessionKind.exam,
        title: session.titleAr,
        subtitle: 'توجه للمشرف لإجراء الاختبار',
      );
    }

    if (session.isSard) {
      return DashboardSessionInfo(
        kind: DashboardSessionKind.sard,
        title: session.titleAr,
        subtitle: session.assessmentInstructionAr,
      );
    }

    return DashboardSessionInfo(
      kind: DashboardSessionKind.lesson,
      title: 'الحلقة ${session.sessionNumber}',
      // Never an app-derived hizb — the level and juz are always consistent
      // with the data.
      subtitle: 'الجزء ${session.juzNumber}',
      passage: meeting.newContentAr,
    );
  }
}

/// Keeps loading/error bodies scrollable so RefreshIndicator still works.
class _ScrollableState extends StatelessWidget {
  final Widget child;

  const _ScrollableState({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(16),
      child: SafeArea(child: child),
    );
  }
}

/// Lets a guardian with multiple children pick which child the dashboard
/// is currently focused on. Hidden when the guardian has only one child.
class _GuardianChildSwitcher extends ConsumerWidget {
  const _GuardianChildSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(guardianChildrenProvider);

    return childrenAsync.maybeWhen(
      data: (children) {
        if (children.length < 2) return const SizedBox.shrink();

        final selected =
            ref.watch(selectedChildIdProvider) ?? children.first.student.id;

        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputDecoration(
              labelText: 'الطالب',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            items: children
                .map(
                  (child) => DropdownMenuItem<String>(
                    value: child.student.id,
                    child: Text(child.user.name),
                  ),
                )
                .toList(),
            onChanged: (studentId) {
              ref.read(selectedChildIdProvider.notifier).set(studentId);
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
