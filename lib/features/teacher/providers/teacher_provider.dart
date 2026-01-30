import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../shared/providers/user_provider.dart';

/// Provider for teacher's students
final teacherStudentsProvider =
    FutureProvider<List<StudentWithUser>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsForTeacher(currentUser.id);
});

/// Provider for a specific student
final studentProvider =
    FutureProvider.family<StudentWithUser?, String>((ref, studentId) async {
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

  return curriculumRepo.getCurrentSessionForStudent(
    levelId: student.currentLevel,
    juzNumber: student.currentJuz,
    hizbNumber: student.currentHizb,
    sessionNumber: student.currentSession,
  );
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

  const ActiveSessionState({
    required this.studentId,
    this.currentPart = 1,
    this.part1Errors = 0,
    this.part2Errors = 0,
    this.part3Errors = 0,
    this.repetitions = 0,
    this.notes,
    this.isComplete = false,
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

  bool get allPartsPassed =>
      part1Errors <= 3 && part2Errors <= 3 && part3Errors <= 3;

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

    // Create session record
    final record = await sessionRepo.createSessionRecord(
      studentId: student.id,
      teacherId: currentUser.id,
      curriculumSessionId:
          'L${student.currentLevel}_J${student.currentJuz}_H${student.currentHizb}_S${student.currentSession}',
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
    if (record.passed) {
      await studentRepo.advanceStudentSession(student.id);
    } else {
      await studentRepo.incrementStudentAttempt(student.id);
    }

    // Clear state
    state = state!.copyWith(isComplete: true);

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
    FutureProvider.family<List<SessionRecordModel>, String>(
        (ref, studentId) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getSessionRecordsForStudent(studentId, limit: 20);
});
