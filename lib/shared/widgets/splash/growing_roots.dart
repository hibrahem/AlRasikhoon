import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The brand's root triad — the roots from `assets/branding/logo.svg`,
/// standalone — growing downward and taking hold. Used by the typographic
/// splash where the roots grow from beneath the wordmark الراسخون instead
/// of beneath the mushaf.
///
/// [progress] 0→1 runs the full growth: main roots, then the fine
/// tendrils, then the tips popping in. At 1.0 it is the exact static
/// root geometry of the logo.
class GrowingRoots extends StatelessWidget {
  final double progress;

  /// Rendered WIDTH of the root spread; height follows the natural aspect.
  final double width;

  const GrowingRoots({super.key, required this.progress, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * _GrowingRootsPainter.aspectRatio),
      painter: _GrowingRootsPainter(progress: progress),
    );
  }
}

class _GrowingRootsPainter extends CustomPainter {
  final double progress;

  _GrowingRootsPainter({required this.progress});

  /// Root ink from logo.svg — fixed brand-mark color, not a theme token.
  static const _roots = Color(0xFF8FC98D);

  // logo.svg viewBox coordinates, cropped to the root system's bounds
  // (stroke caps and tip dots included).
  static const _minX = 440.0;
  static const _minY = 732.0;
  static const _rootsWidth = 272.0;
  static const _rootsHeight = 194.0;

  /// Natural height/width ratio of the cropped root system.
  static const aspectRatio = _rootsHeight / _rootsWidth;

  double _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(begin, end, curve: curve).transform(progress.clamp(0, 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _rootsWidth;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-_minX, -_minY);

    // Main roots grow from the crown point — center leads the sides.
    final rootStagger = [0.10, 0.0, 0.10];
    for (var i = 0; i < 3; i++) {
      final t = _stage(rootStagger[i], rootStagger[i] + 0.50);
      if (t <= 0) continue;
      _drawTrimmed(canvas, _rootPaths[i], t, _stroke(16));
    }

    // Fine tendrils reach out from the side roots…
    final tendrils = _stage(0.50, 0.78);
    if (tendrils > 0) {
      _drawTrimmed(canvas, _leftTendril, tendrils, _stroke(10));
      _drawTrimmed(canvas, _rightTendril, tendrils, _stroke(10));
    }

    // …and the tips take hold, popping with a slight overshoot.
    const dots = [Offset(576, 886), Offset(452, 912), Offset(700, 912)];
    const dotStarts = [0.62, 0.74, 0.74];
    final dotPaint = Paint()..color = _roots;
    for (var i = 0; i < dots.length; i++) {
      final t = _stage(dotStarts[i], dotStarts[i] + 0.18, Curves.easeOutBack);
      if (t <= 0) continue;
      canvas.drawCircle(dots[i], 9 * t, dotPaint);
    }

    canvas.restore();
  }

  Paint _stroke(double width) => Paint()
    ..color = _roots
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  void _drawTrimmed(Canvas canvas, Path path, double t, Paint paint) {
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final ui.PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  // Root geometry, ported 1:1 from logo.svg (crown point at 576,740).
  static final List<Path> _rootPaths = [
    Path()
      ..moveTo(576, 740)
      ..cubicTo(576, 792, 520, 812, 486, 866),
    Path()
      ..moveTo(576, 740)
      ..cubicTo(576, 800, 576, 828, 576, 884),
    Path()
      ..moveTo(576, 740)
      ..cubicTo(576, 792, 632, 812, 666, 866),
  ];

  static final Path _leftTendril = Path()
    ..moveTo(486, 866)
    ..cubicTo(476, 884, 470, 900, 452, 910);

  static final Path _rightTendril = Path()
    ..moveTo(666, 866)
    ..cubicTo(676, 884, 682, 900, 700, 910);

  @override
  bool shouldRepaint(_GrowingRootsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
