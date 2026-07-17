import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:al_rasikhoon/core/constants/app_constants.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import '../../domain/curriculum/curriculum_position.dart';
import '../../domain/curriculum/meetings_per_week.dart';
import 'session_model.dart';

class StudentModel {
  final String id;
  final String userId;
  final String instituteId;
  final String? teacherId;
  final String? guardianId;

  /// Where the student stands: `(level, juz, session)` — the identity of a
  /// curriculum session document.
  final int currentLevel;
  final int currentJuz;
  final int currentSession;

  /// A LABEL, only meaningful in levels 1-2. Never identity, never ordering.
  final int? currentHizb;

  final int currentAttempt;

  // --- The current session, denormalized ------------------------------------
  // Firestore cannot join, and the supervisor's exam queue must stay ONE query
  // ("every student of my institute standing on an exam"). So the facts the
  // queue and the dashboards filter on are copied onto the student and kept in
  // step whenever the student advances.

  /// The doc id of the session the student stands on (`L{level}_J{juz}_S{n}`).
  final String currentSessionId;

  /// What that session IS — read from the curriculum, never from its number.
  final SessionKind currentSessionKind;

  /// The tier of that session if it is an assessment; null for a lesson.
  final AssessmentTier? currentSessionTier;

  /// The assessment's verbatim Arabic label from the source; null for a lesson.
  final String? currentSessionLabelAr;

  /// The session's position within the level — THE ordering key for advancement
  /// and the numerator of the level progress bar.
  final int currentOrderInLevel;
  // --------------------------------------------------------------------------

  final List<int> completedLevels;
  final List<int> unlockedLevels;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  /// Whether the student has finished the entire curriculum: they passed the
  /// اختبار of the last session of the last level, so there is no session ahead
  /// of them to move onto. Their position stands frozen on that final اختبار
  /// (there is nowhere to advance it to), which is precisely why this flag
  /// exists: without it a finished student — still denormalized as standing on
  /// an اختبار — would sit in the supervisor's exam queue forever and be
  /// re-examined indefinitely. Set once, on the final pass, by
  /// [StudentRepository.advanceStudentSession]; never unset.
  final bool curriculumCompleted;

  /// When the curriculum was completed. Null until the final pass. Paired with
  /// [curriculumCompleted] so "graduated" carries a date, the way [createdAt]
  /// and [updatedAt] date the rest of the record.
  final DateTime? curriculumCompletedAt;

  /// Where this student entered the curriculum. Everything before it is
  /// credited as memorized before joining — the app never taught it. Students
  /// created before flexible placement have no stored anchor and read back as
  /// [CurriculumPosition.start], which is exactly what they were.
  final CurriculumPosition enrollmentPosition;

  /// How many lessons this student covers in one meeting.
  ///
  /// The curriculum is authored for the average student — one meeting, one
  /// session. A student who memorizes quickly can be run at N×, set by their
  /// teacher or supervisor, changeable mid-level.
  ///
  /// The student stores where a meeting STARTS, never how far it extends: the
  /// extent is derived from this pace at read time, which is what lets a pace
  /// change take effect immediately with nothing to migrate.
  final CurriculumPace pace;

  /// How many meetings this student attends in one week — the declared cadence
  /// behind the completion forecast (متى الختم؟), set by their teacher or
  /// supervisor alongside the pace. Pure config: it schedules nothing.
  final MeetingsPerWeek meetingsPerWeek;

  StudentModel({
    required this.id,
    required this.userId,
    required this.instituteId,
    this.teacherId,
    this.guardianId,
    this.currentLevel = 1,
    this.currentJuz = 30,
    this.currentSession = 1,
    this.currentHizb,
    this.currentAttempt = 1,
    this.currentSessionId = 'L1_J30_S1',
    this.currentSessionKind = SessionKind.lesson,
    this.currentSessionTier,
    this.currentSessionLabelAr,
    this.currentOrderInLevel = 1,
    this.completedLevels = const [],
    this.unlockedLevels = const [1],
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.curriculumCompleted = false,
    this.curriculumCompletedAt,
    this.enrollmentPosition = CurriculumPosition.start,
    CurriculumPace? pace,
    MeetingsPerWeek? meetingsPerWeek,
  }) : pace = pace ?? CurriculumPace.standard,
       meetingsPerWeek = meetingsPerWeek ?? MeetingsPerWeek.standard;

