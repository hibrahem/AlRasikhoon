import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/institute_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockInstituteRepository extends Mock implements InstituteRepository {}

UserModel _supervisor(String id) => UserModel(
  id: id,
  username: 'sup_$id',
  email: 'sup_$id@alrasikhoon.local',
  name: 'مشرف $id',
  role: UserRole.supervisor,
  createdAt: DateTime(2026, 1, 1),
);

InstituteModel _institute(String id) => InstituteModel(
  id: id,
  name: 'معهد $id',
  location: 'الرياض',
  createdBy: 'admin',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late _MockUserRepository userRepo;
  late _MockInstituteRepository instituteRepo;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      userRepositoryProvider.overrideWithValue(userRepo),
      instituteRepositoryProvider.overrideWithValue(instituteRepo),
    ],
  );

  setUp(() {
    userRepo = _MockUserRepository();
    instituteRepo = _MockInstituteRepository();
  });

  test('supervisorProvider returns the account for the id', () async {
    when(
      () => userRepo.getUserById('s1'),
    ).thenAnswer((_) async => _supervisor('s1'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(supervisorProvider('s1').future);

    expect(result?.id, 's1');
    expect(result?.role, UserRole.supervisor);
  });

  test('institutesForSupervisorProvider delegates to the repository', () async {
    when(
      () => instituteRepo.getInstitutesForSupervisor('s1'),
    ).thenAnswer((_) async => [_institute('i1'), _institute('i2')]);
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      institutesForSupervisorProvider('s1').future,
    );

    expect(result.map((i) => i.id), ['i1', 'i2']);
  });

  test('supervisorsForInstituteProvider hydrates ids into user models, '
      'dropping ids that no longer resolve', () async {
    when(
      () => instituteRepo.getSupervisorIdsForInstitute('i1'),
    ).thenAnswer((_) async => ['s1', 's2', 'ghost']);
    when(
      () => userRepo.getUserById('s1'),
    ).thenAnswer((_) async => _supervisor('s1'));
    when(
      () => userRepo.getUserById('s2'),
    ).thenAnswer((_) async => _supervisor('s2'));
    when(() => userRepo.getUserById('ghost')).thenAnswer((_) async => null);
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      supervisorsForInstituteProvider('i1').future,
    );

    expect(result.map((s) => s.id), ['s1', 's2']);
  });
}
