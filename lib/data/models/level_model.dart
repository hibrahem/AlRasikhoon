import 'package:cloud_firestore/cloud_firestore.dart';

/// One juz of a level, as the curriculum catalog describes it.
///
/// The session count is DATA (juz 30 has 68 sessions, juz 29 has 69, juz 28 has
/// 67), never `36 × something`. [firstOrderInLevel] is where this juz starts in
/// the level's continuous 1..sessionCount ordering.
class LevelJuz {
  final int juzNumber;
  final int sessionCount;

  /// The verbatim Arabic labels of this juz's units (its halves), in teaching
  /// order — a hizb in levels 1-2, a surah group in levels 3-10.
  final List<String> unitLabels;

  /// The hizbs of this juz, in teaching order. LABELS, and only in levels 1-2;
  /// null elsewhere.
  final List<int>? hizbNumbers;

  final int firstOrderInLevel;

  const LevelJuz({
    required this.juzNumber,
    required this.sessionCount,
    this.unitLabels = const [],
    this.hizbNumbers,
    required this.firstOrderInLevel,
  });

  factory LevelJuz.fromJson(Map<String, dynamic> json) => LevelJuz(
    juzNumber: json['juz_number'] as int,
    sessionCount: json['session_count'] as int? ?? 0,
    unitLabels: List<String>.from(json['unit_labels'] ?? const <String>[]),
    hizbNumbers: json['hizb_numbers'] == null
        ? null
        : List<int>.from(json['hizb_numbers'] as List),
    firstOrderInLevel: json['first_order_in_level'] as int? ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'juz_number': juzNumber,
    'session_count': sessionCount,
    'unit_labels': unitLabels,
    'hizb_numbers': hizbNumbers,
    'first_order_in_level': firstOrderInLevel,
  };

  /// The last `order_in_level` that belongs to this juz.
  int get lastOrderInLevel => firstOrderInLevel + sessionCount - 1;

  @override
  String toString() => 'LevelJuz(juz: $juzNumber, sessions: $sessionCount)';
}

/// A level of منهج الراسخون: three juz, in a teaching order that is DATA.
///
/// Levels 1-9 descend (level 1 is juz 30 → 29 → 28); level 10 ASCENDS (juz
/// 1 → 2 → 3), because سورة البقرة spans those juz and a surah is memorized
/// front to back. [juzNumbers] is therefore read, never computed.
class LevelModel {
  final String id;
  final int levelNumber;
  final String nameAr;
  final String nameEn;

  /// The level's juz, in TEACHING order.
  final List<int> juzNumbers;

  /// Total sessions in the level — the denominator of every progress bar.
  final int sessionCount;

  /// The per-juz catalog, in teaching order.
  final List<LevelJuz> juz;

  final int order;

  const LevelModel({
    required this.id,
    required this.levelNumber,
    required this.nameAr,
    required this.nameEn,
    required this.juzNumbers,
    required this.sessionCount,
    this.juz = const [],
    required this.order,
  });

  factory LevelModel.fromFirestore(DocumentSnapshot doc) =>
      LevelModel.fromJson(doc.id, doc.data() as Map<String, dynamic>);

  factory LevelModel.fromJson(String id, Map<String, dynamic> json) {
    return LevelModel(
      id: id,
      levelNumber: json['id'] as int? ?? int.parse(id.replaceAll('level_', '')),
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      juzNumbers: List<int>.from(json['juz_numbers'] ?? const <int>[]),
      sessionCount: json['session_count'] as int? ?? 0,
      juz: [
        for (final entry in (json['juz'] as List? ?? const []))
          LevelJuz.fromJson(Map<String, dynamic>.from(entry as Map)),
      ],
      order: json['order'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': levelNumber,
    'name_ar': nameAr,
    'name_en': nameEn,
    'juz_numbers': juzNumbers,
    'session_count': sessionCount,
    'juz': [for (final j in juz) j.toJson()],
    'order': order,
  };

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;

  /// The catalog entry for [juzNumber], or null if this level does not teach it.
  LevelJuz? juzEntry(int juzNumber) {
    for (final entry in juz) {
      if (entry.juzNumber == juzNumber) return entry;
    }
    return null;
  }

  /// How far through the level a student standing at [orderInLevel] is, as a
  /// percentage. Data-driven: the denominator is the level's real session count,
  /// never `36 × juz`.
  double progressPercentageAt(int orderInLevel) {
    if (sessionCount <= 0) return 0;
    final done = (orderInLevel - 1).clamp(0, sessionCount);
    return done / sessionCount * 100;
  }

  /// The juz range as a human-readable span. Ordered numerically for reading,
  /// which is NOT the teaching order.
  String get juzRangeAr {
    if (juzNumbers.isEmpty) return '';
    if (juzNumbers.length == 1) return 'الجزء ${juzNumbers.first}';
    final sorted = [...juzNumbers]..sort();
    return 'الأجزاء ${sorted.first} - ${sorted.last}';
  }

  String get juzRangeEn {
    if (juzNumbers.isEmpty) return '';
    if (juzNumbers.length == 1) return 'Juz ${juzNumbers.first}';
    final sorted = [...juzNumbers]..sort();
    return 'Juz ${sorted.first} - ${sorted.last}';
  }

  @override
  String toString() =>
      'LevelModel(id: $id, name: $nameAr, juzNumbers: $juzNumbers)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LevelModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