  /// Enrolls a student onto [session], crediting every level before it as
  /// already memorized. The student's current position *is* the anchor: they
  /// start work at the session they were placed on — which may be a lesson, a
  /// سرد or an اختبار at any tier.
  ///
  /// Takes the [SessionModel] itself so the denormalized facts cannot contradict
  /// the curriculum: they are copied from it, not guessed.
  factory StudentModel.enrolledAt({
    required String id,
    required String userId,
    required String instituteId,
    String? teacherId,
    String? guardianId,
    required SessionModel session,
    required DateTime createdAt,
  }) {
    final level = session.levelId;
    final completedLevels = [for (var l = 1; l < level; l++) l];
    final unlockedLevels = [for (var l = 1; l <= level; l++) l];

    return StudentModel(
      id: id,
      userId: userId,
      instituteId: instituteId,
      teacherId: teacherId,
      guardianId: guardianId,
      currentLevel: level,
      currentJuz: session.juzNumber,
      currentSession: session.sessionNumber,
      currentHizb: session.hizbNumber,
      currentSessionId: session.id,
      currentSessionKind: session.kind,
      currentSessionTier: session.scope?.tier,
      currentSessionLabelAr: session.scope?.labelAr,
      currentOrderInLevel: session.orderInLevel,
      completedLevels: completedLevels,
      unlockedLevels: unlockedLevels,
      enrollmentPosition: CurriculumPosition(
        level: level,
        juz: session.juzNumber,
        session: session.sessionNumber,
      ),
      createdAt: createdAt,
    );
  }

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel.fromJson(doc.id, data);
  }

  factory StudentModel.fromJson(String id, Map<String, dynamic> data) {
    final level = data['current_level'] as int? ?? 1;
    final juz = data['current_juz'] as int? ?? 30;
    final session = data['current_session'] as int? ?? 1;
    final kind = data['current_session_kind'];
    final tier = data['current_session_tier'];

    return StudentModel(
      id: id,
      userId: data['user_id'] ?? '',
      instituteId: data['institute_id'] ?? '',
      teacherId: data['teacher_id'],
      guardianId: data['guardian_id'],
      currentLevel: level,
      currentJuz: juz,
      currentSession: session,
      currentHizb: data['current_hizb'] as int?,
      currentAttempt: data['current_attempt'] as int? ?? 1,
      currentSessionId:
          data['current_session_id'] as String? ??
          'L${level}_J${juz}_S$session',
      // No production student document lacks this field: every write path
      // (StudentRepository._writePosition) sets it alongside the rest of the
      // position, atomically. Unlike an unknown non-null VALUE (which
      // SessionKindX.fromString already refuses to guess), a document
      // missing the field entirely is corrupted or unmigrated data — and
      // silently treating it as an ordinary lesson is exactly how a student
      // truly standing on an اختبار would drop, unnoticed, out of the
      // supervisor's exam queue. It must surface, not be guessed away.
      currentSessionKind: kind == null
          ? throw ArgumentError.value(
              null,
              'current_session_kind',
              'Student document $id is missing current_session_kind',
            )
          : SessionKindX.fromString(kind as String),
      currentSessionTier: tier == null
          ? null
          : AssessmentTierX.fromString(tier as String),
      currentSessionLabelAr: data['current_session_label_ar'] as String?,
      currentOrderInLevel: data['current_order_in_level'] as int? ?? 1,
      completedLevels: List<int>.from(data['completed_levels'] ?? []),
      unlockedLevels: List<int>.from(data['unlocked_levels'] ?? [1]),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
      // Absent on every student who has not finished — legacy documents and
      // in-progress students alike — so a missing field reads as "not yet
      // graduated", never surfaced as corruption.
      curriculumCompleted: data['curriculum_completed'] as bool? ?? false,
      curriculumCompletedAt: (data['curriculum_completed_at'] as Timestamp?)
          ?.toDate(),
      enrollmentPosition: data['enrollment_position'] == null
          ? CurriculumPosition.start
          : CurriculumPosition.fromMap(
              Map<String, dynamic>.from(data['enrollment_position'] as Map),
            ),
      pace: CurriculumPace.fromJson(data['pace']),
      meetingsPerWeek: MeetingsPerWeek.fromJson(data['meetings_per_week']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'institute_id': instituteId,
      'teacher_id': teacherId,
      'guardian_id': guardianId,
      'current_level': currentLevel,
      'current_juz': currentJuz,
      'current_session': currentSession,
      'current_hizb': currentHizb,
      'current_attempt': currentAttempt,
      'current_session_id': currentSessionId,
      'current_session_kind': currentSessionKind.value,
      'current_session_tier': currentSessionTier?.value,
      'current_session_label_ar': currentSessionLabelAr,
      'current_order_in_level': currentOrderInLevel,
      'completed_levels': completedLevels,
      'unlocked_levels': unlockedLevels,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_active': isActive,
      'curriculum_completed': curriculumCompleted,
      'curriculum_completed_at': curriculumCompletedAt != null
          ? Timestamp.fromDate(curriculumCompletedAt!)
          : null,
      'enrollment_position': enrollmentPosition.toMap(),
      'pace': pace.toJson(),
      'meetings_per_week': meetingsPerWeek.toJson(),
    };
  }

  StudentModel copyWith({
    String? id,
    String? userId,
    String? instituteId,
    String? teacherId,
    String? guardianId,
    int? currentLevel,
    int? currentJuz,
    int? currentSession,
    int? currentHizb,
    int? currentAttempt,
    String? currentSessionId,
    SessionKind? currentSessionKind,
    AssessmentTier? currentSessionTier,
    String? currentSessionLabelAr,
    int? currentOrderInLevel,
    List<int>? completedLevels,
    List<int>? unlockedLevels,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? curriculumCompleted,
    DateTime? curriculumCompletedAt,
    CurriculumPosition? enrollmentPosition,
    CurriculumPace? pace,
    MeetingsPerWeek? meetingsPerWeek,
  }) {
    return StudentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      instituteId: instituteId ?? this.instituteId,
      teacherId: teacherId ?? this.teacherId,
      guardianId: guardianId ?? this.guardianId,
      currentLevel: currentLevel ?? this.currentLevel,
      currentJuz: currentJuz ?? this.currentJuz,
      currentSession: currentSession ?? this.currentSession,
      currentHizb: currentHizb ?? this.currentHizb,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      currentSessionKind: currentSessionKind ?? this.currentSessionKind,
      currentSessionTier: currentSessionTier ?? this.currentSessionTier,
      currentSessionLabelAr:
          currentSessionLabelAr ?? this.currentSessionLabelAr,
      currentOrderInLevel: currentOrderInLevel ?? this.currentOrderInLevel,
      completedLevels: completedLevels ?? this.completedLevels,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      curriculumCompleted: curriculumCompleted ?? this.curriculumCompleted,
      curriculumCompletedAt:
          curriculumCompletedAt ?? this.curriculumCompletedAt,
      enrollmentPosition: enrollmentPosition ?? this.enrollmentPosition,
      pace: pace ?? this.pace,
      meetingsPerWeek: meetingsPerWeek ?? this.meetingsPerWeek,
    );
  }

  /// Moves the student onto [session], keeping the denormalized facts in step
  /// with the curriculum. The attempt counter resets: a new session is a fresh
  /// first attempt.
  StudentModel movedTo(SessionModel session) {
    return copyWith(
      currentLevel: session.levelId,
      currentJuz: session.juzNumber,
      currentSession: session.sessionNumber,
      currentHizb: session.hizbNumber,
      currentSessionId: session.id,
      currentSessionKind: session.kind,
      currentSessionTier: session.scope?.tier,
      currentSessionLabelAr: session.scope?.labelAr,
      currentOrderInLevel: session.orderInLevel,
      currentAttempt: 1,
    );
  }

  /// Where the student is now, as a curriculum position.
  CurriculumPosition get currentPosition => CurriculumPosition(
    level: currentLevel,
    juz: currentJuz,
    session: currentSession,
  );

  /// Whether the student stands on a سرد, assessed by their teacher.
  bool get canTakeSard => currentSessionKind == SessionKind.sard;

  /// Whether the student stands on an اختبار the supervisor should still
  /// assess. A graduated student's position stays frozen on the final اختبار
  /// they already passed — there is nowhere ahead to advance it to — so kind
  /// alone would keep offering them for re-examination forever. Graduation is
  /// the terminal state: once finished, there is no exam left to take.
  bool get canTakeExam =>
      currentSessionKind == SessionKind.exam && !curriculumCompleted;

  /// Whether the student stands on an assessment of any tier.
  bool get isOnAssessment => canTakeSard || canTakeExam;

  /// Whether the student stands on a تلقين — a session the teacher reads TO
  /// them, which cannot be failed.
  bool get isOnTalqeen => currentSessionKind == SessionKind.talqeen;

  /// The 3-attempt cap belongs to ordinary lessons ALONE, and is tested for
  /// positively.
  ///
  /// Assessments — سرد and اختبار alike, at every tier — may be retried without
  /// limit: a student who cannot yet recite a juz keeps working at it. A تلقين
  /// has no attempts to exhaust: it is never graded and never failed. Written
  /// as `!isOnAssessment && ...`, this would have capped it and locked the
  /// student out of a session they cannot fail.
  bool get hasReachedMaxAttempts =>
      currentSessionKind == SessionKind.lesson &&
      currentAttempt > AppConstants.maxSessionAttempts;

  /// Whether the student may start another attempt at their current session.
  bool get canStartSession => !hasReachedMaxAttempts;

  @override
  String toString() {
    return 'StudentModel(id: $id, userId: $userId, level: $currentLevel, session: $currentSessionId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
