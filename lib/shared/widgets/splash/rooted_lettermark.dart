import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'rasikhoon_wordmark_path.dart';

/// The typographic brand mark built from the word itself: الراسخون set in
/// Amiri Bold (real shaped outlines, see rasikhoon_wordmark_path.dart), a
/// gold "earth line" along the baseline, and everything beneath the line —
/// the natural descenders of ر, و and ن — painted root-green. The word
/// literally stands rooted in the ground; tip dots pop beneath the three
/// descenders as the roots take hold.
///
/// Choreography by [progress]: the word writes itself on right-to-left
/// (soft ink edge), the earth line draws across, the below-ground strokes
/// tint from ink to root-green, then the root tips pop. At 1.0 the mark is
/// static and complete.
class RootedLettermark extends StatelessWidget {
  final double progress;

  /// Rendered width of the wordmark; height follows its natural aspect.
  final double width;

  /// Above-ground word color (typically AppTokens.onHero).
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
  // file). Extra room below the deepest descender for the tip dots.
  static const _extraBelow = 400.0;
  static const _unitsHeight = kWordmarkAscent + _extraBelow;

  /// Natural height/width ratio of the mark.
  static const aspectRatio = _unitsHeight / kWordmarkAdvance;

  /// Deepest below-ground point of each descender (font units): ر، و، ن —
  /// emitted by the generator as the root-tip anchors.
  static const _rootTips = [
    Offset(1900, 212), // ر
    Offset(606, 293), // و
    Offset(113, 89), // ن
  ];
  static const _tipStarts = [0.68, 0.75, 0.82];

  static final Path _word = buildRasikhoonWordPath();

  double _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(begin, end, curve: curve).transform(progress.clamp(0, 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kWordmarkAdvance;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(0, kWordmarkAscent); // baseline at y = 0

    final writeT = _stage(0.04, 0.48, Curves.easeInOut);
    final lineT = _stage(0.44, 0.60);
    final tintT = _stage(0.56, 0.74, Curves.easeInOut);

    // 1 — the earth line draws right→left along the baseline, painted
    // beneath the word so the standing letters plant in front of it.
    if (lineT > 0) {
      const pad = 60.0;
      const right = kWordmarkAdvance + pad;
      final linePaint = Paint()
        ..color = earth
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        const Offset(right, 0),
        Offset(right - (right + pad) * lineT, 0),
        linePaint,
      );
    }

    // 2 — the word, two-toned across the baseline, inside a layer so the
    // ink-edge write-on mask applies to both tones at once.
    if (writeT > 0) {
      final bounds = Rect.fromLTRB(
        -80,
        -kWordmarkAscent - 80,
        kWordmarkAdvance + 80,
        _extraBelow,
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

      // The qalam's soft ink edge, sweeping right→left.
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

    // 3 — the root tips take hold: dots pop beneath the descenders with a
    // slight overshoot, deepest-first.
    final dotPaint = Paint()..color = _rootGreen;
    for (var i = 0; i < _rootTips.length; i++) {
      final t = _stage(_tipStarts[i], _tipStarts[i] + 0.14, Curves.easeOutBack);
      if (t <= 0) continue;
      final tip = _rootTips[i];
      canvas.drawCircle(Offset(tip.dx, tip.dy + 85), 26 * t, dotPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RootedLettermarkPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      ink != oldDelegate.ink ||
      earth != oldDelegate.earth;
}
