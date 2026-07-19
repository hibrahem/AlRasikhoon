import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../khatam_lattice.dart';

/// The official الراسخون brand mark: gold calligraphy on black, from the
/// brand PDF (see assets/images/logo_gold.png). These are brand-asset
/// colors, fixed by the artwork — not theme tokens.
const _brandBlack = Color(0xFF110F0E);
const _brandGold = Color(0xFFE0A63B);
const _brandLogo = AssetImage('assets/images/logo_gold.png');

/// The splash composition: the brand-black field, a faint gold khatam
/// lattice, the official gold lockup breathing in, and the caption.
/// Pure presentation — [progress] 0→1 drives the whole choreography, so the
/// preview harness can render any frame of it.
class BrandSplashView extends StatelessWidget {
  final double progress;

  const BrandSplashView({super.key, required this.progress});

  double _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(begin, end, curve: curve).transform(progress.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final latticeIn = _stage(0.0, 0.35, Curves.easeOut);
    final logoIn = _stage(0.08, 0.65);
    final captionIn = _stage(0.72, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Decorative moment: never a screen-reader stop on the way in.
      child: ExcludeSemantics(
        child: ColoredBox(
          // Matches the native splash color exactly (flutter_native_splash),
          // so the hand-off from OS splash to this view is invisible.
          color: _brandBlack,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: KhatamLatticePainter(
                color: _brandGold.withValues(alpha: 0.05 * latticeIn),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: logoIn,
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * logoIn,
                        child: const Image(
                          image: _brandLogo,
                          width: 264,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: captionIn,
                      child: Text(
                        'تطبيق حفظ القرآن الكريم',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays the brand splash once over the app's first frame, then fades away
/// and removes itself from the tree. Purely presentational chrome: it never
/// blocks startup work — routing and auth resolve beneath it, so when the
/// veil lifts the user is already on their screen.
///
/// Reduced motion: the choreography is skipped (the finished mark shows
/// immediately) and the splash dismisses after a short hold.
class SplashOverlay extends StatefulWidget {
  final Widget child;

  const SplashOverlay({super.key, required this.child});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  static const _choreography = Duration(milliseconds: 1600);

  // One controller for hold + fade-out: opacity stays 1 through the hold
  // interval, then eases to 0 — no wall-clock timers, so tests and
  // fake-clock environments stay deterministic.
  static const _holdAndFade = Duration(milliseconds: 750);
  static const _fadeStart = 0.47; // ≈350ms hold, ≈400ms fade

  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: _choreography,
  );
  late final AnimationController _dismiss = AnimationController(
    vsync: this,
    duration: _holdAndFade,
  );
  bool _done = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Decode the lockup before its first visible frame.
    precacheImage(_brandLogo, context);

    // Reduced motion: present the finished mark, hold briefly, dismiss.
    if (MediaQuery.of(context).disableAnimations) {
      _play.value = 1;
    }
    _play.forward().whenComplete(() {
      if (!mounted) return;
      _dismiss.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _play.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: Listenable.merge([_play, _dismiss]),
          builder: (context, _) {
            final fading = _dismiss.value > _fadeStart;
            final opacity =
                1 -
                Interval(
                  _fadeStart,
                  1,
                  curve: Curves.easeOut,
                ).transform(_dismiss.value);
            return IgnorePointer(
              // The moment the veil starts lifting, taps reach the app.
              ignoring: fading,
              child: Opacity(
                opacity: opacity,
                child: BrandSplashView(progress: _play.value),
              ),
            );
          },
        ),
      ],
    );
  }
}
