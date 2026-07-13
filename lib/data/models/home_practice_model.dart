import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking student home practice sessions.
/// Students can self-report their practice/repetition at home.
class HomePracticeModel {
  final String id;
  final String studentId;

  /// The curriculum session this practice was ASSIGNED in — the session whose
  /// record carries `home_repetitions_required`.
  ///
  /// Not the student's current session: the teacher advances the student when
  /// the session ends, so by the time they practise at home their current
  /// session is the one AFTER the assignment. Attributing practice to the
  /// current position files every repetition against the wrong session.
  final String curriculumSessionId;
  final int levelId;
  final int juzNumber;

  /// A LABEL, present only in levels 1-2. It keys nothing — the practice is
  /// identified by its level, juz and session. It used to default to 59, filing
  /// every practice of the whole curriculum under the first hizb of level 1.
  final int? hizbNumber;
  final int sessionNumber;
  final int repetitions;
  final String? notes;
  final DateTime practiceDate;
  final DateTime createdAt;

  const HomePracticeModel({
    required this.id,
    required this.studentId,
    required this.curriculumSessionId,
    required this.levelId,
    required this.juzNumber,
    this.hizbNumber,
    required this.sessionNumber,
    required this.repetitions,
    this.notes,
    required this.practiceDate,
    required this.createdAt,
  });

  factory HomePracticeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HomePracticeModel(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      curriculumSessionId: data['curriculum_session_id'] ?? '',
      levelId: data['level_id'] ?? 1,
      juzNumber: data['juz_number'] ?? 30,
      hizbNumber: data['hizb_number'] as int?,
      sessionNumber: data['session_number'] ?? 1,
      repetitions: data['repetitions'] ?? 0,
      notes: data['notes'],
      practiceDate:
          (data['practice_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'student_id': studentId,
      'curriculum_session_id': curriculumSessionId,
      'level_id': levelId,
      'juz_number': juzNumber,
      'hizb_number': hizbNumber,
      'session_number': sessionNumber,
      'repetitions': repetitions,
      'notes': notes,
      'practice_date': Timestamp.fromDate(practiceDate),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  HomePracticeModel copyWith({
    String? id,
    String? studentId,
    String? curriculumSessionId,
    int? levelId,
    int? juzNumber,
    int? hizbNumber,
    int? sessionNumber,
    int? repetitions,
    String? notes,
    DateTime? practiceDate,
    DateTime? createdAt,
  }) {
    return HomePracticeModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      curriculumSessionId: curriculumSessionId ?? this.curriculumSessionId,
      levelId: levelId ?? this.levelId,
      juzNumber: juzNumber ?? this.juzNumber,
      hizbNumber: hizbNumber ?? this.hizbNumber,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      repetitions: repetitions ?? this.repetitions,
      notes: notes ?? this.notes,
      practiceDate: practiceDate ?? this.practiceDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'HomePracticeModel(id: $id, studentId: $studentId, session: $sessionNumber, repetitions: $repetitions)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomePracticeModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
