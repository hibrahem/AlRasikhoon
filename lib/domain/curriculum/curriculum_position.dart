import 'curriculum_order.dart';

/// An immutable point in the curriculum: a session, in a hizb, in a level.
///
/// The juz is derived from the hizb rather than stored, so a position cannot
/// contradict itself. Positions are ordered by the curriculum's teaching order
/// (see [CurriculumOrder]), which is not the numeric order of the hizbs.
class CurriculumPosition {
  final int level;
  final int hizb;
  final int session;

  /// The first session of the curriculum: level 1, juz 30, hizb 59, session 1.
  static const CurriculumPosition start = CurriculumPosition(
    level: 1,
    hizb: 59,
    session: 1,
  );

  const CurriculumPosition({
    required this.level,
    required this.hizb,
    required this.session,
  }) : assert(level >= 1),
       assert(session >= 1);

  /// Validates the position against the curriculum. Throws [ArgumentError] if
  /// the level, hizb and session cannot describe a real point in the curriculum.
  CurriculumPosition.validated({
    required this.level,
    required this.hizb,
    required this.session,
  }) {
    if (level < 1 || level > CurriculumOrder.totalLevels) {
      throw ArgumentError.value(level, 'level', 'Level must be 1-10');
    }
    if (CurriculumOrder.levelOfHizb(hizb) != level) {
      throw ArgumentError.value(
        hizb,
        'hizb',
        'Hizb $hizb does not belong to level $level',
      );
    }
    if (session < 1 || session > 36) {
      throw ArgumentError.value(session, 'session', 'Session must be 1-36');
    }
  }

  /// The juz this position falls in, derived from the hizb.
  int get juz => CurriculumOrder.juzOfHizb(hizb);

  /// Whether this position is taught before [other].
  bool isBefore(CurriculumPosition other) {
    final thisHizb = CurriculumOrder.hizbOrderIndex(hizb);
    final otherHizb = CurriculumOrder.hizbOrderIndex(other.hizb);
    if (thisHizb != otherHizb) return thisHizb < otherHizb;
    return session < other.session;
  }

  factory CurriculumPosition.fromMap(Map<String, dynamic> map) {
    return CurriculumPosition.validated(
      level: map['level'] as int,
      hizb: map['hizb'] as int,
      session: map['session'] as int,
    );
  }

  /// The juz is written for readability; [fromMap] re-derives it from the hizb.
  Map<String, dynamic> toMap() => {
    'level': level,
    'juz': juz,
    'hizb': hizb,
    'session': session,
  };

  @override
  String toString() =>
      'CurriculumPosition(level: $level, juz: $juz, hizb: $hizb, session: $session)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumPosition &&
          other.level == level &&
          other.hizb == hizb &&
          other.session == session;

  @override
  int get hashCode => Object.hash(level, hizb, session);
}
