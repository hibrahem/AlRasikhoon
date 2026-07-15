import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/exam_record_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/providers/meeting_provider.dart' show composeMeetingFor;

/// The canonical institute a supervisor is scoped to, read off
/// `users/{uid}.institute_id` (AgDR-0003 — the single source of truth for
/// authorization). `null` when the current user is not a supervisor or has no
/// institute bound. All supervisor student-management providers scope through
/// this value so a supervisor can never see or touch another institute's data.
final supervisorInstituteIdProvider = Provider<String?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser?.instituteId;
});

/// Students of the supervisor's institute — teacher-parity student management
/// (#28) scoped to `users/{uid}.institute_id`. Reuses the same
/// `StudentRepository.getStudentsForInstitute` backing query the teacher view
/// uses, parameterized by the supervisor's institute rather than a teacher id.
/// Returns empty when the supervisor has no institute bound.
final supervisorStudentsProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final instituteId = ref.watch(supervisorInstituteIdProvider);
  if (instituteId == null || instituteId.isEmpty) return [];

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsForInstitute(instituteId);
});

/// Teachers of the supervisor's institute (al_rasikhoon-6bw) — the pool a
/// supervisor picks from both when creating a student (a teacher is now
/// REQUIRED at creation, so no new teacher-less student can exist) and when
/// rescuing an already teacher-less one via [StudentRepository.assignTeacher].
/// Composes `instituteRepository.getTeacherIdsForInstitute` with
/// `userRepository.getUserById` — the same pattern as the admin's
/// `teachersForInstituteProvider` (lib/features/admin/providers/admin_provider.dart)
/// — but written here, scoped to [supervisorInstituteIdProvider], so
/// supervisor code never reaches into the admin feature (al_rasikhoon-pz2).
/// Empty when the supervisor has no institute bound.
final supervisorInstituteTeachersProvider = FutureProvider<List<UserModel>>((
  ref,
) async {
  final instituteId = ref.watch(supervisorInstituteIdProvider);
  if (instituteId == null || instituteId.isEmpty) return [];

  final instituteRepo = ref.watch(instituteRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);

  final teacherIds = await instituteRepo.getTeacherIdsForInstitute(instituteId);
  final teachers = <UserModel>[];
  for (final id in teacherIds) {
    final teacher = await userRepo.getUserById(id);
    if (teacher != null) {
      teachers.add(teacher);
    }
  }
  return teachers;
});

/// A single student within the supervisor's institute, looked up from
/// [supervisorStudentsProvider] so the institute scope is enforced for
/// detail/evaluation views too. Returns null when the id is not in the
/// supervisor's institute scope — a supervisor can never resolve a student
/// from outside their institute (no cross-institute leak), and an out-of-scope
/// id is indistinguishable from a non-existent one.
final supervisorStudentProvider =
    FutureProvider.family<StudentWithUser?, String>((ref, studentId) async {
      final students = await ref.watch(supervisorStudentsProvider.future);
      for (final s in students) {
        if (s.student.id == studentId) return s;
      }
      return null;
    });

/// Recent session records for a student in the supervisor's institute — the
/// history half of the supervisor's read-only progress view (al_rasikhoon-801).
/// Reads are not institute-scoped at the repository level (al_rasikhoon-bpk);
/// the SCREEN only ever asks for a student the institute-scoped
/// [supervisorStudentProvider] already resolved.
final supervisorStudentSessionHistoryProvider =
    FutureProvider.family<List<SessionRecordModel>, String>((
      ref,
      studentId,
    ) async {
      final repo = ref.watch(sessionRepositoryProvider);
      return repo.getSessionRecordsForStudent(studentId, limit: 50);
    });

