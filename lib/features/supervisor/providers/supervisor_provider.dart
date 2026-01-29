import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/models/exam_record_model.dart';
import '../../../shared/providers/user_provider.dart';

/// Provider for students ready for exam in supervisor's institutes
final examQueueProvider = FutureProvider<List<StudentWithUser>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final instituteRepo = ref.watch(instituteRepositoryProvider);
  final studentRepo = ref.watch(studentRepositoryProvider);

  // Get supervisor's institutes
  final institutes = await instituteRepo.getInstitutesForSupervisor(currentUser.id);

  // Get students ready for exam from each institute
  final allStudents = <StudentWithUser>[];
  for (final institute in institutes) {
    final students = await studentRepo.getStudentsReadyForExam(institute.id);
    allStudents.addAll(students);
  }

  return allStudents;
});

/// Provider for a specific student for exam
final examStudentProvider =
    FutureProvider.family<StudentWithUser?, String>((ref, studentId) async {
  final examQueue = await ref.watch(examQueueProvider.future);
  return examQueue.firstWhere(
    (s) => s.student.id == studentId,
    orElse: () => throw Exception('Student not found'),
  );
});

/// Provider for supervisor's exam history
final supervisorExamHistoryProvider =
    FutureProvider<List<ExamRecordModel>>((ref) async {
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
