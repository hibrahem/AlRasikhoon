import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/curriculum_repository.dart';
import '../../data/models/student_model.dart';
import '../../domain/curriculum/paced_session.dart';

/// Composes the meeting [student] currently stands on.
///
/// Shared by the teacher, supervisor and student-dashboard meeting providers,
/// which differ only in how they RESOLVE the student (teacher-scoped,
/// institute-scoped per AgDR-0003, or the signed-in student). The composition
/// itself is one rule and lives in one place — here, rather than in any one
/// feature, since all three features need it.
Future<PacedSession?> composeMeetingFor(Ref ref, StudentModel student) async {
  final curriculumRepo = ref.watch(curriculumRepositoryProvider);

  final levelSessions = await curriculumRepo.getSessionsForLevel(
    level: student.currentLevel,
  );
  if (levelSessions.isEmpty) return null;

  return PacedSessionComposer.compose(
    levelSessions: levelSessions,
    startOrderInLevel: student.currentOrderInLevel,
    pace: student.pace,
  );
}

/// Composes the meeting the student will stand on AFTER completing [current],
/// used to preview the next new passage before a session closes.
///
/// Composes at `current.toOrderInLevel + 1` within the student's CURRENT
/// level, at the student's live pace — the same rule as [composeMeetingFor].
/// Returns null when no session stands at that order (end of level: the next
/// passage lives in the next level, which this preview deliberately does not
/// load) or when the level has no rows.
Future<PacedSession?> composeNextMeetingAfter(
  Ref ref,
  StudentModel student,
  PacedSession current,
) async {
  final curriculumRepo = ref.watch(curriculumRepositoryProvider);

  final levelSessions = await curriculumRepo.getSessionsForLevel(
    level: student.currentLevel,
  );
  if (levelSessions.isEmpty) return null;

  final nextOrder = current.toOrderInLevel + 1;
  final hasNext = levelSessions.any(
    (session) => session.orderInLevel == nextOrder,
  );
  if (!hasNext) return null;

  return PacedSessionComposer.compose(
    levelSessions: levelSessions,
    startOrderInLevel: nextOrder,
    pace: student.pace,
  );
}
