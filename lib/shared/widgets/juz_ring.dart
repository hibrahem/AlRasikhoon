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
              Text(
                '${(progress * 100).round()}٪',
                style: textTheme.headlineMedium?.copyWith(color: tokens.green),
              ),
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
