import '../../data/models/session_model.dart';
import 'curriculum_pace.dart';

/// One meeting between a teacher and a student: the N curriculum sessions it
/// discharges, and the three content streams the student recites.
///
/// A meeting is DERIVED, never stored. The curriculum collection holds one row
/// per session and knows nothing of pace; a meeting is composed from those rows
/// on demand. Every range here is a range the curriculum already states — this
/// class unions blocks, it never authors content.
class PacedSession {
  /// The sessions this meeting covers, ascending by [SessionModel.orderInLevel].
  final List<SessionModel> sessions;

  final List<QuranContent> newContent;

  /// May contain a DUPLICATE block at a unit's start — the تلقين that opens
  /// a unit carries the same passage as the unit's first lesson, so both can
  /// land in this list. The display getters (`recentReviewAr`) de-duplicate
  /// before rendering; a raw consumer of this list must do the same or it
  /// will double-count.
  final List<QuranContent> recentReview;
  final List<QuranContent> distantReview;

  const PacedSession({
    required this.sessions,
    required this.newContent,
    required this.recentReview,
    required this.distantReview,
  });

  /// The session the meeting starts on. Its kind, tier and label are the
  /// meeting's — a batch is all lessons, so they agree.
  SessionModel get first => sessions.first;

  int get fromOrderInLevel => sessions.first.orderInLevel;

  /// The last session discharged. THE advancement key: the student's next
  /// meeting begins at `toOrderInLevel + 1`.
  int get toOrderInLevel => sessions.last.orderInLevel;

  List<String> get coversSessionIds =>
      sessions.map((session) => session.id).toList();

  /// Whether this meeting covers more than one session — i.e. whether its
  /// content was composed rather than read verbatim.
  bool get isBatched => sessions.length > 1;

  /// The passages of one stream on one line — what a screen shows where it
  /// used to show a single range.
  ///
  /// A composed stream is DISCRETE (one block per session it drew from), and a
  /// 2x meeting's recent window carries a block equal to what the unit's
  /// opening تلقين already read out — genuinely duplicate content, not a
  /// formatting accident. This is display-only cleanup, never authoring:
  ///
  /// 1. DE-DUPLICATE — drop a block equal to one already emitted.
  /// 2. MERGE CONTIGUOUS RUNS — collapse a run into ONE range spanning the
  ///    first block's start to the last block's end. Two blocks are
  ///    contiguous ONLY when they sit in the SAME surah AND
  ///    `next.fromVerse == prev.toVerse + 1` (adjacent verses within one
  ///    surah).
  ///    Same-surah alone is NOT contiguous — two blocks in one surah with a
  ///    verse gap between them (e.g. النبأ 1-11 then النبأ 30-40) must stay
  ///    separate, or the merge would claim verses 12-29 that neither block
  ///    covers.
  ///    A block that opens a DIFFERENT surah is NEVER merged with the one
  ///    before it, even when it starts at verse 1 — this app deliberately does
  ///    not know surah lengths, so seeing "verse 1" cannot tell it the
  ///    previous surah was finished. The curriculum itself may cross a surah
  ///    boundary mid-block (its author knows the lengths); this code cannot
  ///    replicate that safely, so a cross-surah run always renders as
  ///    separate blocks joined by ` • `. This code never authors content, so
  ///    it must never invent a range wider than what's actually there.
  ///
  /// A merged block's four fields are always copied from two blocks that are
  /// already there — this computes no surah name and no verse number. A 1x
  /// meeting has exactly one block per stream, so both steps are no-ops and
  /// the line is byte-identical to what the screen rendered before paced
  /// curricula.
  static String _line(List<QuranContent> blocks) =>
      _merge(_deduplicate(blocks)).map((block) => block.rangeAr).join(' • ');

  static List<QuranContent> _deduplicate(List<QuranContent> blocks) {
    final seen = <QuranContent>[];
    for (final block in blocks) {
      if (seen.contains(block)) continue;
      seen.add(block);
    }
    return seen;
  }

  static bool _isContiguous(QuranContent prev, QuranContent next) =>
      next.fromSurah == prev.toSurah && next.fromVerse == prev.toVerse + 1;

  static List<QuranContent> _merge(List<QuranContent> blocks) {
    if (blocks.isEmpty) return const [];

    final merged = <QuranContent>[];
    var runStart = blocks.first;
    var runEnd = blocks.first;

    for (final block in blocks.skip(1)) {
      if (_isContiguous(runEnd, block)) {
        runEnd = block;
        continue;
      }
      merged.add(
        QuranContent(
          fromSurah: runStart.fromSurah,
          fromVerse: runStart.fromVerse,
          toSurah: runEnd.toSurah,
          toVerse: runEnd.toVerse,
        ),
      );
      runStart = block;
      runEnd = block;
    }
    merged.add(
      QuranContent(
        fromSurah: runStart.fromSurah,
        fromVerse: runStart.fromVerse,
        toSurah: runEnd.toSurah,
        toVerse: runEnd.toVerse,
      ),
    );
    return merged;
  }

  String get newContentAr => _line(newContent);
  String get recentReviewAr => _line(recentReview);
  String get distantReviewAr => _line(distantReview);

  bool get hasNewContent => newContent.isNotEmpty;
  bool get hasRecentReview => recentReview.isNotEmpty;
  bool get hasDistantReview => distantReview.isNotEmpty;

