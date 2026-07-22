# Listing Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Arabic-normalized client-side search on six list screens (admin students/teachers/supervisors/institutes, teacher students, supervisor students).

**Architecture:** A pure-Dart normalization utility (`normalizeArabic` / `matchesSearch`) + a shared `AppSearchField` widget + one autoDispose Riverpod query provider per screen. Each screen filters its already-loaded list in memory inside its `data:` branch; a non-empty query with no matches shows a search-specific empty state.

**Tech Stack:** Flutter, Riverpod 3.x (`NotifierProvider.autoDispose`), flutter_test. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-22-listing-search-design.md`
**Beads issue:** al_rasikhoon-dql

## Global Constraints

- UI strings are hardcoded Arabic literals (match existing screens; do NOT add ARB keys).
- Search hint copy: people lists «بحث بالاسم أو الهاتف…», institutes «بحث بالاسم أو الموقع…».
- No-results empty state: icon `Icons.search_off`, title «لا توجد نتائج مطابقة للبحث».
- `lib/core/utils/arabic_search.dart` MUST have zero Flutter/Firebase imports (pure Dart).
- Riverpod 3 syntax: `class X extends Notifier<String>` + `NotifierProvider.autoDispose<X, String>(X.new)` (Riverpod 3 unified Notifier for autoDispose).
- Every commit message references `(al_rasikhoon-dql)` and ends with the Co-Authored-By line used in this repo.
- After each task: `flutter analyze` must report no new issues on touched files.

---

### Task 1: Arabic-normalized matching utility

**Files:**
- Create: `lib/core/utils/arabic_search.dart`
- Test: `test/unit/core/utils/arabic_search_test.dart`

**Interfaces:**
- Produces: `String normalizeArabic(String input)`, `bool matchesSearch(String query, Iterable<String?> fields)` — used by all screen tasks.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/core/utils/arabic_search_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/core/utils/arabic_search.dart';

void main() {
  group('normalizeArabic', () {
    test('folds hamza forms onto bare alef', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إبراهيم'), 'ابراهيم');
      expect(normalizeArabic('آمنة'), 'امنه');
      expect(normalizeArabic('ٱلرحمن'), 'الرحمن');
    });

    test('folds taa marbuta onto haa', () {
      expect(normalizeArabic('فاطمة'), 'فاطمه');
    });

    test('folds alef maqsura onto yaa', () {
      expect(normalizeArabic('هدى'), 'هدي');
      expect(normalizeArabic('مصطفى'), 'مصطفي');
    });

    test('strips diacritics and tatweel', () {
      expect(normalizeArabic('مُحَمَّد'), 'محمد');
      expect(normalizeArabic('محـــمد'), 'محمد');
    });

    test('lowercases Latin text', () {
      expect(normalizeArabic('Ahmad'), 'ahmad');
    });

    test('collapses and trims whitespace', () {
      expect(normalizeArabic('  عبد   الله '), 'عبد الله');
    });
  });

  group('matchesSearch', () {
    test('empty and blank queries match everything', () {
      expect(matchesSearch('', ['أحمد']), isTrue);
      expect(matchesSearch('   ', ['أحمد']), isTrue);
    });

    test('hamza-variant query matches stored spelling and vice versa', () {
      expect(matchesSearch('احمد', ['أحمد علي']), isTrue);
      expect(matchesSearch('أحمد', ['احمد علي']), isTrue);
      expect(matchesSearch('هدي', ['هدى']), isTrue);
    });

    test('matches a phone-digit substring', () {
      expect(matchesSearch('0501', ['أحمد', '0501234567']), isTrue);
    });

    test('matches Latin usernames case-insensitively', () {
      expect(matchesSearch('TEACH', ['teacher_1']), isTrue);
    });

    test('skips null fields', () {
      expect(matchesSearch('احمد', [null, 'أحمد']), isTrue);
      expect(matchesSearch('احمد', [null]), isFalse);
    });

    test('returns false when nothing matches', () {
      expect(matchesSearch('خالد', ['أحمد', '0501234567']), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/utils/arabic_search_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... arabic_search.dart` (file does not exist).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/utils/arabic_search.dart
