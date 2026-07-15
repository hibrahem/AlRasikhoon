import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/grade_calculator.dart';
import 'session_model.dart';

class SessionGrades {
  final int newMemorizationErrors;
  final int recentReviewErrors;
  final int distantReviewErrors;

  const SessionGrades({
    required this.newMemorizationErrors,
    required this.recentReviewErrors,
    required this.distantReviewErrors,
  });

  factory SessionGrades.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      );
    }
    return SessionGrades(
      newMemorizationErrors: json['new_memorization_errors'] ?? 0,
      recentReviewErrors: json['recent_review_errors'] ?? 0,
      distantReviewErrors: json['distant_review_errors'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'new_memorization_errors': newMemorizationErrors,
      'recent_review_errors': recentReviewErrors,
      'distant_review_errors': distantReviewErrors,
    };
  }

  int get totalErrors =>
      newMemorizationErrors + recentReviewErrors + distantReviewErrors;

  /// The error count recorded for a recitation [part]: 1 = new memorization,
  /// 2 = recent review, 3 = distant review. Lets a reader walk
  /// [SessionRecordModel.presentParts] instead of naming the three fields by
  /// hand.
  int errorsForPart(int part) {
    switch (part) {
      case 1:
        return newMemorizationErrors;
      case 2:
        return recentReviewErrors;
      case 3:
        return distantReviewErrors;
      default:
        return 0;
    }
  }

  /// Whether the session passes at the student's [level], per
  /// hibrahem/AlRasikhoon#24: FAILED if ANY component grades محب (ويعاد),
  /// passes only if none is محب. No averaging, no level-agnostic threshold —
  /// the component grade is level-based (#22) via [GradeCalculator].
  bool passesForLevel(int level) => GradeCalculator.sessionPassesForLevel(
    level: level,
    newMemorizationErrors: newMemorizationErrors,
    recentReviewErrors: recentReviewErrors,
    distantReviewErrors: distantReviewErrors,
  );
}

class SessionRecordModel {
  final String id;
  final String studentId;
  final String teacherId;
  final String curriculumSessionId;
  final int levelId;

  /// What the session this record is FOR IS — a تلقين or a lesson, read off
  /// that curriculum session itself (the last one the meeting discharged), never
  /// off the student's denormalized `current_session_kind`, and never inferred
  /// from [sessionNumber]. A تلقين is never graded, so this is what tells the
  /// pass/fail statistics and the history/detail screens to treat this record as
  /// attendance, not a graded pass.
  final SessionKind kind;

  /// The juz this record's session belongs to, copied verbatim from the
  /// session this record is FOR — never the student's CURRENT juz, which may
  /// already be a different one by the time this is read (the teacher may
  /// have advanced the student across a juz boundary in between).
  ///
  /// Null only for records written before this field existed — those records
  /// genuinely do not carry a juz, so this stays nullable rather than
  /// defaulting to a sentinel like `0`, which is not a real juz and would be
  /// written straight into a new document (e.g. home practice) by any caller
  /// that read it with `??`.
  final int? juzNumber;

  /// A LABEL, present only in levels 1-2 — and absent even there on juz- and
  /// level-tier sessions. It keys nothing: the record is identified by
  /// [curriculumSessionId]. It used to default to 59, which quietly filed every
  /// record of the curriculum under the first hizb of level 1.
  final int? hizbNumber;
  final int sessionNumber;

  /// The first session this meeting discharged.
  final int fromOrderInLevel;

  /// The LAST session this meeting discharged, and THE advancement key: the
  /// student's next meeting begins at `toOrderInLevel + 1`.
  ///
  /// Copied verbatim from the curriculum, never recomputed from
  /// [sessionNumber]. It is the only thing that orders session records within a
  /// level: juz numbers cannot (level 10 teaches juz 1 → 2 → 3), and
  /// [date]/[createdAt] cannot either, since both come from the same
  /// `DateTime.now()` at write time and can tie. This can: a later meeting
  /// always carries a strictly greater [toOrderInLevel] within a level.
  final int toOrderInLevel;

  /// Every curriculum session this ONE recitation discharged. A student at 2x
  /// recites two sessions' content in one sitting and is graded once — writing
  /// two records would fabricate an observation that never happened.
  final List<String> coversSessionIds;

