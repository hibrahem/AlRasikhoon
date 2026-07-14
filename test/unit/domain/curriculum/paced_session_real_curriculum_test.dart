import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

/// The curriculum as it ships, read from `data/curriculum/` — not fixtures.
///
/// Fixtures cannot prove this: the claim is about the REAL 952 sessions, whose
/// source data is known to contain ~8 rows that disagree with its own window
/// rule (see al_rasikhoon-drw). Those rows are exactly the ones that would break
/// if pace 1 ever started composing.
List<SessionModel> _sessionsOfLevel(int level) {
  final file = File('data/curriculum/sessions_level_$level.json');
  final decoded = jsonDecode(file.readAsStringSync());
  final rows = decoded is Map<String, dynamic>
      ? (decoded['sessions'] as List)
      : (decoded as List);

  return rows.map((row) {
    final json = Map<String, dynamic>.from(row as Map);
    final id =
        'L${json['level_id']}_J${json['juz_number']}_S${json['session_number']}';
    return SessionModel.fromJson(id, json);
  }).toList();
}

void main() {
  final levels = [for (var level = 1; level <= 10; level++) level];

  group('the standard pace leaves the curriculum exactly as authored', () {
    for (final level in levels) {
      test('level $level: every session composes to its own blocks', () {
        final sessions = _sessionsOfLevel(level);
        expect(sessions, isNotEmpty, reason: 'level $level has no sessions');

        for (final session in sessions) {
          final meeting = PacedSessionComposer.compose(
            levelSessions: sessions,
            startOrderInLevel: session.orderInLevel,
            pace: CurriculumPace.standard,
          );

          expect(
            meeting.coversSessionIds,
            [session.id],
            reason: '${session.id} must stand alone at the standard pace',
          );
          expect(
            meeting.newContent,
            session.currentLevelContent == null
                ? isEmpty
                : [session.currentLevelContent],
            reason: '${session.id} new content was rewritten',
          );
          expect(
            meeting.recentReview,
            session.recentReviewContent == null
                ? isEmpty
                : [session.recentReviewContent],
            reason: '${session.id} recent review was rewritten',
          );
          expect(
            meeting.distantReview,
            session.distantReviewContent == null
                ? isEmpty
                : [session.distantReviewContent],
            reason: '${session.id} distant review was rewritten',
          );
        }
      });
    }
  });

  group('a doubled student never reviews what he is learning today', () {
    for (final level in levels) {
      test('level $level: recent review never intersects new content', () {
        final sessions = _sessionsOfLevel(level);

        for (final session in sessions) {
          final meeting = PacedSessionComposer.compose(
            levelSessions: sessions,
            startOrderInLevel: session.orderInLevel,
            pace: CurriculumPace(2),
          );

          for (final taught in meeting.newContent) {
            expect(
              meeting.recentReview,
              isNot(contains(taught)),
              reason:
                  'a 2x meeting at ${session.id} asks the student to review '
                  '${taught.rangeAr}, which it is teaching him today',
            );
          }
        }
      });
    }
  });

  group('an assessment is never swallowed by a fast student', () {
    for (final level in levels) {
      test('level $level: no batch contains a سرد, an اختبار or a تلقين', () {
        final sessions = _sessionsOfLevel(level);

        for (final session in sessions) {
          for (final multiplier in [2, 3, 5]) {
            final meeting = PacedSessionComposer.compose(
              levelSessions: sessions,
              startOrderInLevel: session.orderInLevel,
              pace: CurriculumPace(multiplier),
            );

            if (meeting.isBatched) {
              expect(
                meeting.sessions.every((s) => s.isLesson),
                isTrue,
                reason:
                    'a ${multiplier}x meeting at ${session.id} batched a '
                    'session that is not a lesson',
              );
            } else {
              expect(meeting.coversSessionIds, [session.id]);
            }
          }
        }
      });
    }
  });
}
