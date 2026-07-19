import '../models/user_model.dart';
import '../repositories/curriculum_repository.dart';
import '../repositories/institute_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/user_repository.dart';
import '../../domain/curriculum/curriculum_position.dart';

/// Warms Firestore's disk cache with the data each role needs offline
/// (docs/superpowers/specs/2026-07-19-offline-mode-design.md §2). It performs
/// ordinary reads — the documents land in Firestore's own persistence layer,
/// no second store — and is purely opportunistic: every read is best-effort
/// and failures are swallowed, because an unprimed cache merely degrades to
/// the screens' existing empty states.
///
/// Runs after login / app start when online, and again on every
/// offline→online transition (see `offlineSyncControllerProvider`).
class OfflineCachePrimer {
  final StudentRepository _studentRepository;
  final CurriculumRepository _curriculumRepository;
  final SessionRepository _sessionRepository;
  final InstituteRepository _instituteRepository;
  final UserRepository _userRepository;

  /// How much per-student history is primed: enough for the history list a
  /// teacher consults mid-halaqa, without downloading whole careers.
  static const int historyDepth = 20;

  OfflineCachePrimer({
    required StudentRepository studentRepository,
    required CurriculumRepository curriculumRepository,
    required SessionRepository sessionRepository,
    required InstituteRepository instituteRepository,
    required UserRepository userRepository,
  }) : _studentRepository = studentRepository,
       _curriculumRepository = curriculumRepository,
       _sessionRepository = sessionRepository,
       _instituteRepository = instituteRepository,
       _userRepository = userRepository;

  Future<void> prime(UserModel user) async {
    try {
      switch (user.role) {
        case UserRole.teacher:
          await _primeTeacher(user.id);
        case UserRole.supervisor:
          await _primeSupervisor(user.id);
        case UserRole.superAdmin:
          await _primeAdmin();
        case UserRole.student:
        case UserRole.guardian:
          await _primeStudentOrGuardian(user);
      }
    } catch (_) {
      // Opportunistic by design — a priming failure must never surface.
    }
  }

  /// The levels catalog plus the session lists for [levels] — including, per
  /// caller, each student's NEXT level, so an advancement crossing a level
  /// boundary still resolves against the cache offline.
  Future<void> _primeCurriculum(Iterable<int> levels) async {
    await _curriculumRepository.getLevels();
    for (final level in levels.toSet()) {
      if (level < 1 || level > CurriculumPosition.totalLevels) continue;
      await _curriculumRepository.getSessionsForLevel(level: level);
    }
  }

  Future<void> _primeStudentHistories(Iterable<String> studentIds) async {
    for (final id in studentIds) {
      // The latest record carries the current home assignment; the history
      // feeds the profile's سجل الحلقات list.
      await _sessionRepository.getLatestSessionRecord(id);
      await _sessionRepository.getStudentHistory(id, limit: historyDepth);
    }
  }

  Future<void> _primeTeacher(String teacherId) async {
    // Students + their user docs (the repository already fans out per user).
    final students = await _studentRepository.getStudentsForTeacher(teacherId);
    await _primeCurriculum([
      for (final s in students) ...[
        s.student.currentLevel,
        s.student.currentLevel + 1,
      ],
    ]);
    await _primeStudentHistories([for (final s in students) s.student.id]);
  }

  Future<void> _primeSupervisor(String supervisorId) async {
    final institutes = await _instituteRepository.getInstitutesForSupervisor(
      supervisorId,
    );
    final ids = [for (final i in institutes) i.id];
    final students = await _studentRepository.getStudentsForInstitutes(ids);
    for (final id in ids) {
      await _studentRepository.getStudentsReadyForExam(id);
    }
    await _primeCurriculum([
      for (final s in students) ...[
        s.student.currentLevel,
        s.student.currentLevel + 1,
      ],
    ]);
    await _sessionRepository.getExamRecordsForSupervisor(supervisorId);
  }

  Future<void> _primeAdmin() async {
    await _instituteRepository.getInstitutes();
    await _studentRepository.getAllStudents();
    await _userRepository.getTeachers();
    await _userRepository.getSupervisors();
  }

  Future<void> _primeStudentOrGuardian(UserModel user) async {
    // Mirrors currentStudentProvider's resolution: a student reads their own
    // record, a guardian reads their children's.
    final students = user.role == UserRole.guardian
        ? [
            for (final s in await _studentRepository.getStudentsByGuardianId(
              user.id,
            ))
              s.student,
          ]
        : [
            if (await _studentRepository.getStudentByUserId(user.id)
                case final student?)
              student,
          ];
    if (students.isEmpty) return;
    await _primeCurriculum([for (final s in students) s.currentLevel]);
    await _primeStudentHistories([for (final s in students) s.id]);
  }
}
