# Al Rasikhoon Manuscript UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the student-facing slice of Al Rasikhoon a distinctive "illuminated manuscript" visual identity backed by a design-token system and a genuine dark theme.

**Architecture:** Introduce an `AppTokens` `ThemeExtension` (brightness-aware colors) plus static dimension/motion tokens. Rebuild `AppTheme` to emit real light AND dark `ThemeData` from the tokens. Add a persisted theme-mode provider wired to `MaterialApp`. Reskin the shared widget library and the four student screens to read tokens instead of raw `AppColors` constants, so everything flips light/dark. Two custom-painted signature pieces (Illuminated Juz Ring, mastery ladder). No behavior/logic changes.

**Tech Stack:** Flutter (Material 3), `flutter_riverpod` 3.x (plain providers, no codegen), `google_fonts` 8.x (runtime fetch disabled — fonts bundled under `google_fonts/`), `shared_preferences`, `flutter_test`.

## Global Constraints

- Arabic-first, RTL: every screen/widget must render correctly under `TextDirection.rtl`. The app wraps everything in `Directionality(textDirection: TextDirection.rtl)` (`lib/app.dart`).
- `GoogleFonts.config.allowRuntimeFetching = false` (`lib/main.dart`). Any new font MUST be bundled into `google_fonts/` as `.ttf` (like `Cairo-*.ttf`). Never fetch at runtime.
- Presentation layer only. Do NOT modify providers, routing, domain, repositories, or data models. No behavior changes.
- Colors that must adapt to dark mode MUST be read from `Theme.of(context).extension<AppTokens>()!` or `Theme.of(context).colorScheme` — never from raw `AppColors.*` constants inside widgets.
- Locale is locked to `ar`; all user-facing copy is Arabic.
- Respect reduced motion: gate every animation on `MediaQuery.of(context).disableAnimations`.
- Run `flutter analyze` clean before every commit. Existing tests must keep passing (`flutter test`).
- Commit after each task.

---

## File Structure

**New files:**
- `lib/core/theme/app_tokens.dart` — `AppTokens` ThemeExtension (colors, light + dark).
- `lib/core/theme/app_dimens.dart` — static spacing + radius constants.
- `lib/core/theme/app_motion.dart` — static motion durations + reduced-motion helper.
- `lib/features/settings/providers/theme_mode_provider.dart` — persisted `ThemeMode`.
- `lib/features/settings/widgets/theme_mode_selector.dart` — 3-way segmented control.
- `lib/shared/widgets/juz_ring.dart` — Illuminated Juz Ring (signature) + painter.
- `lib/shared/widgets/mastery_ladder.dart` — mastery-ladder painter/widget.
- `lib/shared/widgets/states/empty_state.dart`, `error_state.dart`, `loading_state.dart`, `shimmer_box.dart` — shared UI states.
- `test/support/theme_test_harness.dart` — `pumpInTheme` helper.
- Matching test files under `test/unit/core/`, `test/unit/providers/`, `test/widget/`.

**Modified files:**
- `lib/core/theme/app_theme.dart` — real light + dark from tokens.
- `lib/app.dart` — add `darkTheme` + `themeMode`.
- `lib/features/settings/screens/settings_screen.dart` — embed theme selector.
- `lib/shared/widgets/*` — reskin to tokens (`app_card`, `app_button`, `stat_card`, `student_card`, `app_text_field`, `grade_display`, `progress_bar`, `session_timer`, `session_record_row`, `error_counter`, `bottom_nav_bar`, `nav_destinations`, `role_shell`, `confirm_sign_out`, `student_level_progress`, `level_progression_widget`).
- `lib/features/student/screens/*` — adopt the system.

---

## Task 1: Bundle display fonts (Amiri + Aref Ruqaa)

**Files:**
- Create: `google_fonts/Amiri-Regular.ttf`, `google_fonts/Amiri-Bold.ttf`, `google_fonts/ArefRuqaa-Regular.ttf`, `google_fonts/ArefRuqaa-Bold.ttf`
- Test: `test/unit/core/display_fonts_test.dart`

**Interfaces:**
- Produces: fonts loadable via `GoogleFonts.amiri()` and `GoogleFonts.arefRuqaa()` with runtime fetching disabled.

- [ ] **Step 1: Download the four TTFs into `google_fonts/`**

```bash
cd google_fonts
curl -fSL -o Amiri-Regular.ttf     https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Regular.ttf
curl -fSL -o Amiri-Bold.ttf        https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Bold.ttf
curl -fSL -o ArefRuqaa-Regular.ttf https://github.com/google/fonts/raw/main/ofl/arefruqaa/ArefRuqaa-Regular.ttf
curl -fSL -o ArefRuqaa-Bold.ttf    https://github.com/google/fonts/raw/main/ofl/arefruqaa/ArefRuqaa-Bold.ttf
cd ..
file google_fonts/Amiri-Regular.ttf
```
Expected: each file is `TrueType Font data` and non-empty (`ls -l` shows > 100 KB for Amiri).

- [ ] **Step 2: Write the failing test**

```dart
// test/unit/core/display_fonts_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  test('Amiri display font is available', () {
    expect(GoogleFonts.amiri().fontFamily, contains('Amiri'));
  });

  test('Aref Ruqaa hero font is available', () {
    expect(GoogleFonts.arefRuqaa().fontFamily, contains('ArefRuqaa'));
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/unit/core/display_fonts_test.dart`
Expected: PASS (the `google_fonts` API resolves the family names).

- [ ] **Step 4: Confirm assets are wired**

The pubspec already lists `- google_fonts/` under `assets:` (it globs the directory), so no pubspec change is needed. Verify:
Run: `grep -n 'google_fonts/' pubspec.yaml`
Expected: a line `    - google_fonts/`.

- [ ] **Step 5: Commit**

```bash
git add google_fonts/Amiri-Regular.ttf google_fonts/Amiri-Bold.ttf google_fonts/ArefRuqaa-Regular.ttf google_fonts/ArefRuqaa-Bold.ttf test/unit/core/display_fonts_test.dart
git commit -m "feat(theme): bundle Amiri + Aref Ruqaa display fonts"
```

---

## Task 2: AppTokens ThemeExtension + dimension/motion tokens

