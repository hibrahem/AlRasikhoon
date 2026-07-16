import 'dart:async';
import 'package:flutter/material.dart';
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

  /// The neutral (on-pace / no-target) color. Defaults to [AppTokens.ink] —
  /// readable on the parchment app bars. Hosts that place the timer on a
  /// dark pill (the recitation hero) pass a light color instead.
  final Color? neutralColor;

  const SessionTimer({
    super.key,
    required this.startedAt,
    this.target,
    this.neutralColor,
  });

  @override
  State<SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<SessionTimer>
    with WidgetsBindingObserver {
  Timer? _ticker;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _elapsed = DateTime.now().difference(widget.startedAt);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _elapsed += const Duration(seconds: 1)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android suspends the ticker while the app is backgrounded; on resume
    // the elapsed time is resynced from the wall clock so the pace nudge
    // never under-reports a session that spanned an app switch.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _elapsed = DateTime.now().difference(widget.startedAt));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  Color _colorFor(LiveTimerLevel level, AppTokens tokens) {
    switch (level) {
      case LiveTimerLevel.neutral:
        // Ink by default: the old fixed white was designed for the colored
        // app-bar slabs and turned invisible on the parchment bars the
        // redesign put everywhere.
        return widget.neutralColor ?? tokens.ink;
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
