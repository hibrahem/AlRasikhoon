import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/models/student_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../shared/providers/user_provider.dart';

/// Provider for current student profile
final currentStudentProvider = FutureProvider<StudentModel?>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentByUserId(currentUser.id);
});

/// Provider for student's current session
final studentDashboardSessionProvider = FutureProvider<SessionModel?>((ref) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return null;

  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getCurrentSessionForStudent(
    levelId: student.currentLevel,
    juzNumber: student.currentJuz,
    hizbNumber: student.currentHizb,
    sessionNumber: student.currentSession,
  );
});

/// Provider for student's session history
final studentHistoryProvider =
    FutureProvider<List<SessionRecordModel>>((ref) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return [];

  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getSessionRecordsForStudent(student.id, limit: 50);
});

/// Provider for student statistics
final studentStatsProvider = FutureProvider<StudentStats>((ref) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return const StudentStats();

  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final stats = await sessionRepo.getStudentStatistics(student.id);

  return StudentStats(
    currentLevel: student.currentLevel,
    currentJuz: student.currentJuz,
    currentHizb: student.currentHizb,
    currentSession: student.currentSession,
    totalSessions: stats['total_sessions'] ?? 0,
    passedSessions: stats['passed_sessions'] ?? 0,
    completedLevels: student.completedLevels.length,
  );
});

class StudentStats {
  final int currentLevel;
  final int currentJuz;
  final int currentHizb;
  final int currentSession;
  final int totalSessions;
  final int passedSessions;
  final int completedLevels;

  const StudentStats({
    this.currentLevel = 1,
    this.currentJuz = 30,
    this.currentHizb = 59,
    this.currentSession = 1,
    this.totalSessions = 0,
    this.passedSessions = 0,
    this.completedLevels = 0,
  });

  double get passRate =>
      totalSessions > 0 ? passedSessions / totalSessions : 0;
}