**Files:**
- Create: `lib/core/theme/app_tokens.dart`, `lib/core/theme/app_dimens.dart`, `lib/core/theme/app_motion.dart`
- Test: `test/unit/core/app_tokens_test.dart`

**Interfaces:**
- Produces:
  - `class AppTokens extends ThemeExtension<AppTokens>` with `final Color` fields: `page, card, elevated, surfaceVariant, ink, sepia, green, primaryContainer, gold, maroon, hairline, gradeRasikh, gradeMutqin, gradeHafiz, gradeMujtahid, gradeMuhib`; plus `static const AppTokens light` and `static const AppTokens dark`; plus `copyWith(...)` and `lerp(...)`.
  - `class AppDimens` with `static const double space4=4, space8=8, space12=12, space16=16, space24=24, space32=32, radiusCard=12, radiusControl=8;`
  - `class AppMotion` with `static const Duration fast=Duration(milliseconds:150), base=Duration(milliseconds:300), slow=Duration(milliseconds:500);` and `static Duration of(BuildContext context, Duration d)` returning `Duration.zero` when reduced motion is on.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/core/app_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';

void main() {
  test('light tokens carry the parchment palette', () {
    expect(AppTokens.light.page, const Color(0xFFF4EEE1));
    expect(AppTokens.light.ink, const Color(0xFF1C2A24));
    expect(AppTokens.light.gold, const Color(0xFFC9A227));
  });

  test('dark tokens carry the lamplight palette', () {
    expect(AppTokens.dark.page, const Color(0xFF14110B));
    expect(AppTokens.dark.ink, const Color(0xFFEDE4CE));
    expect(AppTokens.dark.gold, const Color(0xFFE0B84A));
  });

  test('lerp at t=0 returns the start tokens', () {
    final result = AppTokens.light.lerp(AppTokens.dark, 0);
    expect(result.page, AppTokens.light.page);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/app_tokens_test.dart`
Expected: FAIL — `app_tokens.dart` does not exist (compile error).

- [ ] **Step 3: Create `app_tokens.dart`**

```dart
// lib/core/theme/app_tokens.dart
import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color page;
  final Color card;
  final Color elevated;
  final Color surfaceVariant;
  final Color ink;
  final Color sepia;
  final Color green;
  final Color primaryContainer;
  final Color gold;
  final Color maroon;
  final Color hairline;
  final Color gradeRasikh;
  final Color gradeMutqin;
  final Color gradeHafiz;
  final Color gradeMujtahid;
  final Color gradeMuhib;

  const AppTokens({
    required this.page,
    required this.card,
    required this.elevated,
    required this.surfaceVariant,
    required this.ink,
    required this.sepia,
    required this.green,
    required this.primaryContainer,
    required this.gold,
    required this.maroon,
    required this.hairline,
    required this.gradeRasikh,
    required this.gradeMutqin,
    required this.gradeHafiz,
    required this.gradeMujtahid,
    required this.gradeMuhib,
  });

  static const AppTokens light = AppTokens(
    page: Color(0xFFF4EEE1),
    card: Color(0xFFFBF7ED),
    elevated: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDE4D2),
    ink: Color(0xFF1C2A24),
    sepia: Color(0xFF6B5D46),
    green: Color(0xFF1B5E20),
    primaryContainer: Color(0xFFDCE9D8),
    gold: Color(0xFFC9A227),
    maroon: Color(0xFF7A3B2E),
    hairline: Color(0xFFE0D4BC),
    gradeRasikh: Color(0xFF1B5E20),
    gradeMutqin: Color(0xFF388E3C),
    gradeHafiz: Color(0xFF66BB6A),
    gradeMujtahid: Color(0xFFC9A227),
    gradeMuhib: Color(0xFF7A3B2E),
  );

  static const AppTokens dark = AppTokens(
    page: Color(0xFF14110B),
    card: Color(0xFF1E1A12),
    elevated: Color(0xFF2A2318),
    surfaceVariant: Color(0xFF2A2318),
    ink: Color(0xFFEDE4CE),
    sepia: Color(0xFFB8A681),
    green: Color(0xFF8FBF7F),
    primaryContainer: Color(0xFF25341F),
    gold: Color(0xFFE0B84A),
    maroon: Color(0xFFC98A6E),
    hairline: Color(0xFF3A3222),
    gradeRasikh: Color(0xFF8FBF7F),
    gradeMutqin: Color(0xFFA6CF98),
    gradeHafiz: Color(0xFFBFE0B0),
    gradeMujtahid: Color(0xFFE0B84A),
    gradeMuhib: Color(0xFFC98A6E),
  );

  @override
  AppTokens copyWith({
    Color? page,
    Color? card,
    Color? elevated,
    Color? surfaceVariant,
    Color? ink,
    Color? sepia,
    Color? green,
    Color? primaryContainer,
    Color? gold,
    Color? maroon,
    Color? hairline,
    Color? gradeRasikh,
    Color? gradeMutqin,
    Color? gradeHafiz,
    Color? gradeMujtahid,
    Color? gradeMuhib,
  }) {
    return AppTokens(
      page: page ?? this.page,
      card: card ?? this.card,
      elevated: elevated ?? this.elevated,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      ink: ink ?? this.ink,
      sepia: sepia ?? this.sepia,
      green: green ?? this.green,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      gold: gold ?? this.gold,
      maroon: maroon ?? this.maroon,
      hairline: hairline ?? this.hairline,
      gradeRasikh: gradeRasikh ?? this.gradeRasikh,
      gradeMutqin: gradeMutqin ?? this.gradeMutqin,
      gradeHafiz: gradeHafiz ?? this.gradeHafiz,
      gradeMujtahid: gradeMujtahid ?? this.gradeMujtahid,
      gradeMuhib: gradeMuhib ?? this.gradeMuhib,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      sepia: Color.lerp(sepia, other.sepia, t)!,
      green: Color.lerp(green, other.green, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      maroon: Color.lerp(maroon, other.maroon, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      gradeRasikh: Color.lerp(gradeRasikh, other.gradeRasikh, t)!,
      gradeMutqin: Color.lerp(gradeMutqin, other.gradeMutqin, t)!,
      gradeHafiz: Color.lerp(gradeHafiz, other.gradeHafiz, t)!,
      gradeMujtahid: Color.lerp(gradeMujtahid, other.gradeMujtahid, t)!,
      gradeMuhib: Color.lerp(gradeMuhib, other.gradeMuhib, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
```

- [ ] **Step 4: Create `app_dimens.dart`**

```dart
// lib/core/theme/app_dimens.dart
class AppDimens {
  AppDimens._();
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double radiusCard = 12;
  static const double radiusControl = 8;
}
```

- [ ] **Step 5: Create `app_motion.dart`**

```dart
// lib/core/theme/app_motion.dart
import 'package:flutter/widgets.dart';

class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  /// Returns [d], or [Duration.zero] when the platform requests reduced motion.
  static Duration of(BuildContext context, Duration d) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : d;
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/unit/core/app_tokens_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_tokens.dart lib/core/theme/app_dimens.dart lib/core/theme/app_motion.dart test/unit/core/app_tokens_test.dart
git commit -m "feat(theme): add AppTokens extension, dimension and motion tokens"
```

---

## Task 3: Rebuild AppTheme (real light + dark from tokens)

**Files:**
- Modify: `lib/core/theme/app_theme.dart` (full rewrite)
- Test: `test/unit/core/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppTokens.light`, `AppTokens.dark` (Task 2).
- Produces: `AppTheme.lightTheme` and `AppTheme.darkTheme`, each a `ThemeData` with the matching `Brightness`, the `AppTokens` extension attached, and `scaffoldBackgroundColor == tokens.page`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/core/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';

void main() {
  test('lightTheme is light and carries light tokens', () {
    final t = AppTheme.lightTheme;
    expect(t.brightness, Brightness.light);
    expect(t.extension<AppTokens>()!.page, AppTokens.light.page);
    expect(t.scaffoldBackgroundColor, AppTokens.light.page);
  });

  test('darkTheme is genuinely dark and carries dark tokens', () {
    final t = AppTheme.darkTheme;
    expect(t.brightness, Brightness.dark);
    expect(t.extension<AppTokens>()!.page, AppTokens.dark.page);
    expect(t.scaffoldBackgroundColor, AppTokens.dark.page);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/app_theme_test.dart`
Expected: FAIL — `darkTheme.brightness` is currently `Brightness.light` (it returns `lightTheme`), and no `AppTokens` extension is attached.

- [ ] **Step 3: Rewrite `app_theme.dart`**

Replace the whole file. It builds one `ThemeData` from a given `AppTokens` + `Brightness`, so light and dark share structure and only differ by tokens. Keep Cairo as the body text theme; use Amiri for headline/title roles.

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';
import 'app_dimens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(AppTokens.light, Brightness.light);
  static ThemeData get darkTheme => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final onGreen = brightness == Brightness.light
        ? const Color(0xFFFBF7ED)
        : const Color(0xFF14110B);

    final baseText = GoogleFonts.cairoTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    ).apply(bodyColor: t.ink, displayColor: t.ink);

    final textTheme = baseText.copyWith(
      headlineLarge: GoogleFonts.amiri(fontSize: 32, fontWeight: FontWeight.bold, color: t.ink),
      headlineMedium: GoogleFonts.amiri(fontSize: 28, fontWeight: FontWeight.bold, color: t.ink),
      headlineSmall: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold, color: t.ink),
      titleLarge: GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.w600, color: t.ink),
      titleMedium: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w600, color: t.ink),
      titleSmall: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: t.ink),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: t.ink),
      bodyMedium: GoogleFonts.cairo(fontSize: 14, color: t.ink),
      bodySmall: GoogleFonts.cairo(fontSize: 12, color: t.sepia),
      labelLarge: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500, color: t.ink),
      labelMedium: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink),
      labelSmall: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w500, color: t.sepia),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [t],
      scaffoldBackgroundColor: t.page,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.green,
        onPrimary: onGreen,
        primaryContainer: t.primaryContainer,
        onPrimaryContainer: t.ink,
        secondary: t.gold,
        onSecondary: const Color(0xFF3D2F06),
        secondaryContainer: t.gold,
        onSecondaryContainer: const Color(0xFF3D2F06),
        surface: t.card,
        onSurface: t.ink,
        surfaceContainerHighest: t.surfaceVariant,
        error: t.maroon,
        onError: onGreen,
        outline: t.hairline,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: t.green,
        foregroundColor: onGreen,
        titleTextStyle: GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.bold, color: onGreen),
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.light ? 1 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusCard)),
        color: t.card,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.green,
          foregroundColor: onGreen,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space24, vertical: AppDimens.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusControl)),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.green,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space24, vertical: AppDimens.space12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusControl)),
          side: BorderSide(color: t.green),
          textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.green,
          textStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.space16, vertical: AppDimens.space12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          borderSide: BorderSide(color: t.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          borderSide: BorderSide(color: t.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          borderSide: BorderSide(color: t.green, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          borderSide: BorderSide(color: t.maroon),
        ),
        labelStyle: GoogleFonts.cairo(fontSize: 14, color: t.sepia),
        hintStyle: GoogleFonts.cairo(fontSize: 14, color: t.sepia),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.card,
        selectedItemColor: t.green,
        unselectedItemColor: t.sepia,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.gold,
        foregroundColor: const Color(0xFF3D2F06),
      ),
      dividerTheme: DividerThemeData(color: t.hairline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: t.page),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusControl)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.bold, color: t.ink),
        contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: t.ink),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceVariant,
        selectedColor: t.primaryContainer,
        labelStyle: GoogleFonts.cairo(fontSize: 12, color: t.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/core/app_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Analyze and run the full unit suite**

Run: `flutter analyze lib/core/theme && flutter test test/unit/core`
Expected: no analyzer issues; all core tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/app_theme.dart test/unit/core/app_theme_test.dart
git commit -m "feat(theme): build real light and dark themes from AppTokens"
```

---

## Task 4: Persisted theme-mode provider

**Files:**
- Create: `lib/features/settings/providers/theme_mode_provider.dart`
- Test: `test/unit/providers/theme_mode_provider_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider` from `lib/data/services/shared_preferences_provider.dart` (a `Provider<SharedPreferences>`).
- Produces: `themeModeProvider` — a `NotifierProvider<ThemeModeNotifier, ThemeMode>`; `ThemeModeNotifier` exposes `void setThemeMode(ThemeMode mode)`. Persists under key `'theme_mode'` with string values `'light' | 'dark' | 'system'`. Default `ThemeMode.system`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/providers/theme_mode_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/features/settings/providers/theme_mode_provider.dart';

ProviderContainer _containerWith(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _containerWith(prefs);
    expect(c.read(themeModeProvider), ThemeMode.system);
  });

  test('reads a persisted mode on init', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    final c = _containerWith(prefs);
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });

  test('setThemeMode updates state and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = _containerWith(prefs);
    c.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);
    expect(prefs.getString('theme_mode'), 'light');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/theme_mode_provider_test.dart`
Expected: FAIL — provider file does not exist.

- [ ] **Step 3: Create the provider**

```dart
// lib/features/settings/providers/theme_mode_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/shared_preferences_provider.dart';

const _kThemeModeKey = 'theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_kThemeModeKey);
    return _decode(stored);
  }

  void setThemeMode(ThemeMode mode) {
    ref.read(sharedPreferencesProvider).setString(_kThemeModeKey, _encode(mode));
    state = mode;
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/providers/theme_mode_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/providers/theme_mode_provider.dart test/unit/providers/theme_mode_provider_test.dart
git commit -m "feat(settings): add persisted theme-mode provider"
```

---

## Task 5: Wire dark theme + themeMode into MaterialApp

**Files:**
- Modify: `lib/app.dart`
- Test: `test/widget/theme_mode_switch_test.dart`

**Interfaces:**
- Consumes: `AppTheme.lightTheme`, `AppTheme.darkTheme` (Task 3); `themeModeProvider` (Task 4).
- Produces: the running app honours `themeModeProvider`; the widget test proves light/dark tokens actually switch under the same provider.

- [ ] **Step 1: Write the failing test**

This test reproduces the app's theme wiring on a minimal `MaterialApp` (avoiding the Firebase-dependent router) and asserts the provider drives brightness.

```dart
// test/widget/theme_mode_switch_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/features/settings/providers/theme_mode_provider.dart';

Widget _harness() => Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ref.watch(themeModeProvider),
        home: Builder(
          builder: (context) => Text(
            'x',
            key: const Key('probe'),
            style: TextStyle(color: Theme.of(context).colorScheme.surface),
          ),
        ),
      ),
    );

void main() {
  testWidgets('themeMode provider drives brightness', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [themeModeProvider.overrideWith(() => _FixedMode(ThemeMode.dark))],
      child: _harness(),
    ));
    final ctx = tester.element(find.byKey(const Key('probe')));
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });
}

class _FixedMode extends ThemeModeNotifier {
  _FixedMode(this._mode);
  final ThemeMode _mode;
  @override
  ThemeMode build() => _mode;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/theme_mode_switch_test.dart`
Expected: FAIL — `_harness` compiles, but until `app.dart` is wired the intent is unproven; more importantly this locks the wiring pattern. (If it already passes because it does not touch `app.dart`, proceed — its purpose is the regression guard for the pattern used in Step 3.)

- [ ] **Step 3: Edit `app.dart`**

Add the dark theme and mode. Change the `MaterialApp.router(...)` construction:

```dart
// lib/app.dart — inside build(), after `final router = ref.watch(routerProvider);`
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'الراسخون',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar'),
      // ...unchanged: supportedLocales, localizationsDelegates, routerConfig, builder
```

Add the import at the top:

```dart
import 'features/settings/providers/theme_mode_provider.dart';
```

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/widget/theme_mode_switch_test.dart && flutter analyze lib/app.dart`
Expected: PASS; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart test/widget/theme_mode_switch_test.dart
git commit -m "feat(app): wire dark theme and persisted theme mode"
```

---

## Task 6: Settings theme selector

**Files:**
- Create: `lib/features/settings/widgets/theme_mode_selector.dart`
- Modify: `lib/features/settings/screens/settings_screen.dart`
- Test: `test/widget/theme_mode_selector_test.dart`

**Interfaces:**
- Consumes: `themeModeProvider` (Task 4); `AppCard` (Task 7 reskins it, but its constructor is unchanged).
- Produces: `ThemeModeSelector` — a `ConsumerWidget` showing a 3-option `SegmentedButton<ThemeMode>` (فاتح / داكن / تلقائي) that calls `setThemeMode`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/theme_mode_selector_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/features/settings/providers/theme_mode_provider.dart';
import 'package:al_rasikhoon/features/settings/widgets/theme_mode_selector.dart';

void main() {
  testWidgets('tapping داكن selects dark mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ThemeModeSelector()),
        ),
      ),
    ));

    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/theme_mode_selector_test.dart`
Expected: FAIL — `theme_mode_selector.dart` does not exist.

- [ ] **Step 3: Create the selector**

```dart
// lib/features/settings/widgets/theme_mode_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/theme_mode_provider.dart';