  /// The STUDENT'S PACE SETTING in force when this was recorded — not the
  /// number of sessions this meeting happened to cover. History must not be
  /// rewritten when the student's pace later changes: the student may be
  /// moved back to 1x tomorrow, but he really was a [paceAtTime]x student
  /// when this was recorded. A batch can truncate short of the pace (a تلقين
  /// or a سرد boundary stops it early), so [coversSessionIds.length] can be
  /// LESS than [paceAtTime] — the two must never be conflated.
  final int paceAtTime;

  /// Whether this meeting covered more than one curriculum session.
  bool get isBatched => coversSessionIds.length > 1;

  final DateTime date;
  final int attemptNumber;
  final SessionGrades grades;

  /// The recitation parts (1 = new memorization, 2 = recent review, 3 =
  /// distant review) this meeting actually evaluated, copied verbatim from the
  /// meeting's `presentParts` at write time. A review-only or short meeting
  /// omits parts 2 and/or 3, so history must render only these — a part left
  /// out was never recited, and its zeroed grade is absence, not a perfect
  /// score.
  ///
  /// Records written before this field existed do not carry it. They read back
  /// as all three present ([1, 2, 3]): the parts they actually evaluated are
  /// not reconstructable from an error count alone (0 errors is
  /// indistinguishable from an absent part), so the legacy view is preserved
  /// rather than guessed.
  final List<int> presentParts;
  final bool passed;

  /// How many times teacher and student recited the passage through TOGETHER in
  /// the session. Carried by the sessions that teach new content — a تلقين and
  /// a lesson.
  final int repetitionsWithTeacher;

  /// How many repetitions the student owes at home before the next session. An
  /// assignment, not a note: the student sees it and their home practice counts
  /// against it.
  final int homeRepetitionsRequired;
  final String? notes;
  final DateTime createdAt;

  /// How long the session took, wall-clock from start to save. Null for
  /// records written before sessions were timed, and for any record whose
  /// start was not captured. Capped to 3× the pace target at write time; see
  /// [SessionDuration].
  final Duration? duration;

