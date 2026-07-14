import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

QuranContent _content(String surah, int from, int to) => QuranContent(
  fromSurah: surah,
  fromVerse: from,
  toSurah: surah,
  toVerse: to,
);

SessionModel _session({
  required int order,
  SessionKind kind = SessionKind.lesson,
  QuranContent? newContent,
  QuranContent? recent,
  QuranContent? distant,
}) => SessionModel(
  id: 'L1_J30_S$order',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: order,
  orderInLevel: order,
  kind: kind,
  currentLevelContent: newContent,
  recentReviewContent: recent,
  distantReviewContent: distant,
);

/// The same unit shape `paced_session_real_curriculum_test.dart` composes
/// from: a تلقين that opens it, lessons whose recent review is a sliding
/// window over the previous two lessons' new content, then a سرد.
///
/// order 1  تلقين   new: النبأ 1-11
/// order 2  lesson  new: النبأ 1-11    (the تلقين's passage, now recited)
/// order 3  lesson  new: النبأ 12-20   recent: النبأ 1-11
/// order 4  lesson  new: النبأ 21-30   recent: النبأ 1-20
/// order 5  lesson  new: النبأ 31-37   recent: النبأ 12-30   distant: الفاتحة 1-3
/// order 6  lesson  new: النبأ 38-40   recent: النبأ 21-37   distant: الفاتحة 4-7
List<SessionModel> _unit() => [
  _session(
    order: 1,
    kind: SessionKind.talqeen,
    newContent: _content('النبأ', 1, 11),
  ),
  _session(order: 2, newContent: _content('النبأ', 1, 11)),
  _session(
    order: 3,
    newContent: _content('النبأ', 12, 20),
    recent: _content('النبأ', 1, 11),
  ),
  _session(
    order: 4,
    newContent: _content('النبأ', 21, 30),
    recent: _content('النبأ', 1, 20),
  ),
  _session(
    order: 5,
    newContent: _content('النبأ', 31, 37),
    recent: _content('النبأ', 12, 30),
    distant: _content('الفاتحة', 1, 3),
  ),
  _session(
    order: 6,
    newContent: _content('النبأ', 38, 40),
    recent: _content('النبأ', 21, 37),
    distant: _content('الفاتحة', 4, 7),
  ),
];

void main() {
  group(
    'the merged display line — de-duplicate, then merge contiguous runs',
    () {
      test('an empty stream has no line and no content', () {
        final meeting = PacedSession(
          sessions: [_session(order: 5)],
          newContent: const [],
          recentReview: const [],
          distantReview: const [],
        );

        expect(meeting.newContentAr, '');
        expect(meeting.hasNewContent, isFalse);
      });

      test('a single block renders as-is', () {
        final meeting = PacedSession(
          sessions: [_session(order: 5)],
          newContent: [_content('النبأ', 31, 37)],
          recentReview: const [],
          distantReview: const [],
        );

        expect(meeting.newContentAr, 'النبأ: 31 - 37');
        expect(meeting.hasNewContent, isTrue);
      });

      test('two contiguous blocks in one surah merge into one range', () {
        final meeting = PacedSession(
          sessions: [_session(order: 5), _session(order: 6)],
          newContent: [_content('النبأ', 31, 37), _content('النبأ', 38, 40)],
          recentReview: const [],
          distantReview: const [],
        );

        expect(meeting.newContentAr, 'النبأ: 31 - 40');
      });

      test('two blocks across a SURAH BOUNDARY whose verse numbers run on are '
          'contiguous — the curriculum merges these too', () {
        // fromVerse (39) == prev.toVerse + 1 (38 + 1) even though the surah
        // changes: contiguity is a run-on of the numbers, not a same-surah
        // check.
        final meeting = PacedSession(
          sessions: [_session(order: 6), _session(order: 8)],
          newContent: [
            _content('النبأ', 38, 38),
            QuranContent(
              fromSurah: 'النازعات',
              fromVerse: 39,
              toSurah: 'النازعات',
              toVerse: 14,
            ),
          ],
          recentReview: const [],
          distantReview: const [],
        );

        expect(meeting.newContentAr, 'النبأ: 38 إلى النازعات: 14');
      });

      test('two genuinely non-contiguous blocks stay separate', () {
        // Different surahs AND a verse gap — neither half of the contiguity
        // rule holds.
        final meeting = PacedSession(
          sessions: [_session(order: 5), _session(order: 6)],
          newContent: const [],
          recentReview: const [],
          distantReview: [
            _content('الفاتحة', 1, 3),
            _content('المرسلات', 5, 10),
          ],
        );

        expect(meeting.distantReviewAr, 'الفاتحة: 1 - 3 • المرسلات: 5 - 10');
      });

      test('a duplicate pair collapses to one block before merging', () {
        final meeting = PacedSession(
          sessions: [_session(order: 1), _session(order: 2)],
          newContent: const [],
          recentReview: [_content('النبأ', 1, 11), _content('النبأ', 1, 11)],
          distantReview: const [],
        );

        expect(meeting.recentReviewAr, 'النبأ: 1 - 11');
      });

      test('a 2x meeting\'s recent window drops the تلقين duplicate then merges '
          'the remaining rows into one range', () {
        // Orders 1-4's new content, exactly as `_recentWindow` would hand a
        // 2x meeting standing at order 5: the تلقين (1-11) and order 2 (1-11)
        // are the same block — one is dropped — then 1-11, 12-20, 21-30 merge.
        final meeting = PacedSession(
          sessions: [_session(order: 5), _session(order: 6)],
          newContent: const [],
          recentReview: [
            _content('النبأ', 1, 11),
            _content('النبأ', 1, 11),
            _content('النبأ', 12, 20),
            _content('النبأ', 21, 30),
          ],
          distantReview: const [],
        );

        expect(meeting.recentReviewAr, 'النبأ: 1 - 30');
      });

      test('a whole 2x meeting renders all three streams merged', () {
        final meeting = PacedSessionComposer.compose(
          levelSessions: _unit(),
          startOrderInLevel: 5,
          pace: CurriculumPace(2),
        );

        expect(meeting.newContentAr, 'النبأ: 31 - 40');
        expect(meeting.recentReviewAr, 'النبأ: 1 - 30');
        expect(meeting.distantReviewAr, 'الفاتحة: 1 - 7');
      });

      // No-regression pin: a 1x meeting has exactly one block per stream, so
      // de-dupe and merge are both no-ops — the line is byte-identical to what
      // the screen rendered before this feature (`session.rangeAr`).
      test('a 1x meeting is a no-op for de-dupe and merge: the line is '
          'byte-identical to the block it was composed from', () {
        final meeting = PacedSessionComposer.compose(
          levelSessions: _unit(),
          startOrderInLevel: 5,
          pace: CurriculumPace.standard,
        );

        expect(meeting.newContentAr, _content('النبأ', 31, 37).rangeAr);
        expect(meeting.recentReviewAr, _content('النبأ', 12, 30).rangeAr);
        expect(meeting.distantReviewAr, _content('الفاتحة', 1, 3).rangeAr);
      });
    },
  );

  group('hasNewContent / hasRecentReview / hasDistantReview', () {
    test('true when the stream has at least one block', () {
      final meeting = PacedSession(
        sessions: [_session(order: 5)],
        newContent: [_content('النبأ', 31, 37)],
        recentReview: const [],
        distantReview: const [],
      );

      expect(meeting.hasNewContent, isTrue);
      expect(meeting.hasRecentReview, isFalse);
      expect(meeting.hasDistantReview, isFalse);
    });
  });
}
