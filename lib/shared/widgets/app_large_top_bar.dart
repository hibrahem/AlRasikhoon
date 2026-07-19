import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_tokens.dart';

/// Large-title top bar for list & detail screens: a pinned sliver bar whose
/// Amiri title starts oversized beneath the toolbar row and glides up into
/// the 64dp bar as content scrolls — a manuscript heading, not a floating
/// caption. Background, foreground and the light-mode scroll-under shadow
/// all come from the global AppBarTheme.
///
/// Use inside a CustomScrollView (with any RefreshIndicator wrapping the
/// scroll view, not the slivers):
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     const AppLargeTopBar(title: 'ملف الطالب'),
///     SliverPadding(
///       padding: const EdgeInsets.all(16),
///       sliver: SliverToBoxAdapter(child: ...),
///     ),
///   ],
/// )
/// ```
///
/// Forms and in-session flow screens keep the compact themed [AppBar]; hero
/// dashboards keep [HeroHeader]. This bar is for the browsing surfaces in
/// between.
class AppLargeTopBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const AppLargeTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  /// Matches AppBarTheme.toolbarHeight — SliverAppBar does not read the
  /// theme's toolbarHeight, so it is pinned here explicitly.
  static const double _toolbarHeight = 64;

  /// The extra strip the large title occupies while expanded.
  static const double _largeTitleStrip = 52;

  @override
  Widget build(BuildContext context) {
    final hasLeading =
        leading != null || (ModalRoute.of(context)?.canPop ?? false);
    return SliverAppBar(
      pinned: true,
      leading: leading,
      actions: actions,
      toolbarHeight: _toolbarHeight,
      expandedHeight: _toolbarHeight + _largeTitleStrip,
      flexibleSpace: _CollapsingTitle(
        title: title,
        hasLeading: hasLeading,
        actionCount: actions?.length ?? 0,
      ),
    );
  }
}

/// The single interpolated title: bottom-start anchored, sized and inset by
/// the collapse fraction read from the enclosing [FlexibleSpaceBarSettings].
/// One Text widget throughout, so `find.text(title)` keeps matching once.
class _CollapsingTitle extends StatelessWidget {
  final String title;
  final bool hasLeading;
  final int actionCount;

  const _CollapsingTitle({
    required this.title,
    required this.hasLeading,
    required this.actionCount,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()!;
    final range = settings.maxExtent - settings.minExtent;
    final t = range > 0
        ? ((settings.currentExtent - settings.minExtent) / range).clamp(
            0.0,
            1.0,
          )
        : 1.0;
    final tokens = context.tokens;
    final topPadding = MediaQuery.paddingOf(context).top;

    // Collapsed, the title sits in the toolbar row and must clear the back
    // button and the actions; expanded, it owns the full width at the page
    // margin. All insets are directional — RTL flips them for free.
    final startInset = lerpDouble(hasLeading ? 56 : 20, 20, t)!;
    final endInset = lerpDouble(
      actionCount > 0 ? 12.0 + actionCount * 48.0 : 20.0,
      20,
      t,
    )!;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: topPadding,
        start: startInset,
        end: endInset,
        bottom: 12,
      ),
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: GoogleFonts.amiri(
            fontSize: lerpDouble(26, 32, t),
            fontWeight: FontWeight.bold,
            color: tokens.ink,
          ),
        ),
      ),
    );
  }
}
