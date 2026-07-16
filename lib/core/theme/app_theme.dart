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
      headlineLarge: GoogleFonts.amiri(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: t.ink,
      ),
      headlineMedium: GoogleFonts.amiri(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: t.ink,
      ),
      headlineSmall: GoogleFonts.amiri(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: t.ink,
      ),
      titleLarge: GoogleFonts.amiri(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: t.ink,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: t.ink,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: t.ink,
      ),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: t.ink),
      bodyMedium: GoogleFonts.cairo(fontSize: 15, color: t.ink),
      bodySmall: GoogleFonts.cairo(fontSize: 14, color: t.sepia),
      labelLarge: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: t.ink,
      ),
      labelMedium: GoogleFonts.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: t.ink,
      ),
      labelSmall: GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: t.sepia,
      ),
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
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: t.page,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: t.ink),
        titleTextStyle: GoogleFonts.amiri(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: t.ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.light ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        color: t.card,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.green,
          foregroundColor: onGreen,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space24,
            vertical: AppDimens.space12,
          ),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.green,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space24,
            vertical: AppDimens.space12,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(color: t.green),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.green,
          textStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
          vertical: AppDimens.space12,
        ),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.card,
        indicatorColor: t.primaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? t.green : t.sepia,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? t.green : t.sepia,
          ),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.amiri(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: t.ink,
        ),
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
