import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String userId;
  final String instituteId;
  final String? teacherId;
  final String? guardianId;
  final int currentLevel;
  final int currentJuz;
  final int currentHizb;
  final int currentSession;
  final int currentAttempt;
  final List<int> completedLevels;
  final List<int> unlockedLevels;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const StudentModel({
    required this.id,
    required this.userId,
    required this.instituteId,
    this.teacherId,
    this.guardianId,
    this.currentLevel = 1,
    this.currentJuz = 30,
    this.currentHizb = 59,
    this.currentSession = 1,
    this.currentAttempt = 1,
    this.completedLevels = const [],
    this.unlockedLevels = const [1],
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      instituteId: data['institute_id'] ?? '',
      teacherId: data['teacher_id'],
      guardianId: data['guardian_id'],
      currentLevel: data['current_level'] ?? 1,
      currentJuz: data['current_juz'] ?? 30,
      currentHizb: data['current_hizb'] ?? 59,
      currentSession: data['current_session'] ?? 1,
      currentAttempt: data['current_attempt'] ?? 1,
      completedLevels: List<int>.from(data['completed_levels'] ?? []),
      unlockedLevels: List<int>.from(data['unlocked_levels'] ?? [1]),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
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
      'current_hizb': currentHizb,
      'current_session': currentSession,
      'current_attempt': currentAttempt,
      'completed_levels': completedLevels,
      'unlocked_levels': unlockedLevels,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_active': isActive,
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
    int? currentHizb,
    int? currentSession,
    int? currentAttempt,
    List<int>? completedLevels,
    List<int>? unlockedLevels,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return StudentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      instituteId: instituteId ?? this.instituteId,
      teacherId: teacherId ?? this.teacherId,
      guardianId: guardianId ?? this.guardianId,
      currentLevel: currentLevel ?? this.currentLevel,
      currentJuz: currentJuz ?? this.currentJuz,
      currentHizb: currentHizb ?? this.currentHizb,
      currentSession: currentSession ?? this.currentSession,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      completedLevels: completedLevels ?? this.completedLevels,
      unlockedLevels: unlockedLevels ?? this.unlockedLevels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get progress percentage for current level
  double get levelProgressPercentage {
    // Assuming 36 sessions per hizb and 6 hizbs per level = 216 sessions per level
    // But actual session count varies by level
    final sessionInLevel = (currentSession - 1) % 36; // Simplified
    return sessionInLevel / 36 * 100;
  }

  /// Check if student can take Sard test
  bool get canTakeSard => currentSession == 35;

  /// Check if student can take Exam
  bool get canTakeExam => currentSession == 36;

  @override
  String toString() {
    return 'StudentModel(id: $id, userId: $userId, level: $currentLevel, session: $currentSession)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
