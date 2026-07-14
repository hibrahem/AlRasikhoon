import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/widgets/bottom_nav_bar.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

void main() {
  testWidgets('every teacher nav tab reports its own index when tapped', (
    tester,
  ) async {
    final tapped = <int>[];
    var currentIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                currentIndex: currentIndex,
                role: UserRole.teacher,
                onTap: (index) {
                  tapped.add(index);
                  setState(() => currentIndex = index);
                },
              ),
            );
          },
        ),
      ),
    );

    final destinations = destinationsFor(UserRole.teacher);
    for (final destination in destinations) {
      await tester.tap(find.text(destination.label));
      await tester.pumpAndSettle();
    }

    // Not just "the taps registered" — each tab reported a DISTINCT index, so
    // no two tabs collapse onto the same branch.
    expect(tapped, List.generate(destinations.length, (i) => i));
  });
}
