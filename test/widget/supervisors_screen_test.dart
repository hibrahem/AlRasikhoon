import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/supervisors_screen.dart';
import 'package:al_rasikhoon/shared/widgets/app_search_field.dart';

UserModel _supervisor(String id, String name) => UserModel(
  id: id,
  username: 'sup_$id',
  email: 'sup_$id@alrasikhoon.local',
  name: name,
  role: UserRole.supervisor,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester, List<UserModel> supervisors) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSupervisorsProvider.overrideWith((ref) async => supervisors),
      ],
      child: const MaterialApp(home: SupervisorsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every supervisor by name', (tester) async {
    await _pump(tester, [
      _supervisor('s1', 'مشرف النور'),
      _supervisor('s2', 'مشرف الهدى'),
    ]);

    expect(find.text('مشرف النور'), findsOneWidget);
    expect(find.text('مشرف الهدى'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no supervisors', (
    tester,
  ) async {
    await _pump(tester, const []);

    expect(find.text('لا يوجد مشرفون'), findsOneWidget);
  });

  testWidgets('renders an add FAB', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('typing a query filters the list to matching supervisors', (
    tester,
  ) async {
    await _pump(tester, [
      _supervisor('s1', 'مشرف النور'),
      _supervisor('s2', 'مشرف الهدى'),
    ]);

    await tester.enterText(find.byType(AppSearchField), 'النور');
    await tester.pumpAndSettle();

    expect(find.text('مشرف النور'), findsOneWidget);
    expect(find.text('مشرف الهدى'), findsNothing);
  });

  testWidgets('hamza-variant query still finds the supervisor', (tester) async {
    await _pump(tester, [_supervisor('s1', 'أحمد المشرف')]);

    await tester.enterText(find.byType(AppSearchField), 'احمد');
    await tester.pumpAndSettle();

    expect(find.text('أحمد المشرف'), findsOneWidget);
  });

  testWidgets('a query with no matches shows the search empty state', (
    tester,
  ) async {
    await _pump(tester, [_supervisor('s1', 'مشرف النور')]);

    await tester.enterText(find.byType(AppSearchField), 'خالد');
    await tester.pumpAndSettle();

    expect(find.text('لا توجد نتائج مطابقة للبحث'), findsOneWidget);
    expect(find.text('مشرف النور'), findsNothing);
  });

  testWidgets('no search field is shown when there are no supervisors at all', (
    tester,
  ) async {
    await _pump(tester, const []);

    expect(find.byType(AppSearchField), findsNothing);
    expect(find.text('لا يوجد مشرفون'), findsOneWidget);
  });
}
