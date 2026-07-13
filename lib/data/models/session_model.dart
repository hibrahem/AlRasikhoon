import 'package:cloud_firestore/cloud_firestore.dart';

/// What a curriculum session IS. Read from the session's `kind` field, which the
/// extractor took verbatim from the source spreadsheets — except [talqeen],
/// which the extractor DERIVES at the start of every unit and marks as derived.
///
/// A session's kind is NEVER inferred from its number. The curriculum used to be
/// modelled as "36 sessions per hizb, 35 = sard, 36 = exam"; the real curriculum
/// runs 1..N continuously across a whole juz and puts assessments wherever the
/// source puts them.
enum SessionKind { talqeen, lesson, sard, exam }

extension SessionKindX on SessionKind {
  String get value => name;

  String get nameAr {
    switch (this) {
      case SessionKind.talqeen:
        return 'تلقين';
      case SessionKind.lesson:
        return 'حلقة';
      case SessionKind.sard:
        return 'سرد';
      case SessionKind.exam:
        return 'اختبار';
    }
  }

  String get nameEn {
    switch (this) {
      case SessionKind.talqeen:
        return 'Talqeen';
      case SessionKind.lesson:
        return 'Lesson';
      case SessionKind.sard:
        return 'Sard';
      case SessionKind.exam:
        return 'Exam';
    }
  }

  /// Parses a kind from the curriculum data.
  ///
  /// An unknown value is a corrupted or unmigrated document and MUST surface:
  /// silently defaulting to a lesson is how a supervisor's exam turns into an
  /// ordinary session.
  static SessionKind fromString(String value) {
    switch (value) {
      case 'talqeen':
        return SessionKind.talqeen;
      case 'lesson':
        return SessionKind.lesson;
      case 'sard':
        return SessionKind.sard;
      case 'exam':
        return SessionKind.exam;
      default:
        throw ArgumentError.value(value, 'kind', 'Unknown session kind');
    }
  }
}

/// How much of the curriculum an assessment covers.
///
/// - [unit]: half a juz — a hizb in levels 1-2, a surah group in levels 3-10.
/// - [juz]: a whole juz.
/// - [cumulative]: every juz taught so far in the level.
enum AssessmentTier { unit, juz, cumulative }

extension AssessmentTierX on AssessmentTier {
  String get value => name;

  String get nameAr {
    switch (this) {
      case AssessmentTier.unit:
        return 'وحدة';
      case AssessmentTier.juz:
        return 'جزء';
      case AssessmentTier.cumulative:
        return 'تراكمي';
    }
  }

  static AssessmentTier fromString(String value) {
    switch (value) {
      case 'unit':
        return AssessmentTier.unit;
      case 'juz':
        return AssessmentTier.juz;
      case 'cumulative':
        return AssessmentTier.cumulative;
      default:
        throw ArgumentError.value(value, 'tier', 'Unknown assessment tier');
    }
  }
}

/// Who assesses a session: the teacher (سرد) or the supervisor (اختبار).
enum AssessedBy { teacher, supervisor }

extension AssessedByX on AssessedBy {
  String get value => name;

  static AssessedBy fromString(String value) {
    switch (value) {
      case 'teacher':
        return AssessedBy.teacher;
      case 'supervisor':
        return AssessedBy.supervisor;
      default:
        throw ArgumentError.value(value, 'assessed_by', 'Unknown assessor');
    }
  }

  static AssessedBy? maybeFromString(Object? value) =>
      value == null ? null : fromString(value as String);
}

/// What an assessment covers, and what the curriculum calls it.
///
/// [labelAr] is the source spreadsheet's own wording — e.g.
/// `سرد الجزء رقم 30 كاملًا على المحفظ المتابع`. It is shown verbatim; the app
/// never rebuilds an assessment's name from its numbers.
class SessionScope {
  final AssessmentTier tier;
  final String labelAr;

