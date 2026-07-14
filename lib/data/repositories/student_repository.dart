import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import '../../domain/curriculum/curriculum_position.dart';
import 'curriculum_repository.dart';
import 'user_repository.dart';

class StudentWithUser {
  final StudentModel student;
  final UserModel user;

  const StudentWithUser({required this.student, required this.user});
}

/// The outcome of walking forward to the next session. Kept as a sealed type
/// rather than a nullable session so "end of the curriculum" (a structural
/// fact) can never be conflated with "no seeded data ahead" (a fixture or
/// environment problem) — see [StudentRepository._nextSession].
sealed class _NextSessionOutcome {
  const _NextSessionOutcome();
}

/// There is a later session in the curriculum; move to it.
final class _Advanced extends _NextSessionOutcome {
  final SessionModel session;
  const _Advanced(this.session);
}

/// The student stands on the last session of the last level: nothing follows it
/// in the curriculum at all.
final class _CurriculumCompleted extends _NextSessionOutcome {
  const _CurriculumCompleted();
}

/// The walk ran out of seeded sessions before reaching the end of the
/// curriculum. This is a data problem (an unseeded environment or a fixture),
/// not the end of the curriculum, so the caller must not credit completion or
/// move the student.
final class _CurriculumDataMissing extends _NextSessionOutcome {
  const _CurriculumDataMissing();
}

/// The outcome of [StudentRepository.advanceStudentSession], as seen by
/// callers outside this repository. A silent no-op must never be
/// indistinguishable from a real advance: a caller that ignores this and
/// shows an unqualified "saved successfully" message would tell a teacher or
/// supervisor a student progressed when they in fact did not (e.g. no seeded
/// sessions exist ahead of them), leaving the student re-taught the same
/// session forever with no signal to anyone.
enum StudentAdvanceOutcome {
  /// The student moved to a later session of the curriculum.
  advanced,

  /// The student passed the last session of the last level: the curriculum is
  /// finished. Their final level was credited; their position did not move,
  /// because there is nowhere to move to.
  curriculumCompleted,

  /// The walk ran out of seeded curriculum data before it could tell whether
  /// the student had truly reached the end. The student was left exactly as
  /// they were; nothing was written.
  curriculumDataMissing,

  /// No student exists with the given id.
  studentNotFound,
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

