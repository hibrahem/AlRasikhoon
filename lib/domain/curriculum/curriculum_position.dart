/// An immutable point in the curriculum: a session, in a juz, in a level.
///
/// Identity is `(level, juz, session)` — exactly what the curriculum's session
/// documents are keyed on (`L{level}_J{juz}_S{session}`).
///
/// A position deliberately knows NOTHING about teaching order. The juz of a
/// level are taught in an order that is *data*, not arithmetic (levels 1-9
/// descend — level 1 is juz 30 → 29 → 28 — but level 10 ASCENDS, juz 1 → 2 → 3,
/// because سورة البقرة spans those juz and a surah is memorized front to back).
/// Two positions therefore cannot be compared without the curriculum catalog:
/// ordering lives on the session's `orderInLevel`, which is read from the data.
///
/// Nor does a position know how many sessions a juz has (juz 30 has 68, juz 29
/// has 69, juz 28 has 67 — and it varies per level). Whether a position exists
/// is a DATA question, answered by the curriculum repository, not by the domain.
class CurriculumPosition {
  /// The curriculum has 10 levels and the Qur'an has 30 juz. Nothing beyond
  /// that topology is assumed here.
  static const int totalLevels = 10;
  static const int totalJuz = 30;

  final int level;
  final int juz;
  final int session;

  /// The first session of the curriculum: level 1, juz 30, session 1.
  static const CurriculumPosition start = CurriculumPosition(
    level: 1,
    juz: 30,
    session: 1,
  );

  const CurriculumPosition({
    required this.level,
    required this.juz,
    required this.session,
  }) : assert(level >= 1),
       assert(juz >= 1),
       assert(session >= 1);

  /// Validates the position against the curriculum's topology. Throws
  /// [ArgumentError] if the level, juz or session could never name a real point.
  ///
  /// It does NOT check that the session exists, nor that the juz belongs to the
  /// level — both are facts about the curriculum data, and only the repository
  /// holding that data can answer them.
  CurriculumPosition.validated({
    required this.level,
    required this.juz,
    required this.session,
  }) {
    if (level < 1 || level > totalLevels) {
      throw ArgumentError.value(level, 'level', 'Level must be 1-$totalLevels');
    }
    if (juz < 1 || juz > totalJuz) {
      throw ArgumentError.value(juz, 'juz', 'Juz must be 1-$totalJuz');
    }
    if (session < 1) {
      throw ArgumentError.value(session, 'session', 'Session must be >= 1');
    }
  }

  /// The id of the curriculum session document this position names.
  String get sessionId => 'L${level}_J${juz}_S$session';

  factory CurriculumPosition.fromMap(Map<String, dynamic> map) {
    return CurriculumPosition.validated(
      level: map['level'] as int,
      juz: map['juz'] as int,
      session: map['session'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'level': level,
    'juz': juz,
    'session': session,
  };

  @override
  String toString() =>
      'CurriculumPosition(level: $level, juz: $juz, session: $session)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumPosition &&
          other.level == level &&
          other.juz == juz &&
          other.session == session;

  @override
  int get hashCode => Object.hash(level, juz, session);
}
