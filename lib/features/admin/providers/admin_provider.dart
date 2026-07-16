import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/session_record_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/institute_model.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../shared/providers/meeting_provider.dart' show composeMeetingFor;

class AdminStats {
  final int institutesCount;
  final int teachersCount;
  final int supervisorsCount;
  final int studentsCount;

  const AdminStats({
    this.institutesCount = 0,
    this.teachersCount = 0,
    this.supervisorsCount = 0,
    this.studentsCount = 0,
  });
}

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final instituteRepo = ref.watch(instituteRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);

  final institutes = await instituteRepo.getInstitutes();
  final teachers = await userRepo.getTeachers();
  final supervisors = await userRepo.getSupervisors();

  // Count students from all institutes
  int studentsCount = 0;
  for (final institute in institutes) {
    final studentRepo = ref.watch(studentRepositoryProvider);
    final students = await studentRepo.getStudentsForInstitute(institute.id);
    studentsCount += students.length;
  }

  return AdminStats(
    institutesCount: institutes.length,
    teachersCount: teachers.length,
    supervisorsCount: supervisors.length,
    studentsCount: studentsCount,
  );
});

/// Provider for all institutes
final institutesProvider = FutureProvider<List<InstituteModel>>((ref) async {
  final repo = ref.watch(instituteRepositoryProvider);
  return repo.getInstitutes();
});

/// Provider for all teachers
final allTeachersProvider = FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getTeachers();
});

/// Provider for all supervisors
final allSupervisorsProvider = FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getSupervisors();
});

/// Provider for single institute
final instituteProvider = FutureProvider.family<InstituteModel?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(instituteRepositoryProvider);
  return repo.getInstituteById(id);
});

/// Provider for single teacher
final teacherProvider = FutureProvider.family<UserModel?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserById(id);
});

/// Provider for teachers in an institute
final teachersForInstituteProvider =
    FutureProvider.family<List<UserModel>, String>((ref, instituteId) async {
      final instituteRepo = ref.watch(instituteRepositoryProvider);
      final userRepo = ref.watch(userRepositoryProvider);

      final teacherIds = await instituteRepo.getTeacherIdsForInstitute(
        instituteId,
      );
      final teachers = <UserModel>[];

      for (final id in teacherIds) {
        final teacher = await userRepo.getUserById(id);
        if (teacher != null) {
          teachers.add(teacher);
        }
      }

      return teachers;
    });

/// Provider for institutes for a teacher
final institutesForTeacherProvider =
    FutureProvider.family<List<InstituteModel>, String>((ref, teacherId) async {
      final repo = ref.watch(instituteRepositoryProvider);
      return repo.getInstitutesForTeacher(teacherId);
    });

/// All active students across every institute (admin-only).
final allStudentsProvider = FutureProvider<List<StudentWithUser>>((ref) async {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getAllStudents();
});

/// Students assigned to a specific teacher (admin-only view).
final studentsForTeacherAdminProvider =
    FutureProvider.family<List<StudentWithUser>, String>((
      ref,
      teacherId,
    ) async {
      final repo = ref.watch(studentRepositoryProvider);
      return repo.getStudentsForTeacher(teacherId);
    });

/// A single student with its user profile (admin-only read-only view).
final adminStudentProvider = FutureProvider.family<StudentWithUser?, String>((
  ref,
  studentId,
) async {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentWithUserById(studentId);
});

/// The MEETING a student stands on (admin-only view) — the admin twin of
/// `studentCurrentMeetingProvider`. Resolves the student via
/// [adminStudentProvider] (the admin's own read-only lookup, scoped to no
/// teacher/institute — an admin sees every student), then composes the
/// meeting through the one shared rule in [composeMeetingFor].
final adminStudentCurrentMeetingProvider =
    FutureProvider.family<PacedSession?, String>((ref, studentId) async {
      final studentWithUser = await ref.watch(
        adminStudentProvider(studentId).future,
      );
      if (studentWithUser == null) return null;

      return composeMeetingFor(ref, studentWithUser.student);
    });

/// Recent session records for a student (admin-only view).
final adminStudentSessionHistoryProvider =
    FutureProvider.family<List<SessionRecordModel>, String>((
      ref,
      studentId,
    ) async {
      final repo = ref.watch(sessionRepositoryProvider);
      return repo.getSessionRecordsForStudent(studentId, limit: 50);
    });

/// A single supervisor account (admin read-only view). Mirrors
/// [teacherProvider] — both are just `getUserById` — but named in supervisor
/// terms so supervisor screens never read as teacher screens.
final supervisorProvider = FutureProvider.family<UserModel?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserById(id);
});

/// Institutes a supervisor is assigned to, resolved from the
/// `supervisor_institutes` membership (al_rasikhoon-3n6). The admin twin of the
/// supervisor-side `supervisorInstituteIdsProvider`, but returns full
/// [InstituteModel]s for display and is keyed by an explicit supervisor id (the
/// admin inspects any supervisor, not "the current user").
final institutesForSupervisorProvider =
    FutureProvider.family<List<InstituteModel>, String>((
      ref,
      supervisorId,
    ) async {
      final repo = ref.watch(instituteRepositoryProvider);
      return repo.getInstitutesForSupervisor(supervisorId);
    });

/// Supervisors assigned to a given institute — the exact mirror of
/// [teachersForInstituteProvider], composing
/// `getSupervisorIdsForInstitute` with `getUserById`. An id that no longer
/// resolves to a user (deleted account) is dropped rather than surfaced as a
/// blank row.
final supervisorsForInstituteProvider =
    FutureProvider.family<List<UserModel>, String>((ref, instituteId) async {
      final instituteRepo = ref.watch(instituteRepositoryProvider);
      final userRepo = ref.watch(userRepositoryProvider);

      final supervisorIds = await instituteRepo.getSupervisorIdsForInstitute(
        instituteId,
      );
      final supervisors = <UserModel>[];
      for (final id in supervisorIds) {
        final supervisor = await userRepo.getUserById(id);
        if (supervisor != null) {
          supervisors.add(supervisor);
        }
      }
      return supervisors;
    });
