import 'package:cloud_firestore/cloud_firestore.dart';

class LevelModel {
  final String id;
  final int levelNumber;
  final String nameAr;
  final String nameEn;
  final List<int> juzNumbers;
  final int totalSessions;
  final int hizbCount;
  final int order;

  const LevelModel({
    required this.id,
    required this.levelNumber,
    required this.nameAr,
    required this.nameEn,
    required this.juzNumbers,
    required this.totalSessions,
    required this.hizbCount,
    required this.order,
  });

  factory LevelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LevelModel(
      id: doc.id,
      levelNumber: data['id'] ?? int.parse(doc.id.replaceAll('level_', '')),
      nameAr: data['name_ar'] ?? '',
      nameEn: data['name_en'] ?? '',
      juzNumbers: List<int>.from(data['juz_numbers'] ?? []),
      totalSessions: data['total_sessions'] ?? 0,
      hizbCount: data['hizb_count'] ?? 6,
      order: data['order'] ?? 1,
    );
  }

  factory LevelModel.fromJson(String id, Map<String, dynamic> json) {
    return LevelModel(
      id: id,
      levelNumber: json['id'] ?? int.parse(id.replaceAll('level_', '')),
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'] ?? '',
      juzNumbers: List<int>.from(json['juz_numbers'] ?? []),
      totalSessions: json['total_sessions'] ?? 0,
      hizbCount: json['hizb_count'] ?? 6,
      order: json['order'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': levelNumber,
      'name_ar': nameAr,
      'name_en': nameEn,
      'juz_numbers': juzNumbers,
      'total_sessions': totalSessions,
      'hizb_count': hizbCount,
      'order': order,
    };
  }

  /// Get display name based on locale
  String getName(bool isArabic) => isArabic ? nameAr : nameEn;

  /// Get juz range as string
  String get juzRangeAr {
    if (juzNumbers.isEmpty) return '';
    if (juzNumbers.length == 1) return 'الجزء ${juzNumbers.first}';
    return 'الأجزاء ${juzNumbers.last} - ${juzNumbers.first}';
  }

  String get juzRangeEn {
    if (juzNumbers.isEmpty) return '';
    if (juzNumbers.length == 1) return 'Juz ${juzNumbers.first}';
    return 'Juz ${juzNumbers.last} - ${juzNumbers.first}';
  }

  @override
  String toString() {
    return 'LevelModel(id: $id, name: $nameAr, juzNumbers: $juzNumbers)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LevelModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
