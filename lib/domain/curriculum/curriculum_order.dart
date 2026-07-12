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

  /// The level a hizb belongs to. Level 1 owns hizbs 55-60, level 2 owns 49-54.
  static int levelOfHizb(int hizb) => ((60 - hizb) ~/ 6) + 1;

  /// The next hizb in teaching order, or null at the end of the curriculum.
  ///
  /// Odd hizbs are the first half of their juz, so the next hizb is the second
  /// half (59 -> 60). Even hizbs end their juz, so the next hizb is the first
  /// half of the next (lower) juz (60 -> 57). This crosses level boundaries
  /// naturally: 56 -> 53.
  ///
  /// Hizbs below 1 are out of range and have no next hizb. This guards
  /// against corrupted records (the old advancement bug left legacy records
  /// at hizb -1 after level 10) that would otherwise descend forever:
  /// 0 -> -3 -> -2 -> -5 -> ...
  static int? nextHizb(int hizb) {
    if (hizb < 1) return null;
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
