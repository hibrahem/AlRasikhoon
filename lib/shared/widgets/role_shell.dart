import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/user_model.dart';
import 'bottom_nav_bar.dart';
import 'nav_destinations.dart';

/// Persistent shell that hosts a `StatefulNavigationShell` plus the role's
/// bottom navigation bar. Tab swaps are handled by `goBranch`, which performs
/// an `IndexedStack` swap with no transition and preserves each branch's
/// navigator state.
class RoleShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final UserRole role;

  const RoleShell({
    super.key,
    required this.navigationShell,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final branches = navigationShell.route.branches;
    final branchCount = branches.length;

    // A tab with no branch behind it used to be swallowed silently: the button
    // simply did nothing, in production, with no error (al_rasikhoon-256). Fail
    // loudly in debug instead, the first time such a shell is built.
    //
    // Comparing counts alone is not enough: swapping two entries in
    // `destinationsFor` without swapping the matching branches leaves the
    // counts equal while every tap lands on the wrong screen. So compare the
    // ordered ROOT PATHS — the Nth destination's `rootPath` must equal the
    // Nth branch's first route's path.
    assert(() {
      final destinations = destinationsFor(role);
      if (destinations.length != branchCount) {
        throw FlutterError(
          '$role renders ${destinations.length} nav destinations but its '
          'shell declares $branchCount branches. Every destination in '
          'nav_destinations.dart needs a matching StatefulShellBranch, in the '
          'same order, in app_router.dart.',
        );
      }
      for (var i = 0; i < branchCount; i++) {
        final branchPath = (branches[i].routes.first as GoRoute).path;
        final destinationPath = destinations[i].rootPath;
        if (branchPath != destinationPath) {
          throw FlutterError(
            '$role nav destination $i ("${destinations[i].label}") has '
            'rootPath "$destinationPath" but shell branch $i starts at '
            '"$branchPath". destinationsFor(role) in nav_destinations.dart '
            'must correspond 1:1, in order, with the StatefulShellBranch list '
            'for $role in app_router.dart.',
          );
        }
      }
      return true;
    }());

    return Scaffold(
      backgroundColor: tokens.page,
      body: navigationShell,
      bottomNavigationBar: AppNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          // Release-mode safety net for the invariant asserted above.
          if (index >= branchCount) return;
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        role: role,
      ),
    );
  }
}
