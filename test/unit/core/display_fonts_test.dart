import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('Amiri display font is available', (WidgetTester tester) async {
    expect(GoogleFonts.amiri().fontFamily, contains('Amiri'));
  });

  testWidgets('Aref Ruqaa hero font is available', (WidgetTester tester) async {
    expect(GoogleFonts.arefRuqaa().fontFamily, contains('ArefRuqaa'));
  });
}
