/// Arabic copy for the completion forecast (متى الختم؟).
///
/// Pure formatting over a week count — no clock, no widget. Kept beside
/// `assessment_copy.dart`: user-facing curriculum wording lives here, not in
/// the domain and not scattered through widgets.
library;

/// "3 أسابيع" / "أسبوعان" / "58 أسبوعًا" — Arabic number agreement for weeks.
String weeksAr(int weeks) {
  if (weeks == 1) return 'أسبوع واحد';
  if (weeks == 2) return 'أسبوعان';
  if (weeks >= 3 && weeks <= 10) return '$weeks أسابيع';
  return '$weeks أسبوعًا';
}

String _monthsAr(int months) {
  if (months == 1) return 'شهر';
  if (months == 2) return 'شهران';
  if (months >= 3 && months <= 10) return '$months أشهر';
  return '$months شهرًا';
}

String _yearsAr(int years) {
  if (years == 1) return 'سنة';
  if (years == 2) return 'سنتان';
  if (years >= 3 && years <= 10) return '$years سنوات';
  return '$years سنة';
}

/// A friendly reading of [weeks]: "سنة و3 أشهر", "سنتان", "5 أشهر" — or the
/// exact week count when the span is too short for months to be friendlier.
///
/// Months are whole (4.35 weeks each, rounded), because a forecast is an
/// estimate and "شهران" reads honest where "8.7 أسابيع" reads fake-precise.
String approxDurationAr(int weeks) {
  const weeksPerMonth = 4.345; // 365.25 days / 12 months / 7 days
  final months = (weeks / weeksPerMonth).round();
  if (months < 2) return weeksAr(weeks);

  final years = months ~/ 12;
  final leftoverMonths = months % 12;
  if (years == 0) return _monthsAr(leftoverMonths);
  if (leftoverMonths == 0) return _yearsAr(years);
  return '${_yearsAr(years)} و${_monthsAr(leftoverMonths)}';
}

/// "3 لقاءات" / "لقاء واحد" / "58 لقاءً" — Arabic number agreement for meetings.
String meetingsAr(int meetings) {
  if (meetings == 1) return 'لقاء واحد';
  if (meetings == 2) return 'لقاءان';
  if (meetings >= 3 && meetings <= 10) return '$meetings لقاءات';
  return '$meetings لقاءً';
}

/// Why the forecast flattens at high paces: every تقييم and تلقين keeps its
/// own meeting whatever the pace, so only the lessons between them speed up.
/// Shown wherever a pace dial sits next to a forecast, so the diminishing
/// returns read as curriculum truth, not a broken calculator.
String paceHintAr(int standaloneMeetings) =>
    'التقييمات والتلقين (${meetingsAr(standaloneMeetings)}) تُعقد كما هي مهما '
    'كانت الوتيرة — لذلك لا يتضاعف التسارع مع رفعها';
