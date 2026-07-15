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