class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المظهر', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode)),
              ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto)),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setThemeMode(s.first),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Embed it in the settings screen**

In `lib/features/settings/screens/settings_screen.dart`, add the import and insert the selector into the `ListView` children (after `_ProfileCard`). Also remove the now-stale comment on the class that says the screen has "no language or theme toggle".

```dart
// add import near the other imports
import '../widgets/theme_mode_selector.dart';
```
```dart
// in build(), ListView children — after `_ProfileCard(user: user),`
          const SizedBox(height: 16),
          const ThemeModeSelector(),
```

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/widget/theme_mode_selector_test.dart && flutter analyze lib/features/settings`
Expected: PASS; no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/widgets/theme_mode_selector.dart lib/features/settings/screens/settings_screen.dart test/widget/theme_mode_selector_test.dart
git commit -m "feat(settings): add theme mode selector to profile screen"
```

---

## Task 7: Test harness + reskin AppCard (with illuminated variant)

**Files:**
- Create: `test/support/theme_test_harness.dart`
- Modify: `lib/shared/widgets/app_card.dart`
- Test: `test/widget/app_card_theme_test.dart`

**Interfaces:**
- Produces:
  - `pumpInTheme(WidgetTester tester, {required Widget child, Brightness brightness = Brightness.light})` — pumps `child` inside a `MaterialApp` using `AppTheme.lightTheme`/`darkTheme`, RTL, wrapped in a `Scaffold` body.
  - `AppCard` gains `final bool illuminated;` (default `false`). When `true`, the card draws a gold hairline inner border using `context.tokens.gold`. Its default background becomes `context.tokens.card` (was `AppColors.surface`).

