import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import 'app_card.dart';

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

  const SessionRecordRow({
    super.key,
    required this.title,
    required this.subtitleLines,
    required this.passed,
    required this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final passColor = passed ? AppColors.success : AppColors.error;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: passColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                passed ? Icons.check_circle : Icons.cancel,
                color: passColor,
              ),
            ),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  dateFormat.format(date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
              passed ? 'نجح' : 'رسب',
              style: TextStyle(
                fontSize: 13,
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
