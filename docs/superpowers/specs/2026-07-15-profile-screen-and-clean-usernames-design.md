# Profile screen + clean usernames — design

Date: 2026-07-15
Branch: `feat/profile-screen-analytics` (worktree off `main`)

## Problem

Three related gaps in the account experience:

1. The synthesized Firebase Auth email `<username>@alrasikhoon.local` leaks into the
   UI wherever a screen prints `user.email` — the profile card and the admin
   teacher lists show a fake-looking `.local` address instead of the real login
   name.
2. The account tab is labeled "الإعدادات" (Settings), but it is a profile screen,
   not a settings screen — it has no toggles to set (the app is locale-locked and
   has no theme mode). The label misdescribes it.
3. The profile screen shows only identity. It carries no sense of the person's
   activity — a teacher cannot see how many sessions they have run, a student
   cannot see their progress at a glance.

## Goals

- Never display the `@alrasikhoon.local` suffix anywhere user-facing.
- Rename the account tab and screen to "الملف الشخصي" (Profile) across all shells.
- Add a small, role-aware analytics block to the profile screen.

## Non-goals

- Renaming route paths / screen file names (`settings_*`). Churn with no
  user-facing value; only labels and the app-bar title change.
- Changing how usernames are stored or how the synthesized auth email is built at
  login/creation — that backend behavior is correct and untouched.
- Supervisor/admin analytics — not requested. Their profile screen keeps the
  profile card + sign-out only.
- Username-based search in `user_repository` — not user-facing, out of scope.

## Design

### 1. Strip `@alrasikhoon.local` app-wide

`UserModel` already carries a clean `username` field (the "user-visible login
identifier"). Add a domain-language getter that never exposes the synthesized
email:

```dart
/// The user-visible login name — never the synthesized auth email.
/// Prefers the stored username; falls back to stripping the synthesized
/// domain off legacy records written before the username field existed.
String get displayUsername => username.isNotEmpty
    ? username
    : email.endsWith('@${AppConstants.synthesizedEmailDomain}')
        ? email.split('@').first
        : email;
```

This lives on `UserModel` (`lib/data/models/user_model.dart`) and imports the
existing `AppConstants.synthesizedEmailDomain` from `core/constants`. It is a
domain-language accessor over domain data, consistent with the model's existing
framing of `username` as the login identifier.

Swap the display call sites that currently print raw `.email`:

| File | Current | New |
|------|---------|-----|
| `features/settings/screens/settings_screen.dart` (profile card) | `user.email.isNotEmpty ? user.email : (user.phone ?? '')` | show `user.phone` if set, else `user.displayUsername` |
| `features/admin/screens/teacher_detail_screen.dart:106` | `teacher.phone ?? teacher.email` | `teacher.phone ?? teacher.displayUsername` |
| `features/admin/screens/teachers_screen.dart:79` | `teacher.phone ?? teacher.email` | `teacher.phone ?? teacher.displayUsername` |
| `features/admin/screens/institute_detail_screen.dart:352,418` | `teacher.phone ?? teacher.email` | `teacher.phone ?? teacher.displayUsername` |

### 2. Rename "الإعدادات" → "الملف الشخصي" (all shells)

- `lib/shared/widgets/nav_destinations.dart` — the three account destinations
  (teacher, student/guardian, supervisor):
  - `label: 'الإعدادات'` → `label: 'الملف الشخصي'`
  - `icon: Icons.settings_outlined` → `Icons.person_outline`
  - `activeIcon: Icons.settings` → `Icons.person`
- `lib/features/settings/screens/settings_screen.dart` — `AppBar` title
  `'الإعدادات'` → `'الملف الشخصي'`.

Route names and file paths (`settings_*`, `AppRoutes.teacherSettings`, ...) are
unchanged.

### 3. Role-aware analytics block

A stats card rendered under the profile card in `SettingsScreen`, chosen by the
signed-in user's role.

#### Teacher

New data-layer count and an application-layer stats provider.

- `SessionRepository.getSessionCountForTeacher(String teacherId, {DateTime? startDate})`
  — Firestore aggregation `.count()` over `session_records` where
  `teacher_id == teacherId` and, if `startDate` given, `date >= startDate`.
  Reuses the existing `(teacher_id, date)` composite index that
  `getSessionRecordsForTeacher` already depends on. No new index.
- `TeacherStats { totalSessions, sessionsThisMonth, studentCount, instituteCount }`
  and `teacherStatsProvider` (in `features/teacher/providers/teacher_provider.dart`):
  - `totalSessions` = `getSessionCountForTeacher(id)`
  - `sessionsThisMonth` = `getSessionCountForTeacher(id, startDate: DateTime(now.year, now.month, 1))`
  - `studentCount` = length of `teacherStudentsProvider`
  - `instituteCount` = length of `teacherInstitutesProvider`

Displayed metrics: **إجمالي الجلسات** (total sessions), **جلسات هذا الشهر**
(sessions this month), **عدد الطلاب** (students), **عدد المعاهد** (institutes).

#### Student / guardian

Reuses the existing `studentStatsProvider` (which already resolves a guardian to
their selected/first child). No new query.

Displayed metrics: **إجمالي الجلسات** (total sessions), **نسبة النجاح** (pass
rate, from `passedSessions/totalSessions`), **المستويات المكتملة** (completed
levels), **المستوى الحالي** (current level — with juz as sublabel).

#### Presentation

- `_StatTile(icon, value, label)` — a compact tile: icon, large value, small
  label. Reused by both cards.
- `_TeacherStatsCard` / `_StudentStatsCard` — `ConsumerWidget`s that watch their
  provider and lay the tiles out in a `Wrap`/grid inside an `AppCard`. Each
  handles loading (spinner or shimmer-free placeholder) and the empty/zero case
  (show zeros rather than hiding — a new teacher with 0 sessions still sees the
  card).
- `SettingsScreen.build` selects the card by `user.role`:
  - `teacher` → `_TeacherStatsCard`
  - `student` / `guardian` → `_StudentStatsCard`
  - everything else → nothing.

## Layering (project DDD/Clean Architecture rules)

- `.count()` query → `SessionRepository` (data / infrastructure).
- `TeacherStats` value + provider → teacher feature providers (application
  orchestration; no business rules, just composition of repo + roster counts).
- Stat widgets and role selection → settings feature screen (presentation).
- `displayUsername` → `UserModel` domain-language getter.

No inner layer gains a dependency on an outer one.

## Testing

- **Domain/unit:** `UserModel.displayUsername` — returns username when present;
  strips the synthesized domain for a legacy record with empty username; returns
  a non-synthesized email untouched.
- **Application:** `teacherStatsProvider` composes counts and roster/institute
  lengths (repo + providers mocked/overridden).
- **Data:** `getSessionCountForTeacher` with and without `startDate` (fake
  Firestore).
- **Presentation:** `SettingsScreen` renders the teacher card for a teacher and
  the student card for a student, and shows the profile card's `displayUsername`
  rather than the `.local` email.

## Rollout

Single branch, no migration, no schema change, no new Firestore index.
