import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import 'user_repository.dart';

class StudentWithUser {
  final StudentModel student;
  final UserModel user;

  const StudentWithUser({
    required this.student,
    required this.user,
  });
}

class StudentRepository {
  final FirebaseFirestore _firestore;
  final UserRepository _userRepository;

  StudentRepository({
    FirebaseFirestore? firestore,
    required UserRepository userRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _userRepository = userRepository;

  CollectionReference<Map<String, dynamic>> get _studentsCollection =>
      _firestore.collection(AppConstants.collectionStudents);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.collectionUsers);

  /// Create student with user
  Future<StudentWithUser> createStudent({
    required String name,
    required String phone,
    required String instituteId,
    required String teacherId,
    String? guardianPhone,
  }) async {
    // First, create the user
    final userDocRef = _usersCollection.doc();
    final user = UserModel(
      id: userDocRef.id,
      phone: phone,
      name: name,
      role: UserRole.student,
      createdAt: DateTime.now(),
    );
    await userDocRef.set(user.toFirestore());

    // Create guardian if provided
    String? guardianId;
    if (guardianPhone != null && guardianPhone.isNotEmpty) {
      // Check if guardian already exists
      final existingGuardian = await _userRepository.getUserByPhone(guardianPhone);
      if (existingGuardian != null) {
        guardianId = existingGuardian.id;
      } else {
        // Create new guardian user
        final guardianDocRef = _usersCollection.doc();
        final guardian = UserModel(
          id: guardianDocRef.id,
          phone: guardianPhone,
          name: 'ولي أمر $name',
          role: UserRole.guardian,
          createdAt: DateTime.now(),
        );
        await guardianDocRef.set(guardian.toFirestore());
        guardianId = guardianDocRef.id;
      }
    }

    // Create student record
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
  Future<List<StudentWithUser>> getStudentsForInstitute(String instituteId) async {
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
  Future<List<StudentWithUser>> getStudentsReadyForExam(String instituteId) async {
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

  /// Advance student to next session
  Future<void> advanceStudentSession(String studentId) async {
    final student = await getStudentById(studentId);
    if (student == null) return;

    int newSession = student.currentSession + 1;
    int newHizb = student.currentHizb;
    int newJuz = student.currentJuz;
    int newLevel = student.currentLevel;
    List<int> completedLevels = List.from(student.completedLevels);
    List<int> unlockedLevels = List.from(student.unlockedLevels);

    // Check if hizb is complete (after exam = session 36)
    if (newSession > 36) {
      newSession = 1;
      newHizb = newHizb - 1; // Move to previous hizb (going backwards through Quran)

      // Check if level is complete (6 hizbs)
      if (newHizb < _getFirstHizbOfLevel(newLevel)) {
        if (!completedLevels.contains(newLevel)) {
          completedLevels.add(newLevel);
        }
        newLevel = newLevel + 1;
        if (newLevel <= 10 && !unlockedLevels.contains(newLevel)) {
          unlockedLevels.add(newLevel);
        }
        newHizb = _getFirstHizbOfLevel(newLevel);
        newJuz = _getFirstJuzOfLevel(newLevel);
      }
    }

    await _studentsCollection.doc(studentId).update({
      'current_session': newSession,
      'current_hizb': newHizb,
      'current_juz': newJuz,
      'current_level': newLevel,
      'current_attempt': 1,
      'completed_levels': completedLevels,
      'unlocked_levels': unlockedLevels,
      'updated_at': FieldValue.serverTimestamp(),
    });
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
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .toList());
  }

  /// Get students by guardian ID (for guardian role)
  Future<List<StudentWithUser>> getStudentsByGuardianId(String guardianId) async {
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

  // Helper methods to map levels to hizbs/juz
  int _getFirstHizbOfLevel(int level) {
    // Level 1: Juz 30, 29, 28 -> Hizb 59-54
    // Level 2: Juz 27, 26, 25 -> Hizb 53-48
    // ... and so on
    return 60 - ((level - 1) * 6) - 1; // Returns 59, 53, 47, etc.
  }

  int _getFirstJuzOfLevel(int level) {
    // Level 1: 30, Level 2: 27, etc.
    return 31 - (level * 3) + 2; // Returns 30, 27, 24, etc.
  }
}

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(
    firestore: ref.watch(firestoreProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});
