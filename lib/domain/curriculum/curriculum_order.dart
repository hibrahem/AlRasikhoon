/// Curriculum arithmetic for منهج الراسخون — pure domain, no framework imports.
///
/// The curriculum is 10 levels. Level L owns three juz, descending, and the six
/// hizbs of those juz. Within a juz the hizbs ascend: juz j is hizb 2j-1, then
/// hizb 2j. Level 1 is therefore taught as 59, 60, 57, 58, 55, 56 — a student
/// begins at juz 30, hizb 59, and the juz descend as they advance.
class CurriculumOrder {
  CurriculumOrder._();

  static const int totalLevels = 10;
  static const int hizbsPerLevel = 6;

  /// The juz a hizb belongs to. Juz j spans hizbs 2j-1 and 2j.
  static int juzOfHizb(int hizb) => (hizb + 1) ~/ 2;

  /// The two hizbs of a juz, in teaching order.
  static List<int> hizbsOfJuz(int juz) => [juz * 2 - 1, juz * 2];

  /// The three juz of a level, in teaching order (descending).
  static List<int> juzOfLevel(int level) => [
    33 - 3 * level,
    32 - 3 * level,
    31 - 3 * level,
  ];

  /// The six hizbs of a level, in teaching order.
  static List<int> hizbsOfLevel(int level) => [
    for (final juz in juzOfLevel(level)) ...hizbsOfJuz(juz),
  ];

  /// The hizb a level starts at: 59, 53, 47 ... 5.
  static int firstHizbOfLevel(int level) => 65 - 6 * level;

  /// The hizb a level ends at: 56, 50, 44 ... 2. A level is complete only
  /// after this hizb — not after its first, which was the historical bug.
  static int lastHizbOfLevel(int level) => 62 - 6 * level;

  /// Whether [hizb] is a real hizb of this curriculum (1-60). Every other
  /// method here that takes a hizb assumes it satisfies this — callers
  /// receiving hizbs from outside the domain (Firestore, UI input) must
  /// check this first.
  static bool isValidHizb(int hizb) =>
      hizb >= 1 && hizb <= totalLevels * hizbsPerLevel;

  /// The level a hizb belongs to. Level 1 owns hizbs 55-60, level 2 owns
  /// 49-54.
  ///
  /// Only meaningful for a valid hizb ([isValidHizb]). Dart's `~/` truncates
  /// toward zero, so out-of-range hizbs above 60 alias back into level 1's
  /// range (e.g. `levelOfHizb(61) == 1`, same as hizb 1-6) instead of
  /// signalling invalidity — callers MUST check [isValidHizb] first rather
  /// than relying on this to reject out-of-range input.
  static int levelOfHizb(int hizb) => ((60 - hizb) ~/ 6) + 1;

  /// The next hizb in teaching order, or null at the end of the curriculum.
  ///
  /// Odd hizbs are the first half of their juz, so the next hizb is the second
  /// half (59 -> 60). Even hizbs end their juz, so the next hizb is the first
  /// half of the next (lower) juz (60 -> 57). This crosses level boundaries
  /// naturally: 56 -> 53.
  ///
  /// Any hizb outside 1-60 is out of range and has no next hizb. This guards
  /// against corrupted records (the old advancement bug left legacy records
  /// at hizb -1 after level 10) that would otherwise descend forever:
  /// 0 -> -3 -> -2 -> -5 -> ... It also guards the top end: without it,
  /// `levelOfHizb(61) == 1` would make `nextHizb(61)` compute 62 and wander
  /// back into the curriculum instead of terminating.
  static int? nextHizb(int hizb) {
    if (!isValidHizb(hizb)) return null;
    if (hizb == lastHizbOfLevel(totalLevels)) return null;
    return hizb.isOdd ? hizb + 1 : hizb - 3;
  }

  /// A hizb's position in the whole curriculum, 0 (hizb 59) to 59 (hizb 2).
  /// Monotonic in teaching order, so positions can be compared numerically.
  static int hizbOrderIndex(int hizb) {
    final level = levelOfHizb(hizb);
    final indexInLevel = hizbsOfLevel(level).indexOf(hizb);
    return (level - 1) * hizbsPerLevel + indexInLevel;
  }
}
