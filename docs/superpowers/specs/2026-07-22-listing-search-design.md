# Listing Search — Design

**Date:** 2026-07-22
**Status:** Approved

## Goal

Let admins, teachers, and supervisors find a person or institute quickly by
typing into a search field on any list screen. Matching is Arabic-aware so
spelling variants (hamza forms, taa marbuta, alef maqsura, diacritics) never
hide a result.

## Scope

Six list screens get a search field:

| Screen | File | Matched fields |
|---|---|---|
| Admin: all students | `lib/features/admin/screens/all_students_screen.dart` | `user.name`, `user.phone`, `user.displayUsername` |
| Admin: teachers | `lib/features/admin/screens/teachers_screen.dart` | same |
| Admin: supervisors | `lib/features/admin/screens/supervisors_screen.dart` | same |
| Admin: institutes | `lib/features/admin/screens/institutes_screen.dart` | `name`, `location` |
| Teacher: my students | `lib/features/teacher/screens/teacher_students_screen.dart` | same as students |
| Supervisor: students | `lib/features/supervisor/screens/supervisor_students_screen.dart` | same as students |

Out of scope: server-side search (Firestore prefix queries, Algolia),
pagination, searching any other screens. Lists already load their full
collections into memory, so filtering is client-side.

## Approach

In-memory filtering per screen (mirrors the existing
`selectedTeacherInstituteFilterProvider` dropdown-filter pattern in
`lib/features/teacher/providers/teacher_provider.dart`). No Firestore or
repository changes.

### 1. Arabic-normalized matching utility

`lib/core/utils/arabic_search.dart` — pure Dart, no Flutter/Firebase imports.

- `String normalizeArabic(String input)`
  - lowercases (for Latin usernames/phones)
  - strips Arabic diacritics (tashkeel) and tatweel
  - folds hamza forms: `أ إ آ ٱ` → `ا`
  - folds taa marbuta: `ة` → `ه`
  - folds alef maqsura: `ى` → `ي`
  - collapses/trims whitespace
- `bool matchesSearch(String query, Iterable<String?> fields)`
  - normalizes the query once
  - empty/blank query → `true`
  - `true` if any non-null field's normalized form contains the normalized
    query (substring match)

### 2. Shared search field widget

`lib/shared/widgets/app_search_field.dart` — a styled `TextField` consistent
with `AppTextField`:

- search icon prefix, clear (✕) suffix shown only when non-empty
- Arabic hint, default «بحث بالاسم أو الهاتف…», overridable per screen
  (institutes use «بحث بالاسم أو الموقع…»)
- `onChanged(String)` callback; no debounce (filtering is cheap and local)
- RTL comes free from the app-wide `Directionality`

### 3. Per-screen wiring

Each screen gets an autoDispose query provider
(`NotifierProvider.autoDispose<…, String>`), so the query resets when the
screen is left. The search field renders under the `AppLargeTopBar` sliver.
The already-loaded list is filtered with `matchesSearch` before building rows.

On the teacher's students screen, search composes with the existing institute
dropdown filter — both apply (AND).

### 4. Empty-results state

When a non-empty query yields no rows, show the existing `EmptyState` widget
with «لا توجد نتائج مطابقة للبحث» instead of the generic empty message, so the
list doesn't look empty when it isn't.

### 5. Cleanup

Delete the dead `UserRepository.searchUsers()` method
(`lib/data/repositories/user_repository.dart`) — unused, superseded by the
normalized client-side matcher.

## Testing

- **Unit** (`test/core/utils/arabic_search_test.dart`): hamza-variant match
  (`احمد` ↔ `أحمد`), alef-maqsura (`هدى` ↔ `هدي`), taa marbuta, diacritics
  stripped, phone-digit substring, Latin case-insensitivity, empty query
  matches, non-match returns false, null fields skipped.
- **Widget** (`test/shared/widgets/app_search_field_test.dart`): typing fires
  `onChanged`; clear button appears when non-empty and empties the field.
- **Screen-level widget test** (one representative screen): typing a query
  filters visible rows; a no-match query shows the search empty state.

## Changelog

Add a stakeholder bullet to `CHANGELOG.md` under `## Unreleased`: admins,
teachers, and supervisors can now search the students, teachers, supervisors,
and institutes lists by name or phone number.
