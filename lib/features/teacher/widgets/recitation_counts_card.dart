import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';

/// The two counts a teacher records on every session that teaches new content —
/// a تلقين and a lesson alike.
///
/// The home figure is an ASSIGNMENT, not a note: the student sees it and their
/// home practice counts against it.
class RecitationCountsCard extends StatelessWidget {
  final int repetitionsWithTeacher;
  final int homeRepetitionsRequired;
  final ValueChanged<int> onRepetitionsWithTeacherChanged;
  final ValueChanged<int> onHomeRepetitionsRequiredChanged;

  const RecitationCountsCard({
    super.key,
    required this.repetitionsWithTeacher,
    required this.homeRepetitionsRequired,
    required this.onRepetitionsWithTeacherChanged,
    required this.onHomeRepetitionsRequiredChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountStepper(
            label: 'عدد مرات القراءة مع الطالب',
            keyPrefix: 'repetitions_with_teacher',
            value: repetitionsWithTeacher,
            onChanged: onRepetitionsWithTeacherChanged,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _CountStepper(
            label: 'عدد مرات التكرار في المنزل',
            keyPrefix: 'home_repetitions_required',
            value: homeRepetitionsRequired,
            onChanged: onHomeRepetitionsRequiredChanged,
          ),
        ],
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  final String label;
  final String keyPrefix;
  final int value;
  final ValueChanged<int> onChanged;

  const _CountStepper({
    required this.label,
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        IconButton(
          key: Key('decrement_$keyPrefix'),
          icon: const Icon(Icons.remove_circle_outline),
          color: tokens.sepia,
          // A count cannot go below zero: a session recited a negative number
          // of times is not a thing a teacher can report.
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            // Data numeral: Cairo bold with tabular figures so the count
            // doesn't jitter as it steps.
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFeatures: [const FontFeature.tabularFigures()],
              color: tokens.green,
            ),
          ),
        ),
        IconButton(
          key: Key('increment_$keyPrefix'),
          icon: const Icon(Icons.add_circle_outline),
          color: tokens.green,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
