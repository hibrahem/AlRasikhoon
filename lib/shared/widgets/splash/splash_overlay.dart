import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_tokens.dart';

/// The splash drop artwork — the same asset the native splash shows
/// (flutter_native_splash), so the OS→Flutter hand-off keeps the exact
/// same mark on screen. One flat ink per surface (brand rule): cream on
/// the hero green, with the slightly deeper cream for dark mode.
const _dropLight = AssetImage('assets/brand/splash-logo-cream.png');
const _dropDark = AssetImage('assets/brand/splash-logo-cream-dark.png');

/// The splash composition per the final brand sheet: hero gradient, a
/// breathing cream halo, the cream drop rising and settling, then the typed
/// Reem Kufi lockup fading up line by line.
///
/// Pure presentation — [progress] 0→1 drives the entrance choreography and
/// [haloPhase] 0→1 drives one cycle of the halo's 4s breathing loop, so the
/// preview harness can render any frame of it.
class BrandSplashView extends StatelessWidget {
  final double progress;
  final double haloPhase;

  const BrandSplashView({
    super.key,
    required this.progress,
    this.haloPhase = 0,
  });

  double _stage(double begin, double end, Curve curve) {
    return Interval(begin, end, curve: curve).transform(progress.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Entrance timeline, mapped onto the 1600ms choreography:
    //   drop     0–1000ms  rises 14px, scales .92→1, cubic-bezier(.2,.7,.3,1)
    //   title  550–1250ms  fades up 10px, ease-out
    //   tagline 850–1550ms fades up 10px, ease-out
    final dropIn = _stage(0.0, 0.625, const Cubic(.2, .7, .3, 1));
    // The drop is fully opaque at 60% of its own run (mock's 60% keyframe).
    final dropFade = (_stage(0.0, 0.625, Curves.linear) / 0.6).clamp(0.0, 1.0);
    final titleIn = _stage(0.34375, 0.78125, Curves.easeOut);
    final taglineIn = _stage(0.53125, 0.96875, Curves.easeOut);

    // Breathing halo: opacity .55→1→.55, scale 1→1.12→1 over one phase.
    final breathe = Curves.easeInOut.transform(
      haloPhase <= 0.5 ? haloPhase * 2 : 2 - haloPhase * 2,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Decorative moment: never a screen-reader stop on the way in.
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Reference frame: 82px drop on a 250px-wide phone ≈ 33% of
              // screen width; type sizes keep the mock's ratios to the drop.
              final dropWidth = (constraints.maxWidth * 0.33).clamp(
                90.0,
                150.0,
              );
              final titleSize = dropWidth * (20 / 82);
              final taglineSize = titleSize * 0.525;

              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [tokens.heroTop, tokens.heroBottom],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Radial cream halo at 50%/30%, breathing on a 4s loop.
                    Opacity(
                      opacity: 0.55 + 0.45 * breathe,
                      child: Transform.scale(
                        scale: 1 + 0.12 * breathe,
                        alignment: const Alignment(0, -0.4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.4),
                              radius: 0.6,
                              colors: [
                                tokens.onHero.withValues(alpha: 0.10),
                                tokens.onHero.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Lockup centered at ~45% screen height.
                    Align(
                      alignment: const Alignment(0, -0.1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: dropFade,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - dropIn)),
                              child: Transform.scale(
                                scale: 0.92 + 0.08 * dropIn,
                                child: Image(
                                  image: dark ? _dropDark : _dropLight,
                                  width: dropWidth,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: dropWidth * (5 / 82)),
                          Opacity(
                            opacity: titleIn,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - titleIn)),
                              child: Text(
                                'الراسخون',
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.reemKufi(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.onHero,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: dropWidth * (5 / 82)),
                          Opacity(
                            opacity: taglineIn,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - taglineIn)),
                              child: Text(
                                'في حفظ كتاب الله',
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.reemKufi(
                                  fontSize: taglineSize,
                                  color: tokens.onHero.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
/// Reduced motion: the choreography is skipped (the finished lockup shows
/// immediately, the halo holds still) and the splash dismisses after a
/// short hold.
class SplashOverlay extends StatefulWidget {
  final Widget child;

  const SplashOverlay({super.key, required this.child});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  static const _choreography = Duration(milliseconds: 1600);

  /// One 4s breath of the halo (mock: `splashHalo 4s ease-in-out infinite`).
  static const _breath = Duration(seconds: 4);

  // One controller for hold + fade-out: opacity stays 1 through the hold
  // interval, then eases to 0 — no wall-clock timers, so tests and
  // fake-clock environments stay deterministic.
  static const _holdAndFade = Duration(milliseconds: 750);
  static const _fadeStart = 0.47; // ≈350ms hold, ≈400ms fade

  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: _choreography,
  );
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: _breath,
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

    // Decode the drop before its first visible frame.
    final dark = Theme.of(context).brightness == Brightness.dark;
    precacheImage(dark ? _dropDark : _dropLight, context);

    // Reduced motion: present the finished lockup, hold briefly, dismiss —
    // and never start the breathing loop.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _play.value = 1;
    } else {
      _halo.repeat();
    }
    _play.forward().whenComplete(() {
      if (!mounted) return;
      _dismiss.forward().whenComplete(() {
        if (!mounted) return;
        // The breathing loop must not outlive the splash: a repeating
        // ticker would keep scheduling frames forever (pumpAndSettle hangs).
        _halo.stop();
        setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _play.dispose();
    _halo.dispose();
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
          animation: Listenable.merge([_play, _halo, _dismiss]),
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
                child: BrandSplashView(
                  progress: _play.value,
                  haloPhase: _halo.value,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
