import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../shared/providers/user_provider.dart';

/// Provider for teacher's students
final teacherStudentsProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsForTeacher(currentUser.id);
});

/// Institutes the current teacher is assigned to.
final teacherInstitutesProvider = FutureProvider<List<InstituteModel>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(instituteRepositoryProvider);
  return repo.getInstitutesForTeacher(currentUser.id);
});

/// Selected institute id to filter the teacher's students view.
/// `null` means "all institutes".
class SelectedTeacherInstituteFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? instituteId) => state = instituteId;
}

final selectedTeacherInstituteFilterProvider =
    NotifierProvider<SelectedTeacherInstituteFilter, String?>(
      SelectedTeacherInstituteFilter.new,
    );

/// Teacher's students filtered by the selected institute filter.
final filteredTeacherStudentsProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final all = await ref.watch(teacherStudentsProvider.future);
  final filter = ref.watch(selectedTeacherInstituteFilterProvider);
  if (filter == null) return all;
  return all
      .where((s) => s.student.instituteId == filter)
      .toList(growable: false);
});

/// Provider for a specific student
final studentProvider = FutureProvider.family<StudentWithUser?, String>((
  ref,
  studentId,
) async {
  final students = await ref.watch(teacherStudentsProvider.future);
  return students.firstWhere(
    (s) => s.student.id == studentId,
    orElse: () => throw Exception('Student not found'),
  );
});

/// Provider for student's current session data
final studentCurrentSessionProvider =
    FutureProvider.family<SessionModel?, String>((ref, studentId) async {
      final studentAsync = await ref.watch(studentProvider(studentId).future);
      if (studentAsync == null) return null;

      final student = studentAsync.student;
      final curriculumRepo = ref.watch(curriculumRepositoryProvider);

      // The student carries the id of the session they stand on
      // (`L{level}_J{juz}_S{n}`) — a direct read, no id rebuilding.
      return curriculumRepo.getSessionById(student.currentSessionId);
    });

/// Session state for recording a session
class ActiveSessionState {
  final String studentId;
  final int currentPart; // 1, 2, or 3
  final int part1Errors;
  final int part2Errors;
  final int part3Errors;
  final int repetitions;
  final String? notes;
  final bool isComplete;

  /// The outcome of the student-progress update triggered by
  /// [ActiveSessionNotifier.completeSession] on a pass. Null until
  /// `completeSession` runs (or when the record failed, since progress is
  /// never advanced on a fail). Screens read this to tell a real advance
  /// apart from a silent no-op (e.g. no seeded curriculum data ahead) so
  /// they never show an unqualified success message for the latter.
  final StudentAdvanceOutcome? advanceOutcome;

  const ActiveSessionState({
    required this.studentId,
    this.currentPart = 1,
    this.part1Errors = 0,
    this.part2Errors = 0,
    this.part3Errors = 0,
    this.repetitions = 0,
    this.notes,
    this.isComplete = false,
    this.advanceOutcome,
  });

  ActiveSessionState copyWith({
    String? studentId,
    int? currentPart,
    int? part1Errors,
    int? part2Errors,
    int? part3Errors,
    int? repetitions,
    String? notes,
    bool? isComplete,
    StudentAdvanceOutcome? advanceOutcome,
  }) {
    return ActiveSessionState(
      studentId: studentId ?? this.studentId,
      currentPart: currentPart ?? this.currentPart,
      part1Errors: part1Errors ?? this.part1Errors,
      part2Errors: part2Errors ?? this.part2Errors,
      part3Errors: part3Errors ?? this.part3Errors,
      repetitions: repetitions ?? this.repetitions,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
      advanceOutcome: advanceOutcome ?? this.advanceOutcome,
    );
  }

  int get errorsForPart {
    switch (currentPart) {
      case 1:
        return part1Errors;
      case 2:
        return part2Errors;
      case 3:
        return part3Errors;
      default:
        return 0;
    }
  }

  /// Whether the in-progress session passes at the student's [level], per
  /// hibrahem/AlRasikhoon#24: FAILED if ANY component (new/near/far) grades
  /// محب (ويعاد); passes only if none is محب. No averaging, no level-agnostic
  /// ≤3 threshold — component grades are level-based (#22).
  bool passesForLevel(int level) => GradeCalculator.sessionPassesForLevel(
    level: level,
    newMemorizationErrors: part1Errors,
    recentReviewErrors: part2Errors,
    distantReviewErrors: part3Errors,
  );

  int get totalErrors => part1Errors + part2Errors + part3Errors;
}

class ActiveSessionNotifier extends Notifier<ActiveSessionState?> {
  @override
  ActiveSessionState? build() => null;

  void startSession(String studentId) {
    state = ActiveSessionState(studentId: studentId);
  }