/// Arabic-aware search normalization. Pure Dart — no Flutter/Firebase imports.
///
/// Users spell names inconsistently (أحمد/احمد, هدى/هدي, فاطمة/فاطمه, with or
/// without tashkeel), so both the query and the searched fields are folded
/// onto one canonical form before substring matching.
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    // Tashkeel (U+064B–U+065F), superscript alef (U+0670), tatweel (U+0640):
    // decoration, never identity — dropped entirely.
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        rune == 0x0640) {
      continue;
    }
    switch (rune) {
      case 0x0622: // آ
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0671: // ٱ
        buffer.write('ا');
      case 0x0629: // ة
        buffer.write('ه');
      case 0x0649: // ى
        buffer.write('ي');
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// True when any non-null field contains [query] after normalization.
/// A blank query matches everything (an empty search box hides nothing).
bool matchesSearch(String query, Iterable<String?> fields) {
  final normalizedQuery = normalizeArabic(query);
  if (normalizedQuery.isEmpty) return true;
  return fields.any(
    (field) => field != null && normalizeArabic(field).contains(normalizedQuery),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/core/utils/arabic_search_test.dart`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/arabic_search.dart test/unit/core/utils/arabic_search_test.dart
git commit -m "feat(search): Arabic-normalized matching utility (al_rasikhoon-dql)"
```

---

### Task 2: Shared AppSearchField widget

**Files:**
- Create: `lib/shared/widgets/app_search_field.dart`
- Test: `test/widget/app_search_field_test.dart`

**Interfaces:**
- Produces: `AppSearchField({Key? key, String hint = 'بحث بالاسم أو الهاتف…', required ValueChanged<String> onChanged})` — used by all screen tasks.

- [ ] **Step 1: Write the failing test**

```dart
// test/widget/app_search_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/shared/widgets/app_search_field.dart';

Future<void> _pump(WidgetTester tester, ValueChanged<String> onChanged) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AppSearchField(onChanged: onChanged)),
    ),
  );
}

void main() {
  testWidgets('typing reports the query through onChanged', (tester) async {
    final reported = <String>[];
    await _pump(tester, reported.add);

    await tester.enterText(find.byType(TextField), 'أحمد');

    expect(reported, ['أحمد']);
  });

  testWidgets('clear button appears only when non-empty and empties the field',
      (tester) async {
    final reported = <String>[];
    await _pump(tester, reported.add);

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), 'هدى');
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(reported, ['هدى', '']);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/app_search_field_test.dart`
Expected: FAIL — package import unresolved (widget file does not exist).

- [ ] **Step 3: Write the implementation**

```dart
// lib/shared/widgets/app_search_field.dart
import 'package:flutter/material.dart';

/// Search box for list screens. Owns its text state; reports every change
/// (including clearing) through [onChanged]. No debounce — filtering is
/// in-memory and cheap. RTL layout comes from the app-wide Directionality.
class AppSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AppSearchField({
    super.key,
    this.hint = 'بحث بالاسم أو الهاتف…',
    required this.onChanged,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild on every edit so the clear button tracks emptiness.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'مسح البحث',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/app_search_field_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_search_field.dart test/widget/app_search_field_test.dart
git commit -m "feat(search): shared AppSearchField widget (al_rasikhoon-dql)"
```

---

### Task 3: Query-provider class + supervisors screen (representative, TDD)

**Files:**
- Create: `lib/shared/providers/search_query_provider.dart`
- Modify: `lib/features/admin/providers/admin_provider.dart` (append at end)
- Modify: `lib/features/admin/screens/supervisors_screen.dart`
- Test: `test/widget/supervisors_screen_test.dart` (append tests)

**Interfaces:**
- Consumes: `matchesSearch` (Task 1), `AppSearchField` (Task 2).
- Produces: `class SearchQueryNotifier extends Notifier<String>` with `String build() => ''` and `void set(String query)`; providers in admin_provider.dart: `allStudentsSearchQueryProvider`, `allTeachersSearchQueryProvider`, `allSupervisorsSearchQueryProvider`, `institutesSearchQueryProvider` — each `NotifierProvider.autoDispose<SearchQueryNotifier, String>(SearchQueryNotifier.new)`. Tasks 4–5 rely on these exact names.

- [ ] **Step 1: Write the failing tests** — append to the end of `main()` in `test/widget/supervisors_screen_test.dart`, and add these imports at the top of the file:

```dart
import 'package:al_rasikhoon/shared/widgets/app_search_field.dart';
```

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/supervisors_screen_test.dart`
Expected: new tests FAIL (`AppSearchField` not found on screen); pre-existing tests still PASS.

- [ ] **Step 3: Create the shared notifier**

```dart
// lib/shared/providers/search_query_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Query text behind a list screen's [AppSearchField]. Each screen declares
/// its own `NotifierProvider.autoDispose<SearchQueryNotifier, String>` so
/// searches are independent and reset when the screen is left.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}
```

- [ ] **Step 4: Declare the four admin query providers** — append to the end of `lib/features/admin/providers/admin_provider.dart`, and add this import at the top:

```dart
import '../../../shared/providers/search_query_provider.dart';
```

```dart
/// Search queries for the admin list screens — one per screen so each list's
/// search is independent; autoDispose resets the query when the screen is
/// left.
final allStudentsSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

final allTeachersSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

final allSupervisorsSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

final institutesSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );
```

- [ ] **Step 5: Wire the supervisors screen** — in `lib/features/admin/screens/supervisors_screen.dart`:

Add imports:

```dart
import '../../../core/utils/arabic_search.dart';
import '../../../shared/widgets/app_search_field.dart';
```

Replace the whole `data: (supervisors) { ... }` callback body with:

```dart
              data: (supervisors) {
                if (supervisors.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'لا يوجد مشرفون',
                      message: 'اضغط على + لإضافة مشرف جديد',
                    ),
                  );
                }
                final query = ref.watch(allSupervisorsSearchQueryProvider);
                final filtered = supervisors
                    .where(
                      (supervisor) => matchesSearch(query, [
                        supervisor.name,
                        supervisor.phone,
                        supervisor.displayUsername,
                      ]),
                    )
                    .toList(growable: false);
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: AppSearchField(
                          onChanged: (value) => ref
                              .read(allSupervisorsSearchQueryProvider.notifier)
                              .set(value),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: EmptyState(
                            icon: Icons.search_off,
                            title: 'لا توجد نتائج مطابقة للبحث',
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final supervisor = filtered[index];
                            // ... existing AppCard row UNCHANGED, but reading
                            // from `filtered[index]` instead of
                            // `supervisors[index]` ...
                          },
                        ),
                      ),
                  ],
                );
              },
