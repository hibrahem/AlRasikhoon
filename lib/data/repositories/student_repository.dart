import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/curriculum/curriculum_order.dart';
import '../../domain/curriculum/curriculum_position.dart';
import 'curriculum_repository.dart';
import 'user_repository.dart';

class StudentWithUser {
  final StudentModel student;
  final UserModel user;

  const StudentWithUser({required this.student, required this.user});
}

class StudentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseService _firebaseService;
  final UserRepository _userRepository;
  final CurriculumRepository _curriculumRepository;

  StudentRepository({
    FirebaseFirestore? firestore,
    required FirebaseService firebaseService,
    required UserRepository userRepository,
    required CurriculumRepository curriculumRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseService = firebaseService,
       _userRepository = userRepository,
       _curriculumRepository = curriculumRepository;

  CollectionReference<Map<String, dynamic>> get _studentsCollection =>
      _firestore.collection(AppConstants.collectionStudents);

  /// Create a student plus the underlying user account. The auth user AND
  /// users/{uid} Firestore profile are provisioned atomically by the
  /// createUserAccount Cloud Function. Optionally provisions a guardian
  /// account too. Throws on username collision.
  /// [teacherId] is optional: a teacher provisioning a student assigns it to
  /// themselves; a supervisor provisioning a student for their institute may
  /// leave it null (the student is institute-scoped, not teacher-owned). The
  /// student record always carries [instituteId] so both UI providers and
  /// Firestore rules can scope access by `users/{uid}.institute_id` per
  /// AgDR-0003 — no multi-hop reads.
  Future<StudentWithUser> createStudent({
    required String name,
    required String username,
    required String password,
    String? phone,
    required String instituteId,
    String? teacherId,
    String? guardianUsername,
    String? guardianPassword,
    String? guardianPhone,
  }) async {
    final normalizedUsername = username.toLowerCase();
    final synthesizedEmail =
        '$normalizedUsername@${AppConstants.synthesizedEmailDomain}';

    final uid = await _firebaseService.provisionUserAccount(
      email: synthesizedEmail,
      password: password,
      role: UserRole.student.value,
      name: name,
      username: normalizedUsername,
      phone: phone,
    );

    final user = UserModel(
      id: uid,
      username: normalizedUsername,
      email: synthesizedEmail,
      phone: phone,
      name: name,
      role: UserRole.student,
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime.now(),
    );

    String? guardianId;
    if (guardianUsername != null && guardianUsername.isNotEmpty) {
      final guardianNormalized = guardianUsername.toLowerCase();
      final existingGuardian = await _userRepository.getUserByUsername(
        guardianNormalized,
      );
      if (existingGuardian != null) {
        guardianId = existingGuardian.id;
      } else {
        if (guardianPassword == null || guardianPassword.isEmpty) {
          throw ArgumentError(
            'guardianPassword is required when creating a new guardian',
          );
        }
        final guardianEmail =
            '$guardianNormalized@${AppConstants.synthesizedEmailDomain}';
        final guardianName = 'ولي أمر $name';
        final guardianUid = await _firebaseService.provisionUserAccount(
          email: guardianEmail,
          password: guardianPassword,
          role: UserRole.guardian.value,
          name: guardianName,
          username: guardianNormalized,
          phone: guardianPhone,
        );
        guardianId = guardianUid;
      }
    }

    final studentDocRef = _studentsCollection.doc();
    final student = StudentModel(
      id: studentDocRef.id,
      userId: user.id,
      instituteId: instituteId,
      teacherId: teacherId,
      guardianId: guardianId,
      createdAt: DateTime.now(),
    );
    await studentDocRef.set(student.toFirestore());

    return StudentWithUser(student: student, user: user);
  }

  /// Get student by ID
  Future<StudentModel?> getStudentById(String studentId) async {
    final doc = await _studentsCollection.doc(studentId).get();
    if (doc.exists) {
      return StudentModel.fromFirestore(doc);
    }
    return null;
  }

  /// Get student by user ID
  Future<StudentModel?> getStudentByUserId(String userId) async {
    // First try direct lookup by user_id
    final query = await _studentsCollection
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return StudentModel.fromFirestore(query.docs.first);
    }

    // Fallback: If user was migrated but student record wasn't updated,
    // try to find and repair orphaned student records.
    // This happens when admin creates a student (random user_id),
    // then the student logs in (gets Firebase UID), and the old migration
    // didn't update the student record.
    final user = await _userRepository.getUserById(userId);

    if (user != null && user.role == UserRole.student) {
      // Find all orphaned students (students whose user document no longer exists)
      final allStudents = await _studentsCollection
          .where('is_active', isEqualTo: true)
          .get();

      final orphanedStudents = <DocumentSnapshot>[];

      for (final studentDoc in allStudents.docs) {
        final student = StudentModel.fromFirestore(studentDoc);

        // Skip if already pointing to current user
        if (student.userId == userId) continue;

        // Check if the user document exists
        final studentUser = await _userRepository.getUserById(student.userId);
        if (studentUser == null) {
          orphanedStudents.add(studentDoc);
        }
      }

      // Only auto-repair if there's exactly ONE orphaned student
      // to avoid incorrectly assigning the wrong student
      if (orphanedStudents.length == 1) {
        final orphanDoc = orphanedStudents.first;

        // Repair: Update the student's user_id to the current Firebase UID
        await _studentsCollection.doc(orphanDoc.id).update({
          'user_id': userId,
          'updated_at': FieldValue.serverTimestamp(),
        });

        // Return the repaired student
        final repairedDoc = await _studentsCollection.doc(orphanDoc.id).get();
        return StudentModel.fromFirestore(repairedDoc);
      }
    }

    return null;
  }

  /// Get all active students across every institute.
  Future<List<StudentWithUser>> getAllStudents() async {
    final query = await _studentsCollection
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();

    final students = query.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();

    final studentsWithUsers = <StudentWithUser>[];
    for (final student in students) {
      final user = await _userRepository.getUserById(student.userId);
      if (user != null) {
        studentsWithUsers.add(StudentWithUser(student: student, user: user));
      }
    }

    return studentsWithUsers;
  }

  /// Get a single student plus its underlying user account.
  Future<StudentWithUser?> getStudentWithUserById(String studentId) async {
    final student = await getStudentById(studentId);
    if (student == null) return null;
    final user = await _userRepository.getUserById(student.userId);
    if (user == null) return null;
    return StudentWithUser(student: student, user: user);
  }

  /// Get students for teacher
  Future<List<StudentWithUser>> getStudentsForTeacher(String teacherId) async {
    final query = await _studentsCollection
        .where('teacher_id', isEqualTo: teacherId)
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();

    final students = query.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();

    // Get user data for each student
    final studentsWithUsers = <StudentWithUser>[];
    for (final student in students) {
      final user = await _userRepository.getUserById(student.userId);
      if (user != null) {
        studentsWithUsers.add(StudentWithUser(student: student, user: user));
      }
    }

    return studentsWithUsers;
  }

  /// Get students for institute
  Future<List<StudentWithUser>> getStudentsForInstitute(
    String instituteId,
  ) async {
    final query = await _studentsCollection
        .where('institute_id', isEqualTo: instituteId)
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();

    final students = query.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();

    final studentsWithUsers = <StudentWithUser>[];
    for (final student in students) {
      final user = await _userRepository.getUserById(student.userId);
      if (user != null) {
        studentsWithUsers.add(StudentWithUser(student: student, user: user));
      }
    }

    return studentsWithUsers;
  }

  /// Get students ready for exam (session 36)
  Future<List<StudentWithUser>> getStudentsReadyForExam(
    String instituteId,
  ) async {
    final query = await _studentsCollection
        .where('institute_id', isEqualTo: instituteId)
        .where('current_session', isEqualTo: AppConstants.examSessionNumber)
        .where('is_active', isEqualTo: true)
        .get();

    final students = query.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();

    final studentsWithUsers = <StudentWithUser>[];
    for (final student in students) {
      final user = await _userRepository.getUserById(student.userId);
      if (user != null) {
        studentsWithUsers.add(StudentWithUser(student: student, user: user));
      }
    }

    return studentsWithUsers;
  }

  /// Update student
  Future<void> updateStudent(StudentModel student) async {
    await _studentsCollection.doc(student.id).update({
      ...student.toFirestore(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Advance the student to the next session in the curriculum.
  ///
  /// Follows the real teaching order (level 1 runs 59, 60, 57, 58, 55, 56) over
  /// the sessions that actually exist — the curriculum is sparse, so the next
  /// session is rarely `current + 1`. A level completes only after its last
  /// hizb. At the end of the curriculum the student stays where they are.
  Future<void> advanceStudentSession(String studentId) async {
    final student = await getStudentById(studentId);
    if (student == null) return;

    final next = await _nextPosition(student.currentPosition);
    if (next == null) {
      await resetStudentAttempt(studentId);
      return;
    }

    final completedLevels = List<int>.from(student.completedLevels);
    final unlockedLevels = List<int>.from(student.unlockedLevels);
    if (next.level > student.currentLevel) {
      if (!completedLevels.contains(student.currentLevel)) {
        completedLevels.add(student.currentLevel);
      }
      if (!unlockedLevels.contains(next.level)) {
        unlockedLevels.add(next.level);
      }
    }

    await _studentsCollection.doc(studentId).update({
      'current_level': next.level,
      'current_juz': next.juz,
      'current_hizb': next.hizb,
      'current_session': next.session,
      'current_attempt': 1,
      'completed_levels': completedLevels,
      'unlocked_levels': unlockedLevels,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// The next position after [from] in teaching order, or null at the end of
  /// the curriculum. Hizbs with no seeded sessions are stepped over.
  Future<CurriculumPosition?> _nextPosition(CurriculumPosition from) async {
    final sessions = await _curriculumRepository.getSessionNumbersForHizb(
      level: from.level,
      hizb: from.hizb,
    );
    final laterInHizb = sessions.where((s) => s > from.session);
    if (laterInHizb.isNotEmpty) {
      return CurriculumPosition(
        level: from.level,
        hizb: from.hizb,
        session: laterInHizb.first,
      );
    }

    int? hizb = CurriculumOrder.nextHizb(from.hizb);
    while (hizb != null) {
      final level = CurriculumOrder.levelOfHizb(hizb);
      final next = await _curriculumRepository.getSessionNumbersForHizb(
        level: level,
        hizb: hizb,
      );
      if (next.isNotEmpty) {
        return CurriculumPosition(
          level: level,
          hizb: hizb,
          session: next.first,
        );
      }
      hizb = CurriculumOrder.nextHizb(hizb);
    }

    return null;
  }

  /// Increment attempt for failed session
  Future<void> incrementStudentAttempt(String studentId) async {
    await _studentsCollection.doc(studentId).update({
      'current_attempt': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Reset attempt on new session
  Future<void> resetStudentAttempt(String studentId) async {
    await _studentsCollection.doc(studentId).update({
      'current_attempt': 1,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete student (soft delete)
  Future<void> deleteStudent(String studentId) async {
    await _studentsCollection.doc(studentId).update({
      'is_active': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Stream students for teacher
  Stream<List<StudentModel>> streamStudentsForTeacher(String teacherId) {
    return _studentsCollection
        .where('teacher_id', isEqualTo: teacherId)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream the active students of an institute. Backing query for the
  /// supervisor's institute-scoped student-management view (AgDR-0003): a
  /// supervisor sees exactly the students whose `institute_id` matches their
  /// own `users/{uid}.institute_id`.
  Stream<List<StudentModel>> streamStudentsForInstitute(String instituteId) {
    return _studentsCollection
        .where('institute_id', isEqualTo: instituteId)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get students by guardian ID (for guardian role)
  Future<List<StudentWithUser>> getStudentsByGuardianId(
    String guardianId,
  ) async {
    final query = await _studentsCollection
        .where('guardian_id', isEqualTo: guardianId)
        .where('is_active', isEqualTo: true)
        .get();

    final students = query.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();

    final studentsWithUsers = <StudentWithUser>[];
    for (final student in students) {
      final user = await _userRepository.getUserById(student.userId);
      if (user != null) {
        studentsWithUsers.add(StudentWithUser(student: student, user: user));
      }
    }

    return studentsWithUsers;
  }

  /// Get first student by guardian ID (for simple case with one child)
  Future<StudentModel?> getFirstStudentByGuardianId(String guardianId) async {
    final query = await _studentsCollection
        .where('guardian_id', isEqualTo: guardianId)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return StudentModel.fromFirestore(query.docs.first);
    }
    return null;
  }
}

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseService: ref.watch(firebaseServiceProvider),
    userRepository: ref.watch(userRepositoryProvider),
    curriculumRepository: ref.watch(curriculumRepositoryProvider),
  );
});
