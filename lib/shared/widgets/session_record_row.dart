import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
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
