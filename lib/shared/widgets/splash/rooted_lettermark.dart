import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'rasikhoon_wordmark_path.dart';

/// The typographic brand mark built from the word itself: الراسخون set in
/// Uthman Taha Naskh Bold — the hand of the Madinah mushaf — via real
/// shaped outlines (see rasikhoon_wordmark_path.dart). A gold "earth line"
/// runs along the baseline; the word's own descenders (ر، و، ن) below the
/// line wear the root green, and fine root tendrils grow on from their
/// tips, ending in the logo's root-tip dots. The letters literally take
/// root: الراسخون are the firmly rooted.
///
/// Choreography by [progress]: the word writes itself on right-to-left
/// (soft ink edge), the earth line draws across, the below-ground strokes
/// tint to root green, the tendrils grow on out of the letters, and the
/// tips pop as they take hold. At 1.0 the mark is static and complete.
class RootedLettermark extends StatelessWidget {
  final double progress;

  /// Rendered width of the wordmark; height follows its natural aspect.
  final double width;

  /// Word color (typically AppTokens.onHero).
  final Color ink;

  /// Earth-line color (typically AppTokens.gold).
  final Color earth;

  const RootedLettermark({
    super.key,
    required this.progress,
    required this.width,
    required this.ink,
    required this.earth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * _RootedLettermarkPainter.aspectRatio),
      painter: _RootedLettermarkPainter(
        progress: progress,
        ink: ink,
        earth: earth,
      ),
    );
  }
}

class _RootedLettermarkPainter extends CustomPainter {
  final double progress;
  final Color ink;
  final Color earth;

  _RootedLettermarkPainter({
    required this.progress,
    required this.ink,
    required this.earth,
  });

  /// Root ink from logo.svg — fixed brand-mark color, not a theme token.
  static const _rootGreen = Color(0xFF8FC98D);

  // Layout in font units (y-down, baseline at 0 — see the generated path
  // file). Extra room below the deepest descender for tendrils and dots.
  static const _extraBelow = 920.0;
  static const _unitsHeight = kWordmarkAscent + _extraBelow;

  /// Natural height/width ratio of the mark.
  static const aspectRatio = _unitsHeight / kWordmarkAdvance;

  // Deepest below-ground point of each descender (font units, from the
  // generator's anchors): ر، و، ن. Each grows a fine tendril that curls
  // on downward from the letter's lowest point.
  static final List<Path> _tendrils = [
    // ر — curls down-left, the direction its tail already flows.
    Path()
      ..moveTo(4682, 557)
      ..cubicTo(4682, 680, 4630, 760, 4560, 850),
    // و — curls down-right, mirroring.
    Path()
      ..moveTo(1333, 558)
      ..cubicTo(1333, 680, 1380, 760, 1445, 850),
    // ن — a shorter drop from its shallower bowl.
    Path()
      ..moveTo(312, 346)
      ..cubicTo(312, 460, 285, 540, 250, 620),
  ];

  static const List<Offset> _dots = [
    Offset(4535, 900),
    Offset(1468, 900),
    Offset(238, 668),
  ];
  static const _tendrilStarts = [0.62, 0.68, 0.74];

  static final Path _word = buildRasikhoonWordPath();

  // Staggered stages can overshoot 1.0 (the last root tip lands right at
  // the end of the choreography); Interval asserts end <= 1.0, so clamp.
  double _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(
      begin.clamp(0.0, 1.0),
      end.clamp(0.0, 1.0),
      curve: curve,
    ).transform(progress.clamp(0, 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kWordmarkAdvance;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(0, kWordmarkAscent); // baseline (earth line) at y = 0

    final writeT = _stage(0.04, 0.44, Curves.easeInOut);
    final lineT = _stage(0.40, 0.56);
    final tintT = _stage(0.52, 0.68, Curves.easeInOut);

    // 1 — the earth line draws right→left along the baseline, painted
    // beneath the word so the standing letters plant in front of it.
    if (lineT > 0) {
      const pad = 140.0;
      const right = kWordmarkAdvance + pad;
      canvas.drawLine(
        const Offset(right, 0),
        Offset(right - (right + pad) * lineT, 0),
        Paint()
          ..color = earth
          ..strokeWidth = 46
          ..strokeCap = StrokeCap.round,
      );
    }

    // 2 — the word, two-toned across the earth line, inside a layer so the
    // qalam's ink-edge write-on mask sweeps both tones at once.
    if (writeT > 0) {
      final bounds = Rect.fromLTRB(
        -160,
        -kWordmarkAscent - 160,
        kWordmarkAdvance + 160,
        kWordmarkDescent + 160,
      );
      canvas.saveLayer(bounds, Paint());

      // Above ground: ink.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(bounds.left, bounds.top, bounds.right, 0));
      canvas.drawPath(_word, Paint()..color = ink);
      canvas.restore();

      // Below ground: the descenders come alive as roots.
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(bounds.left, 0, bounds.right, bounds.bottom),
      );
      canvas.drawPath(
        _word,
        Paint()..color = Color.lerp(ink, _rootGreen, tintT)!,
      );
      canvas.restore();

      final edge = writeT * 1.12;
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            Offset(bounds.right, 0),
            Offset(bounds.left, 0),
            const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            [0, (edge - 0.12).clamp(0.0, 1.0), edge.clamp(0.0, 1.0)],
          ),
      );
      canvas.restore(); // saveLayer
    }

    // 3 — root tendrils grow on downward out of the letters' tips…
    for (var i = 0; i < _tendrils.length; i++) {
      final t = _stage(_tendrilStarts[i], _tendrilStarts[i] + 0.20);
      if (t <= 0) continue;
      _drawTrimmed(
        canvas,
        _tendrils[i],
        t,
        Paint()
          ..color = _rootGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 88
          ..strokeCap = StrokeCap.round,
      );
    }

    // 4 — …and take hold: tip dots pop with a slight overshoot.
    final dotPaint = Paint()..color = _rootGreen;
    for (var i = 0; i < _dots.length; i++) {
      final t = _stage(
        _tendrilStarts[i] + 0.18,
        _tendrilStarts[i] + 0.30,
        Curves.easeOutBack,
      );
      if (t <= 0) continue;
      canvas.drawCircle(_dots[i], 62 * t, dotPaint);
    }

    canvas.restore();
  }

  void _drawTrimmed(Canvas canvas, Path path, double t, Paint paint) {
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final ui.PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_RootedLettermarkPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      ink != oldDelegate.ink ||
      earth != oldDelegate.earth;
}
