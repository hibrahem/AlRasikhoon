# Teacher navigation tabs — design

Bug: `al_rasikhoon-256`
Date: 2026-07-14

## Problem

The teacher bottom nav renders four items (`الطلاب` / `الحلقة` / `السجل` / `الإعدادات`,
`lib/shared/widgets/bottom_nav_bar.dart:82-104`) but the teacher `StatefulShellRoute` declares
exactly one `StatefulShellBranch` (`lib/routing/app_router.dart:341-400`). `RoleShell` guards tab
taps with `if (index >= branchCount) return;` (`lib/shared/widgets/role_shell.dart:28`), so taps on
indexes 1–3 are silently swallowed — no navigation, no error, no log.

The same mismatch is latent elsewhere: supervisor and student/guardian each render four nav items
over three branches, so `الإعدادات` is a dead button for them too. Only the superAdmin shell is
fully wired (4 items, 4 branches).

The root cause is that two lists — the nav items and the shell branches — are declared in different
files and are only expected to agree by convention. Nothing enforces it, and when they disagree the
failure is invisible.

## Scope

1. A guardrail that makes "a tab with no branch" impossible by construction.
2. `السجل` — the teacher's recitation history.
3. `الإعدادات` — a home for the account actions that currently have nowhere to live.

`الحلقة` is **dropped**, not built. See Decisions.

## Decisions

### الحلقة is dropped

The teacher works across multiple institutes, and the intuition was that `الحلقة` should be where a
teacher picks the institute they are teaching in, then sees that institute's students.

That flow already exists and is the `الطلاب` tab. `teacher_students_screen.dart:166-203` renders a
`المعهد` dropdown (`كل المعاهد` plus one entry per assigned institute), backed by
`teacherInstitutesProvider` and `filteredTeacherStudentsProvider` in
`lib/features/teacher/providers/teacher_provider.dart:23-58`. Building `الحلقة` as an institute
picker would duplicate a working screen.

With its only concrete job already done, `الحلقة` has no defined content. We do not build a tab we
cannot describe. Dropping it now forecloses nothing: the guardrail below means that the day a
branch is added for it, its tab appears automatically.

The teacher's nav becomes three tabs: `الطلاب` / `السجل` / `الإعدادات`.

### الإعدادات is shared across roles, not teacher-only

Supervisor and student/guardian also render a dead `الإعدادات` tab today. The settings screen we
need for the teacher is almost entirely role-agnostic (identity plus sign-out), so the same screen
is routed as the fourth branch of the supervisor and student shells as well. One screen fixes three
dead buttons.

superAdmin has no `الإعدادات` nav item and is left untouched; its logout stays in the AppBar.

### No language or theme toggle

`lib/app.dart:19` hardcodes `locale: const Locale('ar')` even though `en` is in `supportedLocales`,
and no `themeMode` is wired anywhere. A toggle would need locale to become stateful and persisted —
a separate feature. A switch that flips a hardcoded constant is a bug, not a setting.

No app-version footer either: `package_info_plus` is not a dependency, and a footer does not justify
adding one.

## The guardrail

Today the per-role nav items live in `bottom_nav_bar.dart` and the per-role branches live in
`app_router.dart`. Correctness depends on the two lists happening to line up, positionally, across
two files.

We replace the convention with a single source of truth. A `RoleDestinations` table declares, per
role, the ordered list of destinations — each destination carrying its icon, active icon, label, and
the route path that is its branch root:

```dart
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String rootPath; // the branch's initial location
}

List<NavDestination> destinationsFor(UserRole role);
```

- `AppBottomNavBar` renders exactly `destinationsFor(role)`.
- `RoleShell` asserts, in debug, that `destinationsFor(role).length ==
  navigationShell.route.branches.length`, and keeps the existing bounds check as a release-mode
  safety net.

The assertion turns the current silent swallow into a loud, immediate developer-facing failure. A
future contributor who adds a nav item without a branch (or a branch without a nav item) gets a
failing test and a debug crash on the first render, rather than a button that quietly does nothing
in production.