  /// A LABEL only, and only in levels 1-2 where a unit is a hizb. Never an
  /// identity, never an ordering key.
  final int? hizbNumber;

  /// The juz this assessment covers — one for unit/juz tiers, several for
  /// cumulative.
  final List<int> juzNumbers;

  const SessionScope({
    required this.tier,
    required this.labelAr,
    this.hizbNumber,
    this.juzNumbers = const [],
  });

  static SessionScope? maybeFromJson(Object? json) {
    if (json == null) return null;
    final map = Map<String, dynamic>.from(json as Map);
    return SessionScope(
      tier: AssessmentTierX.fromString(map['tier'] as String),
      labelAr: map['label_ar'] as String? ?? '',
      hizbNumber: map['hizb_number'] as int?,
      juzNumbers: List<int>.from(map['juz_numbers'] ?? const <int>[]),
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier.value,
    'label_ar': labelAr,
    'hizb_number': hizbNumber,
    'juz_numbers': juzNumbers,
  };

  @override
  String toString() => 'SessionScope(${tier.value}: $labelAr)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionScope &&
          other.tier == tier &&
          other.labelAr == labelAr &&
          other.hizbNumber == hizbNumber &&
          other.juzNumbers.length == juzNumbers.length &&
          other.juzNumbers.every(juzNumbers.contains);

  @override
  int get hashCode =>
      Object.hash(tier, labelAr, hizbNumber, Object.hashAll(juzNumbers));
}

/// A range of the Qur'an, as the curriculum states it.
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

