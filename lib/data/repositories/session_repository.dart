import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
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

  /// Allocates a fresh doc ref, builds the record from it via [build], and
  /// persists it. Shared by [createSessionRecord] and [createTalqeenRecord] so
  /// the doc-ref → construct → save sequence cannot drift between the two.
  ///
  /// [build] receives a single `writtenAt` instant used for BOTH `date` and
  /// `created_at` — one `DateTime.now()` call, not two, so the fields cannot
  /// silently disagree. [now] is a narrow test seam (defaults to
  /// `DateTime.now()`) letting tests give a record an exact, explicit instant
  /// instead of writing raw documents the app itself could never produce.
  Future<SessionRecordModel> _writeSessionRecord(
    SessionRecordModel Function(String id, DateTime writtenAt) build, {
    DateTime? now,
  }) async {
    final docRef = _sessionRecordsCollection.doc();
    final record = build(docRef.id, now ?? DateTime.now());
    await docRef.set(record.toFirestore());
    return record;
  }

  /// Create session record
  ///
  /// [kind] and [juzNumber] are copied verbatim from the session this record
  /// is FOR (via `student.currentSessionKind`/`currentJuz` at write time) —
  /// never inferred from [sessionNumber].
  /// [hizbNumber] is a LABEL, present only in levels 1-2. It keys nothing.
  /// [orderInLevel] is the curriculum's ordering key — copied verbatim from
  /// the session this record is FOR (never recomputed from [sessionNumber]).
  /// [now] is a test seam; see [_writeSessionRecord].
  Future<SessionRecordModel> createSessionRecord({
    required String studentId,
    required String teacherId,
    required String curriculumSessionId,
    required int levelId,
    required SessionKind kind,
    required int juzNumber,
    int? hizbNumber,
    required int sessionNumber,
    required int orderInLevel,
    required int attemptNumber,
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
    String? notes,
    DateTime? now,
  }) {
    final grades = SessionGrades(
      newMemorizationErrors: newMemorizationErrors,
      recentReviewErrors: recentReviewErrors,
      distantReviewErrors: distantReviewErrors,
    );

    // Session-level pass/fail is level-based and fails on ANY محب component
    // (hibrahem/AlRasikhoon#24) — no averaging, no level-agnostic threshold.
    final passed = grades.passesForLevel(levelId);

    return _writeSessionRecord(
      (id, writtenAt) => SessionRecordModel(
        id: id,
        studentId: studentId,
        teacherId: teacherId,
        curriculumSessionId: curriculumSessionId,
        levelId: levelId,
        kind: kind,
        juzNumber: juzNumber,
        hizbNumber: hizbNumber,
        sessionNumber: sessionNumber,
        orderInLevel: orderInLevel,
        date: writtenAt,
        attemptNumber: attemptNumber,
        grades: grades,
        passed: passed,
        repetitionsWithTeacher: repetitionsWithTeacher,
        homeRepetitionsRequired: homeRepetitionsRequired,
        notes: notes,
        createdAt: writtenAt,
      ),
      now: now,
    );
  }

  /// Records that a تلقين happened.
  ///
  /// A تلقين is not graded: the teacher recites the new passage to the student
  /// and repeats it with him. There are no errors to count and nothing to fail,
  /// so the record carries zeroed grades and passes unconditionally — it exists
  /// for history and attendance, and to carry the home assignment.
  ///
  /// [kind] and [juzNumber] are copied verbatim from the session this record
  /// is FOR (via `student.currentSessionKind`/`currentJuz` at write time) —
  /// [kind] is always [SessionKind.talqeen] here, since this method records
  /// nothing else, but it is threaded through rather than hardcoded so the
  /// value keeps coming from the session, exactly like [orderInLevel].
  /// [orderInLevel] is the curriculum's ordering key — copied verbatim from
  /// the session this record is FOR (never recomputed from [sessionNumber]).
  /// [now] is a test seam; see [_writeSessionRecord].
  Future<SessionRecordModel> createTalqeenRecord({
    required String studentId,
    required String teacherId,
    required String curriculumSessionId,
    required int levelId,
    required SessionKind kind,
    required int juzNumber,
    int? hizbNumber,
    required int sessionNumber,
    required int orderInLevel,
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
    String? notes,
    DateTime? now,
  }) {
    return _writeSessionRecord(
      (id, writtenAt) => SessionRecordModel(
        id: id,
        studentId: studentId,
        teacherId: teacherId,
        curriculumSessionId: curriculumSessionId,
        levelId: levelId,
        kind: kind,
        juzNumber: juzNumber,
        hizbNumber: hizbNumber,
        sessionNumber: sessionNumber,
        orderInLevel: orderInLevel,
        date: writtenAt,
        attemptNumber: 1,
        grades: const SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        ),
        passed: true,
        repetitionsWithTeacher: repetitionsWithTeacher,
        homeRepetitionsRequired: homeRepetitionsRequired,
        notes: notes,
        createdAt: writtenAt,
      ),
      now: now,
    );
  }

  /// The student's most recent session record — the one carrying the home
  /// assignment they are currently working off.
  ///
  /// Ordered by `date` DESC, then `order_in_level` DESC as a tie-break.
  /// `order_in_level` — not `created_at` — because `date` and `created_at` are
  /// both stamped from the SAME `DateTime.now()` call (see
  /// `_writeSessionRecord`), so anything that ties `date` ties `created_at`
  /// too; that pairing can never break a tie. `order_in_level` can: a
  /// student's records are written one per completed session, and a later
  /// session always carries a strictly greater `order_in_level` within a
  /// level, so on a same-instant tie the record further along the curriculum
  /// is the genuinely later one.
  Future<SessionRecordModel?> getLatestSessionRecord(String studentId) async {
    final query = await _sessionRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .orderBy('order_in_level', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return SessionRecordModel.fromFirestore(query.docs.first);
  }

  /// Get a single session record by id.
  Future<SessionRecordModel?> getSessionRecordById(String recordId) async {
    final doc = await _sessionRecordsCollection.doc(recordId).get();
    if (doc.exists) {
      return SessionRecordModel.fromFirestore(doc);
    }
    return null;
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
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
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

  /// Record a سرد, scoped by the curriculum session it answers.
  ///
  /// The scope — [tier], [juzNumbers], the optional [hizbNumber] label and the
  /// curriculum's verbatim [scopeLabelAr] — comes from the session itself. A
  /// record keyed on a hizb could not even represent a juz- or level-tier سرد
  /// (`سرد الجزء رقم 30 كاملًا`, `سرد المستوى كاملًا`), which have no hizb at all.
  Future<SardRecordModel> createSardRecord({
    required String studentId,
    required String teacherId,
    required String curriculumSessionId,
    required AssessmentTier tier,
    List<int> juzNumbers = const [],
    int? hizbNumber,
    String scopeLabelAr = '',
    required int levelId,
    required int attemptNumber,
    required int errorCount,
    String? notes,
  }) async {
    // Per-component grade is level-based (hibrahem/AlRasikhoon#22): the same
    // error count maps to a different grade depending on the student's level.
    final gradeInfo = GradeCalculator.calculateForLevel(levelId, errorCount);

    final docRef = _sardRecordsCollection.doc();
    final record = SardRecordModel(
      id: docRef.id,
      studentId: studentId,
      teacherId: teacherId,
      curriculumSessionId: curriculumSessionId,
      tier: tier,
      juzNumbers: juzNumbers,
      hizbNumber: hizbNumber,
      scopeLabelAr: scopeLabelAr,
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
  Future<List<SardRecordModel>> getSardRecordsForStudent(
    String studentId,
  ) async {
    final result = await _sardRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .get();

    return result.docs
        .map((doc) => SardRecordModel.fromFirestore(doc))
        .toList();
  }

  /// How many times this student has attempted this سرد.
  ///
  /// Keyed on the curriculum session, not a hizb: a juz- or level-tier سرد has
  /// no hizb, and two different سرد of the same hizb (unit and juz) would
  /// otherwise share a count. Assessments may be retried without limit, so this
  /// count numbers the attempts — it never caps them.
  Future<int> getSardAttemptCount({
    required String studentId,
    required String curriculumSessionId,
  }) async {
    final result = await _sardRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .where('curriculum_session_id', isEqualTo: curriculumSessionId)
        .count()
        .get();

    return result.count ?? 0;
  }

  // ==================== Exam Records ====================

  /// Record an اختبار, scoped by the curriculum session it answers — see
  /// [createSardRecord]; the same scope reaches the supervisor's record.
  Future<ExamRecordModel> createExamRecord({
    required String studentId,
    required String supervisorId,
    required String curriculumSessionId,
    required AssessmentTier tier,
    List<int> juzNumbers = const [],
    int? hizbNumber,
    String scopeLabelAr = '',
    required int levelId,
    required int attemptNumber,
    required int errorCount,
    String? notes,
  }) async {
    // Per-component grade is level-based (hibrahem/AlRasikhoon#22): the same
    // error count maps to a different grade depending on the student's level.
    final gradeInfo = GradeCalculator.calculateForLevel(levelId, errorCount);

    final docRef = _examRecordsCollection.doc();
    final record = ExamRecordModel(
      id: docRef.id,
      studentId: studentId,
      supervisorId: supervisorId,
      curriculumSessionId: curriculumSessionId,
      tier: tier,
      juzNumbers: juzNumbers,
      hizbNumber: hizbNumber,
      scopeLabelAr: scopeLabelAr,
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
  Future<List<ExamRecordModel>> getExamRecordsForStudent(
    String studentId,
  ) async {
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
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final result = await query.get();
    return result.docs
        .map((doc) => ExamRecordModel.fromFirestore(doc))
        .toList();
  }

  /// How many times this student has sat this اختبار — keyed on the curriculum
  /// session, and uncapped; see [getSardAttemptCount].
  Future<int> getExamAttemptCount({
    required String studentId,
    required String curriculumSessionId,
  }) async {
    final result = await _examRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .where('curriculum_session_id', isEqualTo: curriculumSessionId)
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

    // A تلقين is never graded — no errors, no pass/fail — so it must not
    // inflate `total_sessions`/`passed_sessions` with a phantom pass. Only
    // graded lesson records count here.
    final gradedSessionRecords = sessionRecords
        .where((r) => !r.isTalqeen)
        .toList();
    final totalSessions = gradedSessionRecords.length;
    final passedSessions = gradedSessionRecords.where((r) => r.passed).length;
    final totalSards = sardRecords.length;
    final passedSards = sardRecords.where((r) => r.passed).length;
    final totalExams = examRecords.length;
    final passedExams = examRecords.where((r) => r.passed).length;

    return {
      'total_sessions': totalSessions,
      'passed_sessions': passedSessions,
      'session_pass_rate': totalSessions > 0
          ? passedSessions / totalSessions
          : 0,
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionRecordModel.fromFirestore(doc))
              .toList(),
        );
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(firestore: ref.watch(firestoreProvider));
});