- [ ] **Step 1: Create the harness**

```dart
// test/support/theme_test_harness.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';

Future<void> pumpInTheme(
  WidgetTester tester, {
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  );
}
```

- [ ] **Step 2: Write the failing test**

```dart
// test/widget/app_card_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('AppCard uses card token background in dark mode', (tester) async {
    await pumpInTheme(tester,
        brightness: Brightness.dark,
        child: const AppCard(child: Text('محتوى')));
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
    );
    expect(material.color, AppTokens.dark.card);
  });

  testWidgets('illuminated AppCard draws a gold border', (tester) async {
    await pumpInTheme(tester,
        child: const AppCard(illuminated: true, child: Text('محتوى')));
    final container = tester.widgetList<Container>(find.byType(Container)).firstWhere(
      (c) => c.decoration is BoxDecoration &&
             (c.decoration as BoxDecoration).border != null,
    );
    final border = (container.decoration as BoxDecoration).border as Border;
    expect(border.top.color, AppTokens.light.gold);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/app_card_theme_test.dart`
Expected: FAIL — `illuminated` param does not exist and background is `AppColors.surface`.

- [ ] **Step 4: Reskin `app_card.dart`**

Replace the imports and the `AppCard.build` so it reads tokens; add `illuminated`. Keep `AppListTile` unchanged in API (it delegates to `AppCard`).

