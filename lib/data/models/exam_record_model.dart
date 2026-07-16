import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/assessment/assessment_evaluation.dart';
import 'recitation_error_tally_fields.dart';
import 'session_model.dart';

/// An اختبار a student sat with the supervisor (إدارة الحلقات).
///
/// A record is scoped by the curriculum session it answers, not by a hizb: an
/// اختبار may cover a unit (half a juz), a whole juz, or every juz taught so far
/// in the level. [hizbNumber] survives only as a nullable label for levels 1-2.
class ExamRecordModel {
  final String id;
  final String studentId;
  final String supervisorId;

  /// The curriculum session this اختبار answers (`L{level}_J{juz}_S{n}`).
  final String curriculumSessionId;

  /// What it covered.
  final AssessmentTier tier;
  final List<int> juzNumbers;
  final int? hizbNumber;

  /// The curriculum's own verbatim wording of the scope.
  final String scopeLabelAr;

  final int levelId;
  final DateTime date;

  /// Total errors across all five questions and all four error types. Kept
  /// for statistics; NEVER what pass/fail is judged on — that is per-question.
  final int errorCount;

  /// The sheet's verdict wording: موفق / غير موفق. Records written before the
  /// curriculum-correct evaluation carry a lesson-scale grade (راسخ..محب)
  /// here; both display as stored.
  final String grade;
  final bool passed;
  final int attemptNumber;
  final String? notes;
  final DateTime createdAt;

  /// Errors per question in sheet order (السؤال الأول..الخامس). Empty for
  /// records written before assessments tracked per-question error types.
  final List<RecitationErrorTally> questionErrors;

  /// How long the assessment took, wall-clock from opening the session screen
  /// to save. Raw elapsed — assessments have no pace target, so there is no
  /// cap. Null for records written before assessments were timed.
  final Duration? duration;

  const ExamRecordModel({
    required this.id,
    required this.studentId,
    required this.supervisorId,
    required this.curriculumSessionId,
    required this.tier,
    this.juzNumbers = const [],
    this.hizbNumber,
    this.scopeLabelAr = '',
    required this.levelId,
    required this.date,
    required this.errorCount,
    required this.grade,
    required this.passed,
    required this.attemptNumber,
    this.notes,
    required this.createdAt,
    this.questionErrors = const [],
    this.duration,
  });

  factory ExamRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamRecordModel(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      supervisorId: data['supervisor_id'] ?? '',
      curriculumSessionId: data['curriculum_session_id'] ?? '',
      tier: AssessmentTierX.fromString(data['tier'] as String),
      juzNumbers: List<int>.from(data['juz_numbers'] ?? const <int>[]),
      hizbNumber: data['hizb_number'] as int?,
      scopeLabelAr: data['scope_label_ar'] as String? ?? '',
      levelId: data['level_id'] ?? 1,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      errorCount: data['error_count'] ?? 0,
      grade: data['grade'] ?? '',
      passed: data['passed'] ?? false,
      attemptNumber: data['attempt_number'] ?? 1,
      notes: data['notes'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      questionErrors: recitationTalliesFromJson(data['question_errors']),
      duration: (data['duration_seconds'] as int?) == null
          ? null
          : Duration(seconds: data['duration_seconds'] as int),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'student_id': studentId,
      'supervisor_id': supervisorId,
      'curriculum_session_id': curriculumSessionId,
      'tier': tier.value,
      'juz_numbers': juzNumbers,
      'hizb_number': hizbNumber,
      'scope_label_ar': scopeLabelAr,
      'level_id': levelId,
      'date': Timestamp.fromDate(date),
      'error_count': errorCount,
      'grade': grade,
      'passed': passed,
      'attempt_number': attemptNumber,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'question_errors': recitationTalliesToJson(questionErrors),
      'duration_seconds': duration?.inSeconds,
    };
  }

  ExamRecordModel copyWith({
    String? id,
    String? studentId,
    String? supervisorId,
    String? curriculumSessionId,
    AssessmentTier? tier,
    List<int>? juzNumbers,
    int? hizbNumber,
    String? scopeLabelAr,
    int? levelId,
    DateTime? date,
    int? errorCount,
    String? grade,
    bool? passed,
    int? attemptNumber,
    String? notes,
    DateTime? createdAt,
    List<RecitationErrorTally>? questionErrors,
    Duration? duration,
  }) {
    return ExamRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      supervisorId: supervisorId ?? this.supervisorId,
      curriculumSessionId: curriculumSessionId ?? this.curriculumSessionId,
      tier: tier ?? this.tier,
      juzNumbers: juzNumbers ?? this.juzNumbers,
      hizbNumber: hizbNumber ?? this.hizbNumber,
      scopeLabelAr: scopeLabelAr ?? this.scopeLabelAr,
      levelId: levelId ?? this.levelId,
      date: date ?? this.date,
      errorCount: errorCount ?? this.errorCount,
      grade: grade ?? this.grade,
      passed: passed ?? this.passed,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      questionErrors: questionErrors ?? this.questionErrors,
      duration: duration ?? this.duration,
    );
  }

  @override
  String toString() {
    return 'ExamRecordModel(id: $id, student: $studentId, session: $curriculumSessionId, tier: ${tier.value}, passed: $passed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExamRecordModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
