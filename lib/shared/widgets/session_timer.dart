import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/session/session_duration.dart';

/// A live, once-a-second count-up shown in an active session's app bar.
///
/// Display-only: it seeds elapsed from [startedAt] once and ticks it forward
/// a second at a time, and never writes anything. With a [target] it shows
/// `elapsed / target` and colors itself by [SessionDuration.liveTimerLevel]
/// as a nudge to end the session; without one (assessments) it shows elapsed
/// alone in a neutral color.
class SessionTimer extends StatefulWidget {
  final DateTime startedAt;
  final Duration? target;

  const SessionTimer({super.key, required this.startedAt, this.target});

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer> {
  Timer? _ticker;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _elapsed += const Duration(seconds: 1)),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _colorFor(LiveTimerLevel level, AppTokens tokens) {
    switch (level) {
      case LiveTimerLevel.neutral:
        return AppColors.textOnPrimary;
      case LiveTimerLevel.warning:
        return tokens.gold;
      case LiveTimerLevel.danger:
        return tokens.maroon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final elapsed = _elapsed;
    final target = widget.target;
    final text = target == null
        ? SessionDuration.formatClock(elapsed)
        : '${SessionDuration.formatClock(elapsed)} / ${SessionDuration.formatClock(target)}';
    final color = _colorFor(
      SessionDuration.liveTimerLevel(elapsed, target),
      tokens,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