  /// The ONLY writer of a student's `current_*` fields.
  ///
  /// The student's position is written as one map, copied wholesale from the
  /// curriculum session they now stand on: the identity (`current_level`,
  /// `current_juz`, `current_session`, `current_order_in_level`) AND the
  /// denormalized facts the supervisor's exam queue and the dashboards filter on
  /// (`current_session_id`, `current_session_kind`, `current_session_tier`,
  /// `current_session_label_ar`). They cannot drift apart, because no code path
  /// writes one without the others — a student sitting on an اختبار whose
  /// `current_session_kind` still said `lesson` would simply never appear in the
  /// supervisor's queue, and nobody would know why.
  ///
  /// A new session is always a fresh first attempt, so the attempt counter is
  /// part of the same map.
  Map<String, dynamic> _writePosition(SessionModel next) => {
    'current_level': next.levelId,
    'current_juz': next.juzNumber,
    'current_session': next.sessionNumber,
    'current_order_in_level': next.orderInLevel,
    'current_hizb': next.hizbNumber,
    'current_session_id': next.id,
    'current_session_kind': next.kind.value,
    'current_session_tier': next.scope?.tier.value,
    'current_session_label_ar': next.scope?.labelAr,
    'current_attempt': 1,
  };

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
  /// [startingPosition] is where the student enters the curriculum. It defaults
  /// to the first session; a teacher or supervisor may place a student who has
  /// already memorized part of the Quran at any point, which credits everything
  /// before that point as memorized before joining.
  ///
  /// The placement is resolved against the curriculum BEFORE anything is
  /// provisioned: whether a session exists at a position is a data question, and
  /// a position with no session is a rejected placement — never a
  /// half-provisioned user (an auth account with no student document).
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
    CurriculumPosition startingPosition = CurriculumPosition.start,
  }) async {
    // Topology first (level 1-10, juz 1-30, session >= 1) — a position that
    // could never name a real point is rejected without a read.
    CurriculumPosition.validated(
      level: startingPosition.level,
      juz: startingPosition.juz,
      session: startingPosition.session,
    );

    // Then the data: the curriculum decides whether that session exists. The
    // student is enrolled onto the SessionModel itself, so their denormalized
    // facts are copied from the curriculum and cannot contradict it.
    final startingSession = await _curriculumRepository.getSessionAt(
      startingPosition,
    );
    if (startingSession == null) {
      throw ArgumentError.value(
        startingPosition.sessionId,
        'startingPosition',
        'No curriculum session exists at this position',
      );
    }

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
    final student = StudentModel.enrolledAt(
      id: studentDocRef.id,
      userId: user.id,
      instituteId: instituteId,
      teacherId: teacherId,
      guardianId: guardianId,
      session: startingSession,
      createdAt: DateTime.now(),
    );
    // The position goes through _writePosition like every other write, so the
    // shape of a freshly-created student and an advanced one is one shape.
    await studentDocRef.set({
      ...student.toFirestore(),
      ..._writePosition(startingSession),
    });

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

  /// The supervisor's exam queue: the institute's active students who are
  /// standing on an اختبار.
  ///
  /// The filter is the session's KIND, denormalized onto the student by
  /// [_writePosition] — never a session number. Assessments sit wherever the
  /// curriculum puts them (the juz-30 اختبار of level 1 is session 68), so the
  /// old `current_session == 36` test found nobody at all.
  Future<List<StudentWithUser>> getStudentsReadyForExam(
    String instituteId,
  ) async {
    final query = await _studentsCollection
        .where('institute_id', isEqualTo: instituteId)
        .where('current_session_kind', isEqualTo: AppConstants.sessionKindExam)
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

  /// Update student.
  ///
  /// [_writePosition] is the ONLY writer of the denormalized `current_*`
  /// session facts — the supervisor's exam queue is a single Firestore query
  /// on `current_session_kind`, so a second writer that lets these fields
  /// drift from the curriculum session they name would silently drop a
  /// student out of the queue with no signal to anyone. This method is
  /// STRUCTURALLY unable to write them: every `current_*` key is stripped
  /// from [StudentModel.toFirestore] before the write, however this is
  /// called and whatever position the given [student] carries.
  Future<void> updateStudent(StudentModel student) async {
    final data = student.toFirestore()
      ..removeWhere((key, _) => key.startsWith('current_'));
    await _studentsCollection.doc(student.id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Sets how many lessons the student covers in one meeting.
  ///
  /// Takes effect on the student's very next meeting: the pending meeting's
  /// extent is derived from this pace, not stored, so there is nothing to
  /// migrate and no position to fix up. Records already written keep the pace
  /// they were recorded at.
  Future<void> setStudentPace(String studentId, CurriculumPace pace) async {
    await _studentsCollection.doc(studentId).update({
      'pace': pace.toJson(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Advance the student to the next session of the curriculum.
  ///
  /// Advancement walks `order_in_level`: the next session is the one at
  /// `currentOrderInLevel + 1` of the same level, whatever juz that falls in.
  /// This is the ONLY rule that crosses a juz boundary correctly, because the
  /// teaching order of a level's juz is DATA (levels 1-9 descend — level 1 runs
  /// juz 30 → 29 → 28 — while level 10 ASCENDS, juz 1 → 2 → 3). Every arithmetic
  /// rule that ever tried to compute the next juz got level 10 wrong.
  ///
  /// Assessments need no gating machinery of their own: the سرد and اختبار of a
  /// juz ARE the last sessions of that juz, and the cumulative pair the last of
  /// the level, so passing them IS the advance past them.
  ///
  /// Three internal outcomes, reported back so a silent no-op can never be
  /// mistaken for success:
  /// - [_Advanced]: move onto the session, resetting the attempt and crediting
  ///   every level fully crossed.
  /// - [_CurriculumCompleted]: the student stood on the last session of the last
  ///   level — credit their final level, reset the attempt, stay put.
  /// - [_CurriculumDataMissing]: the walk ran out of *seeded* sessions before it
  ///   could tell whether the student had truly finished — leave the student
  ///   exactly as they are and write nothing.
  Future<StudentAdvanceOutcome> advanceStudentSession(String studentId) async {
    final student = await getStudentById(studentId);
    if (student == null) return StudentAdvanceOutcome.studentNotFound;

    final outcome = await _nextSession(student);

    switch (outcome) {
      case _CurriculumDataMissing():
        return StudentAdvanceOutcome.curriculumDataMissing;

      case _CurriculumCompleted():
        final completedLevels = _creditedLevels(
          student.completedLevels,
          upToAndIncluding: student.currentLevel,
        );
        // There is no eleventh level to unlock into, so finishing the
        // curriculum backfills every level as unlocked.
        final unlockedLevels = _creditedLevels(
          student.unlockedLevels,
          upToAndIncluding: CurriculumPosition.totalLevels,
        );
        await _studentsCollection.doc(studentId).update({
          'current_attempt': 1,
          'completed_levels': completedLevels,
          'unlocked_levels': unlockedLevels,
          'updated_at': FieldValue.serverTimestamp(),
        });
        return StudentAdvanceOutcome.curriculumCompleted;

      case _Advanced(:final session):
        var completedLevels = List<int>.from(student.completedLevels);
        var unlockedLevels = List<int>.from(student.unlockedLevels);
        if (session.levelId > student.currentLevel) {
          // Level credit is awarded on crossing a level boundary. Every level
          // strictly below the new one is complete — including any the walk
          // passed straight through (an entirely unseeded level), which must
          // still be credited rather than silently skipped.
          completedLevels = _creditedLevels(
            completedLevels,
            upToAndIncluding: session.levelId - 1,
          );
          unlockedLevels = _creditedLevels(
            unlockedLevels,
            upToAndIncluding: session.levelId,
          );
        }

        await _studentsCollection.doc(studentId).update({
          ..._writePosition(session),
          'completed_levels': completedLevels,
          'unlocked_levels': unlockedLevels,
          'updated_at': FieldValue.serverTimestamp(),
        });
        return StudentAdvanceOutcome.advanced;
    }
  }

  /// [existing] with every level 1..[upToAndIncluding] present: gap-free (a
  /// level the student walked through is still credited) and duplicate-free (a
  /// repeated advance does not credit the same level twice).
  List<int> _creditedLevels(
    List<int> existing, {
    required int upToAndIncluding,
  }) {
    final credited = List<int>.from(existing);
    for (var level = 1; level <= upToAndIncluding; level++) {
      if (!credited.contains(level)) credited.add(level);
    }
    return credited;
  }

  /// The session that follows the one the student stands on.
  ///
  /// 1. `order_in_level + 1` within the current level — the whole advancement
  ///    rule, juz boundaries included.
  /// 2. If there is none, the level is finished: take the first session
  ///    (`order_in_level == 1`) of the next level that has one, so a level with
  ///    no seeded sessions is stepped over rather than mistaken for the end.
  /// 3. If the student was already in the last level, the curriculum is
  ///    finished.
  ///
  /// Before concluding a level is finished, the levels catalog is consulted: if
  /// it says the level has more sessions after the student's, then the missing
  /// `order_in_level + 1` is a HOLE in the data, not the end of the level, and
  /// the student must not be marched into the next level on the strength of a
  /// missing document.
  Future<_NextSessionOutcome> _nextSession(StudentModel student) async {
    final level = student.currentLevel;
    if (level < 1 || level > CurriculumPosition.totalLevels) {
      // A corrupted or legacy record. Not the end of the curriculum, and not a
      // position to advance from either.
      return const _CurriculumDataMissing();
    }

    final next = await _curriculumRepository.getSessionByOrderInLevel(
      level: level,
      orderInLevel: student.currentOrderInLevel + 1,
    );
    if (next != null) return _Advanced(next);

    // No next session in this level. Is the level really finished, or is the
    // data holed?
    final catalog = await _curriculumRepository.getLevelByNumber(level);
    if (catalog != null &&
        catalog.sessionCount > 0 &&
        student.currentOrderInLevel < catalog.sessionCount) {
      return const _CurriculumDataMissing();
    }

    for (
      var nextLevel = level + 1;
      nextLevel <= CurriculumPosition.totalLevels;
      nextLevel++
    ) {
      final first = await _curriculumRepository.getSessionByOrderInLevel(
        level: nextLevel,
        orderInLevel: 1,
      );
      if (first != null) return _Advanced(first);
    }

    // Nothing ahead. If the student was in the last level, that is the end of
    // the curriculum — a structural fact. Otherwise the levels ahead simply
    // have no seeded data, which is a data problem and must not be credited as
    // completion.
    if (level == CurriculumPosition.totalLevels) {
      return const _CurriculumCompleted();
    }
    return const _CurriculumDataMissing();
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
