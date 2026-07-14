import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level_model.dart';
import '../models/session_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/curriculum/curriculum_position.dart';

/// The single authority on what the curriculum CONTAINS.
///
/// A session is identified by `L{level}_J{juz}_S{n}`, where `n` runs 1..N
/// continuously across a whole juz (70 sessions in juz 30 of level 1, 71 in juz
/// 29, 69 in juz 28 — the counts are data). Sessions are ORDERED by
/// `order_in_level` (1..M within the level), never by juz and never by
/// arithmetic: levels 1-9 teach their juz descending, level 10 teaches them
/// ASCENDING (juz 1 → 2 → 3), so any juz-based ordering rule is wrong somewhere.
///
/// The teaching order of a level's juz is read from the levels catalog
/// ([LevelModel.juzNumbers]); it is never computed.
class CurriculumRepository {
  final FirebaseFirestore _firestore;

  CurriculumRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _levelsCollection =>
      _firestore.collection(AppConstants.collectionLevels);

  CollectionReference<Map<String, dynamic>> get _sessionsCollection =>
      _firestore.collection(AppConstants.collectionSessions);

  // ==================== Levels catalog ====================

  /// Every level, in teaching order. Each carries its per-juz session counts and
  /// the teaching order of its juz — the only honest source of both.
  Future<List<LevelModel>> getLevels() async {
    final query = await _levelsCollection.orderBy('order').get();
    return query.docs.map((doc) => LevelModel.fromFirestore(doc)).toList();
  }

  Future<LevelModel?> getLevelById(String levelId) async {
    final doc = await _levelsCollection.doc(levelId).get();
    if (doc.exists) {
      return LevelModel.fromFirestore(doc);
    }
    return null;
  }

  Future<LevelModel?> getLevelByNumber(int levelNumber) async {
    return getLevelById('level_$levelNumber');
  }

  /// The juz of [levelNumber] in TEACHING order (level 1: 30, 29, 28; level 10:
  /// 1, 2, 3). Empty if the level is not in the catalog.
  Future<List<int>> getJuzTeachingOrder(int levelNumber) async {
    final level = await getLevelByNumber(levelNumber);
    return level?.juzNumbers ?? const <int>[];
  }

  Stream<List<LevelModel>> streamLevels() {
    return _levelsCollection
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LevelModel.fromFirestore(doc))
              .toList(),
        );
  }

  // ==================== Sessions ====================

  /// The session with document id [sessionId] (`L{level}_J{juz}_S{n}`).
  Future<SessionModel?> getSessionById(String sessionId) async {
    final doc = await _sessionsCollection.doc(sessionId).get();
    if (doc.exists) {
      return SessionModel.fromFirestore(doc);
    }
    return null;
  }

  /// The session standing at `(level, juz, session)` — a direct document read:
  /// the position IS the document id.
  Future<SessionModel?> getSessionByPosition({
    required int level,
    required int juz,
    required int session,
  }) {
    return getSessionById('L${level}_J${juz}_S$session');
  }

  /// The same, from a [CurriculumPosition].
  Future<SessionModel?> getSessionAt(CurriculumPosition position) =>
      getSessionById(position.sessionId);

  /// The session standing at [orderInLevel] within [level].
  ///
  /// THE advancement primitive: the next session a student meets is the one at
  /// `orderInLevel + 1`, whatever juz it happens to fall in. Nothing else can
  /// cross a juz boundary correctly, because the teaching order of juz is data.
  Future<SessionModel?> getSessionByOrderInLevel({
    required int level,
    required int orderInLevel,
  }) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: level)
        .where('order_in_level', isEqualTo: orderInLevel)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return SessionModel.fromFirestore(query.docs.first);
  }

  /// Every session of [juz] within [level], in teaching order.
  Future<List<SessionModel>> getSessionsForJuz({
    required int level,
    required int juz,
  }) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: level)
        .where('juz_number', isEqualTo: juz)
        .orderBy('order_in_level')
        .get();

    return query.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
  }

  /// The session numbers that exist in [juz] of [level], ascending — what the
  /// starting-point picker offers.
  ///
  /// Every session the curriculum holds is returned. There is no noise filter
  /// any more: the extraction noise the old filter tolerated (session 0, a hizb
  /// filed under the wrong juz) is gone at the source, and silently dropping
  /// sessions here would now hide a real data bug.
  Future<List<int>> getSessionNumbersForJuz({
    required int level,
    required int juz,
  }) async {
    final sessions = await getSessionsForJuz(level: level, juz: juz);
    final numbers = sessions.map((s) => s.sessionNumber).toList()..sort();
    return numbers;
  }

  /// Every session of [level], ordered by `order_in_level` — the level's
  /// teaching order, juz boundaries included.
  ///
  /// This is what a paced meeting is composed from: the composer needs the
  /// sessions AROUND the student's position (the batch ahead of it, the recent
  /// window behind it), and only the level holds all of them. Ordering by juz
  /// would be wrong in both directions — levels 1-9 descend, level 10 ascends.
  Future<List<SessionModel>> getSessionsForLevel({required int level}) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: level)
        .orderBy('order_in_level')
        .get();

    return query.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();
  }

  /// How many sessions the curriculum holds in total.
  Future<int> getTotalSessionCount() async {
    final result = await _sessionsCollection.count().get();
    return result.count ?? 0;
  }
}

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(firestore: ref.watch(firestoreProvider));
});

/// The levels catalog: names, juz in teaching order, and per-juz session counts.
final levelsProvider = FutureProvider<List<LevelModel>>((ref) async {
  final repository = ref.watch(curriculumRepositoryProvider);
  return repository.getLevels();
});

/// One level of the catalog, by level number.
final levelProvider = FutureProvider.family<LevelModel?, int>((
  ref,
  levelNumber,
) async {
  final repository = ref.watch(curriculumRepositoryProvider);
  return repository.getLevelByNumber(levelNumber);
});

/// Every session of a level, in teaching order.
final levelSessionsProvider = FutureProvider.family<List<SessionModel>, int>((
  ref,
  levelNumber,
) async {
  final repository = ref.watch(curriculumRepositoryProvider);
  return repository.getSessionsForLevel(level: levelNumber);
});

/// The sessions of one juz of one level, in teaching order — what the
/// starting-point picker lists once a level and a juz are chosen.
final juzSessionsProvider =
    FutureProvider.family<List<SessionModel>, ({int level, int juz})>((
      ref,
      args,
    ) async {
      final repository = ref.watch(curriculumRepositoryProvider);
      return repository.getSessionsForJuz(level: args.level, juz: args.juz);
    });
