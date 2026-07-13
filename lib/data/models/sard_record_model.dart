import 'package:cloud_firestore/cloud_firestore.dart';

import 'session_model.dart';

/// A سرد a student recited to their teacher.
///
/// A record is scoped by the curriculum session it answers, not by a hizb: a
/// سرد may cover a unit (half a juz), a whole juz, or every juz taught so far in
/// the level. [hizbNumber] survives only as a nullable label for levels 1-2.
class SardRecordModel {
  final String id;
  final String studentId;
  final String teacherId;

  /// The curriculum session this سرد answers (`L{level}_J{juz}_S{n}`).
  final String curriculumSessionId;

  /// What it covered.
  final AssessmentTier tier;
  final List<int> juzNumbers;
  final int? hizbNumber;

  /// The curriculum's own verbatim wording of the scope.
  final String scopeLabelAr;

  final int levelId;
  final DateTime date;
  final int errorCount;
  final String grade;
  final bool passed;
  final int attemptNumber;
  final String? notes;
  final DateTime createdAt;

  const SardRecordModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
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
  });

  factory SardRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SardRecordModel(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      teacherId: data['teacher_id'] ?? '',
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'student_id': studentId,
      'teacher_id': teacherId,
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
    };
  }

  SardRecordModel copyWith({
    String? id,
    String? studentId,
    String? teacherId,
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
  }) {
    return SardRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
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
    );
  }

  @override
  String toString() {
    return 'SardRecordModel(id: $id, student: $studentId, session: $curriculumSessionId, tier: ${tier.value}, passed: $passed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SardRecordModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
