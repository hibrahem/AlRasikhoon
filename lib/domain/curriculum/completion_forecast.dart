import '../../data/models/level_model.dart';
import '../../data/models/session_model.dart';
import 'curriculum_pace.dart';
import 'meetings_per_week.dart';

/// Everything still ahead of a student, shaped for counting meetings.
///
/// Meetings-to-finish is NOT `ceil(remainingRows / pace)`: only LESSONS batch —
/// a تلقين, a سرد and an اختبار each always stand alone at any pace, a batch
/// never crosses a level boundary, and `PacedSessionComposer._batch` also stops
/// at a hole in `order_in_level`. This class replays exactly those rules, once,
/// into a run-length encoding: the standalone rows, and the lengths of maximal
/// runs of consecutive-by-order lessons. Counting meetings at any pace is then
/// arithmetic — which is what lets a what-if slider re-evaluate every detent
/// without touching the curriculum again.
class RemainingCurriculum {
  /// Rows that take one meeting each, whatever the pace.
  final int standaloneCount;

  /// Lengths of maximal runs of consecutive lessons. A run batches into
  /// `ceil(length / pace)` meetings; runs are computed per level and broken at
  /// non-lessons and order holes, so no run spans what a batch could not.
  final List<int> lessonRuns;

  const RemainingCurriculum({
    required this.standaloneCount,
    required this.lessonRuns,
  });

  static const RemainingCurriculum none = RemainingCurriculum(
    standaloneCount: 0,
    lessonRuns: [],
  );

  int get remainingRows =>
      standaloneCount + lessonRuns.fold<int>(0, (sum, run) => sum + run);

  bool get isFinished => remainingRows == 0;

  /// How many meetings finish the curriculum at [pace] — the composer's
  /// batching, replayed as arithmetic.
  int meetingsAtPace(CurriculumPace pace) =>
      standaloneCount +
      lessonRuns.fold<int>(
        0,
        (sum, run) => sum + (run / pace.multiplier).ceil(),
      );

  /// Derives the encoding from the student's position against the catalog.
  ///
  /// [sessionsByLevel] holds each remaining level's rows ordered by
  /// `order_in_level` (as `getSessionsForLevel` yields them). A level missing
  /// from the map — still loading, or absent from the catalog — contributes
  /// nothing, the same honest-zero posture as [CurriculumProgress.of].
  factory RemainingCurriculum.of({
    required int currentLevel,
    required int currentOrderInLevel,
    required bool curriculumCompleted,
    required List<LevelModel> levels,
    required Map<int, List<SessionModel>> sessionsByLevel,
  }) {
    if (curriculumCompleted) return none;

    var standaloneCount = 0;
    final lessonRuns = <int>[];

    for (final level in levels) {
      if (level.levelNumber < currentLevel) continue;

      final rows = sessionsByLevel[level.levelNumber];
      if (rows == null) continue;

      // Runs restart at every level: a batch never crosses a level boundary.
      var run = 0;
      var previousOrder = -1;

      for (final row in rows) {
        final isAhead =
            level.levelNumber > currentLevel ||
            row.orderInLevel >= currentOrderInLevel;
        if (!isAhead) continue;

        if (!row.isLesson) {
          if (run > 0) lessonRuns.add(run);
          run = 0;
          previousOrder = -1;
          standaloneCount++;
          continue;
        }

        // A hole in order_in_level breaks a batch (see _batch), so it breaks
        // the run too.
        if (run > 0 && row.orderInLevel != previousOrder + 1) {
          lessonRuns.add(run);
          run = 0;
        }
        run++;
        previousOrder = row.orderInLevel;
      }
      if (run > 0) lessonRuns.add(run);
    }

    return RemainingCurriculum(
      standaloneCount: standaloneCount,
      lessonRuns: lessonRuns,
    );
  }
}

/// When a student finishes the whole Quran, given a pace and a weekly cadence.
///
/// Pure arithmetic over a [RemainingCurriculum] — the caller supplies "today",
/// so the domain stays clock-free and a test can pin any date it likes.
class CompletionForecast {
  final int remainingMeetings;
  final MeetingsPerWeek meetingsPerWeek;

  const CompletionForecast({
    required this.remainingMeetings,
    required this.meetingsPerWeek,
  });

  factory CompletionForecast.of({
    required RemainingCurriculum remaining,
    required CurriculumPace pace,
    required MeetingsPerWeek meetingsPerWeek,
  }) => CompletionForecast(
    remainingMeetings: remaining.meetingsAtPace(pace),
    meetingsPerWeek: meetingsPerWeek,
  );

  bool get isFinished => remainingMeetings == 0;

  /// Whole weeks to the ختم. The last partial week counts in full — a forecast
  /// that promises "17 weeks" and delivers in the 18th has lied.
  int get weeks => (remainingMeetings / meetingsPerWeek.count).ceil();

  DateTime completionDate(DateTime from) => from.add(Duration(days: weeks * 7));
}
