import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/session/home_practice_log.dart';
import '../../domain/session/session_duration.dart';
import 'app_card.dart';
import 'icon_medallion.dart';
import 'pending_sync_chip.dart';

/// One row of a session-record listing (student history, teacher history).
///
/// Shows ONLY the binary outcome (نجح / رسب) — never an averaged grade and
/// never the per-component (new/near/far) grade breakdown, per
/// hibrahem/AlRasikhoon#24. The breakdown belongs in the session detail view
/// only.
///
/// Callers differ only in what identifies the row (a session number for the
/// student's own history, a student name for the teacher's), so [title] and
/// [subtitleLines] are supplied by the caller in the order they should
/// appear; this widget owns the shared layout, colors, and pass/fail styling.
class SessionRecordRow extends StatelessWidget {
  final String title;
  final List<String> subtitleLines;
  final bool passed;
  final DateTime date;
  final VoidCallback? onTap;

  /// A تلقين is graded on nothing and cannot be failed, so it carries no
  /// outcome to show. `createTalqeenRecord` writes `passed: true` regardless —
  /// that flag says the session happened, it is not a grade — so rendering
  /// [passed] for one would report a pass the student never earned.
  final bool isTalqeen;

  /// The recorded length of the session, or null for records with no timing.
  /// When present the row shows the duration as `mm:ss`; when it also has a
  /// target (lessons/تلقين) the time is color-coded by pace — green on target,
  /// yellow when faster than target, red when beyond it — so color, not a
  /// verbose label, carries the meaning.
  final SessionDuration? sessionDuration;

  /// Saved offline on this device and still in Firestore's local write queue.
  /// `hasPendingWrites` is only ever true on the device that queued the write,
  /// so this row — the teacher's and the student's own history — is the only
  /// place the chip can actually be seen (al_rasikhoon-q4m).
  final bool isPendingSync;

  /// The home repetitions this session assigned. Together with
  /// [homePractices] it renders the homework line («التكرار في المنزل:
  /// المنجز من المطلوب») plus one dated line per logged practice, so a
  /// teacher/supervisor/admin sees at a glance whether — and when — the
  /// student did the assigned repetition. Nothing renders when the session
  /// assigned nothing and the student logged nothing.
  final int homeRepetitionsRequired;

  /// The practice submissions logged against this session's assignment,
  /// newest first, each carrying its own date and count.
  final List<HomePracticeLog> homePractices;

  const SessionRecordRow({
    super.key,
    required this.title,
    required this.subtitleLines,
    required this.passed,
    required this.date,
    this.onTap,
    this.isTalqeen = false,
    this.sessionDuration,
    this.isPendingSync = false,
    this.homeRepetitionsRequired = 0,
    this.homePractices = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final passColor = isTalqeen
        ? tokens.green
        : (passed ? tokens.green : tokens.maroon);
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          IconMedallion(
            icon: isTalqeen
                ? Icons.record_voice_over
                : (passed ? Icons.check_circle : Icons.cancel),
            accent: passColor,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final line in subtitleLines)
                  Text(
                    line,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                  ),
                Text(
                  dateFormat.format(date),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
                if (sessionDuration != null) ...[
                  const SizedBox(height: 4),
                  _DurationDisplay(duration: sessionDuration!),
                ],
                if (homeRepetitionsRequired > 0 || homePractices.isNotEmpty)
                  _HomePracticeDisplay(
                    required: homeRepetitionsRequired,
                    practices: homePractices,
                    dateFormat: dateFormat,
                  ),
                if (isPendingSync)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: PendingSyncChip(),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: passColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: passColor),
            ),
            child: Text(
              isTalqeen ? 'تلقين' : (passed ? 'نجح' : 'رسب'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: passColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The homework story of one session: how much home repetition was assigned,
/// how much the student actually logged, and WHEN — one dated line per
/// submission, so «سجّل 3 مرات لكن متى؟» never needs the student's word.
///
/// The summary line is color-coded the way the duration chip is: green once
/// the assignment is met, gold while partially done, maroon when nothing was
/// logged against an assignment. Practice logged with NO assignment (the
/// teacher required 0) shows plainly in sepia — voluntary work has no target
/// to fail.
class _HomePracticeDisplay extends StatelessWidget {
  final int required;
  final List<HomePracticeLog> practices;
  final DateFormat dateFormat;

  const _HomePracticeDisplay({
    required this.required,
    required this.practices,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final done = practices.fold<int>(0, (total, p) => total + p.repetitions);
    final small = Theme.of(context).textTheme.bodySmall;

    final Color summaryColor;
    if (required <= 0) {
      summaryColor = tokens.sepia;
    } else if (done >= required) {
      summaryColor = tokens.green;
    } else if (done > 0) {
      summaryColor = tokens.gold;
    } else {
      summaryColor = tokens.maroon;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          required > 0
              ? 'التكرار في المنزل: $done من $required'
              : 'التكرار في المنزل: $done',
          style: small?.copyWith(
            color: summaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        for (final p in practices)
          Text(
            '${repetitionCountAr(p.repetitions)} — '
            '${dateFormat.format(p.date)}',
            style: small?.copyWith(color: tokens.sepia),
          ),
      ],
    );
  }
}

/// Shows a finished session's length as `المدة: mm:ss`.
///
/// For a paced session (lesson/تلقين) the time is color-coded by pace against
/// its target — the color, not a verbose Arabic band label, tells the teacher
/// how the session went. For a session with no target (سرد/اختبار) the time is
/// shown plainly, since color would carry no meaning.
class _DurationDisplay extends StatelessWidget {
  final SessionDuration duration;
  const _DurationDisplay({required this.duration});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = 'المدة: ${duration.clock}';
    final color = _colorForStatus(duration.status, tokens);
    if (color == null) {
      return Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// The pace-vs-target color for [status], per al_rasikhoon-xkd:
  ///   onTarget → green (on time), under → yellow (faster than target),
  ///   over → red (beyond target). Returns null when there is no target, so the
  ///   caller shows the time in a neutral color instead.
  static Color? _colorForStatus(DurationStatus status, AppTokens tokens) {
    switch (status) {
      case DurationStatus.under:
        return tokens.gold; // gold — faster than target
      case DurationStatus.onTarget:
        return tokens.green; // green — on time
      case DurationStatus.over:
        return tokens.maroon; // red — beyond target
      case DurationStatus.none:
        return null;
    }
  }
}
