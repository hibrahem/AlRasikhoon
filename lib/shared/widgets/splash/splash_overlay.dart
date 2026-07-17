import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_tokens.dart';
import '../khatam_lattice.dart';
import 'rooted_lettermark.dart';
import 'rooted_mushaf_mark.dart';

/// Which brand mark the splash animates.
enum SplashVariant {
  /// The rooted-mushaf pictogram: pages settle, lines write, roots grow.
  rootedMushaf,

  /// The typographic lettermark built from the word itself: الراسخون in
  /// real Amiri outlines writes itself on, a gold earth line draws along
  /// its baseline, and the descenders of ر/و/ن below the line come alive
  /// as roots (see [RootedLettermark]).
  rootedWord,
}

/// The splash composition: token hero gradient, faint khatam lattice, the
/// animated brand mark ([SplashVariant]), and the gold rule + tagline.
/// Pure presentation — [progress] 0→1 drives the whole choreography, so the
/// preview harness can render any frame of it.
class BrandSplashView extends StatelessWidget {
  final double progress;
  final SplashVariant variant;

  const BrandSplashView({
    super.key,
    required this.progress,
    this.variant = SplashVariant.rootedWord,
  });

  double _stage(double begin, double end, [Curve curve = Curves.easeOutCubic]) {
    return Interval(begin, end, curve: curve).transform(progress.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final latticeIn = _stage(0.0, 0.35, Curves.easeOut);
    final captionIn = _stage(0.82, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Decorative moment: never a screen-reader stop on the way in.
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tokens.heroTop, tokens.heroBottom],
            ),
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: KhatamLatticePainter(
                color: tokens.latticeOnHero.withValues(
                  alpha: tokens.latticeOnHero.a * latticeIn,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...switch (variant) {
                      SplashVariant.rootedMushaf => _rootedMushaf(tokens),
                      SplashVariant.rootedWord => _rootedWord(tokens),
                    },
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: captionIn,
                      child: Text(
                        'تطبيق حفظ القرآن الكريم',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: tokens.onHeroMuted,
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

  /// The pictogram variant: animated mushaf mark with the wordmark rising
  /// beneath it.
  List<Widget> _rootedMushaf(AppTokens tokens) {
    final wordmarkIn = _stage(0.72, 0.90);
    return [
      RootedMushafMark(progress: progress, size: 176),
      const SizedBox(height: 28),
      Opacity(
        opacity: wordmarkIn,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - wordmarkIn)),
          child: Text(
            'الراسخون',
            style: GoogleFonts.amiri(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: tokens.onHero,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Gold = achievement: a single quiet rule under the name — no glows,
      // no halos. (The lettermark variant carries its gold in the earth
      // line instead.)
      Opacity(
        opacity: _stage(0.82, 1.0),
        child: Container(
          width: 48,
          height: 2,
          decoration: BoxDecoration(
            color: tokens.gold,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    ];
  }

  /// The typographic variant: the الراسخون lettermark — real Amiri
  /// outlines writing themselves on, the gold earth line, and the
  /// descenders rooting below it.
  List<Widget> _rootedWord(AppTokens tokens) {
    return [
      RootedLettermark(
        progress: progress,
        width: 296,
        ink: tokens.onHero,
        earth: tokens.gold,
      ),
    ];
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
  final SplashVariant variant;

  const SplashOverlay({
    super.key,
    required this.child,
    this.variant = SplashVariant.rootedWord,
  });

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
                child: BrandSplashView(
                  progress: _play.value,
                  variant: widget.variant,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
