import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/hero_header.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../providers/supervisor_provider.dart';

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState
    extends ConsumerState<SupervisorDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final statsAsync = ref.watch(supervisorStatsProvider);

    // No SafeArea: the hero owns the top edge and bleeds behind the status
    // bar. Sign-out still lives, confirmed, in الإعدادات.
    return Scaffold(
      body: RefreshIndicator(
        color: tokens.onHero,
        backgroundColor: tokens.heroTop,
        onRefresh: () async {
          ref.invalidate(supervisorStatsProvider);
          ref.invalidate(examQueueProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(tokens),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats
                      statsAsync.when(
                        data: (stats) => _buildStats(stats),
                        loading: () => const LoadingState(lines: 2),
                        error: (e, _) =>
                            ErrorState(message: 'تعذر تحميل الإحصائيات: $e'),
                      ),

                      const SizedBox(height: 24),

                      // Quick action - Exam queue
                      Text(
                        'الإجراءات السريعة',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      AppListTile(
                        title: 'قائمة الاختبارات',
                        subtitle: 'الطلاب الجاهزون للاختبار',
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.gold.withValues(alpha: 0.1),
                          ),
                          child: Icon(Icons.quiz, color: tokens.gold),
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => context.go(AppRoutes.examQueue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calm hero: greeting + avatar + role line. No ring, no beads — the
  /// supervisor's day is examinations, not celebration.
  Widget _buildHero(AppTokens tokens) {
    final currentUser = ref.watch(currentUserProvider);
    return HeroHeader(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السلام عليكم',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: tokens.onHeroMuted,
                  ),
                ),
                Text(
                  currentUser?.name ?? 'المشرف',
                  style: GoogleFonts.amiri(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: tokens.onHero,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إدارة اختبارات الطلاب',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: tokens.onHeroMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.gold.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: Text(
              (currentUser?.name ?? '؟').characters.first,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: tokens.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(SupervisorStats stats) {
    final tokens = context.tokens;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'اختبارات معلقة',
          value: '${stats.pendingExams}',
          icon: Icons.pending_actions,
          // AppColors.warning has no direct AppTokens equivalent. Pending
          // exams are the screen's own "اختبار" quick-action below (which
          // already uses tokens.gold), so gold keeps this card visually tied
          // to that same exam-attention identity — distinct from the
          // pass/fail cards below, which use green/maroon.
          iconColor: tokens.gold,
          onTap: () => context.go(AppRoutes.examQueue),
        ),
        StatCard(
          title: 'اختبارات اليوم',
          value: '${stats.completedToday}',
          icon: Icons.today,
          // AppColors.info has no direct AppTokens equivalent either. This
          // is a neutral daily tally (passed + failed combined), not a
          // warning or an outcome, so it reuses tokens.green — the
          // palette's least alarming accent — rather than the gold/maroon
          // used by the "needs attention" and "failed" cards.
          iconColor: tokens.green,
        ),
        StatCard(
          title: 'ناجحون اليوم',
          value: '${stats.passedToday}',
          icon: Icons.check_circle,
          // No manuscript token for a distinct "success" hue — the primary
          // green already carries the positive/affirmative role, so it is
          // reused here.
          iconColor: tokens.green,
        ),
        StatCard(
          title: 'راسبون اليوم',
          value: '${stats.failedToday}',
          icon: Icons.cancel,
          iconColor: tokens.maroon,
        ),
      ],
    );
  }
}
