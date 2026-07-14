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

      test(
        'blocks in different surahs are never merged: the app cannot know '
        'a surah was finished, even when the next block opens at verse 1',
        () {
          // Different surah, next.fromVerse == 1: this LOOKS like the previous
          // surah just finished and the next one picked up immediately, but the
          // app deliberately does not know surah lengths, so it cannot tell
          // that النبأ actually ended at verse 38. Merging would silently claim
          // النبأ 39-40 that no curriculum row assigned to this meeting — the
          // same class of bug as the same-surah gap case below, just across a
          // surah boundary instead of within one surah.
          final meeting = PacedSession(
            sessions: [_session(order: 6), _session(order: 8)],
            newContent: [
              _content('النبأ', 38, 38),
              QuranContent(
                fromSurah: 'النازعات',
                fromVerse: 1,
                toSurah: 'النازعات',
                toVerse: 14,
              ),
            ],
            recentReview: const [],
            distantReview: const [],
          );

          expect(meeting.newContentAr, 'النبأ: 38 • النازعات: 1 - 14');
        },
      );

      test('level 9\'s distant cursor skipping هود 29-123 must never render '
          'as هود: 1 إلى يوسف: 111 — a cross-surah run always stays separate '
          'blocks', () {
        // Real curriculum data (level 9, distant review): order 13's block is
        // هود 1-28, order 14's block is يوسف 1-111. هود has 123 verses; the
        // curriculum simply skips هود 29-123 at this cursor position. The old
        // rule saw "يوسف starts at verse 1" and merged the two into
        // "هود: 1 إلى يوسف: 111", claiming ~95 verses of هود that no
        // curriculum row assigned to this meeting.
        final meeting = PacedSession(
          sessions: [_session(order: 13), _session(order: 14)],
          newContent: const [],
          recentReview: const [],
          distantReview: [_content('هود', 1, 28), _content('يوسف', 1, 111)],
        );

        expect(meeting.distantReviewAr, 'هود: 1 - 28 • يوسف: 1 - 111');
      });

      test('two blocks in the SAME surah with a verse GAP stay separate — '
          'merging them would claim verses neither block covers', () {
        // Same surah is NOT by itself contiguous: النبأ 1-11 then النبأ
        // 30-40 leaves verses 12-29 unaccounted for. Merging would invent
        // content nobody assigned. This is the bug the old
        // `next.fromSurah == prev.toSurah` clause let through.
        final meeting = PacedSession(
          sessions: [_session(order: 1), _session(order: 6)],
          newContent: [_content('النبأ', 1, 11), _content('النبأ', 30, 40)],
          recentReview: const [],
          distantReview: const [],
        );

        expect(meeting.newContentAr, 'النبأ: 1 - 11 • النبأ: 30 - 40');
      });

      test('two blocks across a SURAH BOUNDARY where the next one does NOT '
          'open at verse 1 stay separate', () {
        // Different surah, and next.fromVerse != 1: nothing says the second
        // block picks up where the first left off.
        final meeting = PacedSession(
          sessions: [_session(order: 6), _session(order: 8)],
          newContent: [
            _content('النبأ', 38, 40),
            QuranContent(
              fromSurah: 'النازعات',
              fromVerse: 5,
              toSurah: 'النازعات',
              toVerse: 14,
            ),
          ],
          recentReview: const [],
          distantReview: const [],
        );

        expect(meeting.newContentAr, 'النبأ: 38 - 40 • النازعات: 5 - 14');
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
