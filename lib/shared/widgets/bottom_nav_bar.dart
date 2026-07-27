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

    // The bar is chrome with fixed short labels sized to fit one line per
    // tab. NavigationBar renders labels with no maxLines, so any device font
    // scaling can wrap الملف الشخصي onto two lines that spill below the
    // themed 72px bar — labels therefore keep their designed size, the same
    // convention as iOS tab bars.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: NavigationBar(
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
      ),
    );
  }
}
