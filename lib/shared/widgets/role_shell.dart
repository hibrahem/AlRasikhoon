import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    final branchCount = navigationShell.route.branches.length;

    // A tab with no branch behind it used to be swallowed silently: the button
    // simply did nothing, in production, with no error (al_rasikhoon-256). Fail
    // loudly in debug instead, the first time such a shell is built.
    assert(
      destinationsFor(role).length == branchCount,
      '$role renders ${destinationsFor(role).length} nav destinations but its '
      'shell declares $branchCount branches. Every destination in '
      'nav_destinations.dart needs a matching StatefulShellBranch, in the same '
      'order, in app_router.dart.',
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavBar(
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
