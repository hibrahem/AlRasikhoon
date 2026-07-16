import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/institute_detail_screen.dart';

const _instituteId = 'i1';

InstituteModel _institute() => InstituteModel(
  id: _instituteId,
  name: 'معهد النور',
  location: 'الرياض',
  createdBy: 'admin',
  createdAt: DateTime(2026, 1, 1),
);

UserModel _supervisor(String id, String name) => UserModel(
  id: id,
  username: 'sup_$id',
  email: 'sup_$id@alrasikhoon.local',
  name: name,
  role: UserRole.supervisor,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<UserModel> supervisors,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        instituteProvider(
          _instituteId,
        ).overrideWith((ref) async => _institute()),
        teachersForInstituteProvider(
          _instituteId,
        ).overrideWith((ref) async => []),
        supervisorsForInstituteProvider(
          _instituteId,
        ).overrideWith((ref) async => supervisors),
        allSupervisorsProvider.overrideWith((ref) async => supervisors),
      ],
      child: const MaterialApp(
        home: InstituteDetailScreen(instituteId: _instituteId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a المشرفون heading and the assigned supervisors', (
    tester,
  ) async {
    await _pump(tester, supervisors: [_supervisor('s1', 'مشرف النور')]);

    expect(find.text('المشرفون'), findsOneWidget);
    expect(find.text('مشرف النور'), findsOneWidget);
  });

  testWidgets('shows a supervisors empty state when none are assigned', (
    tester,
  ) async {
    await _pump(tester, supervisors: const []);

    expect(find.text('لا يوجد مشرفون'), findsOneWidget);
  });
}
