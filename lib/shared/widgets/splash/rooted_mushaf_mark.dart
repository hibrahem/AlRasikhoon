import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The animated brand mark: the rooted mushaf from `assets/branding/logo.svg`
/// re-drawn as a CustomPainter so the splash can stage it — pages settle in,
/// the text lines write themselves, then the roots grow and take hold.
/// الراسخون are "the firmly rooted"; the animation IS the name.
///
/// [progress] drives the whole choreography 0→1. At 1.0 the mark is the
/// exact static logo, so a reduced-motion user simply sees the finished
/// mark. Colors are the fixed brand-mark colors (a light mark designed for
/// the deep-green hero field) — they intentionally do not vary by theme.
///
/// [size] is the mark's WIDTH; the widget takes the mark's natural aspect
/// (taller than wide — book above, roots below) with no dead margins, so
/// compositions can space against its true edges.
class RootedMushafMark extends StatelessWidget {
  final double progress;
  final double size;

  const RootedMushafMark({
    super.key,
    required this.progress,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * _RootedMushafPainter.aspectRatio),
      painter: _RootedMushafPainter(progress: progress),
    );
  }
}

class _RootedMushafPainter extends CustomPainter {
  final double progress;

  _RootedMushafPainter({required this.progress});

  // Brand-mark inks (from logo.svg — fixed, not theme tokens).
  static const _leftPage = Color(0xFFF7F7F2);
  static const _rightPage = Color(0xFFCFE8CE);
  static const _spine = Color(0xFF1B5E20);
  static const _leftLines = Color(0xFFC7D8C6);
  static const _rightLines = Color(0xFF8FB98D);
  static const _roots = Color(0xFF8FC98D);

  // The SVG is authored in a 1152×1152 viewBox, but the mark itself only
  // occupies x 348–804, y 358–926 (page bodies + root dots + stroke caps).
  // Painting is cropped to those bounds so the widget has no dead margins.
  static const _minX = 348.0;
  static const _minY = 358.0;
  static const _markWidth = 456.0;
  static const _markHeight = 568.0;

  /// Natural height/width ratio of the cropped mark.
  static const aspectRatio = _markHeight / _markWidth;

  double _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(begin, end, curve: curve).transform(progress.clamp(0, 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _markWidth;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-_minX, -_minY);

    // ── Stage A: the book settles (fade + gentle scale around its center).
    final pagesIn = _stage(0.0, 0.30);
    final pagesOpacity = _stage(0.0, 0.22, Curves.easeOut);
    if (pagesOpacity > 0) {
      final settle = 0.94 + 0.06 * pagesIn;
      canvas.save();
      canvas.translate(576, 570);
      canvas.scale(settle);
      canvas.translate(-576, -570);

      final left = Paint()..color = _leftPage.withValues(alpha: pagesOpacity);
      final right = Paint()..color = _rightPage.withValues(alpha: pagesOpacity);
      final spine = Paint()..color = _spine.withValues(alpha: pagesOpacity);

      canvas.drawPath(_leftPagePath, left);
      canvas.drawPath(_rightPagePath, right);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(568, 404, 16, 330),
          const Radius.circular(8),
        ),
        spine,
      );

      // ── Stage B: page lines write themselves, top row first, both pages
      // growing outward from the spine at once (balanced under RTL).
      for (var i = 0; i < 3; i++) {
        final t = _stage(0.16 + 0.06 * i, 0.42 + 0.06 * i, Curves.easeInOut);
        if (t <= 0) continue;
        _drawTrimmed(
          canvas,
          _leftLinePaths[i],
          t,
          _stroke(_leftLines, 11, pagesOpacity),
          fromEnd: true, // left lines are authored outer→spine; write
        ); //   spine-outward like the right side.
        _drawTrimmed(
          canvas,
          _rightLinePaths[i],
          t,
          _stroke(_rightLines, 11, pagesOpacity),
        );
      }
      canvas.restore();
    }

    // ── Stage C: the roots grow down from the spine — center first, then
    // the two side roots — and the fine tendrils reach out last.
    final rootStagger = [0.44, 0.38, 0.44]; // center root leads
    for (var i = 0; i < 3; i++) {
      final t = _stage(rootStagger[i], rootStagger[i] + 0.26);
      if (t <= 0) continue;
      _drawTrimmed(canvas, _rootPaths[i], t, _stroke(_roots, 16, 1));
    }
    final tendrils = _stage(0.62, 0.78);
    if (tendrils > 0) {
      _drawTrimmed(canvas, _leftTendril, tendrils, _stroke(_roots, 10, 1));
      _drawTrimmed(canvas, _rightTendril, tendrils, _stroke(_roots, 10, 1));
    }

    // ── Stage D: root tips take hold — dots pop with a slight overshoot.
    const dots = [Offset(576, 886), Offset(452, 912), Offset(700, 912)];
    const dotStarts = [0.68, 0.74, 0.74];
    final dotPaint = Paint()..color = _roots;
    for (var i = 0; i < dots.length; i++) {
      final t = _stage(dotStarts[i], dotStarts[i] + 0.12, Curves.easeOutBack);
      if (t <= 0) continue;
      canvas.drawCircle(dots[i], 9 * t, dotPaint);
    }

    canvas.restore();
  }

  Paint _stroke(Color color, double width, double opacity) => Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  /// Strokes the first [t] fraction of [path] (or the last, [fromEnd]),
  /// so lines and roots "write" themselves.
  void _drawTrimmed(
    Canvas canvas,
    Path path,
    double t,
    Paint paint, {
    bool fromEnd = false,
  }) {
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final ui.PathMetric metric in path.computeMetrics()) {
      final len = metric.length;
      final segment = fromEnd
          ? metric.extractPath(len * (1 - t), len)
          : metric.extractPath(0, len * t);
      canvas.drawPath(segment, paint);
    }
  }

  // ── Geometry, ported 1:1 from logo.svg ─────────────────────────────────

  static final Path _leftPagePath = Path()
    ..moveTo(576, 402)
    ..cubicTo(512, 366, 432, 360, 366, 384)
    ..cubicTo(356, 388, 350, 398, 350, 409)
    ..lineTo(350, 700)
    ..cubicTo(350, 711, 356, 720, 366, 717)
    ..cubicTo(432, 697, 512, 703, 576, 738)
    ..close();

  static final Path _rightPagePath = Path()
    ..moveTo(576, 402)
    ..cubicTo(640, 366, 720, 360, 786, 384)
    ..cubicTo(796, 388, 802, 398, 802, 409)
    ..lineTo(802, 700)
    ..cubicTo(802, 711, 796, 720, 786, 717)
    ..cubicTo(720, 697, 640, 703, 576, 738)
    ..close();

  static final List<Path> _leftLinePaths = [
    Path()
      ..moveTo(410, 452)
      ..cubicTo(470, 438, 520, 440, 556, 456),
    Path()
      ..moveTo(410, 512)
      ..cubicTo(470, 498, 520, 500, 556, 516),
    Path()
      ..moveTo(410, 572)
      ..cubicTo(470, 558, 520, 560, 556, 576),
  ];

  static final List<Path> _rightLinePaths = [
    Path()
      ..moveTo(596, 456)
      ..cubicTo(632, 440, 682, 438, 742, 452),
    Path()
      ..moveTo(596, 516)
      ..cubicTo(632, 500, 682, 498, 742, 512),
    Path()
      ..moveTo(596, 576)
      ..cubicTo(632, 560, 682, 558, 742, 572),
  ];

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
  bool shouldRepaint(_RootedMushafPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
