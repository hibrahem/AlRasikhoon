import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../models/session_record_model.dart';
import '../models/sard_record_model.dart';
import '../models/exam_record_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/grade_calculator.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import '../../domain/curriculum/paced_session.dart';
import '../../domain/session/session_duration.dart';

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
  /// `kind` and `juzNumber` are read off the session this record NAMES — the
  /// last one [meeting] discharged — never off the student's denormalized
  /// `current_session_kind`/`current_juz`, which are a copy and can drift, and
  /// never inferred from [sessionNumber].
  /// [hizbNumber] is a LABEL, present only in levels 1-2. It keys nothing.
  /// [meeting] is the teaching meeting this ONE recitation discharged — one
  /// session at 1x pace, or several batched together at 2x and beyond. The
  /// teacher grades one recitation, so this writes exactly one record no
  /// matter how many curriculum sessions [meeting] spans; see
  /// [SessionRecordModel.toOrderInLevel] for why that span, not
  /// [sessionNumber], is the advancement key.
  /// [pace] is the student's pace SETTING, recorded verbatim as
  /// [SessionRecordModel.paceAtTime] — it is NOT derived from `meeting.sessions.length`,
  /// because a batch can truncate short of the pace (a تلقين or a سرد
  /// boundary stops it early) while the student's pace setting has not
  /// changed.
  /// [now] is a test seam; see [_writeSessionRecord].
  Future<SessionRecordModel> createSessionRecord({
    required String studentId,
    required String teacherId,
    required PacedSession meeting,
    required int levelId,
    int? hizbNumber,
    required int attemptNumber,
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
    required CurriculumPace pace,
    String? notes,
    DateTime? now,
    DateTime? startedAt,
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
        // The record NAMES the last session it discharged, so that a reader
        // that knows nothing of pace still lands on the right point in the
        // curriculum.
        curriculumSessionId: meeting.sessions.last.id,
        levelId: levelId,
        // Read off the session the record NAMES — not off the student's
        // denormalized `current_session_kind`/`current_juz`, which are a copy
        // and can drift. The meeting holds the real curriculum row.
        kind: meeting.sessions.last.kind,
        juzNumber: meeting.sessions.last.juzNumber,
        hizbNumber: hizbNumber,
        sessionNumber: meeting.sessions.last.sessionNumber,
        fromOrderInLevel: meeting.fromOrderInLevel,
        toOrderInLevel: meeting.toOrderInLevel,
        coversSessionIds: meeting.coversSessionIds,
        paceAtTime: pace.multiplier,
        date: writtenAt,
        attemptNumber: attemptNumber,
        grades: grades,
        // Which parts were actually recited, so history renders only these and
        // never shows a skipped review part as a passing zero-error card.
        presentParts: meeting.presentParts,
        passed: passed,
        repetitionsWithTeacher: repetitionsWithTeacher,
        homeRepetitionsRequired: homeRepetitionsRequired,
        notes: notes,
        createdAt: writtenAt,
        duration: startedAt == null
            ? null
            : SessionDuration(
                elapsed: writtenAt.difference(startedAt),
                target: SessionDuration.targetForPace(pace.multiplier),
              ).elapsed,
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
  /// [meeting] is the meeting this تلقين belongs to — see [createSessionRecord].
  /// A تلقين always stands alone (`PacedSessionComposer` never batches one),
  /// so [meeting] here always spans exactly one session; the shape still
  /// holds and needs no special case.
  ///
  /// `kind` and `juzNumber` are read off that session — never off the student's
  /// denormalized `current_session_kind`/`current_juz`, which are a copy and can
  /// drift. `kind` is always [SessionKind.talqeen] here, since this method
  /// records nothing else, but it still comes FROM the session rather than being
  /// hardcoded, exactly as the ordering key does.
  ///
  /// [pace] is the student's pace SETTING, recorded verbatim as
  /// [SessionRecordModel.paceAtTime] — see [createSessionRecord].
  ///
  /// [now] is a test seam; see [_writeSessionRecord].
  Future<SessionRecordModel> createTalqeenRecord({
    required String studentId,
    required String teacherId,
    required PacedSession meeting,
    required int levelId,
    int? hizbNumber,
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
    required CurriculumPace pace,
    String? notes,
    DateTime? now,
    DateTime? startedAt,
  }) {
    return _writeSessionRecord(
      (id, writtenAt) => SessionRecordModel(
        id: id,
        studentId: studentId,
        teacherId: teacherId,
        curriculumSessionId: meeting.sessions.last.id,
        levelId: levelId,
        // Read off the session the record NAMES — not off the student's
        // denormalized `current_session_kind`/`current_juz`, which are a copy
        // and can drift. The meeting holds the real curriculum row.
        kind: meeting.sessions.last.kind,
        juzNumber: meeting.sessions.last.juzNumber,
        hizbNumber: hizbNumber,
        sessionNumber: meeting.sessions.last.sessionNumber,
        fromOrderInLevel: meeting.fromOrderInLevel,
        toOrderInLevel: meeting.toOrderInLevel,
        coversSessionIds: meeting.coversSessionIds,
        paceAtTime: pace.multiplier,
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
        duration: startedAt == null
            ? null
            : SessionDuration(
                elapsed: writtenAt.difference(startedAt),
                target: SessionDuration.targetForPace(pace.multiplier),
              ).elapsed,
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
  /// student's records are written one per completed meeting, and a later
  /// meeting always carries a strictly greater `order_in_level` within a
  /// level, so on a same-instant tie the record further along the curriculum
  /// is the genuinely later one.
  ///
  /// `order_in_level` is now [SessionRecordModel.toOrderInLevel]'s
  /// compatibility mirror — see [SessionRecordModel.toFirestore] — kept
  /// deliberately UNCHANGED here rather than switched to `to_order_in_level`.
  /// Both old records (which only ever had `order_in_level`) and new records
  /// (which write both, in lockstep) sort correctly on this one field, so the
  /// query and its composite index (`student_id`, `date`, `order_in_level` in
  /// `firestore.indexes.json`) need no change.
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
    DateTime? startedAt,
    DateTime? now,
  }) async {
    // Per-component grade is level-based (hibrahem/AlRasikhoon#22): the same
    // error count maps to a different grade depending on the student's level.
    final gradeInfo = GradeCalculator.calculateForLevel(levelId, errorCount);

    final writtenAt = now ?? DateTime.now();
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
      date: writtenAt,
      errorCount: errorCount,
      grade: gradeInfo.nameAr,
      passed: gradeInfo.passed,
      attemptNumber: attemptNumber,
      notes: notes,
      createdAt: writtenAt,
      duration: startedAt == null ? null : writtenAt.difference(startedAt),
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
    DateTime? startedAt,
    DateTime? now,
  }) async {
    // Per-component grade is level-based (hibrahem/AlRasikhoon#22): the same
    // error count maps to a different grade depending on the student's level.
    final gradeInfo = GradeCalculator.calculateForLevel(levelId, errorCount);

    final writtenAt = now ?? DateTime.now();
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
      date: writtenAt,
      errorCount: errorCount,
      grade: gradeInfo.nameAr,
      passed: gradeInfo.passed,
      attemptNumber: attemptNumber,
      notes: notes,
      createdAt: writtenAt,
      duration: startedAt == null ? null : writtenAt.difference(startedAt),
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

  /// How many session records this teacher has recorded — optionally only
  /// those on or after [startDate].
  ///
  /// A Firestore aggregation `.count()`, so it never downloads the records:
  /// the profile screen needs the number, not the rows. Reuses the same
  /// `(teacher_id, date)` composite index as [getSessionRecordsForTeacher],
  /// so it adds no index.
  Future<int> getSessionCountForTeacher(
    String teacherId, {
    DateTime? startDate,
  }) async {
    Query<Map<String, dynamic>> query = _sessionRecordsCollection.where(
      'teacher_id',
      isEqualTo: teacherId,
    );

    if (startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    final result = await query.count().get();
    return result.count ?? 0;
  }

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
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(firestore: ref.watch(firestoreProvider));
});
