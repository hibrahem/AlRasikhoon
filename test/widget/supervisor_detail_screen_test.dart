import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/institute_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/supervisor_detail_screen.dart';

class _MockInstituteRepository extends Mock implements InstituteRepository {}

const _supervisorId = 's1';

UserModel _supervisor() => UserModel(
  id: _supervisorId,
  username: 'sup_s1',
  email: 'sup_s1@alrasikhoon.local',
  name: 'مشرف النور',
  role: UserRole.supervisor,
  createdAt: DateTime(2026, 1, 1),
);

InstituteModel _institute(String id, String name) => InstituteModel(
  id: id,
  name: name,
  location: 'الرياض',
  createdBy: 'admin',
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<InstituteModel> assigned,
  required List<InstituteModel> allInstitutes,
  InstituteRepository? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supervisorProvider(
          _supervisorId,
        ).overrideWith((ref) async => _supervisor()),
        institutesForSupervisorProvider(
          _supervisorId,
        ).overrideWith((ref) async => assigned),
        institutesProvider.overrideWith((ref) async => allInstitutes),
        if (repo != null) instituteRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: SupervisorDetailScreen(supervisorId: _supervisorId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Duration());
  });

  testWidgets('shows the supervisor name and their assigned institutes', (
    tester,
  ) async {
    await _pump(
      tester,
      assigned: [_institute('i1', 'معهد النور')],
      allInstitutes: [
        _institute('i1', 'معهد النور'),
        _institute('i2', 'معهد الهدى'),
      ],
    );

    expect(find.text('مشرف النور'), findsOneWidget);
    expect(find.text('معهد النور'), findsOneWidget);
  });

  testWidgets('empty state when the supervisor covers no institute', (
    tester,
  ) async {
    await _pump(
      tester,
      assigned: const [],
      allInstitutes: [_institute('i1', 'معهد النور')],
    );

    expect(find.text('لا توجد معاهد مسندة'), findsOneWidget);
  });

  testWidgets('remove calls the repository for the tapped institute', (
    tester,
  ) async {
    final repo = _MockInstituteRepository();
    when(
      () => repo.removeSupervisorFromInstitute(
        supervisorId: any(named: 'supervisorId'),
        instituteId: any(named: 'instituteId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.getInstitutesForSupervisor(any()),
    ).thenAnswer((_) async => [_institute('i1', 'معهد النور')]);

    await _pump(
      tester,
      assigned: [_institute('i1', 'معهد النور')],
      allInstitutes: [_institute('i1', 'معهد النور')],
      repo: repo,
    );

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();
    // Confirm dialog -> tap "إزالة".
    await tester.tap(find.widgetWithText(TextButton, 'إزالة'));
    await tester.pumpAndSettle();

    verify(
      () => repo.removeSupervisorFromInstitute(
        supervisorId: _supervisorId,
        instituteId: 'i1',
      ),
    ).called(1);
  });
}
