# Admin Supervisor Management + Admin Nav Restructure — Design

**Date:** 2026-07-16
**Status:** Approved (design), pending implementation plan

## Problem

The supervisor concept is only half-built in the admin surface. An admin can
*create* a supervisor (bound to one institute) but cannot afterwards:

- see all supervisors listed;
- assign an existing supervisor to one or more additional institutes, or remove them;
- open an institute and see which supervisors cover it;
- open a supervisor and see which institutes they cover.

Separately, the admin bottom navigation (الرئيسية / المعاهد / المعلمون / المنهج)
has no single "management" home and no profile/settings tab (sign-out lives in
the dashboard AppBar).

## Backend status — already built

The many-to-many `supervisor_institutes` membership model is the source of truth
for supervisor scoping (al_rasikhoon-3n6). Everything the UI needs already exists:

- `InstituteRepository`: `assignSupervisorToInstitute`, `removeSupervisorFromInstitute`,
  `getInstitutesForSupervisor`, `getSupervisorIdsForInstitute`.
- `UserRepository`: `getSupervisors`, `getUserById`.
- Cloud function `createUserAccount` seeds one `supervisor_institutes/{uid}_{instituteId}`
  membership at creation (requires exactly one `instituteId` for supervisors).
- Firestore rules: `supervisor_institutes` is admin-write-only; a super-admin may
  `create, update, delete` memberships and read them.

**No schema, Firestore-rules, or cloud-function changes are required.** This is a
UI + Riverpod-provider job.

## Decisions (from brainstorming)

1. **Admin nav → 3 tabs:** `الإدارة` (Management) / `المنهج` (Curriculum) /
   `الملف الشخصي` (Profile). "Main" is merged into Management (the dashboard
   stats live at the top of the Management hub).
2. **Creation stays single-institute.** The add-supervisor form is unchanged
   (one required institute seed). Assigning *additional* institutes happens
   afterward on the supervisor detail screen. No cloud-function change.

## Architecture

The project's established pattern is: `models` (Firestore serialization) →
`repositories` (data access + Riverpod provider) → feature `providers`
(FutureProviders composing repositories) → `screens` (ConsumerWidget). This
design follows that pattern exactly; it adds no new repository methods, only
read-side providers and screens.

### Navigation (3-tab admin shell)

`destinationsFor(UserRole.superAdmin)` in `nav_destinations.dart` returns three
destinations, in order:

| # | Label | Icon | rootPath |
|---|-------|------|----------|
| 0 | الإدارة | `Icons.grid_view` / `grid_view_rounded` | `AppRoutes.adminDashboard` (`/admin`) |
| 1 | المنهج | `Icons.menu_book_outlined` / `menu_book` | `AppRoutes.curriculum` |
| 2 | الملف الشخصي | `Icons.person_outline` / `person` | `AppRoutes.adminSettings` (`/admin/settings`) |

The admin `StatefulShellRoute` collapses from 4 branches to **3**, matching the
3 destinations 1:1 in order (the `RoleShell` assert enforces this — each
destination's `rootPath` must equal the Nth branch's first route path).

- **Branch 0 — Management** (`rootPath: /admin`): hosts the dashboard/hub and
  ALL management sub-screens so navigation never crosses a shell boundary:
  institutes (list/create/detail/edit), teachers (list/add/detail), supervisors
  (list/add/detail), students (list/progress/session-detail).
- **Branch 1 — Curriculum** (`rootPath: /admin/curriculum`): curriculum +
  level detail (unchanged).
- **Branch 2 — Profile** (`rootPath: /admin/settings`): `SettingsScreen`.

### Screens

**`admin_dashboard_screen.dart` (edit) — the Management hub**
- Keeps the welcome header + the 2×2 stat grid.
- The 4 stat cards become the hub entries and each navigates to its list:
  المعاهد → institutes, المعلمون → teachers, المشرفون → **supervisors list (new)**,
  الطلاب → students.
- Removes the "الإجراءات السريعة" quick-actions section (each destination list
  already has an add FAB) and removes the AppBar sign-out icon (sign-out now
  lives in the Profile tab).

**`supervisors_screen.dart` (new)** — mirror of `teachers_screen.dart`.
- Watches `allSupervisorsProvider`; empty state; pull-to-refresh.
- Each row: avatar, name, phone-or-`displayUsername`, active/inactive chip.
- Tap → supervisor detail. FAB → `AppRoutes.addSupervisor`.
- Uses the gold token for the supervisor accent (matches the dashboard stat card
  for المشرفون).

