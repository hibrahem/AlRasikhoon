import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_record_model.dart';
import '../models/sard_record_model.dart';
import '../models/exam_record_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/grade_calculator.dart';

class SessionRepository {
  final FirebaseFirestore _firestore;

  SessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessionRecordsCollection =>
      _firestore.collection(AppConstants.collectionSessionRecords);

  CollectionReference<Map<String, dynamic>> get _sardRecordsCollection =>
      _firestore.collection(AppConstants.collectionSardRecords);

  CollectionReference<Map<String, dynamic>> get _examRecordsCollection =>
      _firestore.collection(AppConstants.collectionExamRecords);

  // ==================== Session Records ====================

  /// Create session record
  Future<SessionRecordModel> createSessionRecord({
    required String studentId,
    required String teacherId,
    required String curriculumSessionId,
    required int levelId,
    required int hizbNumber,
    required int sessionNumber,
    required int attemptNumber,
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
    int repetitions = 0,
    String? notes,
  }) async {
    final grades = SessionGrades(
      newMemorizationErrors: newMemorizationErrors,
      recentReviewErrors: recentReviewErrors,
      distantReviewErrors: distantReviewErrors,
    );

    final passed = grades.allPartsPassed;

    final docRef = _sessionRecordsCollection.doc();
    final record = SessionRecordModel(
      id: docRef.id,
      studentId: studentId,
      teacherId: teacherId,
      curriculumSessionId: curriculumSessionId,
      levelId: levelId,
      hizbNumber: hizbNumber,
      sessionNumber: sessionNumber,
      date: DateTime.now(),
      attemptNumber: attemptNumber,
      grades: grades,
      passed: passed,
      repetitions: repetitions,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await docRef.set(record.toFirestore());
    return record;
  }

  /// Get session records for student
  Future<List<SessionRecordModel>> getSessionRecordsForStudent(
    String studentId, {
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _sessionRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final result = await query.get();
    return result.docs
        .map((doc) => SessionRecordModel.fromFirestore(doc))
        .toList();
  }

  /// Get session records for teacher
  Future<List<SessionRecordModel>> getSessionRecordsForTeacher(
    String teacherId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _sessionRecordsCollection
        .where('teacher_id', isEqualTo: teacherId)
        .orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    final result = await query.get();
    return result.docs
        .map((doc) => SessionRecordModel.fromFirestore(doc))
        .toList();
  }

  /// Get attempt count for specific curriculum session
  Future<int> getAttemptCount({
    required String studentId,
    required String curriculumSessionId,
  }) async {
    final result = await _sessionRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .where('curriculum_session_id', isEqualTo: curriculumSessionId)
        .count()
        .get();

    return result.count ?? 0;
  }

  // ==================== Sard Records ====================

  /// Create sard record
  Future<SardRecordModel> createSardRecord({
    required String studentId,
    required String teacherId,
    required int hizbNumber,
    required int juzNumber,
    required int levelId,
    required int attemptNumber,
    required int errorCount,
    String? notes,
  }) async {
    final gradeInfo = GradeCalculator.calculate(errorCount);

    final docRef = _sardRecordsCollection.doc();
    final record = SardRecordModel(
      id: docRef.id,
      studentId: studentId,
      teacherId: teacherId,
      hizbNumber: hizbNumber,
      juzNumber: juzNumber,
      levelId: levelId,
      date: DateTime.now(),
      errorCount: errorCount,
      grade: gradeInfo.nameAr,
      passed: gradeInfo.passed,
      attemptNumber: attemptNumber,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await docRef.set(record.toFirestore());
    return record;
  }

  /// Get sard records for student
  Future<List<SardRecordModel>> getSardRecordsForStudent(String studentId) async {
    final result = await _sardRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .get();

    return result.docs
        .map((doc) => SardRecordModel.fromFirestore(doc))
        .toList();
  }

  /// Get sard attempt count for specific hizb
  Future<int> getSardAttemptCount({
    required String studentId,
    required int hizbNumber,
  }) async {
    final result = await _sardRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .where('hizb_number', isEqualTo: hizbNumber)
        .count()
        .get();

    return result.count ?? 0;
  }

  // ==================== Exam Records ====================

  /// Create exam record
  Future<ExamRecordModel> createExamRecord({
    required String studentId,
    required String supervisorId,
    required int hizbNumber,
    required int juzNumber,
    required int levelId,
    required int attemptNumber,
    required int errorCount,
    String? notes,
  }) async {
    final gradeInfo = GradeCalculator.calculate(errorCount);

    final docRef = _examRecordsCollection.doc();
    final record = ExamRecordModel(
      id: docRef.id,
      studentId: studentId,
      supervisorId: supervisorId,
      hizbNumber: hizbNumber,
      juzNumber: juzNumber,
      levelId: levelId,
      date: DateTime.now(),
      errorCount: errorCount,
      grade: gradeInfo.nameAr,
      passed: gradeInfo.passed,
      attemptNumber: attemptNumber,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await docRef.set(record.toFirestore());
    return record;
  }

  /// Get exam records for student
  Future<List<ExamRecordModel>> getExamRecordsForStudent(String studentId) async {
    final result = await _examRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .get();

    return result.docs
        .map((doc) => ExamRecordModel.fromFirestore(doc))
        .toList();
  }

  /// Get exam records for supervisor
  Future<List<ExamRecordModel>> getExamRecordsForSupervisor(
    String supervisorId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _examRecordsCollection
        .where('supervisor_id', isEqualTo: supervisorId)
        .orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final result = await query.get();
    return result.docs
        .map((doc) => ExamRecordModel.fromFirestore(doc))
        .toList();
  }

  /// Get exam attempt count for specific hizb
  Future<int> getExamAttemptCount({
    required String studentId,
    required int hizbNumber,
  }) async {
    final result = await _examRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .where('hizb_number', isEqualTo: hizbNumber)
        .count()
        .get();

    return result.count ?? 0;
  }

  // ==================== Statistics ====================

  /// Get student statistics
  Future<Map<String, dynamic>> getStudentStatistics(String studentId) async {
    final sessionRecords = await getSessionRecordsForStudent(studentId);
    final sardRecords = await getSardRecordsForStudent(studentId);
    final examRecords = await getExamRecordsForStudent(studentId);

    final totalSessions = sessionRecords.length;
    final passedSessions = sessionRecords.where((r) => r.passed).length;
    final totalSards = sardRecords.length;
    final passedSards = sardRecords.where((r) => r.passed).length;
    final totalExams = examRecords.length;
    final passedExams = examRecords.where((r) => r.passed).length;

    return {
      'total_sessions': totalSessions,
      'passed_sessions': passedSessions,
      'session_pass_rate': totalSessions > 0 ? passedSessions / totalSessions : 0,
      'total_sards': totalSards,
      'passed_sards': passedSards,
      'total_exams': totalExams,
      'passed_exams': passedExams,
    };
  }

  /// Stream session records for student
  Stream<List<SessionRecordModel>> streamSessionRecordsForStudent(
    String studentId,
  ) {
    return _sessionRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRecordModel.fromFirestore(doc))
            .toList());
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(firestore: ref.watch(firestoreProvider));
});