  void setPartErrors(int part, int errors) {
    if (state == null) return;

    switch (part) {
      case 1:
        state = state!.copyWith(part1Errors: errors);
        break;
      case 2:
        state = state!.copyWith(part2Errors: errors);
        break;
      case 3:
        state = state!.copyWith(part3Errors: errors);
        break;
    }
  }

  void nextPart() {
    if (state == null) return;
    if (state!.currentPart < 3) {
      state = state!.copyWith(currentPart: state!.currentPart + 1);
    }
  }

  void setNotes(String notes) {
    if (state == null) return;
    state = state!.copyWith(notes: notes);
  }

  void setRepetitions(int repetitions) {
    if (state == null) return;
    state = state!.copyWith(repetitions: repetitions);
  }

  Future<SessionRecordModel?> completeSession() async {
    if (state == null) return null;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return null;

    // Save studentId before modifying state to avoid accessing stale state
    final studentId = state!.studentId;

    final studentAsync = await ref.read(studentProvider(studentId).future);
    if (studentAsync == null) return null;

    final student = studentAsync.student;
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final studentRepo = ref.read(studentRepositoryProvider);

    // Create session record. The curriculum session id is the student's own
    // `current_session_id` — read from the curriculum on placement/advance,
    // never rebuilt here (the old `..._H{hizb}_S{n}` form names no document).
    final record = await sessionRepo.createSessionRecord(
      studentId: student.id,
      teacherId: currentUser.id,
      curriculumSessionId: student.currentSessionId,
      levelId: student.currentLevel,
      hizbNumber: student.currentHizb,
      sessionNumber: student.currentSession,
      attemptNumber: student.currentAttempt,
      newMemorizationErrors: state!.part1Errors,
      recentReviewErrors: state!.part2Errors,
      distantReviewErrors: state!.part3Errors,
      repetitions: state!.repetitions,
      notes: state!.notes,
    );

    // Update student progress
    StudentAdvanceOutcome? advanceOutcome;
    if (record.passed) {
      advanceOutcome = await studentRepo.advanceStudentSession(student.id);
    } else {
      await studentRepo.incrementStudentAttempt(student.id);
    }

    // Clear state
    state = state!.copyWith(isComplete: true, advanceOutcome: advanceOutcome);

    // Invalidate providers
    ref.invalidate(teacherStudentsProvider);
    ref.invalidate(studentProvider(studentId));

    return record;
  }

  void endSession() {
    state = null;
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSessionState?>(
      ActiveSessionNotifier.new,
    );

/// Provider for student's session history
final studentSessionHistoryProvider =
    FutureProvider.family<List<SessionRecordModel>, String>((
      ref,
      studentId,
    ) async {
      final repo = ref.watch(sessionRepositoryProvider);
      return repo.getSessionRecordsForStudent(studentId, limit: 20);
    });

/// One row of the teacher's history: the record, plus the student identity the
/// record itself does not carry.
class TeacherHistoryEntry {
  final SessionRecordModel record;
  final String studentName;
  final String instituteId;

  const TeacherHistoryEntry({
    required this.record,
    required this.studentName,
    required this.instituteId,
  });
}

/// Every recitation this teacher recorded, newest first.
///
/// Scoped by the SAME institute filter as the students list, so selecting a
/// معهد means one thing across the whole teacher shell.
final teacherHistoryProvider = FutureProvider<List<TeacherHistoryEntry>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(sessionRepositoryProvider);
  // Bounded the same way as studentSessionHistoryProvider: without a limit,
  // a teacher who has recorded a year of sessions re-downloads every one of
  // them on every tab open and pull-to-refresh. Note this limit applies
  // BEFORE the roster/institute filtering below, so fewer than 20 entries can
  // end up on screen — acceptable, since the student-facing provider has the
  // same shape.
  final records = await repo.getSessionRecordsForTeacher(
    currentUser.id,
    limit: 20,
  );

  // Records carry a studentId only; the name and institute come from the
  // teacher's roster, which the students tab has already loaded.
  final students = await ref.watch(teacherStudentsProvider.future);
  final byStudentId = {for (final s in students) s.student.id: s};

  final filter = ref.watch(selectedTeacherInstituteFilterProvider);

  final entries = <TeacherHistoryEntry>[];
  for (final record in records) {
    final student = byStudentId[record.studentId];
    // A student who has since left this teacher's roster: we can no longer
    // name or scope the record, so it is not shown.
    if (student == null) continue;
    if (filter != null && student.student.instituteId != filter) continue;

    entries.add(
      TeacherHistoryEntry(
        record: record,
        studentName: student.user.name,
        instituteId: student.student.instituteId,
      ),
    );
  }
  return entries;
});
