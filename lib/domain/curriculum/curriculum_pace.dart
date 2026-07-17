/// How many curriculum lessons a student covers in one meeting.
///
/// The curriculum is authored for the average student: one meeting, one session.
/// A student who memorizes quickly can be given N× that — the teacher and the
/// supervisor may set it, and it may change mid-level.
///
/// A pace multiplies LESSONS only. A تلقين, a سرد and an اختبار each always
/// stand alone, at any pace.
class CurriculumPace {
  /// One lesson per meeting — the curriculum exactly as authored.
  static final CurriculumPace standard = CurriculumPace(1);

  /// The fastest pace a supervisor may set. Ten lessons in one sitting is
  /// already an exceptional student; beyond it the "meeting" stops being one.
  static const int maxMultiplier = 10;

  final int multiplier;

  /// A value object validates its invariant in its constructor, so this cannot
  /// be `const` — an `assert` would fire only in debug, and a pace of 0 read
  /// from a corrupted document in production would sail through.
  CurriculumPace(this.multiplier) {
    if (multiplier < 1) {
      throw ArgumentError.value(
        multiplier,
        'multiplier',
        'A pace covers at least one session',
      );
    }
    if (multiplier > maxMultiplier) {
      throw ArgumentError.value(
        multiplier,
        'multiplier',
        'A pace covers at most $maxMultiplier sessions',
      );
    }
  }

  /// Reads a pace from storage.
  ///
  /// Absence is not corruption: every student created before paced curricula has
  /// no stored pace and is, correctly, a standard-pace student. A stored value
  /// that is not a valid multiplier IS corruption and must surface — silently
  /// defaulting a broken 0 to 1 would hide it forever.
  factory CurriculumPace.fromJson(Object? json) {
    if (json == null) return standard;
    if (json is! int) {
      throw ArgumentError.value(json, 'pace', 'A pace must be a whole number');
    }
    if (json < 1) {
      throw ArgumentError.value(json, 'pace', 'A pace must be at least 1');
    }
    if (json > maxMultiplier) {
      throw ArgumentError.value(
        json,
        'pace',
        'A pace must be at most $maxMultiplier',
      );
    }
    return CurriculumPace(json);
  }

  int toJson() => multiplier;

  bool get isStandard => multiplier == 1;

  @override
  String toString() => 'CurriculumPace(${multiplier}x)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumPace && other.multiplier == multiplier;

  @override
  int get hashCode => multiplier.hashCode;
}
