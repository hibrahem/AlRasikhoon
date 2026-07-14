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

  /// What the session this record is FOR IS — a تلقين or a lesson, copied
  /// verbatim from the session (via `student.currentSessionKind` at write
  /// time), never inferred from [sessionNumber]. A تلقين is never graded, so
  /// this is what tells the pass/fail statistics and the history/detail
  /// screens to treat this record as attendance, not a graded pass.
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

  /// The curriculum's ordering key (1..M within [levelId]), copied verbatim
  /// from the session this record is FOR — never recomputed, never inferred
  /// from [sessionNumber]. It is the only thing that orders session records
  /// within a level: juz numbers cannot (level 10 teaches juz 1 → 2 → 3), and
  /// [date]/[createdAt] cannot either, since both come from the same
  /// `DateTime.now()` at write time and can tie.
  final int orderInLevel;
  final DateTime date;
  final int attemptNumber;
  final SessionGrades grades;
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
    required this.orderInLevel,
    required this.date,
    required this.attemptNumber,
    required this.grades,
    required this.passed,
    this.repetitionsWithTeacher = 0,
    this.homeRepetitionsRequired = 0,
    this.notes,
    required this.createdAt,
  });

  factory SessionRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionRecordModel(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      teacherId: data['teacher_id'] ?? '',
      curriculumSessionId: data['curriculum_session_id'] ?? '',
      levelId: data['level_id'] ?? 1,
      // Falls back to a lesson only for records written before `kind`
      // existed — every one of them WAS a graded lesson attempt, since a
      // تلقين could not be recorded before this field shipped.
      kind: data['kind'] != null
          ? SessionKindX.fromString(data['kind'] as String)
          : SessionKind.lesson,
      // Null only for records written before this field existed. Never a
      // sentinel like 0 (not a real juz) and never guessed from the
      // student's current juz — a caller that needs a juz for an absent
      // record must fall back explicitly, the way `addPractice` falls back
      // to the student's own current juz.
      juzNumber: data['juz_number'] as int?,
      hizbNumber: data['hizb_number'] as int?,
      sessionNumber: data['session_number'] ?? 1,
      // Falls back to 1 only for records written before this field existed —
      // never recomputed from sessionNumber for records that do carry it.
      orderInLevel: data['order_in_level'] as int? ?? 1,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attemptNumber: data['attempt_number'] ?? 1,
      grades: SessionGrades.fromJson(data['grades']),
      passed: data['passed'] ?? false,
      repetitionsWithTeacher: data['repetitions_with_teacher'] ?? 0,
      homeRepetitionsRequired: data['home_repetitions_required'] ?? 0,
      notes: data['notes'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'order_in_level': orderInLevel,
      'date': Timestamp.fromDate(date),
      'attempt_number': attemptNumber,
      'grades': grades.toJson(),
      'passed': passed,
      'repetitions_with_teacher': repetitionsWithTeacher,
      'home_repetitions_required': homeRepetitionsRequired,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
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
    int? orderInLevel,
    DateTime? date,
    int? attemptNumber,
    SessionGrades? grades,
    bool? passed,
    int? repetitionsWithTeacher,
    int? homeRepetitionsRequired,
    String? notes,
    DateTime? createdAt,
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
      orderInLevel: orderInLevel ?? this.orderInLevel,
      date: date ?? this.date,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      grades: grades ?? this.grades,
      passed: passed ?? this.passed,
      repetitionsWithTeacher:
          repetitionsWithTeacher ?? this.repetitionsWithTeacher,
      homeRepetitionsRequired:
          homeRepetitionsRequired ?? this.homeRepetitionsRequired,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
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