**`supervisor_detail_screen.dart` (new)** — combines the `teacher_detail` header
idiom with the `institute_detail` assign/remove idiom.
- Header card: supervisor name, username/phone, active state.
- **Institutes section** ("المعاهد المسندة"): lists institutes from
  `institutesForSupervisorProvider(supervisorId)`; each row taps through to the
  institute detail and has a remove (`remove_circle_outline`, maroon) button.
- "إضافة" opens a `showModalBottomSheet` listing institutes NOT yet assigned
  (all institutes minus already-assigned), each assignable on tap.
- Empty state when the supervisor covers no institute.

**`institute_detail_screen.dart` (edit)** — add a **Supervisors section**
directly mirroring the existing Teachers section.
- New "المشرفون" section below the teachers section: lists supervisors from
  `supervisorsForInstituteProvider(instituteId)`, each with a remove button and
  tap-through to the supervisor detail.
- New "add supervisor" bottom sheet: all supervisors minus already-assigned.
- Reuses the same assign/remove/snackbar/error structure as the teacher code in
  the same file (a parallel `_showAddSupervisorSheet`, `_assignSupervisor`,
  `_showRemoveSupervisorDialog`, `_removeSupervisor`, and a
  `_SupervisorSelectionTile`).

**`add_supervisor_screen.dart` (unchanged)** — single-institute seed at creation.

### Providers (add to `admin_provider.dart`)

```dart
/// A single supervisor account (admin read-only).
final supervisorProvider = FutureProvider.family<UserModel?, String>((ref, id) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getUserById(id);
});

/// Institutes a supervisor is assigned to (via supervisor_institutes membership).
final institutesForSupervisorProvider =
    FutureProvider.family<List<InstituteModel>, String>((ref, supervisorId) async {
  final repo = ref.watch(instituteRepositoryProvider);
  return repo.getInstitutesForSupervisor(supervisorId);
});

/// Supervisors assigned to a given institute (mirrors teachersForInstituteProvider).
final supervisorsForInstituteProvider =
    FutureProvider.family<List<UserModel>, String>((ref, instituteId) async {
  final instituteRepo = ref.watch(instituteRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final ids = await instituteRepo.getSupervisorIdsForInstitute(instituteId);
  final supervisors = <UserModel>[];
  for (final id in ids) {
    final s = await userRepo.getUserById(id);
    if (s != null) supervisors.add(s);
  }
  return supervisors;
});
```

`allSupervisorsProvider` already exists.

### Write flows & cache invalidation

- **Assign** (from either detail screen): `assignSupervisorToInstitute(supervisorId, instituteId)`,
  then invalidate `institutesForSupervisorProvider(supervisorId)`,
  `supervisorsForInstituteProvider(instituteId)`, and `allSupervisorsProvider`.
- **Remove**: `removeSupervisorFromInstitute(...)` (soft-delete: flips
  `is_active=false`), then the same invalidations.

Both detail screens invalidate BOTH family providers so the two views stay
consistent no matter which one initiated the change.

### Routing changes

New `AppRoutes` constants:
- `supervisors = '/admin/supervisors'`
- `supervisorDetail = '/admin/supervisors/:id'`
- `adminSettings = '/admin/settings'`

`addSupervisor` (`/admin/supervisors/add`) is kept and registered BEFORE the
`:id` detail route so the literal `add` segment still matches the add screen (same
ordering rule already used for supervisor students `add` vs `:studentId`).

## Testing

Follow existing widget/provider test setups (the recent commit repaired the
supervisor-scoping test scaffolding).

- `supervisors_screen`: renders the supervisor list; empty state; FAB routes to add.
- `supervisor_detail_screen`: shows assigned institutes; assign adds a membership
  and refreshes; remove drops it; empty state.
- `institute_detail_screen`: the new supervisors section lists assigned
  supervisors, assign/remove behave, and it does not disturb the teachers section.
- Provider tests for `institutesForSupervisorProvider` and
  `supervisorsForInstituteProvider` against a fake/emulated Firestore.
- A `RoleShell` / nav test asserting the 3 admin destinations match the 3 branches
  (guards the invariant when collapsing branches).

## Out of scope

- Multi-institute selection at supervisor creation (cloud function stays single-seed).
- Any supervisor-side (non-admin) UI changes.
- Schema, Firestore-rules, or cloud-function changes.
- Editing a supervisor's profile fields (name/phone/password) from the detail screen.

## Consequence flagged to user

Collapsing 4 branches into 1 means Institutes and Teachers stop being their own
bottom-tab destinations and become entries inside the Management hub — the
accepted tradeoff of the 3-tab structure.
