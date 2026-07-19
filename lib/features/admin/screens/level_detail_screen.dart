import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/session_model.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';

/// Read-only admin view of a single curriculum level and the predefined
/// sessions that compose it (hibrahem/AlRasikhoon#23).
///
/// "Sessions" here are the curriculum-structure sessions ([SessionModel] in
/// the `sessions` collection, filtered by `level_id`) — NOT individual
/// students' session attempts/results.
class LevelDetailScreen extends ConsumerWidget {
  final int levelNumber;

  const LevelDetailScreen({super.key, required this.levelNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelAsync = ref.watch(levelProvider(levelNumber));
    final sessionsAsync = ref.watch(levelSessionsProvider(levelNumber));

    return Scaffold(
      appBar: AppBar(
        title: levelAsync.maybeWhen(
          data: (level) => Text(level?.nameAr ?? 'المستوى $levelNumber'),
          orElse: () => Text('المستوى $levelNumber'),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) {
          debugPrint('levelSessionsProvider failed: $e');
          return ErrorState(
            message: 'تعذر تحميل الحلقات',
            onRetry: () => ref.invalidate(levelSessionsProvider(levelNumber)),
          );
        },
        data: (sessions) {
          if (sessions.isEmpty) {
            return _EmptyState(levelNumber: levelNumber);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              levelAsync.maybeWhen(
                data: (level) => level == null
                    ? const SizedBox.shrink()
                    : _LevelHeader(
                        levelNumber: levelNumber,
                        nameAr: level.nameAr,
                        juzRangeAr: level.juzRangeAr,
                        sessionCount: sessions.length,
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Text('الحلقات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...sessions.map((session) => _SessionCard(session: session)),
            ],
          );
        },
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final int levelNumber;
  final String nameAr;
  final String juzRangeAr;
  final int sessionCount;

  const _LevelHeader({
    required this.levelNumber,
    required this.nameAr,
    required this.juzRangeAr,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      margin: EdgeInsets.zero,
      backgroundColor: tokens.green.withValues(alpha: 0.05),
      child: Row(
        children: [
          // Level-number badge in the medallion shape (circular tinted
          // disc). IconMedallion itself only takes an IconData, so the
          // numeral gets the same treatment inline: Cairo bold tabular,
          // like every data numeral in the design system.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$levelNumber',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: tokens.green,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nameAr, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$juzRangeAr • $sessionCount حلقة',
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
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    // Content blocks are legitimately absent (assessments carry none) — an
    // absent block is simply not listed.
    final currentRange = session.currentLevelContent?.rangeAr ?? '';
    final recentRange = session.recentReviewContent?.rangeAr ?? '';
    final distantRange = session.distantReviewContent?.rangeAr ?? '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.titleAr,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _SessionKindChip(kind: session.kind),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // Never an app-derived hizb: `session.titleAr` above may already
            // be the assessment's own verbatim label, and level 2's
            // structural hizb is known to disagree with it for the same
            // session. The juz is always consistent with the data.
            'الجزء ${session.juzNumber}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.sepia),
          ),
          if (currentRange.isNotEmpty ||
              recentRange.isNotEmpty ||
              distantRange.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (currentRange.isNotEmpty)
              _ContentRow(label: 'الحفظ الجديد', range: currentRange),
            if (recentRange.isNotEmpty)
              _ContentRow(label: 'المراجعة القريبة', range: recentRange),
            if (distantRange.isNotEmpty)
              _ContentRow(label: 'المراجعة البعيدة', range: distantRange),
          ],
        ],
      ),
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String label;
  final String range;

  const _ContentRow({required this.label, required this.range});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.tokens.sepia),
            ),
          ),
          Expanded(
            child: Text(range, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// What a session IS — تلقين, حلقة, سرد or اختبار — as the curriculum states it
/// in the session's `kind`. Never inferred from the session number.
class _SessionKindChip extends StatelessWidget {
  final SessionKind kind;

  const _SessionKindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color color;
    switch (kind) {
      case SessionKind.sard:
        // No manuscript token for the old "info" blue. Mirrors the
        // identical سرد judgment call already made for the student's
        // current-session card (student_dashboard_screen.dart): maroon,
        // the palette's rubrication/emphasis hue, kept distinct from the
        // lesson's green and the exam's gold below.
        color = tokens.maroon;
        break;
      case SessionKind.exam:
        // Mirrors the exam card's tokens.gold on the same student
        // dashboard, not maroon — an exam/اختبار is a neutral instructional
        // notice ("go take the exam"), not a warning/danger state.
        color = tokens.gold;
        break;
      case SessionKind.talqeen:
      case SessionKind.lesson:
        // A تلقين teaches new content like a lesson does and is never
        // assessed, so it gets the same chip color — green, mirroring the
        // same student dashboard precedent.
        color = tokens.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        kind.nameAr,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int levelNumber;

  const _EmptyState({required this.levelNumber});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.menu_book_outlined,
      title: 'لا توجد حلقات لهذا المستوى',
      message: 'لم تتم إضافة أي حلقات للمستوى $levelNumber بعد.',
    );
  }
}
