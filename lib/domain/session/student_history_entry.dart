import 'session_duration.dart';

/// One row of a student's recitation history, independent of which collection
/// it came from.
///
/// The log ("سجل الحلقات") is one timeline, but the events live in three
/// collections: lessons and تلقين in `sessionRecords`, a سرد in `sardRecords`,
/// and an اختبار in `examRecords`. This is the single shape every history
/// render site consumes, so a merged, date-sorted timeline can show all four
/// kinds without any screen knowing the storage split.
///
/// Pure domain: it carries the raw facts and computes its own display copy, so
/// the title of "الحلقة 6" / "تلقين" / a سرد / an اختبار is decided in ONE
/// place, not re-derived by each screen. The data → entry mapping lives in the
/// repository (the interface adapter), never here.
enum StudentHistoryKind { lesson, talqeen, sard, exam }

class StudentHistoryEntry {
  /// The source record's id.
  final String id;
  final StudentHistoryKind kind;
  final int levelId;

  /// The session number, for a lesson. Null for the other kinds.
  final int? sessionNumber;

  /// The curriculum's verbatim scope wording, for a سرد or an اختبار
  /// (`scope.label_ar`). Empty for a lesson / تلقين.
  final String scopeLabelAr;

  /// Ignored at render time for a تلقين, which is never graded.
  final bool passed;

  final DateTime date;
  final SessionDuration? duration;

  /// Non-null ⇒ the row opens a detail view (via the shell's injected route).
  /// The [kind] decides WHICH view: lessons and تلقين open the session-detail
  /// screen, a سرد and an اختبار open the assessment-detail screen
  /// (al_rasikhoon-nyp).
  final String? detailRecordId;

  const StudentHistoryEntry({
    required this.id,
    required this.kind,
    required this.levelId,
    this.sessionNumber,
    this.scopeLabelAr = '',
    required this.passed,
    required this.date,
    this.duration,
    this.detailRecordId,
  });

  bool get isTalqeen => kind == StudentHistoryKind.talqeen;

  bool get isNavigable => detailRecordId != null;

  /// The row title, decided from the kind so every screen agrees.
  String get titleAr {
    switch (kind) {
      case StudentHistoryKind.lesson:
        return 'الحلقة $sessionNumber';
      case StudentHistoryKind.talqeen:
        return 'تلقين';
      case StudentHistoryKind.sard:
        return scopeLabelAr.isNotEmpty ? scopeLabelAr : 'سرد';
      case StudentHistoryKind.exam:
        return scopeLabelAr.isNotEmpty ? scopeLabelAr : 'اختبار';
    }
  }

  List<String> get subtitleLines => ['المستوى $levelId'];
}
