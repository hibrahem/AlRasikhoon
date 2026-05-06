import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../../shared/widgets/level_progression_widget.dart';
import '../providers/student_provider.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(studentStatsProvider);
    final sessionAsync = ref.watch(studentDashboardSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الراسخون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all providers
          ref.invalidate(currentStudentProvider);
          ref.invalidate(studentStatsProvider);
          ref.invalidate(studentDashboardSessionProvider);
          ref.invalidate(homePracticeStatsProvider);

          // Wait for providers to reload
          await Future.wait([
            ref.read(studentStatsProvider.future),
            ref.read(studentDashboardSessionProvider.future),
            ref.read(homePracticeStatsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guardian child switcher — only shown for guardians with 2+ children
              if (currentUser?.role == UserRole.guardian)
                const _GuardianChildSwitcher(),

              // Welcome
              Text(
                'مرحباً، ${currentUser?.name ?? 'الطالب'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'تقدمك في حفظ القرآن الكريم',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Current progress card
              statsAsync.when(
                data: (stats) => _buildProgressCard(stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: 24),

              // Level progression
              statsAsync.when(
                data: (stats) => LevelProgressionWidget(
                  currentLevel: stats.currentLevel,
                  unlockedLevels: stats.unlockedLevelsList,
                  completedLevels: stats.completedLevelsList,
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 24),

              // Current session
              Text(
                'الحلقة الحالية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              sessionAsync.when(
                data: (session) => _buildCurrentSessionCard(session),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: 24),

              // Home practice card
              _buildHomePracticeCard(),

              const SizedBox(height: 24),

              // Quick stats
              Text('إحصائياتي', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => _buildQuickStats(stats),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 1:
              context.go(AppRoutes.homePractice);
              break;
            case 2:
              context.go(AppRoutes.sessionHistory);
              break;
          }
        },
        role: UserRole.student,
      ),
    );
  }

  Widget _buildHomePracticeCard() {
    final practiceStatsAsync = ref.watch(homePracticeStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'التكرار في المنزل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.homePractice),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('تسجيل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        practiceStatsAsync.when(
          data: (stats) => AppCard(
            onTap: () => context.push(AppRoutes.homePractice),
            child: Row(
              children: [
                Expanded(
                  child: _PracticeStatItem(
                    icon: Icons.today,
                    label: 'اليوم',
                    value: '${stats.todayRepetitions}',
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                Expanded(
                  child: _PracticeStatItem(
                    icon: Icons.local_fire_department,
                    label: 'متتالية',
                    value: '${stats.streakDays}',
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                Expanded(
                  child: _PracticeStatItem(
                    icon: Icons.repeat,
                    label: 'الإجمالي',
                    value: '${stats.totalRepetitions}',
                  ),
                ),
              ],
            ),
          ),
          loading: () => const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildProgressCard(StudentStats stats) {
    return AppCard(
      backgroundColor: AppColors.primary.withOpacity(0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستوى ${stats.currentLevel}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'الجزء ${stats.currentJuz} - الحزب ${stats.currentHizb}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${stats.completedLevels}/10',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LevelProgressBar(
            currentSession: stats.currentSession,
            totalSessions: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSessionCard(dynamic session) {
    final studentAsync = ref.watch(currentStudentProvider);

    return studentAsync.when(
      data: (student) {
        if (student == null) return const SizedBox();

        final isSard = student.currentSession == AppConstants.sardSessionNumber;
        final isExam = student.currentSession == AppConstants.examSessionNumber;

        if (isExam) {
          return AppCard(
            backgroundColor: AppColors.secondary.withOpacity(0.05),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختبار الحزب ${student.currentHizb}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'توجه للمشرف لإجراء الاختبار',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (isSard) {
          return AppCard(
            backgroundColor: AppColors.info.withOpacity(0.05),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.record_voice_over,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سرد الحزب ${student.currentHizb}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'راجع الحزب كاملاً استعداداً للسرد',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحلقة ${student.currentSession}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'الحزب ${student.currentHizb}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (session != null) ...[
                const SizedBox(height: 16),
                _ContentRow(
                  title: 'الحفظ الجديد',
                  content: session.currentLevelContent.rangeAr,
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildQuickStats(StudentStats stats) {
    return Row(
      children: [
        Expanded(
          child: StatCardCompact(
            label: 'الحلقات',
            value: '${stats.totalSessions}',
            icon: Icons.school,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCardCompact(
            label: 'الناجحة',
            value: '${stats.passedSessions}',
            icon: Icons.check_circle,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCardCompact(
            label: 'المستويات',
            value: '${stats.completedLevels}',
            icon: Icons.emoji_events,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String title;
  final String content;

  const _ContentRow({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
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

class _PracticeStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PracticeStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
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
