import 'package:cloud_firestore/cloud_firestore.dart';

class ExamRecordModel {
  final String id;
  final String studentId;
  final String supervisorId;
  final int hizbNumber;
  final int juzNumber;
  final int levelId;
  final DateTime date;
  final int errorCount;
  final String grade;
  final bool passed;
  final int attemptNumber;
  final String? notes;
  final DateTime createdAt;

  const ExamRecordModel({
    required this.id,
    required this.studentId,
    required this.supervisorId,
    required this.hizbNumber,
    required this.juzNumber,
    required this.levelId,
    required this.date,
    required this.errorCount,
    required this.grade,
    required this.passed,
    required this.attemptNumber,
    this.notes,
    required this.createdAt,
  });

  factory ExamRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamRecordModel(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      supervisorId: data['supervisor_id'] ?? '',
      hizbNumber: data['hizb_number'] ?? 0,
      juzNumber: data['juz_number'] ?? 0,
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
      'supervisor_id': supervisorId,
      'hizb_number': hizbNumber,
      'juz_number': juzNumber,
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

  ExamRecordModel copyWith({
    String? id,
    String? studentId,
    String? supervisorId,
    int? hizbNumber,
    int? juzNumber,
    int? levelId,
    DateTime? date,
    int? errorCount,
    String? grade,
    bool? passed,
    int? attemptNumber,
    String? notes,
    DateTime? createdAt,
  }) {
    return ExamRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      supervisorId: supervisorId ?? this.supervisorId,
      hizbNumber: hizbNumber ?? this.hizbNumber,
      juzNumber: juzNumber ?? this.juzNumber,
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
    return 'ExamRecordModel(id: $id, student: $studentId, hizb: $hizbNumber, passed: $passed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExamRecordModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
