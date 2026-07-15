import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/shared/providers/meeting_provider.dart';

Future<void> _seedSession(
  FakeFirebaseFirestore db, {
  required int order,
  required String kind,
  Map<String, dynamic>? current,
}) async {
  await db.collection('sessions').doc('L1_S$order').set({
    'level_id': 1,
    'juz_number': 30,
    'session_number': order,
    'order_in_level': order,
    'kind': kind,
    'hizb_number': 59,
    if (current != null) 'current_level_content': current,
  });
}

StudentModel _student() => StudentModel(
  id: 'student-1',
  userId: 'user-1',
  instituteId: 'i1',
  teacherId: 't1',
  currentLevel: 1,
  currentJuz: 30,
  currentHizb: 59,
  currentSession: 1,
  currentAttempt: 1,
  currentOrderInLevel: 2,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  test('composeNextMeetingAfter composes the row after the meeting', () async {
    final db = FakeFirebaseFirestore();
    await _seedSession(
      db,
      order: 2,
      kind: 'lesson',
      current: {
        'from_surah': 'النبأ',
        'from_verse': 1,
        'to_surah': 'النبأ',
        'to_verse': 11,
      },
    );
    await _seedSession(
      db,
      order: 3,
      kind: 'lesson',
      current: {
        'from_surah': 'النبأ',
        'from_verse': 12,
        'to_surah': 'النبأ',
        'to_verse': 20,
      },
    );

    final container = ProviderContainer(
      overrides: [
        curriculumRepositoryProvider.overrideWithValue(
          CurriculumRepository(firestore: db),
        ),
      ],
    );
    addTearDown(container.dispose);

    final levelSessions = await container
        .read(curriculumRepositoryProvider)
        .getSessionsForLevel(level: 1);
    final current = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: 2,
      pace: CurriculumPace(1),
    );

    final next = await composeNextMeetingAfter(
      container.read(_refProvider), // see note
      _student(),
      current,
    );
    expect(next, isNotNull);
    expect(next!.fromOrderInLevel, 3);
    expect(next.newContentAr, contains('12'));
  });

  test('composeNextMeetingAfter returns null past the last session', () async {
    final db = FakeFirebaseFirestore();
    await _seedSession(
      db,
      order: 2,
      kind: 'lesson',
      current: {
        'from_surah': 'النبأ',
        'from_verse': 1,
        'to_surah': 'النبأ',
        'to_verse': 11,
      },
    );

    final container = ProviderContainer(
      overrides: [
        curriculumRepositoryProvider.overrideWithValue(
          CurriculumRepository(firestore: db),
        ),
      ],
    );
    addTearDown(container.dispose);

    final levelSessions = await container
        .read(curriculumRepositoryProvider)
        .getSessionsForLevel(level: 1);
    final current = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: 2,
      pace: CurriculumPace(1),
    );

    final next = await composeNextMeetingAfter(
      container.read(_refProvider),
      _student(),
      current,
    );
    expect(next, isNull);
  });
}

/// `composeNextMeetingAfter` takes a `Ref`. Expose the container's Ref to the
/// test through a trivial provider.
final _refProvider = Provider<Ref>((ref) => ref);
