import 'package:cloud_firestore/cloud_firestore.dart';

class SardRecordModel {
  final String id;
  final String studentId;
  final String teacherId;
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

  const SardRecordModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
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

  factory SardRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SardRecordModel(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      teacherId: data['teacher_id'] ?? '',
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
      'teacher_id': teacherId,
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

  SardRecordModel copyWith({
    String? id,
    String? studentId,
    String? teacherId,
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
    return SardRecordModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
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
    return 'SardRecordModel(id: $id, student: $studentId, hizb: $hizbNumber, passed: $passed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SardRecordModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
