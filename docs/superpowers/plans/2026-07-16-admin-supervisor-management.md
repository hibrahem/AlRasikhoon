# Admin Supervisor Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the admin full supervisor↔institute management (list supervisors, assign/unassign institutes from both directions) and restructure the admin bottom nav to 3 tabs (Management / Curriculum / Profile).

**Architecture:** Pure UI + Riverpod-provider work over the existing `supervisor_institutes` membership model. Three new read providers wrap existing repository methods; two new screens plus one edited screen render assign/remove flows that reuse existing `InstituteRepository` write methods; the admin `StatefulShellRoute` collapses from 4 branches to 3 with all management sub-screens folded into a single Management branch.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), go_router (`StatefulShellRoute.indexedStack`), Firebase/Firestore, mocktail + flutter_test.

## Global Constraints

- UI copy is Arabic (RTL). Match existing labels verbatim; supervisor role label is `مشرف`, plural section headers use `المشرفون` / `المعاهد المسندة`.
- Color/accent uses `context.tokens` only (`gold`, `green`, `maroon`, `sepia`, `hairline`, `card`, `page`) — never raw `Color`. Supervisor accent is `tokens.gold` (matches the dashboard supervisor stat card).
- No changes to Firestore schema, `firestore.rules`, or `functions/`. Backend is already complete.
- The `RoleShell` build-time assert requires `destinationsFor(role)` to match the role's shell branches 1:1, in order, by `rootPath`. Any nav change must keep `nav_destinations.dart` and `app_router.dart` in lockstep.
- Soft-delete semantics: "remove" flips `is_active=false` via the repository; never hard-delete.
- Test commands: `flutter test <path>` for a file, `flutter analyze` for lints.

---

## File Structure

- `lib/features/admin/providers/admin_provider.dart` — **modify**: add 3 read providers.
- `lib/features/admin/screens/supervisors_screen.dart` — **create**: supervisor list.
- `lib/features/admin/screens/supervisor_detail_screen.dart` — **create**: supervisor detail + institute assign/remove.
- `lib/features/admin/screens/institute_detail_screen.dart` — **modify**: add supervisors section.
- `lib/features/admin/screens/admin_dashboard_screen.dart` — **modify**: becomes the Management hub.
- `lib/shared/widgets/nav_destinations.dart` — **modify**: superAdmin → 3 destinations.
- `lib/routing/app_router.dart` — **modify**: 3-branch admin shell + new routes.
- Tests under `test/unit/providers/`, `test/widget/`, `test/unit/shared/`.

---

## Task 1: Supervisor read providers

**Files:**
- Modify: `lib/features/admin/providers/admin_provider.dart`
- Test: `test/unit/providers/admin_supervisor_providers_test.dart`

