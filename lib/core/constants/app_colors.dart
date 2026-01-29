import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF4C8C4A);
  static const Color primaryDark = Color(0xFF003300);

  // Secondary colors
  static const Color secondary = Color(0xFFFFB300);
  static const Color secondaryLight = Color(0xFFFFE54C);
  static const Color secondaryDark = Color(0xFFC68400);

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F0F0);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFF212121);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Grade colors
  static const Color gradeRasikh = Color(0xFF1B5E20);   // 5 stars - excellent
  static const Color gradeMutqin = Color(0xFF388E3C);   // 4 stars - very good
  static const Color gradeHafiz = Color(0xFF66BB6A);    // 3 stars - good
  static const Color gradeMujtahid = Color(0xFFFFB300); // 2 stars - pass
  static const Color gradeMuhib = Color(0xFFE53935);    // 1 star - fail

  // Divider and border
  static const Color divider = Color(0xFFBDBDBD);
  static const Color border = Color(0xFFE0E0E0);

  // Shadow
  static const Color shadow = Color(0x1A000000);

  // Card backgrounds for different roles
  static const Color adminCard = Color(0xFFE8F5E9);
  static const Color supervisorCard = Color(0xFFFFF8E1);
  static const Color teacherCard = Color(0xFFE3F2FD);
  static const Color studentCard = Color(0xFFF3E5F5);
}
