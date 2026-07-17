/// How many meetings a student attends in one week.
///
/// The app holds no calendar and no schedule — this is the student's declared
/// cadence, set by the teacher or the supervisor alongside the pace. Together
/// they answer the one question the forecast exists for: at this pace, meeting
/// this often, when is the ختم?
class MeetingsPerWeek {
  /// The cadence the curriculum was authored around: two meetings a week.
  static final MeetingsPerWeek standard = MeetingsPerWeek(2);

  /// A week has seven days; a meeting takes one.
  static const int maxPerWeek = 7;

  final int count;

  /// A value object validates its invariant in its constructor — same posture
  /// as [CurriculumPace]: a corrupted 0 must throw, not sail through.
  MeetingsPerWeek(this.count) {
    if (count < 1) {
      throw ArgumentError.value(
        count,
        'count',
        'A student meets at least once a week',
      );
    }
    if (count > maxPerWeek) {
      throw ArgumentError.value(
        count,
        'count',
        'A week holds at most $maxPerWeek meetings',
      );
    }
  }

  /// Reads a cadence from storage.
  ///
  /// Absence is not corruption: every student created before forecasts has no
  /// stored cadence and is, correctly, a standard two-meetings-a-week student.
  /// A stored value outside 1..7 IS corruption and must surface.
  factory MeetingsPerWeek.fromJson(Object? json) {
    if (json == null) return standard;
    if (json is! int) {
      throw ArgumentError.value(
        json,
        'meetingsPerWeek',
        'A weekly cadence must be a whole number',
      );
    }
    return MeetingsPerWeek(json);
  }

  int toJson() => count;

  @override
  String toString() => 'MeetingsPerWeek($count)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingsPerWeek && other.count == count;

  @override
  int get hashCode => count.hashCode;
}
