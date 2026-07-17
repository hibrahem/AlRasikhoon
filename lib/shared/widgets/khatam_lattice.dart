import 'package:flutter/material.dart';

/// Tiles an 8-pointed khatam star — two overlapping squares, one rotated
/// 45° — on a 72dp grid, stroked at 1px. Texture, not decoration: the color
/// is expected to be near-transparent ([AppTokens.latticeOnHero]).
///
/// Shared between the dashboard [HeroHeader] and the brand splash so the
/// two surfaces are guaranteed to wear the same weave.
class KhatamLatticePainter extends CustomPainter {
  final Color color;

  const KhatamLatticePainter({required this.color});

  static const double _cell = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Star "radius": half the square's side. Sized so neighbouring stars
    // nearly touch, reading as a continuous lattice.
    const half = _cell * 0.38;

    for (double cy = _cell / 2; cy < size.height + half; cy += _cell) {
      for (double cx = _cell / 2; cx < size.width + half; cx += _cell) {
        _drawSquare(canvas, paint, cx, cy, half, 0);
        _drawSquare(canvas, paint, cx, cy, half, 0.7853981633974483); // π/4
      }
    }
  }

  void _drawSquare(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double half,
    double angle,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    canvas.drawRect(Rect.fromLTRB(-half, -half, half, half), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(KhatamLatticePainter oldDelegate) =>
      color != oldDelegate.color;
}
