import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/session/home_practice_log.dart';
import '../providers/home_assignment_status_provider.dart';
import 'app_card.dart';
import 'icon_medallion.dart';

/// The student's current home assignment as the person ABOUT TO HEAR THEM
/// needs it: before starting the session, did the student do the assigned
/// repetition at home, how many times, and on which dates — each logged
/// submission on its own dated line.
///
/// Shown on the teacher's pre-session profile and the supervisor/admin
/// progress view. Renders NOTHING when there is no assignment to report on
/// (no session record yet, or the last session assigned no home repetition) —
/// the card carries its own title, so absence leaves no dangling header. The
/// history rows tell the same story per past session; this card answers for
/// the one assignment that matters right now.
class HomePracticeStatusCard extends ConsumerWidget {
  final String studentId;

  const HomePracticeStatusCard({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(homeAssignmentStatusProvider(studentId));

    return statusAsync.when(
      data: (status) {
        if (status == null) return const SizedBox.shrink();
        return _StatusCard(status: status);
      },
      // Auxiliary card: while loading (or if the read fails) it simply is not
      // there yet — the screen's primary content must not gain a spinner or
      // an error banner for it. Pull-to-refresh re-reads it.
      loading: () => const SizedBox.shrink(),
      error: (e, _) {
        debugPrint('homeAssignmentStatusProvider failed: $e');
        return const SizedBox.shrink();
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final HomeAssignmentStatus status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

    // The same three-state coding the history rows use: green once the
    // assignment is met, gold while partially done, maroon when nothing was
    // logged — color and label together, never color alone.
    final Color accent;
    final String badgeLabel;
    if (status.isComplete) {
      accent = tokens.green;
      badgeLabel = 'مكتمل';
    } else if (status.repetitionsDone > 0) {
      accent = tokens.gold;
      badgeLabel = 'غير مكتمل';
    } else {
      accent = tokens.maroon;
      badgeLabel = 'لم يبدأ';
    }

    return AppCard(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconMedallion(
                icon: Icons.home_outlined,
                accent: accent,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التكرار في المنزل',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أنجز الطالب ${status.repetitionsDone} من '
                      '${status.repetitionsRequired} تكرارًا مطلوبًا',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (status.practices.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'لم يسجّل الطالب أي تكرار في المنزل بعد',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final p in status.practices)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16, color: tokens.green),
                    const SizedBox(width: 8),
                    Text(
                      '${repetitionCountAr(p.repetitions)} — '
                      '${dateFormat.format(p.date)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
