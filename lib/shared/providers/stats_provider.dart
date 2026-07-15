import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/student_repository.dart';
import 'current_student_provider.dart';
import 'institute_provider.dart';
import 'user_provider.dart';

/// At-a-glance activity/progress figures shown on the shared account screen.
///
/// Both providers are role-agnostic by construction: each depends only on the
/// shared [currentUserProvider] / [currentStudentProvider] and the data-layer
/// repositories, so they live in `shared/providers` rather than the teacher or
/// student feature. This lets the shared account screen render its stats cards
/// without reaching into a feature package.

/// A teacher's at-a-glance activity, shown on the profile screen.
class TeacherStats {
  final int totalSessions;
  final int sessionsThisMonth;
  final int studentCount;
  final int instituteCount;

  const TeacherStats({
    this.totalSessions = 0,
    this.sessionsThisMonth = 0,
    this.studentCount = 0,
    this.instituteCount = 0,
  });
}

/// Composes the signed-in teacher's profile stats: an all-time and a
/// this-month session count (cheap `.count()` queries), plus the roster and
/// institute sizes.
final teacherStatsProvider = FutureProvider<TeacherStats>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const TeacherStats();

  final studentRepo = ref.watch(studentRepositoryProvider);
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final students = await studentRepo.getStudentsForTeacher(currentUser.id);
  final institutes = await ref.watch(teacherInstitutesProvider.future);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final totalSessions = await sessionRepo.getSessionCountForTeacher(
    currentUser.id,
  );
  final sessionsThisMonth = await sessionRepo.getSessionCountForTeacher(
    currentUser.id,
    startDate: monthStart,
  );

  return TeacherStats(
    totalSessions: totalSessions,
    sessionsThisMonth: sessionsThisMonth,
    studentCount: students.length,
    instituteCount: institutes.length,
  );
});

class StudentStats {
  final int currentLevel;
  final int currentJuz;

  /// A LABEL, and only in levels 1-2 — null elsewhere. Never identity.
  final int? currentHizb;
  final int currentSession;

  /// Where the student stands within the level — the numerator of the level
  /// progress bar, whose denominator is the level's real session count.
  final int currentOrderInLevel;
  final int totalSessions;
  final int passedSessions;
  final List<int> completedLevelsList;
  final List<int> unlockedLevelsList;

  const StudentStats({
    this.currentLevel = 1,
    this.currentJuz = 30,
    this.currentHizb,
    this.currentSession = 1,
    this.currentOrderInLevel = 1,
    this.totalSessions = 0,
    this.passedSessions = 0,
    this.completedLevelsList = const [],
    this.unlockedLevelsList = const [1],
  });

  int get completedLevels => completedLevelsList.length;

  double get passRate => totalSessions > 0 ? passedSessions / totalSessions : 0;

  bool isLevelLocked(int level) => !unlockedLevelsList.contains(level);

  bool isLevelCompleted(int level) => completedLevelsList.contains(level);

  bool isLevelCurrent(int level) => level == currentLevel;
}

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
    currentOrderInLevel: student.currentOrderInLevel,
    totalSessions: stats['total_sessions'] ?? 0,
    passedSessions: stats['passed_sessions'] ?? 0,
    completedLevelsList: student.completedLevels,
    unlockedLevelsList: student.unlockedLevels,
  );
});
