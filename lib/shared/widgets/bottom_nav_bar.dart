import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/user_model.dart';
import 'nav_destinations.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final UserRole role;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final destinations = destinationsFor(role);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: tokens.card,
      selectedItemColor: tokens.gold,
      unselectedItemColor: tokens.sepia,
      items: [
        for (final destination in destinations)
          BottomNavigationBarItem(
            icon: Icon(destination.icon),
            activeIcon: Icon(destination.activeIcon),
            label: destination.label,
          ),
      ],
    );
  }
}