```

(The `itemBuilder` body — the `AppCard` with avatar, name, phone/username, active badge — is the existing code verbatim; only the list variable changes from `supervisors` to `filtered`.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widget/supervisors_screen_test.dart`
Expected: PASS (all, including the three pre-existing tests).

- [ ] **Step 7: Analyze and commit**

Run: `flutter analyze lib/shared/providers/search_query_provider.dart lib/features/admin/providers/admin_provider.dart lib/features/admin/screens/supervisors_screen.dart`
Expected: No issues found.

```bash
git add lib/shared/providers/search_query_provider.dart lib/features/admin/providers/admin_provider.dart lib/features/admin/screens/supervisors_screen.dart test/widget/supervisors_screen_test.dart
git commit -m "feat(search): search on supervisors list + shared query notifier (al_rasikhoon-dql)"
```

---

### Task 4: Remaining admin sliver screens (teachers, students, institutes)

**Files:**
- Modify: `lib/features/admin/screens/teachers_screen.dart`
- Modify: `lib/features/admin/screens/all_students_screen.dart`
- Modify: `lib/features/admin/screens/institutes_screen.dart`

**Interfaces:**
- Consumes: `matchesSearch`, `AppSearchField`, and the query providers from Task 3 (`allTeachersSearchQueryProvider`, `allStudentsSearchQueryProvider`, `institutesSearchQueryProvider`).
- Produces: nothing new.

Apply the exact Task 3 Step 5 transformation to each screen — same imports, same `SliverMainAxisGroup` structure, generic empty state unchanged when the collection itself is empty:

- [ ] **Step 1: Teachers screen** — provider `allTeachersSearchQueryProvider`; filter fields `[teacher.name, teacher.phone, teacher.displayUsername]`; default hint (omit `hint:`); `itemBuilder` reads `filtered[index]`.

- [ ] **Step 2: All-students screen** — provider `allStudentsSearchQueryProvider`; items are `StudentWithUser`, filter fields:

```dart
                final filtered = students
                    .where(
                      (s) => matchesSearch(query, [
                        s.user.name,
                        s.user.phone,
                        s.user.displayUsername,
                      ]),
                    )
                    .toList(growable: false);
```

- [ ] **Step 3: Institutes screen** — provider `institutesSearchQueryProvider`; filter fields `[institute.name, institute.location]`; pass the institutes hint:

```dart
                        child: AppSearchField(
                          hint: 'بحث بالاسم أو الموقع…',
                          onChanged: (value) => ref
                              .read(institutesSearchQueryProvider.notifier)
                              .set(value),
                        ),
```

(`_InstitutesScreenState` is a `ConsumerState`, so `ref` is available directly.)

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/admin/screens/` — Expected: No issues found.
Run: `flutter test test/widget/teachers_screen_overflow_test.dart test/widget/supervisors_screen_test.dart` — Expected: PASS (existing screen tests unbroken).

- [ ] **Step 5: Commit**

```bash
git add lib/features/admin/screens/teachers_screen.dart lib/features/admin/screens/all_students_screen.dart lib/features/admin/screens/institutes_screen.dart
git commit -m "feat(search): search on admin teachers/students/institutes lists (al_rasikhoon-dql)"
```

---

### Task 5: Teacher & supervisor student lists

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart` (append provider)
- Modify: `lib/features/teacher/screens/teacher_students_screen.dart`
- Modify: `lib/features/supervisor/providers/supervisor_provider.dart` (append provider)
- Modify: `lib/features/supervisor/screens/supervisor_students_screen.dart`