```dart
// lib/shared/widgets/app_card.dart — replace the top import
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
```
```dart
// AppCard: add field + constructor param
  final bool illuminated;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12,
    this.elevation = 1,
    this.illuminated = false,
  });
```
```dart
// AppCard.build — replace body
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectiveBorder = illuminated
        ? tokens.gold
        : borderColor;
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: backgroundColor ?? tokens.card,
        elevation: illuminated ? 0 : elevation,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: effectiveBorder != null
                  ? Border.all(color: effectiveBorder, width: illuminated ? 1 : 1)
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
```

Note: `context.tokens` is the extension getter defined in `app_tokens.dart` (Task 2).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widget/app_card_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add test/support/theme_test_harness.dart lib/shared/widgets/app_card.dart test/widget/app_card_theme_test.dart
git commit -m "feat(ui): reskin AppCard to tokens with illuminated variant"
```

---

## Task 8: Illuminated Juz Ring (signature)

**Files:**
- Create: `lib/shared/widgets/juz_ring.dart`
- Test: `test/unit/shared/juz_ring_sweep_test.dart`, `test/widget/juz_ring_test.dart`

**Interfaces:**
- Consumes: `AppTokens` via `context.tokens`; `AppMotion` for the fill animation.
- Produces:
  - `double juzRingSweep(double progress)` — top-level pure function returning the sweep angle in radians for `progress` clamped to `[0,1]` (`0 -> 0`, `1 -> 2*pi`).
  - `class JuzRing extends StatelessWidget` with `JuzRing({required int juz, required double progress, super.key})`; renders the medallion with center text `'الجزء $juz'` and `'${(progress*100).round()}٪'`.

- [ ] **Step 1: Write the failing sweep test**

```dart
// test/unit/shared/juz_ring_sweep_test.dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/juz_ring.dart';