  const SessionRecordModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.curriculumSessionId,
    this.levelId = 1,
    required this.kind,
    required this.juzNumber,
    this.hizbNumber,
    this.sessionNumber = 1,
    required this.fromOrderInLevel,
    required this.toOrderInLevel,
    required this.coversSessionIds,
    this.paceAtTime = 1,
    required this.date,
    required this.attemptNumber,
    required this.grades,
    this.presentParts = const [1, 2, 3],
    required this.passed,
    this.repetitionsWithTeacher = 0,
    this.homeRepetitionsRequired = 0,
    this.notes,
    required this.createdAt,
    this.duration,
  });

  factory SessionRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionRecordModel.fromJson(doc.id, data);
  }

  factory SessionRecordModel.fromJson(String id, Map<String, dynamic> json) {
    final curriculumSessionId = json['curriculum_session_id'] ?? '';
    // Backward compatibility: every record written before paced curricula
    // has `order_in_level` and no span. It must read back as a
    // single-session, pace-1 meeting — never recomputed, never guessed.
    final toOrderInLevel =
        json['to_order_in_level'] as int? ??
        json['order_in_level'] as int? ??
        1;
    return SessionRecordModel(
      id: id,
      studentId: json['student_id'] ?? '',
      teacherId: json['teacher_id'] ?? '',
      curriculumSessionId: curriculumSessionId,
      levelId: json['level_id'] ?? 1,
      // Falls back to a lesson only for records written before `kind`
      // existed — every one of them WAS a graded lesson attempt, since a
      // تلقين could not be recorded before this field shipped.
      kind: json['kind'] != null
          ? SessionKindX.fromString(json['kind'] as String)
          : SessionKind.lesson,
      // Null only for records written before this field existed. Never a
      // sentinel like 0 (not a real juz) and never guessed from the
      // student's current juz — a caller that needs a juz for an absent
      // record must fall back explicitly, the way `addPractice` falls back
      // to the student's own current juz.
      juzNumber: json['juz_number'] as int?,
      hizbNumber: json['hizb_number'] as int?,
      sessionNumber: json['session_number'] ?? 1,
      fromOrderInLevel: json['from_order_in_level'] as int? ?? toOrderInLevel,
      toOrderInLevel: toOrderInLevel,
      coversSessionIds: json['covers_session_ids'] != null
          ? List<String>.from(json['covers_session_ids'] as List)
          : [curriculumSessionId as String],
      paceAtTime: json['pace_at_time'] as int? ?? 1,
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attemptNumber: json['attempt_number'] ?? 1,
      grades: SessionGrades.fromJson(json['grades']),
      // Records written before `present_parts` shipped do not carry it. They
      // read back as all three present rather than guessed from grades — a
      // zeroed part is indistinguishable from an absent one.
      presentParts: json['present_parts'] != null
          ? List<int>.from(json['present_parts'] as List)
          : const [1, 2, 3],
      passed: json['passed'] ?? false,
      repetitionsWithTeacher: json['repetitions_with_teacher'] ?? 0,
      homeRepetitionsRequired: json['home_repetitions_required'] ?? 0,
      notes: json['notes'],
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: (json['duration_seconds'] as int?) == null
          ? null
          : Duration(seconds: json['duration_seconds'] as int),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'student_id': studentId,
      'teacher_id': teacherId,
      'curriculum_session_id': curriculumSessionId,
      'level_id': levelId,
      'kind': kind.value,
      'juz_number': juzNumber,
      'hizb_number': hizbNumber,
      'session_number': sessionNumber,
      'from_order_in_level': fromOrderInLevel,
      'to_order_in_level': toOrderInLevel,
      // Compatibility mirror, kept equal to `toOrderInLevel`: pre-pace
      // readers, and `SessionRepository.getLatestSessionRecord`'s ordering
      // query, both key off `order_in_level`. Writing it here means old and
      // new records keep sorting together without a second Firestore index.
      'order_in_level': toOrderInLevel,
      'covers_session_ids': coversSessionIds,
      'pace_at_time': paceAtTime,
      'date': Timestamp.fromDate(date),
      'attempt_number': attemptNumber,
      'grades': grades.toJson(),
      'present_parts': presentParts,
      'passed': passed,
      'repetitions_with_teacher': repetitionsWithTeacher,
      'home_repetitions_required': homeRepetitionsRequired,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'duration_seconds': duration?.inSeconds,
    };
  }

  /// A تلقين is never graded: it carries no pass/fail and no error counts, so
  /// it must never be counted as a graded pass in statistics, and never
  /// rendered with a pass/fail badge or grade in history/detail.
  bool get isTalqeen => kind == SessionKind.talqeen;

  SessionRecordModel copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? curriculumSessionId,
    int? levelId,
    SessionKind? kind,
    int? juzNumber,
    int? hizbNumber,
    int? sessionNumber,
    int? fromOrderInLevel,
    int? toOrderInLevel,
    List<String>? coversSessionIds,
    int? paceAtTime,
    DateTime? date,
    int? attemptNumber,
    SessionGrades? grades,
    List<int>? presentParts,
    bool? passed,
    int? repetitionsWithTeacher,
    int? homeRepetitionsRequired,
    String? notes,
    DateTime? createdAt,
    Duration? duration,
  }) {
    return SessionRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      curriculumSessionId: curriculumSessionId ?? this.curriculumSessionId,
      levelId: levelId ?? this.levelId,
      kind: kind ?? this.kind,
      juzNumber: juzNumber ?? this.juzNumber,
      hizbNumber: hizbNumber ?? this.hizbNumber,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      fromOrderInLevel: fromOrderInLevel ?? this.fromOrderInLevel,
      toOrderInLevel: toOrderInLevel ?? this.toOrderInLevel,
      coversSessionIds: coversSessionIds ?? this.coversSessionIds,
      paceAtTime: paceAtTime ?? this.paceAtTime,
      date: date ?? this.date,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      grades: grades ?? this.grades,
      presentParts: presentParts ?? this.presentParts,
      passed: passed ?? this.passed,
      repetitionsWithTeacher:
          repetitionsWithTeacher ?? this.repetitionsWithTeacher,
      homeRepetitionsRequired:
          homeRepetitionsRequired ?? this.homeRepetitionsRequired,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
    );
  }

  @override
  String toString() {
    return 'SessionRecordModel(id: $id, student: $studentId, session: $curriculumSessionId, passed: $passed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionRecordModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
