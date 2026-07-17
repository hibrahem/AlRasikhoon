import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/institute_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/supervisor_detail_screen.dart';

class _MockInstituteRepository extends Mock implements InstituteRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

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
  UserRepository? userRepo,
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
        if (userRepo != null)
          userRepositoryProvider.overrideWithValue(userRepo),
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

  group('account actions (al_rasikhoon-1nw)', () {
    testWidgets('the app bar carries reset-password and edit-profile actions', (
      tester,
    ) async {
      await _pump(
        tester,
        assigned: const [],
        allInstitutes: [_institute('i1', 'معهد النور')],
      );

      expect(find.byTooltip('إعادة تعيين كلمة المرور'), findsOneWidget);
      expect(find.byTooltip('تعديل الملف الشخصي'), findsOneWidget);
    });

    testWidgets('reset-password opens the dialog for THIS supervisor', (
      tester,
    ) async {
      await _pump(
        tester,
        assigned: const [],
        allInstitutes: [_institute('i1', 'معهد النور')],
      );

      await tester.tap(find.byTooltip('إعادة تعيين كلمة المرور'));
      await tester.pumpAndSettle();

      expect(find.text('إعادة تعيين كلمة مرور مشرف النور'), findsOneWidget);
    });

    testWidgets('saving an edited name writes through UserRepository', (
      tester,
    ) async {
      final userRepo = _MockUserRepository();
      when(
        () => userRepo.updateProfileFields(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
          phone: any(named: 'phone'),
        ),
      ).thenAnswer((_) async {});

      await _pump(
        tester,
        assigned: const [],
        allInstitutes: [_institute('i1', 'معهد النور')],
        userRepo: userRepo,
      );

      await tester.tap(find.byTooltip('تعديل الملف الشخصي'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'مشرف النور'),
        'مشرف النور المحدث',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      verify(
        () => userRepo.updateProfileFields(
          userId: _supervisorId,
          name: 'مشرف النور المحدث',
          phone: null,
        ),
      ).called(1);
    });
  });

  testWidgets('assign calls the repository for the tapped institute', (
    tester,
  ) async {
    final repo = _MockInstituteRepository();
    when(
      () => repo.assignSupervisorToInstitute(
        supervisorId: any(named: 'supervisorId'),
        instituteId: any(named: 'instituteId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.getInstitutesForSupervisor(any()),
    ).thenAnswer((_) async => [_institute('i1', 'معهد النور')]);

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(
      tester,
      assigned: const [],
      allInstitutes: [_institute('i1', 'معهد النور')],
      repo: repo,
    );

    await tester.tap(find.text('إسناد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('معهد النور'));
    await tester.pumpAndSettle();

    verify(
      () => repo.assignSupervisorToInstitute(
        supervisorId: _supervisorId,
        instituteId: 'i1',
      ),
    ).called(1);
  });
}
