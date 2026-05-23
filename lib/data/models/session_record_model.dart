import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/grade_calculator.dart';

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
  final int hizbNumber;
  final int sessionNumber;
  final DateTime date;
  final int attemptNumber;
  final SessionGrades grades;
  final bool passed;
  final int repetitions;
  final String? notes;
  final DateTime createdAt;

  const SessionRecordModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.curriculumSessionId,
    this.levelId = 1,
    this.hizbNumber = 59,
    this.sessionNumber = 1,
    required this.date,
    required this.attemptNumber,
    required this.grades,
    required this.passed,
    this.repetitions = 0,
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
      hizbNumber: data['hizb_number'] ?? 59,
      sessionNumber: data['session_number'] ?? 1,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attemptNumber: data['attempt_number'] ?? 1,
      grades: SessionGrades.fromJson(data['grades']),
      passed: data['passed'] ?? false,
      repetitions: data['repetitions'] ?? 0,
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
      'hizb_number': hizbNumber,
      'session_number': sessionNumber,
      'date': Timestamp.fromDate(date),
      'attempt_number': attemptNumber,
      'grades': grades.toJson(),
      'passed': passed,
      'repetitions': repetitions,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  SessionRecordModel copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? curriculumSessionId,
    int? levelId,
    int? hizbNumber,
    int? sessionNumber,
    DateTime? date,
    int? attemptNumber,
    SessionGrades? grades,
    bool? passed,
    int? repetitions,
    String? notes,
    DateTime? createdAt,
  }) {
    return SessionRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      curriculumSessionId: curriculumSessionId ?? this.curriculumSessionId,
      levelId: levelId ?? this.levelId,
      hizbNumber: hizbNumber ?? this.hizbNumber,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      date: date ?? this.date,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      grades: grades ?? this.grades,
      passed: passed ?? this.passed,
      repetitions: repetitions ?? this.repetitions,
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
