import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/hero_header.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

/// The admin Management hub (branch 0 of the admin shell). A full-bleed hero
/// (wordmark + role) in the calm register — no ring, no beads, no gold
/// fills; management is action, not achievement — over a 2×2 grid of stat
/// cards that double as the navigation into each management area:
/// institutes, teachers, supervisors, students. Sign-out lives in the
/// Profile tab.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    // No SafeArea: the hero owns the top edge and bleeds behind the status
    // bar.
    return Scaffold(
      body: RefreshIndicator(
        color: tokens.onHero,
        backgroundColor: tokens.heroTop,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context, tokens),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                  child: ref
                      .watch(adminStatsProvider)
                      .when(
                        data: (stats) => _buildStats(context, stats),
                        loading: () => const LoadingState(),
                        error: (e, _) {
                          debugPrint('adminStatsProvider failed: $e');
                          return ErrorState(
                            message: 'تعذر تحميل الإحصائيات',
                            onRetry: () => ref.invalidate(adminStatsProvider),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppTokens tokens) {
    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مدير النظام',
            style: GoogleFonts.cairo(fontSize: 14, color: tokens.onHeroMuted),
          ),
          Text(
            'الراسخون',
            style: GoogleFonts.amiri(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: tokens.onHero,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'إدارة المعاهد والمعلمين والمشرفين والطلاب',
            style: GoogleFonts.cairo(fontSize: 14, color: tokens.onHeroMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, AdminStats stats) {
    final tokens = context.tokens;
    // Shared bento delegate (see statCardGridDelegate): compact fixed-height
    // tiles that reflow to more columns on wide screens and grow with the
    // system font size.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: statCardGridDelegate(context),
      children: [
        StatCard(
          title: 'المعاهد',
          value: '${stats.institutesCount}',
          icon: Icons.account_balance,
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.institutes),
        ),
        StatCard(
          title: 'المعلمون',
          value: '${stats.teachersCount}',
          icon: Icons.people,
          iconColor: tokens.maroon,
          onTap: () => context.push(AppRoutes.teachers),
        ),
        StatCard(
          title: 'المشرفون',
          value: '${stats.supervisorsCount}',
          icon: Icons.admin_panel_settings,
          iconColor: tokens.gold,
          onTap: () => context.push(AppRoutes.supervisors),
        ),
        StatCard(
          title: 'الطلاب',
          value: '${stats.studentsCount}',
          icon: Icons.school,
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.adminStudents),
        ),
      ],
    );
  }
}
