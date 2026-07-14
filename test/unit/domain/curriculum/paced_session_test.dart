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
  int level = 1,
  int juz = 30,
}) => SessionModel(
  id: 'L${level}_J${juz}_S$order',
  levelId: level,
  juzNumber: juz,
  sessionNumber: order,
  orderInLevel: order,
  kind: kind,
  currentLevelContent: newContent,
  recentReviewContent: recent,
  distantReviewContent: distant,
);

/// A unit shaped like the real curriculum: a تلقين that opens it, lessons whose
/// recent review is the previous two lessons' new content, then a سرد.
///
/// order 1  تلقين   new: النبأ 1-11
/// order 2  lesson  new: النبأ 1-11    (the تلقين's passage, now recited)
/// order 3  lesson  new: النبأ 12-20   recent: النبأ 1-11
/// order 4  lesson  new: النبأ 21-30   recent: النبأ 1-20
/// order 5  lesson  new: النبأ 31-37   recent: النبأ 12-30   distant: الفاتحة 1-3
/// order 6  lesson  new: النبأ 38-40   recent: النبأ 21-37   distant: الفاتحة 4-7
/// order 7  سرد
/// order 8  lesson   — trailing filler so the سرد's "stands alone" test is
///                      load-bearing: without the non-lesson guard it would
///                      batch forward into this row.
/// order 9  اختبار
/// order 10 lesson   — ditto, for the اختبار's "stands alone" test.
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
  _session(order: 7, kind: SessionKind.sard),
  _session(order: 8, newContent: _content('المرسلات', 1, 10)),
  _session(order: 9, kind: SessionKind.exam),
  _session(order: 10, newContent: _content('المرسلات', 11, 20)),
];

