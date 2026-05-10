import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import 'bottom_nav_bar.dart';

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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
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
