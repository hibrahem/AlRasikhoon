import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

QuranContent _c(String surah, int from, int to) => QuranContent(
  fromSurah: surah,
  fromVerse: from,
  toSurah: surah,
  toVerse: to,
);

SessionModel _lesson() => SessionModel(
  id: 'L1_J30_S1',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: 1,
  orderInLevel: 1,
  kind: SessionKind.lesson,
);

PacedSession _meeting({
  required List<QuranContent> newC,
  required List<QuranContent> recent,
  required List<QuranContent> distant,
}) => PacedSession(
  sessions: [_lesson()],
  newContent: newC,
  recentReview: recent,
  distantReview: distant,
);

void main() {
  test('present parts include new plus only the non-empty review streams', () {
    final all = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [_c('النبأ', 1, 5)],
      distant: [_c('الفاتحة', 1, 7)],
    );
    expect(all.presentParts, [1, 2, 3]);

    final noRecent = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [],
      distant: [_c('الفاتحة', 1, 7)],
    );
    expect(noRecent.presentParts, [1, 3]);

    final noReview = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [],
      distant: [],
    );
    expect(noReview.presentParts, [1]);
  });

  test('new memorization part is present even when its content is empty', () {
    final reviewOnly = _meeting(
      newC: [],
      recent: [_c('النبأ', 1, 5)],
      distant: [],
    );
    expect(reviewOnly.presentParts, [1, 2]);
  });

  test('partAfter walks present parts and returns null past the last', () {
    final skipRecent = _meeting(
      newC: [_c('النبأ', 1, 11)],
      recent: [],
      distant: [_c('الفاتحة', 1, 7)],
    );
    expect(skipRecent.partAfter(1), 3); // recent skipped
    expect(skipRecent.partAfter(3), isNull); // last present part
    expect(skipRecent.partAfter(2), isNull); // 2 not present
  });
}
