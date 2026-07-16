import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// The streak, told as a chain of day-beads (tasbih metaphor — this app's
/// answer to the flame icon, which is banned): the last seven days as 12dp
/// beads, today first (at the start side, so it leads in RTL) receding into
/// the past. Practiced = gold fill; missed = dim gold outline; today also
/// wears a thin outer halo ring (a stroke, never a blur).
///
/// [days] is today-first, `days[0]` = today. No data logic lives here.
class DayBeads extends StatelessWidget {
  final List<bool> days;
  final double beadSize;

  /// Outline/halo color override; on the hero pass `onHero @ 25%`.
  final Color? dimColor;

  const DayBeads({
    super.key,
    required this.days,
    this.beadSize = 12,
    this.dimColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dim = dimColor ?? tokens.rewardDim;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) SizedBox(width: beadSize * 0.66),
          _Bead(
            filled: days[i],
            isToday: i == 0,
            size: beadSize,
            fill: tokens.gold,
            dim: dim,
          ),
        ],
      ],
    );
  }
}

class _Bead extends StatelessWidget {
  final bool filled;
  final bool isToday;
  final double size;
  final Color fill;
  final Color dim;

  const _Bead({
    required this.filled,
    required this.isToday,
    required this.size,
    required this.fill,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    final bead = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? fill : null,
        border: filled ? null : Border.all(color: dim, width: 1.5),
      ),
    );

    if (!isToday) return bead;

    // Today's halo: a 3dp-offset stroke ring around the bead.
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: dim, width: 1.5),
      ),
      child: bead,
    );
  }
}
