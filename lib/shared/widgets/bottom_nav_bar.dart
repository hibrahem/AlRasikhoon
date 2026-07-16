import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import 'nav_destinations.dart';

/// Material 3 bottom navigation for a role. Styling (pill indicator, selected
/// colors) comes from `NavigationBarThemeData` in app_theme.dart — this widget
/// carries no per-instance colors, which is what keeps selected styling
/// consistent (previously gold here vs green in the theme).
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final UserRole role;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(role);

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.activeIcon),
            label: destination.label,
          ),
      ],
    );
  }
}
