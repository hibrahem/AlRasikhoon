import 'package:intl/intl.dart';

/// How a measured session length compares to its target.
enum DurationStatus { none, under, onTarget, over }

/// The timing facts [SessionDuration.fromRecord] needs from a finished session
/// record. Declared in the domain so the value object never depends on a
/// data-layer model (the Dependency Rule): the record implements this
/// interface, the domain does not reach out to the record's concrete type.
abstract interface class SessionTiming {
  /// The measured wall-clock length, or null when no start was captured.
  Duration? get duration;

  /// The pace multiple in force when the session happened; sets the target.
  int get paceAtTime;
}

/// The urgency of the live in-session timer, driving its color.
enum LiveTimerLevel { neutral, warning, danger }

/// The length of a session, judged against its expected length.
///
/// Paced sessions (lesson, تلقين) have a target of `20 min × pace`; a سرد or
/// اختبار has none. With a target the measured [elapsed] is clamped to
/// [kCapMultiple]× it on construction, so a session left open overnight is
/// recorded as the clamped maximum rather than an absurd number.
class SessionDuration {
  static const int kMinutesPerPace = 20;
  static const double kToleranceFraction = 0.25;
  static const int kCapMultiple = 3;

  final Duration elapsed;
  final Duration? target;

  SessionDuration({required Duration elapsed, this.target})
    : elapsed = _capped(elapsed, target);

  static Duration targetForPace(int pace) =>
      Duration(minutes: kMinutesPerPace * pace);

  /// The duration of a finished session [record], or null when it captured no
  /// timing. A paced record (lesson, تلقين) targets `20 min × paceAtTime`; the
  /// elapsed time is clamped to that on construction.
  static SessionDuration? fromRecord(SessionTiming record) {
    final elapsed = record.duration;
    if (elapsed == null) return null;
    return SessionDuration(
      elapsed: elapsed,
      target: targetForPace(record.paceAtTime),
    );
  }

  static Duration _capped(Duration elapsed, Duration? target) {
    if (target == null) return elapsed;
    final cap = target * kCapMultiple;
    return elapsed > cap ? cap : elapsed;
  }

  DurationStatus get status {
    final t = target;
    if (t == null) return DurationStatus.none;
    final lower = t * (1 - kToleranceFraction);
    final upper = t * (1 + kToleranceFraction);
    if (elapsed < lower) return DurationStatus.under;
    if (elapsed > upper) return DurationStatus.over;
    return DurationStatus.onTarget;
  }

  String get clock => formatClock(elapsed);

  String get arabicMinutesLabel {
    final minutes = (elapsed.inSeconds / 60).round();
    return '${NumberFormat('#', 'ar_EG').format(minutes)} دقيقة';
  }

  static String formatClock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static LiveTimerLevel liveTimerLevel(Duration rawElapsed, Duration? target) {
    if (target == null) return LiveTimerLevel.neutral;
    if (rawElapsed >= target * 2) return LiveTimerLevel.danger;
    if (rawElapsed >= target) return LiveTimerLevel.warning;
    return LiveTimerLevel.neutral;
  }
}