/// Whether a student in the supervisor's institute has STARTED — has any
/// session/سرد/اختبار record. This gates the "edit starting point" affordance
/// (al_rasikhoon-sne): a not-yet-started student can still be repositioned, a
/// started one cannot, so the UI only offers the edit while this is `false`.
/// The authoritative check lives in the repository write path too — this
/// provider only drives visibility, never enforcement.
final supervisorStudentHasStartedProvider = FutureProvider.family<bool, String>(
  (ref, studentId) async {
    final repo = ref.watch(sessionRepositoryProvider);
    return repo.hasAnyProgressRecords(studentId);
  },
);

/// The MEETING a student in the supervisor's institute stands on — the
/// institute-scoped twin of `studentCurrentMeetingProvider`. Resolves the
/// student via [supervisorStudentProvider] (institute-scoped, AgDR-0003)
/// rather than the teacher-scoped `getStudentsForTeacher`, so a
/// supervisor-created student (null `teacher_id`) is not lost, then composes
/// the meeting through the one shared rule in [composeMeetingFor].
final supervisorStudentCurrentMeetingProvider =
    FutureProvider.family<PacedSession?, String>((ref, studentId) async {
      final studentAsync = await ref.watch(
        supervisorStudentProvider(studentId).future,
      );
      if (studentAsync == null) return null;

      return composeMeetingFor(ref, studentAsync.student);
    });

/// The curriculum session a student in the supervisor's EXAM QUEUE stands on.
/// The اختبار screens read the assessment's scope (tier, juz, the source's
/// verbatim Arabic label) off it, so what is being assessed — this hizb, this
/// juz, or the level so far — is shown and recorded from the data.
final examSessionProvider = FutureProvider.family<SessionModel?, String>((
  ref,
  studentId,
) async {
  final studentAsync = await ref.watch(examStudentProvider(studentId).future);
  if (studentAsync == null) return null;

  final curriculumRepo = ref.watch(curriculumRepositoryProvider);
  return curriculumRepo.getSessionById(studentAsync.student.currentSessionId);
});

/// Provider for students ready for exam in supervisor's institutes
final examQueueProvider = FutureProvider<List<StudentWithUser>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final instituteRepo = ref.watch(instituteRepositoryProvider);
  final studentRepo = ref.watch(studentRepositoryProvider);

  // Get supervisor's institutes
  final institutes = await instituteRepo.getInstitutesForSupervisor(
    currentUser.id,
  );

  // Get students ready for exam from each institute
  final allStudents = <StudentWithUser>[];
  for (final institute in institutes) {
    final students = await studentRepo.getStudentsReadyForExam(institute.id);
    allStudents.addAll(students);
  }

  return allStudents;
});

/// Provider for a specific student for exam
final examStudentProvider = FutureProvider.family<StudentWithUser?, String>((
  ref,
  studentId,
) async {
  final examQueue = await ref.watch(examQueueProvider.future);
  return examQueue.firstWhere(
    (s) => s.student.id == studentId,
    orElse: () => throw Exception('Student not found'),
  );
});

/// Provider for supervisor's exam history
final supervisorExamHistoryProvider = FutureProvider<List<ExamRecordModel>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getExamRecordsForSupervisor(currentUser.id);
});

/// Supervisor statistics
class SupervisorStats {
  final int pendingExams;
  final int completedToday;
  final int passedToday;
  final int failedToday;

  const SupervisorStats({
    this.pendingExams = 0,
    this.completedToday = 0,
    this.passedToday = 0,
    this.failedToday = 0,
  });
}

final supervisorStatsProvider = FutureProvider<SupervisorStats>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const SupervisorStats();

  final examQueue = await ref.watch(examQueueProvider.future);
  final sessionRepo = ref.watch(sessionRepositoryProvider);

  // Get today's exams
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final todayExams = await sessionRepo.getExamRecordsForSupervisor(
    currentUser.id,
    startDate: startOfDay,
    endDate: endOfDay,
  );

  return SupervisorStats(
    pendingExams: examQueue.length,
    completedToday: todayExams.length,
    passedToday: todayExams.where((e) => e.passed).length,
    failedToday: todayExams.where((e) => !e.passed).length,
  );
});
