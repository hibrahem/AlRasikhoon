import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/level_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/completion_forecast.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/meetings_per_week.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

/// The forecast's one hard claim: `meetingsAtPace` counts EXACTLY the meetings
/// [PacedSessionComposer] would compose — lessons batch up to the pace,
/// a تلقين/سرد/اختبار stands alone, a batch breaks at an order hole and never
/// crosses a level. These tests pin the encoding directly and then replay the
/// composer itself over synthetic levels as the oracle.
void main() {
  SessionModel row(int level, int order, SessionKind kind) => SessionModel(
    id: 'L${level}_O$order',
    levelId: level,
    juzNumber: 30,
    sessionNumber: order,
    orderInLevel: order,
    kind: kind,
  );

  LevelModel level(int number) => LevelModel(
    id: 'level_$number',
    levelNumber: number,
    nameAr: 'المستوى $number',
    nameEn: 'Level $number',
    juzNumbers: const [30],
    sessionCount: 0,
    order: number,
  );

  /// Counts meetings by walking the composer itself — the production batching
  /// rules, applied one meeting at a time.
  int meetingsByComposer(
    List<SessionModel> rows,
    int fromOrder,
    CurriculumPace pace,
  ) {
    final orders = rows.map((r) => r.orderInLevel).toSet();
    final maxOrder = orders.reduce((a, b) => a > b ? a : b);
    var order = fromOrder;
    var meetings = 0;
    while (order <= maxOrder) {
      if (!orders.contains(order)) {
        order++;
        continue;
      }
      final meeting = PacedSessionComposer.compose(
        levelSessions: rows,
        startOrderInLevel: order,
        pace: pace,
      );
      meetings++;
      order = meeting.toOrderInLevel + 1;
    }
    return meetings;
  }

  group('RemainingCurriculum', () {
    test('lessons batch, assessments stand alone', () {
      // lesson ×4, سرد, lesson ×2, اختبار
      final rows = [
        row(1, 1, SessionKind.lesson),
        row(1, 2, SessionKind.lesson),
        row(1, 3, SessionKind.lesson),
        row(1, 4, SessionKind.lesson),
        row(1, 5, SessionKind.sard),
        row(1, 6, SessionKind.lesson),
        row(1, 7, SessionKind.lesson),
        row(1, 8, SessionKind.exam),
      ];
      final remaining = RemainingCurriculum.of(
        currentLevel: 1,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: [level(1)],
        sessionsByLevel: {1: rows},
      );

      expect(remaining.standaloneCount, 2);
      expect(remaining.lessonRuns, [4, 2]);
      expect(remaining.remainingRows, 8);

      expect(remaining.meetingsAtPace(CurriculumPace(1)), 8);
      expect(remaining.meetingsAtPace(CurriculumPace(2)), 5); // 2+2+1
      expect(remaining.meetingsAtPace(CurriculumPace(3)), 5); // 2+2+1
      expect(remaining.meetingsAtPace(CurriculumPace(10)), 4); // 2+1+1
    });

    test('rows behind the student do not count', () {
      final rows = [
        row(1, 1, SessionKind.lesson),
        row(1, 2, SessionKind.lesson),
        row(1, 3, SessionKind.sard),
        row(1, 4, SessionKind.lesson),
        row(1, 5, SessionKind.lesson),
      ];
      final remaining = RemainingCurriculum.of(
        currentLevel: 1,
        currentOrderInLevel: 4,
        curriculumCompleted: false,
        levels: [level(1)],
        sessionsByLevel: {1: rows},
      );

      expect(remaining.standaloneCount, 0);
      expect(remaining.lessonRuns, [2]);
    });

    test('a hole in order_in_level breaks a run, as it breaks a batch', () {
      final rows = [
        row(1, 1, SessionKind.lesson),
        row(1, 2, SessionKind.lesson),
        // order 3 missing
        row(1, 4, SessionKind.lesson),
        row(1, 5, SessionKind.lesson),
      ];
      final remaining = RemainingCurriculum.of(
        currentLevel: 1,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: [level(1)],
        sessionsByLevel: {1: rows},
      );

      expect(remaining.lessonRuns, [2, 2]);
      // At pace 4 the difference shows: one unbroken run of 4 would be a
      // single meeting; the broken runs take two.
      expect(remaining.meetingsAtPace(CurriculumPace(4)), 2);
    });

    test('a run never crosses a level boundary', () {
      final remaining = RemainingCurriculum.of(
        currentLevel: 1,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: [level(1), level(2)],
        sessionsByLevel: {
          1: [row(1, 1, SessionKind.lesson), row(1, 2, SessionKind.lesson)],
          2: [row(2, 1, SessionKind.lesson), row(2, 2, SessionKind.lesson)],
        },
      );

      expect(remaining.lessonRuns, [2, 2]);
      expect(remaining.meetingsAtPace(CurriculumPace(4)), 2);
    });

    test('levels behind the student contribute nothing', () {
      final remaining = RemainingCurriculum.of(
        currentLevel: 2,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: [level(1), level(2)],
        sessionsByLevel: {
          1: [row(1, 1, SessionKind.lesson)],
          2: [row(2, 1, SessionKind.lesson), row(2, 2, SessionKind.exam)],
        },
      );

      expect(remaining.remainingRows, 2);
    });

    test('a completed curriculum has nothing remaining', () {
      final remaining = RemainingCurriculum.of(
        currentLevel: 10,
        currentOrderInLevel: 50,
        curriculumCompleted: true,
        levels: [level(10)],
        sessionsByLevel: {
          10: [row(10, 50, SessionKind.exam)],
        },
      );

      expect(remaining.isFinished, isTrue);
      expect(remaining.meetingsAtPace(CurriculumPace(3)), 0);
    });

    test('a level missing from the map contributes nothing, not a crash', () {
      final remaining = RemainingCurriculum.of(
        currentLevel: 1,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: [level(1), level(2)],
        sessionsByLevel: {
          1: [row(1, 1, SessionKind.lesson)],
        },
      );

      expect(remaining.remainingRows, 1);
    });

    test('meetingsAtPace agrees with the composer replayed over the level', () {
      // A gauntlet of shapes: تلقين openers, lesson runs of odd lengths,
      // back-to-back assessments, a trailing lone lesson, and a hole.
      final kinds = [
        SessionKind.talqeen, // 1
        SessionKind.lesson, // 2
        SessionKind.lesson, // 3
        SessionKind.lesson, // 4
        SessionKind.lesson, // 5
        SessionKind.lesson, // 6
        SessionKind.sard, // 7
        SessionKind.exam, // 8
        SessionKind.talqeen, // 9
        SessionKind.lesson, // 10
        SessionKind.lesson, // 11
        SessionKind.lesson, // 12 (order 13 is a hole)
        SessionKind.lesson, // 14
        SessionKind.sard, // 15
        SessionKind.lesson, // 16
      ];
      final rows = <SessionModel>[];
      var order = 0;
      for (final kind in kinds) {
        order++;
        if (order == 13) order++; // the hole
        rows.add(row(1, order, kind));
      }

      for (var pace = 1; pace <= CurriculumPace.maxMultiplier; pace++) {
        for (final fromOrder in [1, 2, 5, 9, 14]) {
          final remaining = RemainingCurriculum.of(
            currentLevel: 1,
            currentOrderInLevel: fromOrder,
            curriculumCompleted: false,
            levels: [level(1)],
            sessionsByLevel: {1: rows},
          );
          expect(
            remaining.meetingsAtPace(CurriculumPace(pace)),
            meetingsByComposer(rows, fromOrder, CurriculumPace(pace)),
            reason: 'pace $pace from order $fromOrder',
          );
        }
      }
    });
  });

  group('CompletionForecast', () {
    const remaining = RemainingCurriculum(
      standaloneCount: 2,
      lessonRuns: [4, 2],
    );

    test('weeks round up — the last partial week counts in full', () {
      final forecast = CompletionForecast.of(
        remaining: remaining,
        pace: CurriculumPace(2), // 5 meetings
        meetingsPerWeek: MeetingsPerWeek(2),
      );
      expect(forecast.remainingMeetings, 5);
      expect(forecast.weeks, 3);
    });

    test('the completion date is weeks of seven days from today', () {
      final forecast = CompletionForecast.of(
        remaining: remaining,
        pace: CurriculumPace(2),
        meetingsPerWeek: MeetingsPerWeek(2),
      );
      expect(
        forecast.completionDate(DateTime(2026, 1, 1)),
        DateTime(2026, 1, 22),
      );
    });

    test('a finished student needs zero weeks', () {
      final forecast = CompletionForecast.of(
        remaining: RemainingCurriculum.none,
        pace: CurriculumPace.standard,
        meetingsPerWeek: MeetingsPerWeek.standard,
      );
      expect(forecast.isFinished, isTrue);
      expect(forecast.weeks, 0);
    });
  });
}
