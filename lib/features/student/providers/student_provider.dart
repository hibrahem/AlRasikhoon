import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/home_practice_repository.dart';
import '../../../data/models/student_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../data/models/home_practice_model.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../shared/providers/user_provider.dart';
import '../../teacher/providers/teacher_provider.dart' show composeMeetingFor;

/// Selected child id for guardians who have multiple children.
/// `null` means "show the first child" (default for single-child guardians).
class SelectedChildId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? studentId) => state = studentId;
}

final selectedChildIdProvider = NotifierProvider<SelectedChildId, String?>(
  SelectedChildId.new,
);

/// Provider for current student profile
/// For students: returns their own student record
/// For guardians: returns the selected child (or first child if none selected)
final currentStudentProvider = FutureProvider<StudentModel?>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final repo = ref.watch(studentRepositoryProvider);

  // If user is a guardian, fetch their child's data
  if (currentUser.role == UserRole.guardian) {
    final selectedId = ref.watch(selectedChildIdProvider);
    if (selectedId != null) {
      return repo.getStudentById(selectedId);
    }
    return repo.getFirstStudentByGuardianId(currentUser.id);
  }

  // Otherwise, fetch the student's own data
  return repo.getStudentByUserId(currentUser.id);
});

/// Provider for guardian's children (for multi-child support)
final guardianChildrenProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null || currentUser.role != UserRole.guardian) return [];

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsByGuardianId(currentUser.id);
});

/// Provider for student's current session
final studentDashboardSessionProvider = FutureProvider<SessionModel?>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return null;

  final repo = ref.watch(curriculumRepositoryProvider);
  // The student carries the id of the session they stand on
  // (`L{level}_J{juz}_S{n}`) — a direct read, no id rebuilding.
  return repo.getSessionById(student.currentSessionId);
});

/// The MEETING the signed-in student (or a guardian's selected child) stands
/// on — the dashboard's twin of `studentCurrentMeetingProvider`. Resolves the
/// student via [currentStudentProvider], then composes the meeting through
/// the one shared rule in [composeMeetingFor].
final studentDashboardMeetingProvider = FutureProvider<PacedSession?>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return null;

  return composeMeetingFor(ref, student);
});

/// Provider for student's session history
final studentHistoryProvider = FutureProvider<List<SessionRecordModel>>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return [];

  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getSessionRecordsForStudent(student.id, limit: 50);
});

/// Fetches a single session record by its id. Works for any caller —
/// student, guardian, or admin viewing someone else's history.
final sessionRecordByIdProvider =
    FutureProvider.family<SessionRecordModel?, String>((ref, recordId) async {
      final repo = ref.watch(sessionRepositoryProvider);
      return repo.getSessionRecordById(recordId);
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
    currentOrderInLevel: student.currentOrderInLevel,
    totalSessions: stats['total_sessions'] ?? 0,
    passedSessions: stats['passed_sessions'] ?? 0,
    completedLevelsList: student.completedLevels,
    unlockedLevelsList: student.unlockedLevels,
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

/// Provider for student's home practice history
final studentHomePracticesProvider = FutureProvider<List<HomePracticeModel>>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return [];

  final repo = ref.watch(homePracticeRepositoryProvider);
  return repo.getHomePracticesForStudent(student.id, limit: 50);
});

/// Provider for today's home practice
final todaysPracticesProvider = FutureProvider<List<HomePracticeModel>>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return [];

  final repo = ref.watch(homePracticeRepositoryProvider);
  return repo.getTodaysPractices(student.id);
});

/// Provider for this week's home practice
final thisWeeksPracticesProvider = FutureProvider<List<HomePracticeModel>>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return [];

  final repo = ref.watch(homePracticeRepositoryProvider);
  return repo.getThisWeeksPractices(student.id);
});

/// Provider for home practice statistics
final homePracticeStatsProvider = FutureProvider<HomePracticeStats>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return const HomePracticeStats();

  final repo = ref.watch(homePracticeRepositoryProvider);
  final todaysPractices = await repo.getTodaysPractices(student.id);
  final weekPractices = await repo.getThisWeeksPractices(student.id);
  final totalReps = await repo.getTotalRepetitions(student.id);
  final streak = await repo.getPracticeStreak(student.id);

  return HomePracticeStats(
    todayRepetitions: todaysPractices.fold<int>(
      0,
      (total, p) => total + p.repetitions,
    ),
    weekRepetitions: weekPractices.fold<int>(
      0,
      (total, p) => total + p.repetitions,
    ),
    totalRepetitions: totalReps,
    streakDays: streak,
    practiceCount: todaysPractices.length,
  );
});

