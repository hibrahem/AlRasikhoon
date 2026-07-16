import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/providers/curriculum_progress_provider.dart';
import '../../../shared/providers/current_student_provider.dart';
import '../../../shared/providers/stats_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/level_progression_widget.dart';
import '../providers/student_provider.dart';
import '../widgets/home_practice_card.dart';
import '../widgets/progress_hero_card.dart';

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
    final currentUser = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(studentStatsProvider);
    final meetingAsync = ref.watch(studentDashboardMeetingProvider);
    final progressAsync = ref.watch(curriculumProgressProvider);

    return Scaffold(
      appBar: AppBar(
        // Sign-out is not offered here: it lives, confirmed, in الإعدادات
        // (the shared SettingsScreen) so a destructive action never fires on a
        // single unconfirmed tap next to routine navigation.
        //
        // The wordmark inherits the shared AppBar title style
        // (GoogleFonts.amiri) so it matches the admin, teacher, and supervisor
        // dashboards — never a one-off font just for this screen.
        title: const Text('الراسخون'),
      ),
      body: RefreshIndicator(
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentUser?.role == UserRole.guardian)
                const _GuardianChildSwitcher(),

              Text(
                'مرحباً، ${currentUser?.name ?? 'الطالب'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Progress hero — the screen's headline. Needs curriculum progress, the
              // student's position (level/juz/passed), and the streak; renders only
              // when all three have resolved, else a single loading block.
              statsAsync.when(
                data: (stats) => progressAsync.when(
                  data: (progress) {
                    final practice = ref
                        .watch(homePracticeStatsProvider)
                        .asData
                        ?.value;
                    return ProgressHeroCard(
                      percent: progress.percent,
                      fraction: progress.fraction,
                      juzMemorized: progress.juzMemorized,
                      currentLevel: stats.currentLevel,
                      streakDays: practice?.streakDays ?? 0,
                      passedSessions: stats.passedSessions,
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(message: 'تعذر تحميل التقدم: $e'),
                ),
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: 'تعذر تحميل التقدم: $e'),
              ),

              const SizedBox(height: 24),

              // Current session — juz lives here, and only here.
              Text(
                'الحلقة الحالية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              meetingAsync.when(
                data: (meeting) => _buildCurrentSessionCard(meeting),
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: 'تعذر تحميل الحلقة: $e'),
              ),

              const SizedBox(height: 24),

              // Home practice — one merged card.
              const HomePracticeCard(),

              const SizedBox(height: 24),

              // Level journey — collapsed by default; the only home of completed-levels.
              statsAsync.when(
                data: (stats) => _buildJourneyExpander(stats),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),

              const SizedBox(height: 12),

              // Full stats — collapsed by default; no 'المستويات' tile (it lives in the
              // hero chip and the journey row above).
              statsAsync.when(
                data: (stats) => _buildStatsExpander(stats),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The level journey, collapsed. Its header carries the completed count; the
  /// body is the full ten-tile grid. This is the single place completed-levels
  /// is shown on the dashboard.
  Widget _buildJourneyExpander(StudentStats stats) {
    final tokens = context.tokens;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'رحلة المستويات',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: Text(
            '${stats.completedLevels}/10 مكتمل',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
          children: [
            LevelProgressionWidget(
              currentLevel: stats.currentLevel,
              unlockedLevels: stats.unlockedLevelsList,
              completedLevels: stats.completedLevelsList,
            ),
          ],
        ),
      ),
    );
  }

  /// The full stat set, collapsed. No 'المستويات' tile — that figure lives in
  /// the hero chip and the journey header.
  Widget _buildStatsExpander(StudentStats stats) {
    final tokens = context.tokens;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'إحصائياتي',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'الحلقات',
                    value: '${stats.totalSessions}',
                    color: tokens.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'الناجحة',
                    value: '${stats.passedSessions}',
                    color: tokens.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The student's current meeting, as the curriculum describes it. What the
  /// meeting IS comes from the `kind` of the session it starts on — a batch is
  /// all lessons, so they agree — and an assessment is named by the
  /// curriculum's own label — never `'سرد الحزب $hizb'`, which cannot name a
  /// juz- or level-tier سرد at all.
  Widget _buildCurrentSessionCard(PacedSession? meeting) {
    final tokens = context.tokens;
    final studentAsync = ref.watch(currentStudentProvider);

    return studentAsync.when(
      data: (student) {
        if (student == null) return const SizedBox();
        if (meeting == null) {
          return const AppCard(
            child: Center(child: Text('لا توجد بيانات للحلقة')),
          );
        }

        final session = meeting.first;

        // The تلقين branch MUST come before isExam/isSard and the regular
        // lesson fallthrough (see student_profile_screen.dart's identical
        // ordering): a تلقين is neither graded nor new memorization for the
        // student to recite alone, and falling through to the lesson card
        // would tell him to memorize a passage the teacher has not yet read
        // to him.
        if (session.isTalqeen) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.record_voice_over, color: tokens.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تلقين',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'الجزء ${session.juzNumber}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.sepia),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'المقطع الجديد',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
                const SizedBox(height: 4),
                Text(
                  meeting.newContentAr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'سيقرأ المعلّم هذا المقطع معك ويكرره معك. لا حفظ عليك ولا '
                  'تسميع ولا تقييم في هذه الحلقة.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        if (session.isExam) {
          return AppCard(
            backgroundColor: tokens.gold.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.quiz, color: tokens.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.titleAr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'توجه للمشرف لإجراء الاختبار',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (session.isSard) {
          // No manuscript token maps directly to the old "info" blue, so
          // سرد is given tokens.maroon — the palette's rubrication/emphasis
          // hue — as its own distinct accent: distinct from the lesson's
          // green, the exam's gold, and (unlike sepia) distinct from this
          // same card's own sepia-toned caption text below.
          return AppCard(
            backgroundColor: tokens.maroon.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.maroon.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.record_voice_over, color: tokens.maroon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.titleAr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        session.assessmentInstructionAr,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.menu_book, color: tokens.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحلقة ${session.sessionNumber}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          // Never an app-derived hizb — see the comment on
                          // the progress-card header above.
                          'الجزء ${session.juzNumber}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ContentRow(title: 'الحفظ الجديد', content: meeting.newContentAr),
            ],
          ),
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: 'تعذر تحميل الطالب: $e'),
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String title;
  final String content;

  const _ContentRow({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content.isNotEmpty ? content : '-',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
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
          padding: const EdgeInsets.only(bottom: 16),
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
