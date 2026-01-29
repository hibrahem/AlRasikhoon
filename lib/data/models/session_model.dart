import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionType {
  regular,
  sard,
  exam,
}

extension SessionTypeExtension on SessionType {
  String get value {
    switch (this) {
      case SessionType.regular:
        return 'regular';
      case SessionType.sard:
        return 'sard';
      case SessionType.exam:
        return 'exam';
    }
  }

  String get nameAr {
    switch (this) {
      case SessionType.regular:
        return 'حلقة عادية';
      case SessionType.sard:
        return 'سرد';
      case SessionType.exam:
        return 'اختبار';
    }
  }

  String get nameEn {
    switch (this) {
      case SessionType.regular:
        return 'Regular Session';
      case SessionType.sard:
        return 'Sard';
      case SessionType.exam:
        return 'Exam';
    }
  }

  static SessionType fromString(String value) {
    switch (value) {
      case 'sard':
        return SessionType.sard;
      case 'exam':
        return SessionType.exam;
      default:
        return SessionType.regular;
    }
  }
}

class QuranContent {
  final String fromSurah;
  final int fromVerse;
  final String toSurah;
  final int toVerse;

  const QuranContent({
    required this.fromSurah,
    required this.fromVerse,
    required this.toSurah,
    required this.toVerse,
  });

  factory QuranContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const QuranContent(
        fromSurah: '',
        fromVerse: 0,
        toSurah: '',
        toVerse: 0,
      );
    }
    return QuranContent(
      fromSurah: json['from_surah'] ?? '',
      fromVerse: json['from_verse'] ?? 0,
      toSurah: json['to_surah'] ?? '',
      toVerse: json['to_verse'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_surah': fromSurah,
      'from_verse': fromVerse,
      'to_surah': toSurah,
      'to_verse': toVerse,
    };
  }

  /// Get formatted range string in Arabic
  String get rangeAr {
    if (fromSurah.isEmpty) return '';
    if (fromSurah == toSurah) {
      if (fromVerse == toVerse) {
        return '$fromSurah: $fromVerse';
      }
      return '$fromSurah: $fromVerse - $toVerse';
    }
    return '$fromSurah: $fromVerse إلى $toSurah: $toVerse';
  }

  /// Get formatted range string in English
  String get rangeEn {
    if (fromSurah.isEmpty) return '';
    if (fromSurah == toSurah) {
      if (fromVerse == toVerse) {
        return '$fromSurah: $fromVerse';
      }
      return '$fromSurah: $fromVerse - $toVerse';
    }
    return '$fromSurah: $fromVerse to $toSurah: $toVerse';
  }

  bool get isEmpty => fromSurah.isEmpty;

  @override
  String toString() => rangeAr;
}

class SessionModel {
  final String id;
  final int sessionNumber;
  final int levelId;
  final int juzNumber;
  final int hizbNumber;
  final SessionType sessionType;
  final QuranContent currentLevelContent;
  final QuranContent recentReviewContent;
  final QuranContent distantReviewContent;

  const SessionModel({
    required this.id,
    required this.sessionNumber,
    required this.levelId,
    required this.juzNumber,
    required this.hizbNumber,
    required this.sessionType,
    required this.currentLevelContent,
    required this.recentReviewContent,
    required this.distantReviewContent,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel.fromJson(doc.id, data);
  }

  factory SessionModel.fromJson(String id, Map<String, dynamic> json) {
    return SessionModel(
      id: id,
      sessionNumber: json['session_number'] ?? 0,
      levelId: json['level_id'] ?? 1,
      juzNumber: json['juz_number'] ?? 30,
      hizbNumber: json['hizb_number'] ?? 59,
      sessionType: SessionTypeExtension.fromString(json['session_type'] ?? 'regular'),
      currentLevelContent: QuranContent.fromJson(json['current_level_content']),
      recentReviewContent: QuranContent.fromJson(json['recent_review_content']),
      distantReviewContent: QuranContent.fromJson(json['distant_review_content']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'session_number': sessionNumber,
      'level_id': levelId,
      'juz_number': juzNumber,
      'hizb_number': hizbNumber,
      'session_type': sessionType.value,
      'current_level_content': currentLevelContent.toJson(),
      'recent_review_content': recentReviewContent.toJson(),
      'distant_review_content': distantReviewContent.toJson(),
    };
  }

  /// Check if this is a Sard session
  bool get isSard => sessionType == SessionType.sard;

  /// Check if this is an Exam session
  bool get isExam => sessionType == SessionType.exam;

  /// Check if this is a regular session
  bool get isRegular => sessionType == SessionType.regular;

  /// Get session title in Arabic
  String get titleAr {
    if (isSard) return 'سرد الحزب $hizbNumber';
    if (isExam) return 'اختبار الحزب $hizbNumber';
    return 'الحلقة $sessionNumber - الحزب $hizbNumber';
  }

  /// Get session title in English
  String get titleEn {
    if (isSard) return 'Sard - Hizb $hizbNumber';
    if (isExam) return 'Exam - Hizb $hizbNumber';
    return 'Session $sessionNumber - Hizb $hizbNumber';
  }

  @override
  String toString() {
    return 'SessionModel(id: $id, session: $sessionNumber, juz: $juzNumber, hizb: $hizbNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
