import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home_practice_model.dart';
import '../services/firebase_service.dart';
import '../services/firestore_read_source.dart';

final homePracticeRepositoryProvider = Provider<HomePracticeRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return HomePracticeRepository(
    firestore: firestore,
    readSource: ref.watch(firestoreReadSourceProvider),
  );
});

class HomePracticeRepository {
  final FirebaseFirestore _firestore;

  /// Where reads resolve from — offline they pin to the local cache instead
  /// of waiting out a doomed server attempt (al_rasikhoon-gy4).
  final FirestoreReadSource _read;

  HomePracticeRepository({
    FirebaseFirestore? firestore,
    FirestoreReadSource? readSource,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _read = readSource ?? const FirestoreReadSource.alwaysOnline();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('home_practices');

  /// Create a new home practice record.
  ///
  /// [hizbNumber] is a LABEL, carried only by levels 1-2 and absent elsewhere —
  /// it keys nothing (see [HomePracticeModel.hizbNumber]).
  Future<String> createHomePractice({
    required String studentId,
    required String curriculumSessionId,
    required int levelId,
    required int juzNumber,
    int? hizbNumber,
    required int sessionNumber,
    required int repetitions,
    String? notes,
    DateTime? practiceDate,
  }) async {
    final docRef = await _collection.add({
      'student_id': studentId,
      'curriculum_session_id': curriculumSessionId,
      'level_id': levelId,
      'juz_number': juzNumber,
      'hizb_number': hizbNumber,
      'session_number': sessionNumber,
      'repetitions': repetitions,
      'notes': notes,
      'practice_date': Timestamp.fromDate(practiceDate ?? DateTime.now()),
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Get home practice records for a student
  Future<List<HomePracticeModel>> getHomePracticesForStudent(
    String studentId, {
    int limit = 50,
  }) async {
    final snapshot = await _read.getQuery(
      _collection
          .where('student_id', isEqualTo: studentId)
          .orderBy('practice_date', descending: true)
          .limit(limit),
    );

    return snapshot.docs
        .map((doc) => HomePracticeModel.fromFirestore(doc))
        .toList();
  }

  /// Get home practice records for a student within a date range
  Future<List<HomePracticeModel>> getHomePracticesForStudentInRange(
    String studentId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _read.getQuery(
      _collection
          .where('student_id', isEqualTo: studentId)
          .where(
            'practice_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'practice_date',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate),
          )
          .orderBy('practice_date', descending: true),
    );

    return snapshot.docs
        .map((doc) => HomePracticeModel.fromFirestore(doc))
        .toList();
  }

  /// Get today's home practice for a student
  Future<List<HomePracticeModel>> getTodaysPractices(String studentId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getHomePracticesForStudentInRange(
      studentId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get this week's home practice for a student
  Future<List<HomePracticeModel>> getThisWeeksPractices(
    String studentId,
  ) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    return getHomePracticesForStudentInRange(
      studentId,
      startDate: startOfWeekDate,
      endDate: now,
    );
  }

  /// Get total repetitions count for a student
  Future<int> getTotalRepetitions(String studentId) async {
    final practices = await getHomePracticesForStudent(studentId, limit: 1000);
    return practices.fold<int>(
      0,
      (total, practice) => total + practice.repetitions,
    );
  }

  /// Get streak (consecutive days with practice)
  Future<int> getPracticeStreak(String studentId) async {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final practices = await getHomePracticesForStudentInRange(
        studentId,
        startDate: startOfDay,
        endDate: endOfDay,
      );

      if (practices.isEmpty) {
        // Skip today if no practice yet (don't break streak)
        if (i == 0) continue;
        break;
      }
      streak++;
    }

    return streak;
  }

  /// Update a home practice record
  Future<void> updateHomePractice(
    String practiceId, {
    int? repetitions,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (repetitions != null) updates['repetitions'] = repetitions;
    if (notes != null) updates['notes'] = notes;

    if (updates.isNotEmpty) {
      await _collection.doc(practiceId).update(updates);
    }
  }

  /// Delete a home practice record
  Future<void> deleteHomePractice(String practiceId) async {
    await _collection.doc(practiceId).delete();
  }

  /// Stream home practices for real-time updates
  Stream<List<HomePracticeModel>> streamHomePracticesForStudent(
    String studentId, {
    int limit = 20,
  }) {
    return _collection
        .where('student_id', isEqualTo: studentId)
        .orderBy('practice_date', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HomePracticeModel.fromFirestore(doc))
              .toList(),
        );
  }
}