**Interfaces:**
- Consumes: `UserRepository.getUserById(String) → Future<UserModel?>`, `InstituteRepository.getInstitutesForSupervisor(String) → Future<List<InstituteModel>>`, `InstituteRepository.getSupervisorIdsForInstitute(String) → Future<List<String>>` (all already exist).
- Produces:
  - `supervisorProvider` — `FutureProvider.family<UserModel?, String>`
  - `institutesForSupervisorProvider` — `FutureProvider.family<List<InstituteModel>, String>`
  - `supervisorsForInstituteProvider` — `FutureProvider.family<List<UserModel>, String>`

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/admin_supervisor_providers_test.dart`:

```dart
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
    when(() => userRepo.getUserById('s1')).thenAnswer((_) async => _supervisor('s1'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(supervisorProvider('s1').future);

    expect(result?.id, 's1');
    expect(result?.role, UserRole.supervisor);
  });

  test('institutesForSupervisorProvider delegates to the repository', () async {
    when(() => instituteRepo.getInstitutesForSupervisor('s1'))
        .thenAnswer((_) async => [_institute('i1'), _institute('i2')]);
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(institutesForSupervisorProvider('s1').future);

    expect(result.map((i) => i.id), ['i1', 'i2']);
  });

  test('supervisorsForInstituteProvider hydrates ids into user models, '
      'dropping ids that no longer resolve', () async {
    when(() => instituteRepo.getSupervisorIdsForInstitute('i1'))
        .thenAnswer((_) async => ['s1', 's2', 'ghost']);
    when(() => userRepo.getUserById('s1')).thenAnswer((_) async => _supervisor('s1'));
    when(() => userRepo.getUserById('s2')).thenAnswer((_) async => _supervisor('s2'));
    when(() => userRepo.getUserById('ghost')).thenAnswer((_) async => null);
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(supervisorsForInstituteProvider('i1').future);

    expect(result.map((s) => s.id), ['s1', 's2']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/admin_supervisor_providers_test.dart`
Expected: FAIL — `supervisorProvider`, `institutesForSupervisorProvider`, `supervisorsForInstituteProvider` are undefined.

- [ ] **Step 3: Add the providers**

Append to `lib/features/admin/providers/admin_provider.dart` (the imports for `UserModel` and `InstituteModel` already exist at the top of the file):

```dart
/// A single supervisor account (admin read-only view). Mirrors
/// [teacherProvider] — both are just `getUserById` — but named in supervisor
/// terms so supervisor screens never read as teacher screens.
final supervisorProvider = FutureProvider.family<UserModel?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserById(id);
});

/// Institutes a supervisor is assigned to, resolved from the
/// `supervisor_institutes` membership (al_rasikhoon-3n6). The admin twin of the
/// supervisor-side `supervisorInstituteIdsProvider`, but returns full
/// [InstituteModel]s for display and is keyed by an explicit supervisor id (the
/// admin inspects any supervisor, not "the current user").
final institutesForSupervisorProvider =
    FutureProvider.family<List<InstituteModel>, String>((
      ref,
      supervisorId,
    ) async {
      final repo = ref.watch(instituteRepositoryProvider);
      return repo.getInstitutesForSupervisor(supervisorId);
    });

/// Supervisors assigned to a given institute — the exact mirror of
/// [teachersForInstituteProvider], composing
/// `getSupervisorIdsForInstitute` with `getUserById`. An id that no longer
/// resolves to a user (deleted account) is dropped rather than surfaced as a
/// blank row.
final supervisorsForInstituteProvider =
    FutureProvider.family<List<UserModel>, String>((ref, instituteId) async {
      final instituteRepo = ref.watch(instituteRepositoryProvider);
      final userRepo = ref.watch(userRepositoryProvider);

      final supervisorIds = await instituteRepo.getSupervisorIdsForInstitute(
        instituteId,
      );
      final supervisors = <UserModel>[];
      for (final id in supervisorIds) {
        final supervisor = await userRepo.getUserById(id);
        if (supervisor != null) {
          supervisors.add(supervisor);
        }
      }
      return supervisors;
    });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/providers/admin_supervisor_providers_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/providers/admin_provider.dart test/unit/providers/admin_supervisor_providers_test.dart
git commit -m "feat(admin): add supervisor read providers (supervisor, institutes-for-supervisor, supervisors-for-institute)"
```

---

## Task 2: Supervisors list screen

**Files:**
- Create: `lib/features/admin/screens/supervisors_screen.dart`
- Add route constant only: `lib/routing/app_router.dart` (the `AppRoutes.supervisors` / `supervisorDetail` constants — route *registration* happens in Task 5)
- Test: `test/widget/supervisors_screen_test.dart`

**Interfaces:**
- Consumes: `allSupervisorsProvider` (`FutureProvider<List<UserModel>>`, already exists), `AppRoutes.supervisorDetail`, `AppRoutes.addSupervisor`.
- Produces: `class SupervisorsScreen extends ConsumerWidget` (const constructor).

- [ ] **Step 1: Add the route-name constants**

In `lib/routing/app_router.dart`, in the `// Admin` block of `class AppRoutes` (just after `static const String addSupervisor = '/admin/supervisors/add';`), add:

```dart
  static const String supervisors = '/admin/supervisors';
  static const String supervisorDetail = '/admin/supervisors/:id';
```

- [ ] **Step 2: Write the failing test**

Create `test/widget/supervisors_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/supervisors_screen.dart';

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

  testWidgets('shows the empty state when there are no supervisors',
      (tester) async {
    await _pump(tester, const []);

    expect(find.text('لا يوجد مشرفون'), findsOneWidget);
  });

  testWidgets('renders an add FAB', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/supervisors_screen_test.dart`
Expected: FAIL — `supervisors_screen.dart` / `SupervisorsScreen` does not exist.

- [ ] **Step 4: Create the screen**

Create `lib/features/admin/screens/supervisors_screen.dart` (mirrors `teachers_screen.dart`, gold accent, routes to supervisor detail):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

class SupervisorsScreen extends ConsumerWidget {
  const SupervisorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final supervisorsAsync = ref.watch(allSupervisorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المشرفون')),
      body: supervisorsAsync.when(
        data: (supervisors) {
          if (supervisors.isEmpty) {
            return const EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'لا يوجد مشرفون',
              message: 'اضغط على + لإضافة مشرف جديد',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allSupervisorsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: supervisors.length,
              itemBuilder: (context, index) {
                final supervisor = supervisors[index];
                return AppCard(
                  onTap: () => context.push(
                    AppRoutes.supervisorDetail.replaceFirst(':id', supervisor.id),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: tokens.gold.withValues(alpha: 0.1),
                        child: Text(
                          supervisor.name.isNotEmpty ? supervisor.name[0] : '?',
                          style: TextStyle(
                            color: tokens.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supervisor.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  supervisor.phone != null
                                      ? Icons.phone
                                      : Icons.email,
                                  size: 14,
                                  color: tokens.sepia,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    supervisor.phone ??
                                        supervisor.displayUsername,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: tokens.sepia),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: supervisor.isActive
                              ? tokens.green.withValues(alpha: 0.1)
                              : tokens.maroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          supervisor.isActive ? 'نشط' : 'غير نشط',
                          style: TextStyle(
                            fontSize: 11,
                            color: supervisor.isActive
                                ? tokens.green
                                : tokens.maroon,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_left, color: tokens.sepia),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المشرفين: $e'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addSupervisor),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widget/supervisors_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/admin/screens/supervisors_screen.dart lib/routing/app_router.dart test/widget/supervisors_screen_test.dart
git commit -m "feat(admin): add supervisors list screen"
```

---

## Task 3: Supervisor detail screen (institute assign/remove)

**Files:**
- Create: `lib/features/admin/screens/supervisor_detail_screen.dart`
- Test: `test/widget/supervisor_detail_screen_test.dart`

**Interfaces:**
- Consumes: `supervisorProvider(id)`, `institutesForSupervisorProvider(id)`, `institutesProvider` (all institutes, already exists), `InstituteRepository.assignSupervisorToInstitute({required supervisorId, required instituteId})`, `InstituteRepository.removeSupervisorFromInstitute({required supervisorId, required instituteId})`, `instituteRepositoryProvider`, `AppRoutes.instituteDetail`.
- Produces: `class SupervisorDetailScreen extends ConsumerWidget` with `final String supervisorId;` and `const SupervisorDetailScreen({super.key, required this.supervisorId})`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/supervisor_detail_screen_test.dart`:

```dart
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
        supervisorProvider(_supervisorId).overrideWith((ref) async => _supervisor()),
        institutesForSupervisorProvider(_supervisorId)
            .overrideWith((ref) async => assigned),
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

  testWidgets('shows the supervisor name and their assigned institutes',
      (tester) async {
    await _pump(
      tester,
      assigned: [_institute('i1', 'معهد النور')],
      allInstitutes: [_institute('i1', 'معهد النور'), _institute('i2', 'معهد الهدى')],
    );

    expect(find.text('مشرف النور'), findsOneWidget);
    expect(find.text('معهد النور'), findsOneWidget);
  });

  testWidgets('empty state when the supervisor covers no institute',
      (tester) async {
    await _pump(
      tester,
      assigned: const [],
      allInstitutes: [_institute('i1', 'معهد النور')],
    );

    expect(find.text('لا توجد معاهد مسندة'), findsOneWidget);
  });

  testWidgets('remove calls the repository for the tapped institute',
      (tester) async {
    final repo = _MockInstituteRepository();
    when(() => repo.removeSupervisorFromInstitute(
          supervisorId: any(named: 'supervisorId'),
          instituteId: any(named: 'instituteId'),
        )).thenAnswer((_) async {});
    when(() => repo.getInstitutesForSupervisor(any()))
        .thenAnswer((_) async => [_institute('i1', 'معهد النور')]);

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

    verify(() => repo.removeSupervisorFromInstitute(
          supervisorId: _supervisorId,
          instituteId: 'i1',
        )).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/supervisor_detail_screen_test.dart`
Expected: FAIL — `supervisor_detail_screen.dart` / `SupervisorDetailScreen` does not exist.

- [ ] **Step 3: Create the screen**

Create `lib/features/admin/screens/supervisor_detail_screen.dart`. This fuses the `teacher_detail` header idiom with the `institute_detail` assign/remove idiom (bottom sheet of unassigned institutes; remove with confirm dialog):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

/// Admin detail for one supervisor: identity header + the set of institutes the
/// supervisor is assigned to (via `supervisor_institutes` membership), with
/// assign (bottom sheet of not-yet-assigned institutes) and remove (confirm
/// dialog, soft-delete). Parallel to [InstituteDetailScreen]'s teachers
/// section, viewed from the supervisor side.
class SupervisorDetailScreen extends ConsumerWidget {
  final String supervisorId;

  const SupervisorDetailScreen({super.key, required this.supervisorId});

  void _refresh(WidgetRef ref, String instituteId) {
    ref.invalidate(institutesForSupervisorProvider(supervisorId));
    ref.invalidate(supervisorsForInstituteProvider(instituteId));
    ref.invalidate(allSupervisorsProvider);
  }

  void _showAssignInstituteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final allInstitutesAsync = ref.watch(institutesProvider);
          final assignedAsync = ref.watch(
            institutesForSupervisorProvider(supervisorId),
          );

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إسناد معهد',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: allInstitutesAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: 'خطأ: $e'),
                    data: (allInstitutes) => assignedAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: 'خطأ: $e'),
                      data: (assigned) {
                        final assignedIds = assigned.map((i) => i.id).toSet();
                        final available = allInstitutes
                            .where((i) => !assignedIds.contains(i.id))
                            .toList();

                        if (available.isEmpty) {
                          return const Center(
                            child: Text('لا توجد معاهد متاحة للإسناد'),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final institute = available[index];
                            return _InstituteSelectionTile(
                              institute: institute,
                              onTap: () =>
                                  _assignInstitute(context, ref, institute),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignInstitute(
    BuildContext context,
    WidgetRef ref,
    InstituteModel institute,
  ) async {
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.assignSupervisorToInstitute(
        supervisorId: supervisorId,
        instituteId: institute.id,
      );
      _refresh(ref, institute.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إسناد ${institute.name} بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إسناد المعهد: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }

  void _showRemoveInstituteDialog(
    BuildContext context,
    WidgetRef ref,
    InstituteModel institute,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الإسناد'),
        content: Text('هل أنت متأكد من إزالة إسناد ${institute.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => _removeInstitute(context, ref, institute),
            style: TextButton.styleFrom(foregroundColor: context.tokens.maroon),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeInstitute(
    BuildContext context,
    WidgetRef ref,
    InstituteModel institute,
  ) async {
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.removeSupervisorFromInstitute(
        supervisorId: supervisorId,
        instituteId: institute.id,
      );
      _refresh(ref, institute.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إزالة إسناد ${institute.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إزالة الإسناد: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final supervisorAsync = ref.watch(supervisorProvider(supervisorId));
    final institutesAsync = ref.watch(
      institutesForSupervisorProvider(supervisorId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشرف')),
      body: supervisorAsync.when(
        data: (supervisor) {
          if (supervisor == null) {
            return const Center(child: Text('المشرف غير موجود'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: tokens.gold.withValues(alpha: 0.1),
                        child: Text(
                          supervisor.name.isNotEmpty ? supervisor.name[0] : '?',
                          style: TextStyle(
                            color: tokens.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supervisor.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              supervisor.phone ?? supervisor.displayUsername,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.sepia),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المعاهد المسندة',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => _showAssignInstituteSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إسناد'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                institutesAsync.when(
                  data: (institutes) {
                    if (institutes.isEmpty) {
                      return EmptyState(
                        icon: Icons.account_balance_outlined,
                        title: 'لا توجد معاهد مسندة',
                        action: AppButton(
                          text: 'إسناد معهد',
                          onPressed: () =>
                              _showAssignInstituteSheet(context, ref),
                          type: AppButtonType.outline,
                          size: AppButtonSize.small,
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: institutes.length,
                      itemBuilder: (context, index) {
                        final institute = institutes[index];
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: () => context.push(
                            AppRoutes.instituteDetail
                                .replaceFirst(':id', institute.id),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tokens.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.account_balance,
                                  color: tokens.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      institute.name,
                                      style:
                                          Theme.of(context).textTheme.titleSmall,
                                    ),
                                    Text(
                                      institute.location,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.sepia),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: tokens.maroon,
                                ),
                                onPressed: () => _showRemoveInstituteDialog(
                                  context,
                                  ref,
                                  institute,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) =>
                      ErrorState(message: 'تعذر تحميل المعاهد: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المشرف: $e'),
      ),
    );
  }
}

class _InstituteSelectionTile extends StatelessWidget {
  final InstituteModel institute;
  final VoidCallback onTap;

  const _InstituteSelectionTile({required this.institute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.green.withValues(alpha: 0.1),
        child: Icon(Icons.account_balance, color: tokens.green),
      ),
      title: Text(institute.name),
      subtitle: Text(institute.location),
      trailing: Icon(Icons.add_circle_outline, color: tokens.green),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/supervisor_detail_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/screens/supervisor_detail_screen.dart test/widget/supervisor_detail_screen_test.dart
git commit -m "feat(admin): add supervisor detail screen with institute assign/remove"
```

---

## Task 4: Supervisors section on the institute detail screen

**Files:**
- Modify: `lib/features/admin/screens/institute_detail_screen.dart`
- Test: `test/widget/institute_detail_supervisors_section_test.dart`

**Interfaces:**
- Consumes: `supervisorsForInstituteProvider(instituteId)`, `allSupervisorsProvider`, `InstituteRepository.assignSupervisorToInstitute`, `InstituteRepository.removeSupervisorFromInstitute`, `AppRoutes.supervisorDetail`.
- Produces: no new public symbols — extends the existing `InstituteDetailScreen`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/institute_detail_supervisors_section_test.dart`:

```dart
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
        instituteProvider(_instituteId).overrideWith((ref) async => _institute()),
        teachersForInstituteProvider(_instituteId).overrideWith((ref) async => []),
        supervisorsForInstituteProvider(_instituteId)
            .overrideWith((ref) async => supervisors),
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
  testWidgets('renders a المشرفون heading and the assigned supervisors',
      (tester) async {
    await _pump(tester, supervisors: [_supervisor('s1', 'مشرف النور')]);

    expect(find.text('المشرفون'), findsOneWidget);
    expect(find.text('مشرف النور'), findsOneWidget);
  });

  testWidgets('shows a supervisors empty state when none are assigned',
      (tester) async {
    await _pump(tester, supervisors: const []);

    expect(find.text('لا يوجد مشرفون'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/institute_detail_supervisors_section_test.dart`
Expected: FAIL — no `المشرفون` heading / `supervisorsForInstituteProvider` not referenced by the screen.

- [ ] **Step 3: Add the supervisors section**

In `lib/features/admin/screens/institute_detail_screen.dart`:

(a) Add the import for `AppRoutes` if not present — it already imports `'../../../routing/app_router.dart'`; confirm it stays.

(b) Add these four methods to the `InstituteDetailScreen` class, immediately after `_removeTeacher` (before `build`). They mirror the teacher methods but target supervisors:

```dart
  void _showAddSupervisorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final allSupervisorsAsync = ref.watch(allSupervisorsProvider);
          final assignedSupervisorsAsync = ref.watch(
            supervisorsForInstituteProvider(instituteId),
          );

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إضافة مشرف',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: allSupervisorsAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: 'خطأ: $e'),
                    data: (allSupervisors) => assignedSupervisorsAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: 'خطأ: $e'),
                      data: (assignedSupervisors) {
                        final assignedIds =
                            assignedSupervisors.map((s) => s.id).toSet();
                        final available = allSupervisors
                            .where((s) => !assignedIds.contains(s.id))
                            .toList();

                        if (available.isEmpty) {
                          return const Center(
                            child: Text('لا يوجد مشرفون متاحون للإضافة'),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final supervisor = available[index];
                            return _SupervisorSelectionTile(
                              supervisor: supervisor,
                              onTap: () =>
                                  _assignSupervisor(context, ref, supervisor),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignSupervisor(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) async {
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.assignSupervisorToInstitute(
        supervisorId: supervisor.id,
        instituteId: instituteId,
      );
      ref.invalidate(supervisorsForInstituteProvider(instituteId));
      ref.invalidate(institutesForSupervisorProvider(supervisor.id));
      ref.invalidate(allSupervisorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة ${supervisor.name} بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة المشرف: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }

  void _showRemoveSupervisorDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة المشرف'),
        content: Text('هل أنت متأكد من إزالة ${supervisor.name} من هذا المعهد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => _removeSupervisor(context, ref, supervisor),
            style: TextButton.styleFrom(foregroundColor: context.tokens.maroon),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSupervisor(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) async {
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.removeSupervisorFromInstitute(
        supervisorId: supervisor.id,
        instituteId: instituteId,
      );
      ref.invalidate(supervisorsForInstituteProvider(instituteId));
      ref.invalidate(institutesForSupervisorProvider(supervisor.id));
      ref.invalidate(allSupervisorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إزالة ${supervisor.name} بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إزالة المشرف: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }
```

(c) In `build`, add a `supervisorsAsync` watch next to the existing `teachersAsync`:

Find:
```dart
    final teachersAsync = ref.watch(teachersForInstituteProvider(instituteId));
```
Add immediately after:
```dart
    final supervisorsAsync = ref.watch(
      supervisorsForInstituteProvider(instituteId),
    );
```

(d) In the `Column` children, immediately AFTER the closing `)` of the teachers `teachersAsync.when(...)` block (the last widget before the Column closes), insert the supervisors section:

```dart
                const SizedBox(height: 24),
                // Supervisors section — mirrors the teachers section above.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المشرفون',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddSupervisorSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                supervisorsAsync.when(
                  data: (supervisors) {
                    if (supervisors.isEmpty) {
                      return EmptyState(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'لا يوجد مشرفون',
                        action: AppButton(
                          text: 'إضافة مشرف',
                          onPressed: () =>
                              _showAddSupervisorSheet(context, ref),
                          type: AppButtonType.outline,
                          size: AppButtonSize.small,
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: supervisors.length,
                      itemBuilder: (context, index) {
                        final supervisor = supervisors[index];
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: () => context.push(
                            AppRoutes.supervisorDetail
                                .replaceFirst(':id', supervisor.id),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    tokens.gold.withValues(alpha: 0.1),
                                child: Text(
                                  supervisor.name.isNotEmpty
                                      ? supervisor.name[0]
                                      : '?',
                                  style: TextStyle(
                                    color: tokens.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      supervisor.name,
                                      style:
                                          Theme.of(context).textTheme.titleSmall,
                                    ),
                                    Text(
                                      supervisor.phone ??
                                          supervisor.displayUsername,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.sepia),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: tokens.maroon,
                                ),
                                onPressed: () => _showRemoveSupervisorDialog(
                                  context,
                                  ref,
                                  supervisor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) =>
                      ErrorState(message: 'تعذر تحميل المشرفين: $e'),
                ),
```

(e) Add a `_SupervisorSelectionTile` at the bottom of the file, next to `_TeacherSelectionTile`:

```dart
class _SupervisorSelectionTile extends StatelessWidget {
  final UserModel supervisor;
  final VoidCallback onTap;

  const _SupervisorSelectionTile({
    required this.supervisor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.gold.withValues(alpha: 0.1),
        child: Text(
          supervisor.name.isNotEmpty ? supervisor.name[0] : '?',
          style: TextStyle(color: tokens.gold, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(supervisor.name),
      subtitle: Text(supervisor.phone ?? supervisor.displayUsername),
      trailing: Icon(Icons.add_circle_outline, color: tokens.gold),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/institute_detail_supervisors_section_test.dart`
Expected: PASS (2 tests). Also run the existing institute-detail-adjacent tests to confirm no regression:
Run: `flutter test test/widget/teacher_detail_institute_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/screens/institute_detail_screen.dart test/widget/institute_detail_supervisors_section_test.dart
git commit -m "feat(admin): show and manage supervisors on the institute detail screen"
```

---

## Task 5: Restructure admin nav to 3 tabs (Management / Curriculum / Profile)

**Files:**
- Modify: `lib/shared/widgets/nav_destinations.dart`
- Modify: `lib/routing/app_router.dart`
- Modify: `test/unit/shared/nav_destinations_test.dart`
- Test (existing, must stay green): `test/unit/routing/nav_branch_parity_test.dart`

**Interfaces:**
- Consumes: all admin screen classes (already imported in the router), `SettingsScreen` (already imported), `SupervisorsScreen` + `SupervisorDetailScreen` (Tasks 2–3), `AppRoutes.supervisors` / `supervisorDetail` (Task 2), new `AppRoutes.adminSettings`.
- Produces: `AppRoutes.adminSettings = '/admin/settings'`; a 3-branch admin `StatefulShellRoute`; a 3-entry `destinationsFor(UserRole.superAdmin)`.

- [ ] **Step 1: Update the nav-destinations test first (red)**

In `test/unit/shared/nav_destinations_test.dart`:

(a) Add `UserRole.superAdmin` to the `destinationsFor account tab` role loop list so it reads:
```dart
    for (final role in [
      UserRole.superAdmin,
      UserRole.teacher,
      UserRole.student,
      UserRole.guardian,
      UserRole.supervisor,
    ]) {
```

(b) Add a new test inside the top-level `group('destinationsFor', ...)`:
```dart
    test('superAdmin has three tabs: management, curriculum, profile', () {
      final destinations = destinationsFor(UserRole.superAdmin);

      expect(destinations.map((d) => d.label), ['الإدارة', 'المنهج', 'الملف الشخصي']);
      expect(destinations.map((d) => d.rootPath), [
        AppRoutes.adminDashboard,
        AppRoutes.curriculum,
        AppRoutes.adminSettings,
      ]);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/shared/nav_destinations_test.dart`
Expected: FAIL — `AppRoutes.adminSettings` undefined and superAdmin still returns 4 destinations without the profile tab.

- [ ] **Step 3: Add the `adminSettings` route constant**

In `lib/routing/app_router.dart`, in the `// Admin` block of `AppRoutes`, add (after the `adminStudentSessionDetail` constant):
```dart
  static const String adminSettings = '/admin/settings';
```

- [ ] **Step 4: Rewrite the superAdmin destinations**

In `lib/shared/widgets/nav_destinations.dart`, replace the entire `case UserRole.superAdmin:` block with:
```dart
    case UserRole.superAdmin:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الإدارة',
          rootPath: AppRoutes.adminDashboard,
        ),
        NavDestination(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book,
          label: 'المنهج',
          rootPath: AppRoutes.curriculum,
        ),
        NavDestination(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'الملف الشخصي',
          rootPath: AppRoutes.adminSettings,
        ),
      ];
```

- [ ] **Step 5: Restructure the admin shell to 3 branches**

In `lib/routing/app_router.dart`:

(a) Add the imports for the two new screens near the other admin screen imports:
```dart
import '../features/admin/screens/supervisors_screen.dart';
import '../features/admin/screens/supervisor_detail_screen.dart';
```

(b) Replace the whole admin `StatefulShellRoute.indexedStack(...)` (the block whose comment reads `// Admin shell — Home / Institutes / Teachers / Curriculum`) with the following 3-branch shell. Branch 0 (Management) absorbs the old Home + Institutes + Teachers branches and adds the supervisor routes; Branch 1 is Curriculum unchanged; Branch 2 is the new Profile:

```dart
      // Admin shell — Management / Curriculum / Profile. Management (branch 0)
      // is the hub: it hosts the dashboard plus every management sub-screen
      // (institutes, teachers, supervisors, students) so navigation between
      // them never crosses a shell boundary (#45).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleShell(
          navigationShell: navigationShell,
          role: UserRole.superAdmin,
        ),
        branches: [
          // Branch 0: Management hub (dashboard + institutes + teachers +
          // supervisors + students).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminDashboard,
                builder: (context, state) => const AdminDashboardScreen(),
              ),
              // Institutes
              GoRoute(
                path: AppRoutes.institutes,
                builder: (context, state) => const InstitutesScreen(),
              ),
              GoRoute(
                path: AppRoutes.createInstitute,
                builder: (context, state) => const CreateInstituteScreen(),
              ),
              GoRoute(
                path: AppRoutes.instituteDetail,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return InstituteDetailScreen(instituteId: id);
                },
              ),
              GoRoute(
                path: AppRoutes.editInstitute,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return EditInstituteScreen(instituteId: id);
                },
              ),
              // Teachers
              GoRoute(
                path: AppRoutes.teachers,
                builder: (context, state) => const TeachersScreen(),
              ),
              GoRoute(
                path: AppRoutes.addTeacher,
                builder: (context, state) => const AddTeacherScreen(),
              ),
              GoRoute(
                path: AppRoutes.teacherDetail,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return TeacherDetailScreen(teacherId: id);
                },
              ),
              // Supervisors. `add` is registered BEFORE `:id` so the literal
              // segment still matches AddSupervisorScreen.
              GoRoute(
                path: AppRoutes.supervisors,
                builder: (context, state) => const SupervisorsScreen(),
              ),
              GoRoute(
                path: AppRoutes.addSupervisor,
                builder: (context, state) => const AddSupervisorScreen(),
              ),
              GoRoute(
                path: AppRoutes.supervisorDetail,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SupervisorDetailScreen(supervisorId: id);
                },
              ),
              // Students
              GoRoute(
                path: AppRoutes.adminStudents,
                builder: (context, state) => const AllStudentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminStudentProgress,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return StudentProgressScreen(
                    studentId: id,
                    studentProvider: adminStudentProvider,
                    currentMeetingProvider: adminStudentCurrentMeetingProvider,
                    sessionHistoryProvider: adminStudentSessionHistoryProvider,
                    sessionDetailRoute: AppRoutes.adminStudentSessionDetail,
                  );
                },
              ),
              GoRoute(
                path: AppRoutes.adminStudentSessionDetail,
                builder: (context, state) {
                  final recordId = state.pathParameters['recordId']!;
                  return SessionDetailScreen(recordId: recordId);
                },
              ),
            ],
          ),
          // Branch 1: Curriculum
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.curriculum,
                builder: (context, state) => const CurriculumScreen(),
              ),
              GoRoute(
                path: AppRoutes.levelDetail,
                builder: (context, state) {
                  final levelNumber = int.parse(
                    state.pathParameters['levelNumber']!,
                  );
                  return LevelDetailScreen(levelNumber: levelNumber);
                },
              ),
            ],
          ),
          // Branch 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
```

Note: `SessionDetailScreen` is already imported for the supervisor/student shells; confirm the import line `import '../features/student/screens/session_detail_screen.dart';` exists (it does — `SessionDetailScreen` is used by other branches). If `flutter analyze` reports it missing, add it.

- [ ] **Step 6: Run the nav + router tests**

Run: `flutter test test/unit/shared/nav_destinations_test.dart test/unit/routing/nav_branch_parity_test.dart`
Expected: PASS. `nav_branch_parity_test` confirms the 3 destinations match the 3 branches in order; `nav_destinations_test` confirms the new superAdmin tabs.

- [ ] **Step 7: Run analyze to catch any dangling references**

Run: `flutter analyze lib/routing/app_router.dart lib/shared/widgets/nav_destinations.dart`
Expected: No errors. (Warnings pre-existing elsewhere are fine.)

- [ ] **Step 8: Commit**

```bash
git add lib/shared/widgets/nav_destinations.dart lib/routing/app_router.dart test/unit/shared/nav_destinations_test.dart
git commit -m "feat(admin): restructure admin nav to 3 tabs (management/curriculum/profile)"
```

---

## Task 6: Turn the admin dashboard into the Management hub

**Files:**
- Modify: `lib/features/admin/screens/admin_dashboard_screen.dart`
- Test: `test/widget/admin_management_hub_test.dart`

**Interfaces:**
- Consumes: `adminStatsProvider` (exists), `AppRoutes.institutes`, `AppRoutes.teachers`, `AppRoutes.supervisors`, `AppRoutes.adminStudents`.
- Produces: no new public symbols.

- [ ] **Step 1: Write the failing test**

Create `test/widget/admin_management_hub_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/admin_dashboard_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminStatsProvider.overrideWith((ref) async => const AdminStats(
              institutesCount: 2,
              teachersCount: 3,
              supervisorsCount: 1,
              studentsCount: 5,
            )),
      ],
      child: const MaterialApp(home: AdminDashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four management stat cards', (tester) async {
    await _pump(tester);

    expect(find.text('المعاهد'), findsOneWidget);
    expect(find.text('المعلمون'), findsOneWidget);
    expect(find.text('المشرفون'), findsOneWidget);
    expect(find.text('الطلاب'), findsOneWidget);
  });

  testWidgets('no longer shows the old quick-actions section', (tester) async {
    await _pump(tester);

    expect(find.text('الإجراءات السريعة'), findsNothing);
  });

  testWidgets('no longer shows a sign-out action in the AppBar', (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.logout), findsNothing);
  });
}
```

Note: the test does not override `authRepositoryProvider`; after the edit in Step 3 the dashboard no longer watches it, so no override is needed. If a `ProviderScope` error about `authRepositoryProvider` appears, it means Step 3's removal of `ref.watch(authRepositoryProvider)` was not applied.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/admin_management_hub_test.dart`
Expected: FAIL — the quick-actions section (`الإجراءات السريعة`) and the AppBar `Icons.logout` still exist.

- [ ] **Step 3: Rewrite the dashboard as the hub**

Replace the full contents of `lib/features/admin/screens/admin_dashboard_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

/// The admin Management hub (branch 0 of the admin shell). Welcome header + a
/// 2×2 grid of stat cards that double as the navigation into each management
/// area: institutes, teachers, supervisors, students. Sign-out now lives in the
/// Profile tab, so there is no AppBar action here.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('الراسخون')),
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final statsAsync = ref.watch(adminStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً، مدير النظام',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'إدارة المعاهد والمعلمين والمشرفين والطلاب',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              data: (stats) => _buildStats(context, stats),
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: 'تعذر تحميل الإحصائيات: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, AdminStats stats) {
    final tokens = context.tokens;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'المعاهد',
          value: '${stats.institutesCount}',
          icon: Icons.account_balance,
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.institutes),
        ),
        StatCard(
          title: 'المعلمون',
          value: '${stats.teachersCount}',
          icon: Icons.people,
          iconColor: tokens.maroon,
          onTap: () => context.push(AppRoutes.teachers),
        ),
        StatCard(
          title: 'المشرفون',
          value: '${stats.supervisorsCount}',
          icon: Icons.admin_panel_settings,
          iconColor: tokens.gold,
          onTap: () => context.push(AppRoutes.supervisors),
        ),
        StatCard(
          title: 'الطلاب',
          value: '${stats.studentsCount}',
          icon: Icons.school,
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.adminStudents),
        ),
      ],
    );
  }
}
```

Key changes from the original: the المشرفون card now routes to `AppRoutes.supervisors` (the new list) instead of `addSupervisor`; المعاهد / المعلمون use `context.push` (they now live in the same Management branch); the `الإجراءات السريعة` quick-actions section is deleted; the AppBar sign-out `IconButton` and the `ref.watch(authRepositoryProvider)` line are removed; the widget becomes a `ConsumerWidget` (was `ConsumerStatefulWidget`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/admin_management_hub_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/screens/admin_dashboard_screen.dart test/widget/admin_management_hub_test.dart
git commit -m "feat(admin): turn the dashboard into the management hub (stats-as-navigation)"
```

---

## Task 7: Full-suite regression + analyze

**Files:** none (verification only).

- [ ] **Step 1: Run the whole test suite**

Run: `flutter test`
Expected: PASS. Pay attention to any existing admin/nav tests that assumed the old 4-tab shell (e.g. `test/e2e/admin_flow_test.dart`, `test/widget/role_shell_navigation_test.dart`).

- [ ] **Step 2: If any existing test asserted the old admin nav, update it**

For each failure, read the test and update its expectation to the new 3-tab structure (Management/Curriculum/Profile) — do NOT change production code to satisfy a stale assertion. Re-run that test file until green. Commit any such fix:

```bash
git add <updated test files>
git commit -m "test: update admin nav expectations for the 3-tab shell"
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: no new errors introduced by this feature. (Pre-existing warnings unrelated to these files are acceptable.)

- [ ] **Step 4: Final commit if analyze prompted changes**

```bash
git add -A
git commit -m "chore: resolve analyzer findings for supervisor management"
```

---

## Self-Review

**Spec coverage:**
- List all supervisors → Task 2 (`supervisors_screen`). ✓
- Assign supervisor to one or more institutes → Task 3 (supervisor detail assign) + Task 4 (institute detail assign). ✓
- Institute → its supervisors → Task 4. ✓
- Supervisor → their institutes → Task 3. ✓
- Providers (`supervisorProvider`, `institutesForSupervisorProvider`, `supervisorsForInstituteProvider`) → Task 1. ✓
- Nav restructure to Management/Curriculum/Profile → Task 5. ✓
- Management hub (stats-as-hub, drop quick-actions, remove AppBar logout) → Task 6. ✓
- Profile tab = SettingsScreen → Task 5 (branch 2). ✓
- Single-institute creation unchanged → no task touches `add_supervisor_screen`. ✓
- Testing (list/detail/institute-section/nav parity) → Tasks 1–6 + Task 7 regression. ✓
- No schema/rules/function changes → confirmed; no task touches `firestore.rules` or `functions/`. ✓

**Type consistency:** `supervisorProvider`, `institutesForSupervisorProvider`, `supervisorsForInstituteProvider` names are identical across Tasks 1, 3, 4. Repository method names (`assignSupervisorToInstitute`, `removeSupervisorFromInstitute`, `getInstitutesForSupervisor`, `getSupervisorIdsForInstitute`) match `institute_repository.dart` exactly (named params `supervisorId`, `instituteId`). `AppRoutes.supervisors` / `supervisorDetail` / `adminSettings` are defined in Task 2/Task 5 and consumed consistently. `SupervisorDetailScreen(supervisorId:)` and `SupervisorsScreen()` signatures match their router usage in Task 5.

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to" — every code step contains full code.