**Interfaces:**
- Consumes: `SearchQueryNotifier`, `matchesSearch`, `AppSearchField`.
- Produces: `teacherStudentsSearchQueryProvider`, `supervisorStudentsSearchQueryProvider` (same `NotifierProvider.autoDispose<SearchQueryNotifier, String>` shape as Task 3).

- [ ] **Step 1: Append providers.** In `teacher_provider.dart` (import `'../../../shared/providers/search_query_provider.dart'`):

```dart
/// Query text for the teacher's students search field. Composes with the
/// institute dropdown filter — both apply.
final teacherStudentsSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );
```

In `supervisor_provider.dart` (same import):

```dart
/// Query text for the supervisor's institute-students search field.
final supervisorStudentsSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );
```

- [ ] **Step 2: Supervisor students screen** — sliver screen; apply the exact Task 3 Step 5 transformation with provider `supervisorStudentsSearchQueryProvider` and `StudentWithUser` fields (`s.user.name`, `s.user.phone`, `s.user.displayUsername`). Generic empty branch (icon `Icons.school_outlined`, «لا يوجد طلاب») unchanged.

- [ ] **Step 3: Teacher students screen** (Column layout, not slivers). Add imports:

```dart
import '../../../core/utils/arabic_search.dart';
import '../../../shared/widgets/app_search_field.dart';
```

Insert a search field between the institute filter and the `Expanded`, shown only when the (institute-filtered) roster is non-empty:

```dart
          // Search — hidden while loading/erroring and when the roster is
          // empty (nothing to search). Composes with the institute filter.
          studentsAsync.maybeWhen(
            data: (students) => students.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: AppSearchField(
                      onChanged: (value) => ref
                          .read(teacherStudentsSearchQueryProvider.notifier)
                          .set(value),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
```

Inside the `Expanded`'s `data: (students)` branch, after the existing `students.isEmpty` early-return, filter and branch:

```dart
                final query = ref.watch(teacherStudentsSearchQueryProvider);
                final filtered = students
                    .where(
                      (s) => matchesSearch(query, [
                        s.user.name,
                        s.user.phone,
                        s.user.displayUsername,
                      ]),
                    )
                    .toList(growable: false);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'لا توجد نتائج مطابقة للبحث',
                  );
                }
```

…and the `ListView.builder` reads `filtered.length` / `filtered[index]`. The hero's roster count keeps reading the unfiltered `students` (search narrows the list, not the roster).

Note: `_TeacherStudentsScreenState` is a `ConsumerState`, so `ref` is in scope in both spots.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/features/teacher/ lib/features/supervisor/` — Expected: No issues found.
Run: `flutter test test/widget/` — Expected: PASS (no regressions in existing widget tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/teacher/providers/teacher_provider.dart lib/features/teacher/screens/teacher_students_screen.dart lib/features/supervisor/providers/supervisor_provider.dart lib/features/supervisor/screens/supervisor_students_screen.dart
git commit -m "feat(search): search on teacher and supervisor student lists (al_rasikhoon-dql)"
```

---

### Task 6: Delete dead searchUsers + changelog + full verification

**Files:**
- Modify: `lib/data/repositories/user_repository.dart` (delete `searchUsers`, lines ~256-279)
- Modify: `CHANGELOG.md` (top `## Unreleased` section)

- [ ] **Step 1: Delete the dead method.** Remove the entire `searchUsers` method (doc comment through closing brace) from `UserRepository`. It has no callers; its intent is superseded by `matchesSearch`.

- [ ] **Step 2: Changelog.** Add under the top `## Unreleased` section of `CHANGELOG.md`:

```markdown
- يمكن الآن البحث في قوائم الطلاب والمعلمين والمشرفين والمعاهد بالاسم أو رقم الهاتف — مع تجاهل الفروق الإملائية الشائعة (الهمزات والتشكيل).
```

(If the existing entries are in English, use instead: "Admins, teachers, and supervisors can now search the students, teachers, supervisors, and institutes lists by name or phone number — spelling variants like hamza forms and diacritics are matched automatically." Match whichever language the surrounding bullets use.)

- [ ] **Step 3: Full verification**

Run: `flutter analyze` — Expected: no new issues (compare against pre-change baseline if the repo has pre-existing infos).
Run: `flutter test test/unit test/widget` — Expected: ALL PASS.

- [ ] **Step 4: Commit and close the issue**

```bash
git add lib/data/repositories/user_repository.dart CHANGELOG.md
git commit -m "chore(search): drop dead UserRepository.searchUsers, changelog (al_rasikhoon-dql)"
bd close al_rasikhoon-dql
```
