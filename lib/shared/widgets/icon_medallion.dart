import 'package:flutter/material.dart';

/// The design system's leading-icon treatment: a circular tinted disc with
/// the accent-colored icon centered in it. One shape everywhere — ticket
/// cards, stat tiles, list rows — replacing the assorted rounded-square
/// icon boxes of the old design.
class IconMedallion extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;

  const IconMedallion({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.1),
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}