  /// Content blocks are legitimately absent: assessments carry no new content,
  /// and five review-only lessons carry no `current_level_content`. Absence is
  /// data, not an error.
  static QuranContent? maybeFromJson(Object? json) {
    if (json == null) return null;
    final map = Map<String, dynamic>.from(json as Map);
    return QuranContent(
      fromSurah: map['from_surah'] as String? ?? '',
      fromVerse: map['from_verse'] as int? ?? 0,
      toSurah: map['to_surah'] as String? ?? '',
      toVerse: map['to_verse'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'from_surah': fromSurah,
    'from_verse': fromVerse,
    'to_surah': toSurah,
    'to_verse': toVerse,
  };

  String get rangeAr {
    if (fromSurah.isEmpty) return '';
    if (fromSurah == toSurah) {
      if (fromVerse == toVerse) return '$fromSurah: $fromVerse';
      return '$fromSurah: $fromVerse - $toVerse';
    }
    return '$fromSurah: $fromVerse إلى $toSurah: $toVerse';
  }

  String get rangeEn {
    if (fromSurah.isEmpty) return '';
    if (fromSurah == toSurah) {
      if (fromVerse == toVerse) return '$fromSurah: $fromVerse';
      return '$fromSurah: $fromVerse - $toVerse';
    }
    return '$fromSurah: $fromVerse to $toSurah: $toVerse';
  }

  bool get isEmpty => fromSurah.isEmpty;

  @override
  String toString() => rangeAr;
}

/// One row of the curriculum: a lesson, a سرد or an اختبار.
///
/// Identity is the document id `L{level}_J{juz}_S{session}`. Session numbers run
/// 1..N continuously across a whole juz, assessments included; [orderInLevel]
/// (1..M within the level) is THE ordering key for advancement.
class SessionModel {
  final String id;
  final int levelId;
  final int juzNumber;
  final int sessionNumber;

  /// Position within the level (1..level.sessionCount). The only ordering key:
  /// juz numbers cannot order sessions (level 10 teaches juz 1 → 2 → 3).
  final int orderInLevel;

  final SessionKind kind;

  /// Who assesses this session; null for lessons.
  final AssessedBy? assessedBy;

  /// Which half of the juz this belongs to (1 or 2); null for juz- and
  /// cumulative-tier assessments, which belong to no single half.
  final int? unitIndex;

  /// A LABEL, present only in levels 1-2. Not identity, not ordering.
  final int? hizbNumber;

  /// What this assessment covers. Null for lessons.
  final SessionScope? scope;

  final QuranContent? currentLevelContent;
  final QuranContent? recentReviewContent;
  final QuranContent? distantReviewContent;

  const SessionModel({
    required this.id,
    required this.levelId,
    required this.juzNumber,
    required this.sessionNumber,
    required this.orderInLevel,
    required this.kind,
    this.assessedBy,
    this.unitIndex,
    this.hizbNumber,
    this.scope,
    this.currentLevelContent,
    this.recentReviewContent,
    this.distantReviewContent,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel.fromJson(doc.id, data);
  }

  factory SessionModel.fromJson(String id, Map<String, dynamic> json) {
    return SessionModel(
      id: id,
      levelId: json['level_id'] as int,
      juzNumber: json['juz_number'] as int,
      sessionNumber: json['session_number'] as int,
      orderInLevel: json['order_in_level'] as int,
      kind: SessionKindX.fromString(json['kind'] as String),
      assessedBy: AssessedByX.maybeFromString(json['assessed_by']),
      unitIndex: json['unit_index'] as int?,
      hizbNumber: json['hizb_number'] as int?,
      scope: SessionScope.maybeFromJson(json['scope']),
      currentLevelContent: QuranContent.maybeFromJson(
        json['current_level_content'],
      ),
      recentReviewContent: QuranContent.maybeFromJson(
        json['recent_review_content'],
      ),
      distantReviewContent: QuranContent.maybeFromJson(
        json['distant_review_content'],
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'level_id': levelId,
    'juz_number': juzNumber,
    'session_number': sessionNumber,
    'order_in_level': orderInLevel,
    'kind': kind.value,
    'assessed_by': assessedBy?.value,
    'unit_index': unitIndex,
    'hizb_number': hizbNumber,
    'scope': scope?.toJson(),
    'current_level_content': currentLevelContent?.toJson(),
    'recent_review_content': recentReviewContent?.toJson(),
    'distant_review_content': distantReviewContent?.toJson(),
  };

  bool get isSard => kind == SessionKind.sard;

  bool get isExam => kind == SessionKind.exam;

  bool get isLesson => kind == SessionKind.lesson;

  /// A تلقين: the teacher recites the new passage to the student and repeats it
  /// with him. Nothing is memorized, recited alone, or graded.
  bool get isTalqeen => kind == SessionKind.talqeen;

  /// A سرد or an اختبار — the two kinds that are assessed and retried without
  /// limit.
  ///
  /// This is NOT `!isLesson`: a تلقين is neither a lesson nor an assessment, and
  /// defining it by negation is how one would silently acquire an assessment's
  /// unlimited retries and land in the supervisor's exam queue.
  bool get isAssessment => kind == SessionKind.sard || kind == SessionKind.exam;

  /// The sessions that teach new memorization content — a تلقين and a lesson.
  /// These, and only these, carry the recitation counts.
  bool get teachesNewContent => isTalqeen || isLesson;

  /// The tier of this assessment, or null for a lesson.
  AssessmentTier? get tier => scope?.tier;

  /// The session's title in Arabic.
  ///
  /// For an assessment this is the source's own verbatim label — the app never
  /// hand-builds `'سرد الحزب $hizb'`, which cannot even name a juz- or
  /// cumulative-tier assessment.
  String get titleAr {
    final label = scope?.labelAr;
    if (label != null && label.isNotEmpty) return label;
    return 'الحلقة $sessionNumber - الجزء $juzNumber';
  }

  String get titleEn {
    if (isAssessment) return '${kind.nameEn} - Juz $juzNumber';
    if (isTalqeen) return 'Talqeen - Juz $juzNumber';
    return 'Session $sessionNumber - Juz $juzNumber';
  }

  @override
  String toString() =>
      'SessionModel(id: $id, kind: ${kind.value}, orderInLevel: $orderInLevel)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