/// The home assignment the student is currently working off: the passage, how
/// many repetitions they owe, and how many they have logged against it.
class HomeAssignment {
  final String curriculumSessionId;
  final int repetitionsRequired;
  final int repetitionsDone;

  const HomeAssignment({
    required this.curriculumSessionId,
    required this.repetitionsRequired,
    required this.repetitionsDone,
  });

  bool get isComplete => repetitionsDone >= repetitionsRequired;
}

/// Null when the student has no record yet, or when their last session assigned
/// no home repetitions.
final homeAssignmentProvider = FutureProvider<HomeAssignment?>((ref) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return null;

  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final record = await sessionRepo.getLatestSessionRecord(student.id);
  if (record == null || record.homeRepetitionsRequired <= 0) return null;

  final practices = await ref
      .watch(homePracticeRepositoryProvider)
      .getHomePracticesForStudent(student.id);

  final done = practices
      .where((p) => p.curriculumSessionId == record.curriculumSessionId)
      .fold<int>(0, (total, p) => total + p.repetitions);

  return HomeAssignment(
    curriculumSessionId: record.curriculumSessionId,
    repetitionsRequired: record.homeRepetitionsRequired,
    repetitionsDone: done,
  );
});

/// Notifier for creating home practice
class HomePracticeNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> addPractice({required int repetitions, String? notes}) async {
    state = const AsyncValue.loading();

    try {
      final student = await ref.read(currentStudentProvider.future);
      if (student == null) {
        state = AsyncValue.error('Student not found', StackTrace.current);
        return false;
      }

      // The practice belongs to the session it was ASSIGNED in, which is the
      // student's last completed session — NOT the session they now stand on.
      // The teacher advanced them when that session ended.
      final sessionRepo = ref.read(sessionRepositoryProvider);
      final lastRecord = await sessionRepo.getLatestSessionRecord(student.id);

      final repo = ref.read(homePracticeRepositoryProvider);
      await repo.createHomePractice(
        studentId: student.id,
        // Falls back to the student's OWN current_session_id — never ''.
        // With no session record yet, the student's current position is the
        // closest thing to an assignment there is, and every other field
        // below already falls back to that same position: an empty id would
        // make the document internally inconsistent (level/hizb/session say
        // one thing, the id says nothing) and could never match
        // `homeAssignmentProvider`'s equality filter.
        curriculumSessionId:
            lastRecord?.curriculumSessionId ?? student.currentSessionId,
        levelId: lastRecord?.levelId ?? student.currentLevel,
        // The record's OWN juz — never the student's CURRENT juz, which may
        // already be a different one by the time this practice is logged
        // (the teacher may have advanced the student across a juz boundary
        // in between, e.g. finishing juz 30's last lesson and being moved
        // into juz 29 before the student logs practice against the juz-30
        // session they were actually assigned).
        juzNumber: lastRecord?.juzNumber ?? student.currentJuz,
        hizbNumber: lastRecord?.hizbNumber ?? student.currentHizb,
        sessionNumber: lastRecord?.sessionNumber ?? student.currentSession,
        repetitions: repetitions,
        notes: notes,
      );

      ref.invalidate(studentHomePracticesProvider);
      ref.invalidate(todaysPracticesProvider);
      ref.invalidate(thisWeeksPracticesProvider);
      ref.invalidate(homePracticeStatsProvider);
      ref.invalidate(homeAssignmentProvider);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final homePracticeNotifierProvider =
    NotifierProvider<HomePracticeNotifier, AsyncValue<void>>(
      HomePracticeNotifier.new,
    );

class HomePracticeStats {
  final int todayRepetitions;
  final int weekRepetitions;
  final int totalRepetitions;
  final int streakDays;
  final int practiceCount;

  const HomePracticeStats({
    this.todayRepetitions = 0,
    this.weekRepetitions = 0,
    this.totalRepetitions = 0,
    this.streakDays = 0,
    this.practiceCount = 0,
  });
}
