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