We keep the ordering contract explicit rather than deriving labels from the router: `go_router`'s
branches carry no display metadata, so the icon/label must live somewhere, and a single ordered
table per role is the smallest thing that keeps both sides honest.

## السجل — teacher recitation history

**Data.** No new data layer. `SessionRepository.getSessionRecordsForTeacher(teacherId, {startDate,
endDate, limit})` (`lib/data/repositories/session_repository.dart:106-136`) already returns the
teacher's `SessionRecordModel`s ordered by `date` descending.

**Provider.** A new `teacherHistoryProvider` in `teacher_provider.dart`:

- reads `currentUserProvider` for the teacher id;
- calls `getSessionRecordsForTeacher`;
- filters by `selectedTeacherInstituteFilterProvider` — the *same* provider the student list uses,
  so picking an institute scopes the student list and the history consistently. A filter that means
  different things on different tabs is its own future bug report.
- `SessionRecordModel` carries `studentId`, not a student name. Names are resolved by joining
  against `teacherStudentsProvider`, which the teacher already has loaded; that join is also what
  supplies each record's `instituteId` for the filter.

**Screen.** `lib/features/teacher/screens/teacher_history_screen.dart`, a `ConsumerWidget` mirroring
the structure of `lib/features/student/screens/session_history_screen.dart` (an `AsyncValue` list
with pull-to-refresh that invalidates the provider).

Each row shows student name, level and session number, pass/fail, and date. Tapping a row navigates
to that student's existing session overview (`AppRoutes.sessionOverview`) — the realistic reason a
teacher taps a history row is "take me to this student," and it reuses a screen that already exists
rather than adding a record-detail view.

States: loading spinner; error with retry; empty state when the teacher has recorded nothing (or
nothing within the selected institute).

## الإعدادات — account

`lib/features/settings/screens/settings_screen.dart`, a `ConsumerWidget`:

- **Profile header** — name, email/phone, and a role label, from `currentUserProvider`.
- **Institutes** — for a teacher, the institutes they are assigned to, from
  `teacherInstitutesProvider`. Omitted for other roles.
- **تسجيل الخروج** — `authRepositoryProvider.notifier.signOut()`, behind a confirmation dialog.

Logout **moves here** from the AppBar icon on `teacher_students_screen.dart:31-35`, which today fires
a destructive action in one tap, with no confirmation, from a routine screen. The AppBar icon is
removed for the teacher; the same move is made for supervisor and student where they carry one.

The screen lives in a new `lib/features/settings/` rather than under `features/teacher/`, because it
is routed into three role shells.

## Routing changes

`lib/routing/app_router.dart`:

- **Teacher shell** — add branch 1 (`السجل` → `AppRoutes.teacherHistory`, `/teacher/history`) and
  branch 2 (`الإعدادات` → `AppRoutes.teacherSettings`, `/teacher/settings`). Branch 0 (Students, with
  its nested session routes) is unchanged.
- **Supervisor shell** — add a fourth branch for `الإعدادات` (`/supervisor/settings`).
- **Student shell** — add a fourth branch for `الإعدادات` (`/student/settings`).

Each role gets its own settings path so that each shell branch has a distinct root location, as
`StatefulShellRoute` requires; all three build the same `SettingsScreen`.

## Testing

- **Guardrail (unit).** For every `UserRole`, assert `destinationsFor(role).length` equals the branch
  count of that role's shell route in the real router. This is the test that would have caught the
  original bug, and it fails today.
- **Guardrail (widget).** Tapping each nav index in a role shell changes
  `navigationShell.currentIndex` — i.e. no tab is inert.
- **السجل (widget).** Following `test/widget/session_history_listing_test.dart`: records render
  newest-first with student names resolved; selecting an institute filters the list; empty state
  renders when there are no records.
- **السجل (unit).** `teacherHistoryProvider` scopes to the current teacher and honours the institute
  filter.
- **الإعدادات (widget).** Profile fields render for the current user; sign-out is only invoked after
  the confirmation dialog is accepted.

## Out of scope

- Building `الحلقة` in any form, including a "today's circle" roster.
- Language, theme, or notification settings.
- A record-detail view for teacher history.
- superAdmin nav changes.
