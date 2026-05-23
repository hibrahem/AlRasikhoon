import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level_model.dart';
import '../models/session_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';

class CurriculumRepository {
  final FirebaseFirestore _firestore;

  CurriculumRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _levelsCollection =>
      _firestore.collection(AppConstants.collectionLevels);

  CollectionReference<Map<String, dynamic>> get _sessionsCollection =>
      _firestore.collection(AppConstants.collectionSessions);

  /// Get all levels
  Future<List<LevelModel>> getLevels() async {
    final query = await _levelsCollection.orderBy('order').get();
    return query.docs.map((doc) => LevelModel.fromFirestore(doc)).toList();
  }

  /// Get level by ID
  Future<LevelModel?> getLevelById(String levelId) async {
    final doc = await _levelsCollection.doc(levelId).get();
    if (doc.exists) {
      return LevelModel.fromFirestore(doc);
    }
    return null;
  }

  /// Get level by number
  Future<LevelModel?> getLevelByNumber(int levelNumber) async {
    return getLevelById('level_$levelNumber');
  }

  /// Get session by ID
  Future<SessionModel?> getSessionById(String sessionId) async {
    final doc = await _sessionsCollection.doc(sessionId).get();
    if (doc.exists) {
      return SessionModel.fromFirestore(doc);
    }
    return null;
  }

  /// Get session by level, hizb, and session number
  Future<SessionModel?> getSession({
    required int levelId,
    required int juzNumber,
    required int hizbNumber,
    required int sessionNumber,
  }) async {
    // Try to find by constructed ID first
    final sessionId = 'L${levelId}_J${juzNumber}_H${hizbNumber}_S$sessionNumber';
    final doc = await _sessionsCollection.doc(sessionId).get();
    if (doc.exists) {
      return SessionModel.fromFirestore(doc);
    }

    // Fallback to query
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: levelId)
        .where('hizb_number', isEqualTo: hizbNumber)
        .where('session_number', isEqualTo: sessionNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return SessionModel.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Get current session for student
  Future<SessionModel?> getCurrentSessionForStudent({
    required int levelId,
    required int juzNumber,
    required int hizbNumber,
    required int sessionNumber,
  }) async {
    return getSession(
      levelId: levelId,
      juzNumber: juzNumber,
      hizbNumber: hizbNumber,
      sessionNumber: sessionNumber,
    );
  }

  /// Get all sessions for a hizb
  Future<List<SessionModel>> getSessionsForHizb({
    required int levelId,
    required int hizbNumber,
  }) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: levelId)
        .where('hizb_number', isEqualTo: hizbNumber)
        .orderBy('session_number')
        .get();

    return query.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
  }

  /// Get all sessions for a level
  Future<List<SessionModel>> getSessionsForLevel(int levelId) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: levelId)
        .orderBy('hizb_number')
        .orderBy('session_number')
        .get();

    return query.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
  }

  /// Get Sard session for a hizb
  Future<SessionModel?> getSardSession({
    required int levelId,
    required int juzNumber,
    required int hizbNumber,
  }) async {
    return getSession(
      levelId: levelId,
      juzNumber: juzNumber,
      hizbNumber: hizbNumber,
      sessionNumber: AppConstants.sardSessionNumber,
    );
  }

  /// Get Exam session for a hizb
  Future<SessionModel?> getExamSession({
    required int levelId,
    required int juzNumber,
    required int hizbNumber,
  }) async {
    return getSession(
      levelId: levelId,
      juzNumber: juzNumber,
      hizbNumber: hizbNumber,
      sessionNumber: AppConstants.examSessionNumber,
    );
  }

  /// Get total session count for curriculum
  Future<int> getTotalSessionCount() async {
    final result = await _sessionsCollection.count().get();
    return result.count ?? 0;
  }

  /// Stream levels
  Stream<List<LevelModel>> streamLevels() {
    return _levelsCollection.orderBy('order').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => LevelModel.fromFirestore(doc)).toList(),
        );
  }
}

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(firestore: ref.watch(firestoreProvider));
});

/// Provider for all levels
final levelsProvider = FutureProvider<List<LevelModel>>((ref) async {
  final repository = ref.watch(curriculumRepositoryProvider);
  return repository.getLevels();
});

/// Provider for specific level
final levelProvider =
    FutureProvider.family<LevelModel?, int>((ref, levelNumber) async {
  final repository = ref.watch(curriculumRepositoryProvider);
  return repository.getLevelByNumber(levelNumber);
});

/// Provider for the curriculum sessions that compose a level (by level number).
///
/// Reuses [CurriculumRepository.getSessionsForLevel] — the same query the
/// student/teacher flows use to load a level's predefined sessions.
final levelSessionsProvider =
    FutureProvider.family<List<SessionModel>, int>((ref, levelNumber) async {
  final repository = ref.watch(curriculumRepositoryProvider);
  return repository.getSessionsForLevel(levelNumber);
});
