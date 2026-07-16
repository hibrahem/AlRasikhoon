import '../../data/models/level_model.dart';

/// How far a student has come through the whole منهج, derived from their
/// curriculum position against the levels catalog.
///
/// Every figure is DATA-driven — the earlier Juz-ring hero was removed because
/// it computed its own math. `juzMemorized` is NOT `30 - currentJuz`: that
/// conflates the juz being worked on with a completed one, ignores mid-juz
/// progress, and is wrong for level 10 (whose juz ascend 1 → 2 → 3) and for
/// flexibly-enrolled students. Instead a juz counts as memorized only when its
/// whole session block sits behind the student's position, and every level
/// below the frontier is memorized in full (taught or credited at enrollment).
class CurriculumProgress {
  /// The Qur'an is 30 juz — the ceiling for [juzMemorized].
  static const int totalJuz = 30;

  final int sessionsCompleted;
  final int totalSessions;
  final int juzMemorized;

  const CurriculumProgress({
    required this.sessionsCompleted,
    required this.totalSessions,
    required this.juzMemorized,
  });

  /// 0.0..1.0. Zero when the catalog has not resolved ([totalSessions] == 0),
  /// so the hero shows no progress rather than dividing by a made-up total.
  double get fraction => totalSessions > 0
      ? (sessionsCompleted / totalSessions).clamp(0.0, 1.0)
      : 0.0;

  /// The curriculum fraction as a 0..100 integer, for the ring's center label.
  int get percent => (fraction * 100).round();

  /// Derives the figures from the student's position and the whole [levels]
  /// catalog (as `levelsProvider` yields it). An empty [levels] — the catalog
  /// is still loading — yields all zeros.
  factory CurriculumProgress.of({
    required int currentLevel,
    required int currentOrderInLevel,
    required bool curriculumCompleted,
    required List<LevelModel> levels,
  }) {
    if (levels.isEmpty) {
      return const CurriculumProgress(
        sessionsCompleted: 0,
        totalSessions: 0,
        juzMemorized: 0,
      );
    }

    final totalSessions = levels.fold<int>(0, (sum, l) => sum + l.sessionCount);

    if (curriculumCompleted) {
      return CurriculumProgress(
        sessionsCompleted: totalSessions,
        totalSessions: totalSessions,
        juzMemorized: totalJuz,
      );
    }

    var sessionsCompleted = 0;
    var juzMemorized = 0;

    // Every level below the frontier is memorized in full.
    for (final level in levels) {
      if (level.levelNumber < currentLevel) {
        sessionsCompleted += level.sessionCount;
        juzMemorized += level.juz.length;
      }
    }

    // The current level contributes its passed sessions and any juz whose whole
    // block is already behind the student.
    for (final level in levels) {
      if (level.levelNumber == currentLevel) {
        sessionsCompleted += (currentOrderInLevel - 1).clamp(
          0,
          level.sessionCount,
        );
        for (final juz in level.juz) {
          if (juz.lastOrderInLevel < currentOrderInLevel) juzMemorized++;
        }
        break;
      }
    }

    return CurriculumProgress(
      sessionsCompleted: sessionsCompleted,
      totalSessions: totalSessions,
      juzMemorized: juzMemorized,
    );
  }
}
