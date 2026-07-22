/// Arabic-aware search normalization. Pure Dart — no Flutter/Firebase imports.
///
/// Users spell names inconsistently (أحمد/احمد, هدى/هدي, فاطمة/فاطمه, with or
/// without tashkeel), so both the query and the searched fields are folded
/// onto one canonical form before substring matching.
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    // Tashkeel (U+064B–U+065F), superscript alef (U+0670), tatweel (U+0640):
    // decoration, never identity — dropped entirely.
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        rune == 0x0640) {
      continue;
    }
    switch (rune) {
      case 0x0622: // آ
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0671: // ٱ
        buffer.write('ا');
      case 0x0629: // ة
        buffer.write('ه');
      case 0x0649: // ى
        buffer.write('ي');
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// True when any non-null field contains [query] after normalization.
/// A blank query matches everything (an empty search box hides nothing).
bool matchesSearch(String query, Iterable<String?> fields) {
  final normalizedQuery = normalizeArabic(query);
  if (normalizedQuery.isEmpty) return true;
  return fields.any(
    (field) =>
        field != null && normalizeArabic(field).contains(normalizedQuery),
  );
}
