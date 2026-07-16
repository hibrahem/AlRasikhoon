import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_tokens.dart';

/// Full-bleed hero header for dashboard roots: a deep-green vertical
/// gradient that owns the top edge of the frame (bleeds behind the status
/// bar), textured with a faint khatam (8-point star) lattice and finished
/// at the bottom with a shallow ogee — a hinted mihrab, not a theme-park
/// arch (rise is capped at 18dp with a soft center point).
///
/// [child] is padded by the status-bar inset automatically. All insets are
/// directional; the widget is RTL-first like the rest of the app.
class HeroHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Gradient overrides for mode-colored heroes (e.g. the recitation
  /// screens, whose hero wears the part ink). Defaults to the brand green
  /// hero. Pass a color dark enough for [AppTokens.onHero] text.
  final Color? topColor;
  final Color? bottomColor;

  const HeroHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 44),
    this.topColor,
    this.bottomColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final topInset = MediaQuery.of(context).viewPadding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipPath(
        clipper: const _OgeeBottomClipper(rise: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                topColor ?? tokens.heroTop,
                bottomColor ?? tokens.heroBottom,
              ],
            ),
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _KhatamLatticePainter(color: tokens.latticeOnHero),
              child: Padding(
                padding: EdgeInsetsDirectional.only(top: topInset).add(padding),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clips the bottom edge into a shallow ogee: two cubic curves meeting at a
/// soft center point, [rise] dp above the bottom corners.
class _OgeeBottomClipper extends CustomClipper<Path> {
  final double rise;

  const _OgeeBottomClipper({required this.rise});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = rise.clamp(0, h);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - r)
      // End-side cubic easing down toward the center point…
      ..cubicTo(w * 0.85, h - r, w * 0.65, h, w * 0.5, h)
      // …and the start-side cubic rising back to the corner. Symmetric, so
      // it renders identically under RTL and LTR.
      ..cubicTo(w * 0.35, h, w * 0.15, h - r, 0, h - r)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_OgeeBottomClipper oldClipper) => rise != oldClipper.rise;
}

/// Tiles an 8-pointed khatam star — two overlapping squares, one rotated
/// 45° — on a 72dp grid, stroked at 1px. Texture, not decoration: the color
/// is expected to be near-transparent ([AppTokens.latticeOnHero]).
class _KhatamLatticePainter extends CustomPainter {
  final Color color;

  const _KhatamLatticePainter({required this.color});

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
  bool shouldRepaint(_KhatamLatticePainter oldDelegate) =>
      color != oldDelegate.color;
}