  @override
  String toString() =>
      'PacedSession($fromOrderInLevel..$toOrderInLevel, '
      '${sessions.length} session(s))';
}

/// Composes a [PacedSession] from the curriculum.
///
/// The rules, and why:
///
/// - **Only lessons batch.** A تلقين, a سرد and an اختبار each always stand
///   alone. An assessment is a gate, and its scope was always the whole unit or
///   juz — pace does not touch it.
///
/// - **A meeting of one session is NOT composed.** Its blocks are the row's own,
///   verbatim. The source curriculum has ~8 rows that disagree with its own
///   window rule (surah-name typos, ±1 verse drift, duplicated rows), so
///   composing at pace 1 would silently rewrite what every ordinary student
///   sees. The guarantee that a 1x student is untouched is structural: this code
///   does not run for them.
///
/// - **Distant review concatenates.** It is a cursor sweeping non-overlapping
///   chunks of already-memorized Qur'an, independent of what is taught today, so
///   two rows' distant blocks simply add up.
///
/// - **Recent review does NOT concatenate.** It is a sliding window over the
///   previous two sessions' new content, so two rows' recent blocks overlap
///   each other AND reach into content this meeting is itself teaching. The
///   window is therefore recomputed: the new content of the previous 2N
///   sessions.
class PacedSessionComposer {
  const PacedSessionComposer._();

  static PacedSession compose({
    required List<SessionModel> levelSessions,
    required int startOrderInLevel,
    required CurriculumPace pace,
  }) {
    final byOrder = {
      for (final session in levelSessions) session.orderInLevel: session,
    };

    final start = byOrder[startOrderInLevel];
    if (start == null) {
      throw ArgumentError.value(
        startOrderInLevel,
        'startOrderInLevel',
        'No session stands at this order in the level',
      );
    }

    final batch = _batch(byOrder, start, pace);

    // A meeting of one is the curriculum as authored. Do not compose it.
    if (batch.length == 1) {
      return PacedSession(
        sessions: batch,
        newContent: _blocks([start.currentLevelContent]),
        recentReview: _blocks([start.recentReviewContent]),
        distantReview: _blocks([start.distantReviewContent]),
      );
    }

    final newContent = _blocks(
      batch.map((session) => session.currentLevelContent),
    );

    return PacedSession(
      sessions: batch,
      newContent: newContent,
      recentReview: _recentWindow(
        byOrder: byOrder,
        startOrderInLevel: startOrderInLevel,
        pace: pace,
        taughtToday: newContent,
      ),
      distantReview: _blocks(
        batch.map((session) => session.distantReviewContent),
      ),
    );
  }

  /// Up to [pace] consecutive LESSONS from [start]. A non-lesson stands alone;
  /// a batch stops before the first session that is not a lesson of the same
  /// level, and before a hole in the data.
  static List<SessionModel> _batch(
    Map<int, SessionModel> byOrder,
    SessionModel start,
    CurriculumPace pace,
  ) {
    if (!start.isLesson) return [start];

    final batch = <SessionModel>[start];
    for (var step = 1; step < pace.multiplier; step++) {
      final next = byOrder[start.orderInLevel + step];
      if (next == null) break;
      if (!next.isLesson) break;
      if (next.levelId != start.levelId) break;
      batch.add(next);
    }
    return batch;
  }

  /// The new content of the previous 2N sessions — the previous two meetings'
  /// worth — with three exclusions:
  ///
  /// 1. sessions carrying no new content (a سرد, an اختبار);
  /// 2. sessions before the تلقين that opens this unit — the window never
  ///    reaches into the previous unit;
  /// 3. sessions whose new content this meeting is ITSELF teaching. This is
  ///    what zeroes the recent block for a unit's first lesson: the تلقين
  ///    before it read out the very passage it teaches, and a student cannot
  ///    review what he is learning today.
  static List<QuranContent> _recentWindow({
    required Map<int, SessionModel> byOrder,
    required int startOrderInLevel,
    required CurriculumPace pace,
    required List<QuranContent> taughtToday,
  }) {
    final windowStart = startOrderInLevel - 2 * pace.multiplier;
    final unitStart = _unitStart(byOrder, startOrderInLevel);
    final from = windowStart < unitStart ? unitStart : windowStart;

    final window = <QuranContent>[];
    for (var order = from; order < startOrderInLevel; order++) {
      final content = byOrder[order]?.currentLevelContent;
      if (content == null) continue;
      if (taughtToday.contains(content)) continue;
      window.add(content);
    }
    return window;
  }

  /// The first order of the unit containing [orderInLevel]: the order of the
  /// تلقين that opens it, or the order right after the previous unit's
  /// assessment (سرد/اختبار) if the scan reaches one first, or 1 if the level
  /// has neither before it (nothing to clamp against).
  ///
  /// The assessment check matters even though every unit in today's data opens
  /// with a تلقين: without it, a lesson run that ever begins WITHOUT one would
  /// let the window scan straight through an intervening سرد/اختبار and into
  /// the previous unit's content.
  static int _unitStart(Map<int, SessionModel> byOrder, int orderInLevel) {
    for (var order = orderInLevel; order >= 1; order--) {
      final session = byOrder[order];
      if (session?.isTalqeen ?? false) return order;
      if (session?.isAssessment ?? false) return order + 1;
    }
    return 1;
  }

  static List<QuranContent> _blocks(Iterable<QuranContent?> blocks) =>
      blocks.whereType<QuranContent>().toList();
}