void main() {
  final pace1 = CurriculumPace.standard;
  final pace2 = CurriculumPace(2);
  final pace3 = CurriculumPace(3);

  group('a meeting at the standard pace is the session as authored', () {
    test('it covers exactly the one session it starts on', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace1,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [5]);
      expect(meeting.fromOrderInLevel, 5);
      expect(meeting.toOrderInLevel, 5);
      expect(meeting.isBatched, isFalse);
    });

    test('it reads the authored blocks verbatim, it does not compose them', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace1,
      );

      // The source curriculum has ~8 rows that disagree with its own window
      // rule. Composing at pace 1 would silently rewrite them for every
      // ordinary student, so pace 1 must not compose at all.
      expect(meeting.newContent, [_content('النبأ', 31, 37)]);
      expect(meeting.recentReview, [_content('النبأ', 12, 30)]);
      expect(meeting.distantReview, [_content('الفاتحة', 1, 3)]);
    });
  });

  group('a doubled meeting covers two lessons', () {
    test('its new content is both lessons\' new content', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [5, 6]);
      expect(meeting.fromOrderInLevel, 5);
      expect(meeting.toOrderInLevel, 6);
      expect(meeting.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(meeting.newContent, [
        _content('النبأ', 31, 37),
        _content('النبأ', 38, 40),
      ]);
    });

    test('it sweeps both lessons\' distant review', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      expect(meeting.distantReview, [
        _content('الفاتحة', 1, 3),
        _content('الفاتحة', 4, 7),
      ]);
    });

    test(
      'its recent review is the previous two meetings, not the two rows\' own blocks',
      () {
        final meeting = PacedSessionComposer.compose(
          levelSessions: _unit(),
          startOrderInLevel: 5,
          pace: pace2,
        );

        // The rows' own recent blocks union to النبأ 12-37, which contains
        // النبأ 31-37 — this meeting's OWN new content, taught minutes earlier.
        // The correct window is the new content of orders 1..4.
        expect(meeting.recentReview, [
          _content('النبأ', 1, 11), // order 1 تلقين
          _content('النبأ', 1, 11), // order 2
          _content('النبأ', 12, 20), // order 3
          _content('النبأ', 21, 30), // order 4
        ]);
      },
    );

    test('its recent review never overlaps its own new content', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace2,
      );

      for (final taught in meeting.newContent) {
        expect(
          meeting.recentReview,
          isNot(contains(taught)),
          reason: 'a student cannot review a passage he is learning today',
        );
      }
    });
  });

  group('the recent window respects the unit', () {
    test(
      'the unit\'s first lesson reviews nothing — the تلقين taught what it teaches',
      () {
        // Order 2 teaches النبأ 1-11, the very passage the تلقين at order 1 read
        // to the student. The authored curriculum gives this row no recent block,
        // and composition must reproduce that.
        final meeting = PacedSessionComposer.compose(
          levelSessions: _unit(),
          startOrderInLevel: 2,
          pace: pace2,
        );

        expect(meeting.recentReview, isEmpty);
      },
    );

    test(
      'the window never reaches back past the تلقين that opens the unit',
      () {
        // A previous unit, then this one. At pace 3 the window would span 6
        // sessions back — straight through the سرد and into the previous unit.
        final sessions = [
          _session(order: 1, newContent: _content('الفيل', 1, 5)),
          _session(order: 2, newContent: _content('قريش', 1, 4)),
          _session(order: 3, kind: SessionKind.sard),
          _session(
            order: 4,
            kind: SessionKind.talqeen,
            newContent: _content('النبأ', 1, 11),
          ),
          _session(order: 5, newContent: _content('النبأ', 1, 11)),
          _session(order: 6, newContent: _content('النبأ', 12, 20)),
          _session(order: 7, newContent: _content('النبأ', 21, 30)),
          _session(order: 8, newContent: _content('النبأ', 31, 37)),
        ];

        final meeting = PacedSessionComposer.compose(
          levelSessions: sessions,
          startOrderInLevel: 7,
          pace: pace3,
        );

        // Window would be orders 1..6. Clamped to the تلقين at 4, and the سرد
        // carries no new content anyway. الفيل and قريش must NOT appear.
        expect(meeting.recentReview, [
          _content('النبأ', 1, 11), // order 4 تلقين
          _content('النبأ', 1, 11), // order 5
          _content('النبأ', 12, 20), // order 6
        ]);
      },
    );

    test('the window still stops at the previous unit\'s سرد when this unit '
        'opens without a تلقين', () {
      // Nothing in today's curriculum lacks an opening تلقين, but a future
      // re-import could produce a lesson run with no تلقين before it. The
      // clamp must still stop at the previous unit's assessment, not walk
      // past it looking for a تلقين that will never come.
      final sessions = [
        _session(order: 1, newContent: _content('الفيل', 1, 5)),
        _session(order: 2, newContent: _content('قريش', 1, 4)),
        _session(order: 3, kind: SessionKind.sard),
        _session(order: 4, newContent: _content('النبأ', 1, 11)),
        _session(order: 5, newContent: _content('النبأ', 12, 20)),
        _session(order: 6, newContent: _content('النبأ', 21, 30)),
        _session(order: 7, newContent: _content('النبأ', 31, 37)),
        _session(order: 8, newContent: _content('النبأ', 38, 40)),
        _session(order: 9, newContent: _content('المرسلات', 1, 10)),
      ];

      final meeting = PacedSessionComposer.compose(
        levelSessions: sessions,
        startOrderInLevel: 7,
        pace: pace3,
      );

      // Window would be orders 1..6, reaching straight through the سرد into
      // the previous unit. Clamped to the order right after the سرد at 3,
      // i.e. order 4. الفيل and قريش — the previous unit's content — must
      // NOT appear.
      expect(meeting.recentReview, [
        _content('النبأ', 1, 11), // order 4
        _content('النبأ', 12, 20), // order 5
        _content('النبأ', 21, 30), // order 6
      ]);
    });
  });

  group('only lessons batch', () {
    test('a تلقين stands alone however fast the student is', () {
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 1,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [1]);
      expect(meeting.isBatched, isFalse);
      expect(meeting.newContent, [_content('النبأ', 1, 11)]);
    });

    test('a سرد stands alone however fast the student is', () {
      // Order 8 is a lesson right after the سرد: if the non-lesson guard were
      // missing, a 3x meeting starting at the سرد would batch forward into it.
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 7,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [7]);
      expect(meeting.isBatched, isFalse);
    });

    test('an اختبار stands alone however fast the student is', () {
      // Order 10 is a lesson right after the اختبار: if the non-lesson guard
      // were missing, a 3x meeting starting at the اختبار would batch forward
      // into it, the same way the سرد case above would.
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 9,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [9]);
      expect(meeting.isBatched, isFalse);
    });

    test('a batch stops before the سرد rather than swallowing it', () {
      // Orders 5, 6 are lessons; 7 is the سرد. A 3x meeting starting at 5 takes
      // only the two lessons.
      final meeting = PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 5,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [5, 6]);
      expect(meeting.toOrderInLevel, 6);
    });

    test('a batch stops at the end of the level', () {
      final sessions = [
        _session(order: 1, newContent: _content('النبأ', 1, 11)),
        _session(order: 2, newContent: _content('النبأ', 12, 20)),
      ];

      final meeting = PacedSessionComposer.compose(
        levelSessions: sessions,
        startOrderInLevel: 2,
        pace: pace3,
      );

      expect(meeting.sessions.map((s) => s.orderInLevel), [2]);
      expect(meeting.toOrderInLevel, 2);
    });
  });

  test('composing from a session the level does not have is an error', () {
    expect(
      () => PacedSessionComposer.compose(
        levelSessions: _unit(),
        startOrderInLevel: 99,
        pace: pace1,
      ),
      throwsArgumentError,
    );
  });
}
