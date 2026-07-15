// lib/shared/widgets/states/shimmer_box.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_motion.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const ShimmerBox({required this.width, required this.height, super.key});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reduced = AppMotion.of(context, AppMotion.base) == Duration.zero;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    final sized = SizedBox(
      width: widget.width,
      height: widget.height,
      child: box,
    );
    if (reduced) return sized;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1 - 2 * _c.value, 0),
          end: Alignment(1 - 2 * _c.value, 0),
          colors: [
            tokens.surfaceVariant,
            tokens.hairline,
            tokens.surfaceVariant,
          ],
        ).createShader(rect),
        child: sized,
      ),
    );
  }
}
