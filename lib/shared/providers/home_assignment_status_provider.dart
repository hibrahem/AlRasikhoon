import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/home_practice_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/session/home_practice_log.dart';

/// The CURRENT home assignment of one student, as seen by whoever is about to
/// hear them: what the last session required, what the student actually
/// logged at home, and when each submission happened.
class HomeAssignmentStatus {
  /// The curriculum session the assignment was set in — the student's LAST
  /// completed session, whose record carries `home_repetitions_required`.
  final String curriculumSessionId;
  final int repetitionsRequired;

  /// Every practice the student logged against this assignment, newest
  /// first — the dates are the point: they say WHEN the homework happened,
  /// not just that a total exists.
  final List<HomePracticeLog> practices;

  const HomeAssignmentStatus({
    required this.curriculumSessionId,
    required this.repetitionsRequired,
    required this.practices,
  });

  int get repetitionsDone =>
      practices.fold(0, (total, p) => total + p.repetitions);

  bool get isComplete => repetitionsDone >= repetitionsRequired;
}

/// One student's current home-assignment status, for the teacher's
/// pre-session view and the supervisor/admin progress view — the OTHER side
/// of the student-facing `homeAssignmentProvider`, keyed by student id
/// because the viewer here is never the student.
///
/// Null when the student has no session record yet, or when their last
/// session assigned no home repetitions — either way there is no assignment
/// to report on. Deliberately mirrors `homeAssignmentProvider`'s attribution
/// rule (practices whose `curriculumSessionId` equals the latest record's),
/// so the teacher and the student always read the SAME done-count for the
/// same assignment.
final homeAssignmentStatusProvider =
    FutureProvider.family<HomeAssignmentStatus?, String>((
      ref,
      studentId,
    ) async {
      final sessionRepo = ref.watch(sessionRepositoryProvider);
      final record = await sessionRepo.getLatestSessionRecord(studentId);
      if (record == null || record.homeRepetitionsRequired <= 0) return null;

      final practices = await ref
          .watch(homePracticeRepositoryProvider)
          .getHomePracticesForStudent(studentId);

      final logs = [
        for (final p in practices)
          if (p.curriculumSessionId == record.curriculumSessionId)
            HomePracticeLog(date: p.practiceDate, repetitions: p.repetitions),
      ];

      return HomeAssignmentStatus(
        curriculumSessionId: record.curriculumSessionId,
        repetitionsRequired: record.homeRepetitionsRequired,
        practices: logs,
      );
    });