void main() {
  test('sweep maps progress to radians and clamps', () {
    expect(juzRingSweep(0), 0);
    expect(juzRingSweep(1), closeTo(2 * math.pi, 1e-9));
    expect(juzRingSweep(0.5), closeTo(math.pi, 1e-9));
    expect(juzRingSweep(-0.2), 0);
    expect(juzRingSweep(1.5), closeTo(2 * math.pi, 1e-9));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/shared/juz_ring_sweep_test.dart`
Expected: FAIL — file/function missing.

- [ ] **Step 3: Create `juz_ring.dart`**

```dart
// lib/shared/widgets/juz_ring.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

double juzRingSweep(double progress) => progress.clamp(0.0, 1.0) * 2 * math.pi;

class JuzRing extends StatelessWidget {
  final int juz;
  final double progress;
  const JuzRing({required this.juz, required this.progress, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 168,
      height: 168,
      child: CustomPaint(
        painter: _JuzRingPainter(
          progress: progress,
          track: tokens.hairline,
          fill: tokens.green,
          frame: tokens.gold,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الجزء $juz', style: textTheme.titleMedium),
              Text('${(progress * 100).round()}٪',
                  style: textTheme.headlineMedium?.copyWith(color: tokens.green)),
            ],
          ),
        ),
      ),
    );
  }
}

class _JuzRingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fill;
  final Color frame;
  _JuzRingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.frame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 10;
    final stroke = 12.0;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      juzRingSweep(progress),
      false,
      fillPaint,
    );

    // Illuminated frame: a gold hairline just outside the ring + four corner ticks.
    final framePaint = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius + stroke / 2 + 4, framePaint);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      final outer = center + Offset(math.cos(a), math.sin(a)) * (radius + 10);
      final inner = center + Offset(math.cos(a), math.sin(a)) * (radius + 4);
      canvas.drawLine(inner, outer, framePaint);
    }
  }

  @override
  bool shouldRepaint(_JuzRingPainter old) =>
      old.progress != progress || old.fill != fill || old.frame != frame;
}
```

- [ ] **Step 4: Write the widget test**

```dart
// test/widget/juz_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/juz_ring.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('JuzRing shows juz and percent, no overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    await pumpInTheme(tester, child: const Center(child: JuzRing(juz: 18, progress: 0.6)));
    expect(find.text('الجزء 18'), findsOneWidget);
    expect(find.text('60٪'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `flutter test test/unit/shared/juz_ring_sweep_test.dart test/widget/juz_ring_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/juz_ring.dart test/unit/shared/juz_ring_sweep_test.dart test/widget/juz_ring_test.dart
git commit -m "feat(ui): add Illuminated Juz Ring signature widget"
```

---

## Task 9: Reskin card/stat/button/input widgets to tokens

**Files:**
- Modify: `lib/shared/widgets/stat_card.dart`, `lib/shared/widgets/student_card.dart`, `lib/shared/widgets/app_button.dart`, `lib/shared/widgets/app_text_field.dart`
- Test: `test/widget/reskin_group_a_test.dart`

**Interfaces:**
- Consumes: `context.tokens`, existing widget constructors (unchanged public APIs).
- Produces: these four widgets render from tokens and no longer reference `AppColors` for adaptive colors.

- [ ] **Step 1: Read each file, then replace raw `AppColors.*` usages**

For each of the four files: read it, replace `import '../../core/constants/app_colors.dart';` with `import '../../core/theme/app_tokens.dart';`, obtain `final tokens = context.tokens;` at the top of `build`, and swap raw constants for tokens using this mapping:

| Old raw constant | New token |
|---|---|
| `AppColors.surface` | `tokens.card` |
| `AppColors.background` | `tokens.page` |
| `AppColors.surfaceVariant` | `tokens.surfaceVariant` |
| `AppColors.primary` | `tokens.green` |
| `AppColors.primaryLight` | `tokens.primaryContainer` |
| `AppColors.secondary` | `tokens.gold` |
| `AppColors.textPrimary` | `tokens.ink` |
| `AppColors.textSecondary` | `tokens.sepia` |
| `AppColors.border` / `AppColors.divider` | `tokens.hairline` |
| `AppColors.error` | `tokens.maroon` |

Where a widget uses `Theme.of(context).textTheme.*` for text styling, keep it. Do not change layout, sizes, or constructor signatures.

- [ ] **Step 2: Write the failing test**

```dart
// test/widget/reskin_group_a_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/stat_card.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('StatCard renders in dark mode without error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    await pumpInTheme(tester,
        brightness: Brightness.dark,
        child: const StatCard(label: 'الجلسات', value: '12', icon: Icons.menu_book));
    expect(tester.takeException(), isNull);
    expect(find.text('الجلسات'), findsOneWidget);
  });
}
```

Note: verify `StatCard`'s real constructor parameter names when you read the file in Step 1; adjust the test's named arguments to match (do not invent parameters). If `StatCard` takes different params, use its actual required ones.

- [ ] **Step 3: Run the test**

Run: `flutter test test/widget/reskin_group_a_test.dart`
Expected: PASS after Step 1 edits compile.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/shared/widgets/stat_card.dart lib/shared/widgets/student_card.dart lib/shared/widgets/app_button.dart lib/shared/widgets/app_text_field.dart`
Expected: no issues, and no remaining `app_colors` import in these four files (`grep -L 'app_colors' ...`).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/stat_card.dart lib/shared/widgets/student_card.dart lib/shared/widgets/app_button.dart lib/shared/widgets/app_text_field.dart test/widget/reskin_group_a_test.dart
git commit -m "feat(ui): reskin stat/student cards, button, text field to tokens"
```

---

## Task 10: Reskin session/grade widgets + mastery ladder

**Files:**
- Modify: `lib/shared/widgets/grade_display.dart`, `lib/shared/widgets/progress_bar.dart`, `lib/shared/widgets/session_timer.dart`, `lib/shared/widgets/session_record_row.dart`, `lib/shared/widgets/error_counter.dart`, `lib/shared/widgets/student_level_progress.dart`, `lib/shared/widgets/level_progression_widget.dart`
- Test: `test/widget/reskin_group_b_test.dart`

**Interfaces:**
- Consumes: `context.tokens`; grade tokens `gradeRasikh..gradeMuhib`.
- Produces: grade colors read from tokens; `progress_bar` animates its fill with `AppMotion.of(context, AppMotion.base)`; `student_level_progress` + `level_progression_widget` render the mastery-ladder look while keeping their existing public constructors.

- [ ] **Step 1: Read each file; apply the token mapping from Task 9 Step 1**

Additionally, for grade colors map any hardcoded grade colours to tokens: `AppColors.gradeRasikh -> tokens.gradeRasikh`, `...Mutqin -> tokens.gradeMutqin`, `...Hafiz -> tokens.gradeHafiz`, `...Mujtahid -> tokens.gradeMujtahid`, `...Muhib -> tokens.gradeMuhib`. Preserve every constructor signature — screens depend on them.

- [ ] **Step 2: For `progress_bar.dart`, make the fill animate (reduced-motion aware)**

Wrap the fill width in a `TweenAnimationBuilder<double>` driven by the value, with `duration: AppMotion.of(context, AppMotion.base)` and `curve: Curves.easeOut`. Add `import '../../core/theme/app_motion.dart';`. Keep the public API identical.

- [ ] **Step 3: For the two level widgets, render the ladder**

Keep their constructors. Replace the internal visual with a horizontal 5-rung ladder (rung i filled with the grade token when the current level ≥ i). Use `Row` of 5 `Expanded` bars with `tokens.gradeRasikh..gradeMuhib` for reached rungs and `tokens.hairline` for the rest, labelled راسخ · متقن · حافظ · مجتهد · محب beneath. Do not change what data they accept.

- [ ] **Step 4: Write the failing test**

```dart
// test/widget/reskin_group_b_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/grade_display.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('GradeDisplay renders in both themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    for (final b in Brightness.values) {
      await pumpInTheme(tester, brightness: b, child: const GradeDisplay(stars: 4));
      expect(tester.takeException(), isNull);
    }
  });
}
```

Note: confirm `GradeDisplay`'s real constructor when you read it in Step 1 and match its arguments.

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/widget/reskin_group_b_test.dart && flutter analyze lib/shared/widgets`
Expected: PASS; no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/grade_display.dart lib/shared/widgets/progress_bar.dart lib/shared/widgets/session_timer.dart lib/shared/widgets/session_record_row.dart lib/shared/widgets/error_counter.dart lib/shared/widgets/student_level_progress.dart lib/shared/widgets/level_progression_widget.dart test/widget/reskin_group_b_test.dart
git commit -m "feat(ui): reskin session/grade widgets and mastery ladder to tokens"
```

---

## Task 11: Reskin navigation + shell widgets

**Files:**
- Modify: `lib/shared/widgets/bottom_nav_bar.dart`, `lib/shared/widgets/nav_destinations.dart`, `lib/shared/widgets/role_shell.dart`, `lib/shared/widgets/confirm_sign_out.dart`
- Test: rely on the existing `test/widget/role_shell_navigation_test.dart` as the regression guard.

**Interfaces:**
- Consumes: `context.tokens`.
- Produces: bottom nav uses `tokens.card` background with `tokens.gold` selected indicator; `role_shell` scaffold background is `tokens.page`; all read tokens, no raw `AppColors` for adaptive colors. Public APIs unchanged.

- [ ] **Step 1: Apply the token mapping (Task 9 Step 1) to all four files**

For the selected nav indicator/label, use `tokens.gold` for the selected state and `tokens.sepia` for unselected. For `role_shell`'s `Scaffold`, set/keep `backgroundColor: tokens.page`. Preserve navigation logic and constructor signatures exactly.

- [ ] **Step 2: Run the existing navigation regression test**

Run: `flutter test test/widget/role_shell_navigation_test.dart`
Expected: PASS (behavior unchanged).

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/shared/widgets/bottom_nav_bar.dart lib/shared/widgets/nav_destinations.dart lib/shared/widgets/role_shell.dart lib/shared/widgets/confirm_sign_out.dart`
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/bottom_nav_bar.dart lib/shared/widgets/nav_destinations.dart lib/shared/widgets/role_shell.dart lib/shared/widgets/confirm_sign_out.dart
git commit -m "feat(ui): reskin navigation and shell widgets to tokens"
```

---

## Task 12: Shared state widgets (empty / error / loading)

**Files:**
- Create: `lib/shared/widgets/states/shimmer_box.dart`, `lib/shared/widgets/states/empty_state.dart`, `lib/shared/widgets/states/error_state.dart`, `lib/shared/widgets/states/loading_state.dart`
- Test: `test/widget/state_widgets_test.dart`

**Interfaces:**
- Consumes: `context.tokens`, `AppMotion`.
- Produces:
  - `ShimmerBox({required double width, required double height, super.key})` — a vellum placeholder; animates a highlight sweep unless reduced motion is on (then a static `tokens.surfaceVariant` box).
  - `EmptyState({required IconData icon, required String title, String? message, Widget? action, super.key})`.
  - `ErrorState({required String message, VoidCallback? onRetry, super.key})` — retry button labelled `'إعادة المحاولة'`.
  - `LoadingState({int lines = 3, super.key})` — a column of `ShimmerBox` rows.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/state_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/widgets/states/empty_state.dart';
import 'package:al_rasikhoon/shared/widgets/states/error_state.dart';
import 'package:al_rasikhoon/shared/widgets/states/loading_state.dart';
import '../support/theme_test_harness.dart';

void main() {
  testWidgets('EmptyState shows title and action', (tester) async {
    await pumpInTheme(tester,
        child: EmptyState(
          icon: Icons.menu_book,
          title: 'لا توجد جلسات بعد',
          action: FilledButton(onPressed: () {}, child: const Text('ابدأ')),
        ));
    expect(find.text('لا توجد جلسات بعد'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
  });

  testWidgets('ErrorState retry fires callback', (tester) async {
    var tapped = false;
    await pumpInTheme(tester,
        child: ErrorState(message: 'تعذر التحميل', onRetry: () => tapped = true));
    await tester.tap(find.text('إعادة المحاولة'));
    expect(tapped, isTrue);
  });

  testWidgets('LoadingState renders without error', (tester) async {
    await pumpInTheme(tester, child: const LoadingState());
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/state_widgets_test.dart`
Expected: FAIL — files missing.

- [ ] **Step 3: Create `shimmer_box.dart`**

```dart
// lib/shared/widgets/states/shimmer_box.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_motion.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const ShimmerBox({required this.width, required this.height, super.key});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduced = AppMotion.of(context, AppMotion.base) == Duration.zero;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    final sized = SizedBox(width: widget.width, height: widget.height, child: box);
    if (reduced) return sized;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1 - 2 * _c.value, 0),
          end: Alignment(1 - 2 * _c.value, 0),
          colors: [tokens.surfaceVariant, tokens.hairline, tokens.surfaceVariant],
        ).createShader(rect),
        child: sized,
      ),
    );
  }
}
```

- [ ] **Step 4: Create `empty_state.dart`**

```dart
// lib/shared/widgets/states/empty_state.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: tokens.gold),
            const SizedBox(height: 16),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: text.bodyMedium?.copyWith(color: tokens.sepia), textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create `error_state.dart`**

```dart
// lib/shared/widgets/states/error_state.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({required this.message, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: tokens.maroon),
            const SizedBox(height: 16),
            Text(message, style: text.bodyLarge, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create `loading_state.dart`**

```dart
// lib/shared/widgets/states/loading_state.dart
import 'package:flutter/material.dart';
import 'shimmer_box.dart';

class LoadingState extends StatelessWidget {
  final int lines;
  const LoadingState({this.lines = 3, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines; i++) ...[
            const ShimmerBox(width: double.infinity, height: 72),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/widget/state_widgets_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 8: Commit**

```bash
git add lib/shared/widgets/states/ test/widget/state_widgets_test.dart
git commit -m "feat(ui): add shared empty, error and loading state widgets"
```

---

## Task 13: Adopt system in student dashboard

**Files:**
- Modify: `lib/features/student/screens/student_dashboard_screen.dart`
- Test: regression via `flutter analyze` + existing student tests + manual (Task 17).

**Interfaces:**
- Consumes: `JuzRing` (Task 8), reskinned `AppCard`/`StatCard`/mastery ladder, `context.tokens`, `EmptyState`/`ErrorState`/`LoadingState`.

- [ ] **Step 1: Read the screen fully, then apply changes**

- Replace `import '../../../core/constants/app_colors.dart';` with `import '../../../core/theme/app_tokens.dart';` and add `import '../../../shared/widgets/juz_ring.dart';`, `import 'package:google_fonts/google_fonts.dart';`, and the states imports if used.
- Apply the Task 9 token mapping to any raw `AppColors.*`.
- Render the hero wordmark in Aref Ruqaa (the ONE place this font is used — spec's reserved hero role): set this screen's `AppBar` title explicitly rather than relying on the themed Amiri title:
  ```dart
  title: Text('الراسخون',
      style: GoogleFonts.arefRuqaa(
          fontSize: 24, fontWeight: FontWeight.bold,
          color: Theme.of(context).appBarTheme.foregroundColor)),
  ```
- Add the `JuzRing` as the dashboard hero: place it near the top of the scrolling column, fed by the memorization progress already available in `studentStatsProvider` (use the existing juz/progress fields the screen already reads — do NOT add new provider calls). If a precise progress value is not already present on the stats object, use the existing progress the current UI shows; do not compute new domain values.
- Replace any bespoke async `when(loading/error)` inline UI with `LoadingState` / `ErrorState` for consistency; keep the existing data mapping.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/student/screens/student_dashboard_screen.dart`
Expected: no issues; no `app_colors` import remains.

- [ ] **Step 3: Run the full student test folder (regression)**

Run: `flutter test test/widget test/unit/features`
Expected: PASS (no behavior regressions). If a pre-existing test asserts an old color/style, update the assertion to the token value — do not change behavior.

- [ ] **Step 4: Commit**

```bash
git add lib/features/student/screens/student_dashboard_screen.dart
git commit -m "feat(student): adopt manuscript system + Juz Ring on dashboard"
```

---

## Task 14: Adopt system in session detail screen

**Files:**
- Modify: `lib/features/student/screens/session_detail_screen.dart`
- Test: `flutter analyze` + existing tests + manual.

- [ ] **Step 1: Read the screen; apply token mapping + reskinned widgets**

Swap `app_colors` import for `app_tokens`; apply the Task 9 mapping; ensure grade/error/timer/record-row use the now-reskinned shared widgets (no local color literals). Keep all session logic unchanged.

- [ ] **Step 2: Analyze + regression tests**

Run: `flutter analyze lib/features/student/screens/session_detail_screen.dart && flutter test test/widget`
Expected: no issues; PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/student/screens/session_detail_screen.dart
git commit -m "feat(student): adopt manuscript system on session detail"
```

---

## Task 15: Adopt system in session history screen

**Files:**
- Modify: `lib/features/student/screens/session_history_screen.dart`
- Test: `flutter analyze` + existing tests + manual.

- [ ] **Step 1: Read the screen; apply changes**

Swap import; apply token mapping; render each past session as a vellum `AppCard` row with a `tokens`-driven grade marker and tabular duration. Use `EmptyState(icon: Icons.history, title: 'لا توجد جلسات بعد', message: 'ستظهر جلساتك هنا بعد أول تسميع', ...)` for the empty list and `ErrorState` for load failures.

- [ ] **Step 2: Analyze + regression tests**

Run: `flutter analyze lib/features/student/screens/session_history_screen.dart && flutter test test/widget`
Expected: no issues; PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/student/screens/session_history_screen.dart
git commit -m "feat(student): adopt manuscript system + empty state on history"
```

---

## Task 16: Adopt system in home practice screen

**Files:**
- Modify: `lib/features/student/screens/home_practice_screen.dart`
- Test: `flutter analyze` + existing tests + manual.

- [ ] **Step 1: Read the screen; apply changes**

Swap import; apply token mapping; use reskinned cards/buttons/state widgets. Keep practice-logging logic unchanged.

- [ ] **Step 2: Analyze + regression tests**

Run: `flutter analyze lib/features/student/screens/home_practice_screen.dart && flutter test test/widget`
Expected: no issues; PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/student/screens/home_practice_screen.dart
git commit -m "feat(student): adopt manuscript system on home practice"
```

---

## Task 17: Full verification + follow-up issues

**Files:** none (verification + issue tracking).

- [ ] **Step 1: Static analysis on the whole project**

Run: `flutter analyze`
Expected: `No issues found!` Fix anything reported before continuing.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all pass. If a pre-existing test asserted an old hardcoded color, update it to the corresponding token value (behavior, not looks, is what these guard).

- [ ] **Step 3: Confirm no adaptive colors leak from raw constants in student screens/shared widgets**

Run: `grep -rl "app_colors" lib/features/student/screens lib/shared/widgets | grep -v app_colors.dart`
Expected: no output (empty). Any file listed still imports raw constants — migrate it.

- [ ] **Step 4: Manual drive — light, dark, RTL**

Launch the app (device or simulator) and walk the four student screens (dashboard, session detail, session history, home practice) plus the Settings theme selector. For each: verify light mode, toggle to dark, confirm nothing is invisible/low-contrast, and confirm RTL layout is correct (Juz Ring centered, text right-aligned, nav mirrored). Capture a screenshot of the dashboard in both light and dark as evidence.

Run: `flutter run` (or use the project's `/run` flow). Expected: all four screens render correctly in both themes with RTL intact.

- [ ] **Step 5: File follow-up child issues under al_rasikhoon-5ss**

```bash
bd create --title="Manuscript UI: teacher screens (11)" --type=task --priority=2 --description="Adopt AppTokens manuscript system across teacher screens. Foundation + shared widgets shipped in al_rasikhoon-5ss pass 1." 
bd create --title="Manuscript UI: admin screens (12)" --type=task --priority=2 --description="Adopt AppTokens manuscript system across admin screens."
bd create --title="Manuscript UI: supervisor screens (5)" --type=task --priority=2 --description="Adopt AppTokens manuscript system across supervisor screens."
bd create --title="Manuscript UI: auth screens (2)" --type=task --priority=2 --description="Adopt AppTokens manuscript system across auth screens."
```
Then link each as a child/dependent of `al_rasikhoon-5ss` per the project's bd conventions, and mark `al_rasikhoon-5ss` progress accordingly.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore(ui): verification pass and follow-up issues for manuscript UI"
```

---

## Notes for the implementer

- When a task says "read the file first," do it — several shared widgets have constructor signatures this plan preserves but does not re-quote. Match the real parameter names; never invent them.
- The one hard rule that makes dark mode work: inside widgets, adaptive colors come from `context.tokens` or `Theme.of(context).colorScheme`, never from `AppColors.*`. `AppColors` stays only as the raw source the tokens reference.
- Keep every change presentation-only. If you find yourself editing a provider, repository, or domain file, stop — that is out of scope for this plan.
