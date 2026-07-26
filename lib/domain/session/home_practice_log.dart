/// One home-practice submission as the rest of the app shows it: when the
/// student logged it and how many repetitions that submission carried.
///
/// Pure domain shape, deliberately smaller than the stored
/// `HomePracticeModel`: render sites (history rows, the pre-session status
/// card) need the date and the count, never the storage fields
/// (student/level/juz ids), so they consume this instead of dragging the data
/// model into widgets.
class HomePracticeLog {
  final DateTime date;
  final int repetitions;

  const HomePracticeLog({required this.date, required this.repetitions});
}

/// The Arabic count phrase for [n] repetitions, following the noun's
/// singular/dual/plural agreement: «مرة واحدة»، «مرتان»، «3 مرات»، «11 مرة».
/// One shared rule so the history rows and the status card cannot disagree.
String repetitionCountAr(int n) {
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتان';
  if (n >= 3 && n <= 10) return '$n مرات';
  return '$n مرة';
}
