import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_tokens.dart';

/// The hero progress ring: a thick, round-capped arc filled with a gold
/// sweep gradient over a dim track, sweeping counter-clockwise from the top
/// so it reads start-to-end in RTL. The percent numeral is Cairo Bold
/// tabular — words in Amiri, data in Cairo.
///
/// Purely presentational: [fraction] and [percent] arrive pre-derived.
class ProgressRing extends StatelessWidget {
  final double fraction;
  final int percent;
  final String caption;
  final double size;
  final double strokeWidth;

  /// Track color behind the arc. On the hero pass `onHero @ 12%`; on cards
  /// the default [AppTokens.rewardDim] is right.
  final Color? trackColor;

  /// Color of the percent numeral and caption. Defaults to hero ink.
  final Color? foreground;
  final Color? captionColor;

  const ProgressRing({
    super.key,
    required this.fraction,
    required this.percent,
    this.caption = 'من المنهج',
    this.size = 150,
    this.strokeWidth = 14,
    this.trackColor,
    this.foreground,
    this.captionColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const [Color(0xFFE0B84A), Color(0xFFF0D468)]
        : const [Color(0xFFC9A227), Color(0xFFE8C85A)];

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: AppMotion.of(context, const Duration(milliseconds: 900)),
        curve: Curves.easeOutCubic,
        builder: (context, animated, child) {
          return CustomPaint(
            painter: _RingPainter(
              fraction: animated,
              strokeWidth: strokeWidth,
              track: trackColor ?? tokens.rewardDim,
              gradientColors: gradient,
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: GoogleFonts.cairo(
                  fontSize: 46,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: foreground ?? tokens.onHero,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                caption,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: captionColor ?? tokens.onHeroMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final double strokeWidth;
  final Color track;
  final List<Color> gradientColors;

  const _RingPainter({
    required this.fraction,
    required this.strokeWidth,
    required this.track,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction <= 0) return;

    const start = -math.pi / 2; // top
    final sweep = -2 * math.pi * fraction; // counter-clockwise for RTL

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        // The rotated gradient begins at the arc's TIP (start + sweep), so
        // the color list is reversed: bright at the tip, base at the top
        // origin — the tip is what should glow as progress advances.
        colors: [gradientColors[1], gradientColors[0]],
        startAngle: 0,
        endAngle: 2 * math.pi * fraction.clamp(0.001, 1.0),
        transform: GradientRotation(start + sweep),
      ).createShader(rect);

    canvas.drawArc(rect, start, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      track != oldDelegate.track ||
      gradientColors != oldDelegate.gradientColors;
}
