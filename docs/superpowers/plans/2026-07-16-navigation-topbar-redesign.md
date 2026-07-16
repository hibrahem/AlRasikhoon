# Navigation & Top-Bar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dated green-toolbar + stock bottom-nav chrome with a Material 3 `NavigationBar` (pill indicator), a scrolling greeting header on dashboards, and a page-colored top bar everywhere else — no green slab, pure tabs, all roles, RTL.

**Architecture:** One theme change flips every existing `AppBar` from green to page-colored (fixes 38 call sites at once). The bottom nav is rewritten to `NavigationBar` driven by the shared `navigationBarTheme`. Two new shared widgets — `AppGreetingHeader` (dashboards) and `AppTopBar` (list/detail) — provide the new top-bar surfaces. Per-role tabs and routing are unchanged.

**Tech Stack:** Flutter 3.35, Material 3, `google_fonts` (Amiri/Cairo), `AppTokens` ThemeExtension, `go_router` StatefulShellRoute, Riverpod.

## Global Constraints

- RTL-first: app is wrapped in `Directionality(TextDirection.rtl)`, locale `ar`. Titles start-aligned = right-aligned; back button on the right.
- Colors come only from `AppTokens` via `context.tokens` (or `t` inside `app_theme.dart`). No new hex colors, no hardcoded `Colors.white`/green.
- Fonts: Amiri for titles/headers, Cairo for labels/body — via `google_fonts`.
- Per-role tab sets in `nav_destinations.dart` are unchanged. No new tabs, no center action / FAB.
- Scope is nav + top-bar chrome only; do not restyle screen content (cards/lists/forms).
- Commit after each task. Run `flutter analyze` before each commit; it must be clean for touched files.

---

### Task 1: Theme — kill the green AppBar, add NavigationBar theme

**Files:**
- Modify: `lib/core/theme/app_theme.dart` (appBarTheme ~98-108; bottomNavigationBarTheme ~185-195)
- Test: `test/unit/core/app_theme_test.dart`

**Interfaces:**
- Produces: `AppTheme.lightTheme` / `AppTheme.darkTheme` whose `appBarTheme.backgroundColor == tokens.page`, `appBarTheme.foregroundColor == tokens.ink`, and which carry a `navigationBarTheme` and **no** `bottomNavigationBarTheme`.

- [ ] **Step 1: Write the failing test** — append to `test/unit/core/app_theme_test.dart`:

```dart
  testWidgets('AppBar theme is page-colored, not green', (tester) async {
    final t = AppTheme.lightTheme;
    final tokens = t.extension<AppTokens>()!;
    expect(t.appBarTheme.backgroundColor, tokens.page);
    expect(t.appBarTheme.foregroundColor, tokens.ink);
    expect(t.appBarTheme.elevation, 0);
    expect(t.appBarTheme.centerTitle, false);
  });

  testWidgets('NavigationBar theme is present with pill indicator', (tester) async {
    final t = AppTheme.lightTheme;
    final tokens = t.extension<AppTokens>()!;
    expect(t.navigationBarTheme.indicatorColor, tokens.primaryContainer);
    expect(t.navigationBarTheme.backgroundColor, tokens.card);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/core/app_theme_test.dart`
Expected: FAIL (backgroundColor is `green`, `navigationBarTheme` is null).

- [ ] **Step 3: Implement** — in `app_theme.dart`, replace the `appBarTheme:` block with:

```dart
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: t.page,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: t.ink),
        titleTextStyle: GoogleFonts.amiri(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: t.ink,
        ),
      ),
```

Then **delete** the `bottomNavigationBarTheme: BottomNavigationBarThemeData(...)` block and add in its place:

```dart
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.card,
        indicatorColor: t.primaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? t.green : t.sepia,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? t.green : t.sepia,
          ),
        ),
      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/core/app_theme_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart test/unit/core/app_theme_test.dart
git commit -m "feat(nav): page-colored AppBar theme + NavigationBar theme (al_rasikhoon-759)"
```

---

### Task 2: Rewrite bottom nav to Material 3 `NavigationBar`

**Files:**
- Modify: `lib/shared/widgets/bottom_nav_bar.dart`
- Modify: `lib/shared/widgets/role_shell.dart:66` (widget reference)
- Test: `test/widget/role_shell_navigation_test.dart` (should still pass unchanged — taps use label text)

**Interfaces:**
- Consumes: `destinationsFor(role)` from `nav_destinations.dart` (unchanged); `NavigationBarThemeData` from Task 1.
- Produces: `AppNavBar({required int currentIndex, required ValueChanged<int> onTap, required UserRole role})` rendering a `NavigationBar`.

- [ ] **Step 1: Implement** — replace the body of `lib/shared/widgets/bottom_nav_bar.dart` with:

```dart
import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import 'nav_destinations.dart';

/// Material 3 bottom navigation for a role. Styling (pill indicator, selected
/// colors) comes from `NavigationBarThemeData` in app_theme.dart — this widget
/// carries no per-instance colors, which is what keeps selected styling
/// consistent (previously gold here vs green in the theme).
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final UserRole role;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(role);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.activeIcon),
            label: destination.label,
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Update the caller** — in `lib/shared/widgets/role_shell.dart`, change `AppBottomNavBar(` (line ~66) to `AppNavBar(`. The import line `import 'bottom_nav_bar.dart';` stays.

- [ ] **Step 3: Run the navigation widget test**

Run: `flutter test test/widget/role_shell_navigation_test.dart`
Expected: PASS (NavigationBar shows labels via `alwaysShow`; the `find.text('الطلاب')` / `find.text('الملف الشخصي')` taps still resolve).

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/shared/widgets/bottom_nav_bar.dart lib/shared/widgets/role_shell.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/bottom_nav_bar.dart lib/shared/widgets/role_shell.dart
git commit -m "feat(nav): Material 3 NavigationBar with pill indicator (al_rasikhoon-759)"
```

---

### Task 3: `AppTopBar` shared widget (page-colored, opt-in)

**Files:**
- Create: `lib/shared/widgets/app_top_bar.dart`
- Test: `test/widget/app_top_bar_test.dart`

**Interfaces:**
- Produces: `AppTopBar({required String title, List<Widget>? actions, Widget? leading, bool showDivider = true})` implementing `PreferredSizeWidget`, usable as `appBar: AppTopBar(...)`.

- [ ] **Step 1: Write the failing test** — create `test/widget/app_top_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/shared/widgets/app_top_bar.dart';

void main() {
  testWidgets('AppTopBar renders title and actions on a page-colored bar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppTopBar(title: 'تفاصيل', actions: [Icon(Icons.search)]),
          body: SizedBox(),
        ),
      ),
    ));
    expect(find.text('تفاصيل'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/app_top_bar_test.dart`
Expected: FAIL ("Target of URI doesn't exist: app_top_bar.dart").

- [ ] **Step 3: Implement** — create `lib/shared/widgets/app_top_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Slim, page-colored top bar for list & detail screens. Blends into the body
/// (no green slab), start-aligned title, optional actions, optional hairline.
/// Inherits colors/typography from the global AppBarTheme; adds only the
/// hairline. Use directly: `appBar: AppTopBar(title: '...')`.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showDivider;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showDivider = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (showDivider ? 1 : 0));

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppBar(
      title: Text(title),
      leading: leading,
      actions: actions,
      bottom: showDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: tokens.hairline),
            )
          : null,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/app_top_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_top_bar.dart test/widget/app_top_bar_test.dart
git commit -m "feat(nav): AppTopBar shared page-colored top bar (al_rasikhoon-759)"
```

---

### Task 4: `AppGreetingHeader` shared widget (dashboards)

**Files:**
- Create: `lib/shared/widgets/app_greeting_header.dart`
- Test: `test/widget/app_greeting_header_test.dart`

**Interfaces:**
- Produces: `AppGreetingHeader({String? greeting, required String title, Widget? trailing})` — a plain widget (not an AppBar) placed as the first child of a dashboard's scrolling body.

- [ ] **Step 1: Write the failing test** — create `test/widget/app_greeting_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/shared/widgets/app_greeting_header.dart';

void main() {
  testWidgets('AppGreetingHeader shows greeting, title, trailing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AppGreetingHeader(
            greeting: 'السلام عليكم',
            title: 'محمد الأحمد',
            trailing: Icon(Icons.person),
          ),
        ),
      ),
    ));
    expect(find.text('السلام عليكم'), findsOneWidget);
    expect(find.text('محمد الأحمد'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/app_greeting_header_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Implement** — create `lib/shared/widgets/app_greeting_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_tokens.dart';

/// Scrolling greeting header for dashboard roots. Sits directly on the page
/// (no bar, no fill), scrolls away with content. Eyebrow `greeting` + bold
/// Amiri `title` on the start side; `trailing` (avatar / chip) on the end side.
class AppGreetingHeader extends StatelessWidget {
  final String? greeting;
  final String title;
  final Widget? trailing;

  const AppGreetingHeader({
    super.key,
    this.greeting,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (greeting != null)
                  Text(
                    greeting!,
                    style: GoogleFonts.cairo(fontSize: 12, color: tokens.sepia),
                  ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/app_greeting_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_greeting_header.dart test/widget/app_greeting_header_test.dart
git commit -m "feat(nav): AppGreetingHeader for dashboard roots (al_rasikhoon-759)"
```

---

### Task 5: Apply greeting header to the student dashboard

**Files:**
- Modify: `lib/features/student/screens/student_dashboard_screen.dart` (appBar ~37-46; body top ~64-77)

**Interfaces:**
- Consumes: `AppGreetingHeader` (Task 4). Uses existing `currentUserProvider` for name; existing streak/practice provider for the chip if readily available, else omit the chip.

- [ ] **Step 1: Remove the AppBar** — delete the `appBar: AppBar(title: const Text('الراسخون')),` (and its comment block) from the `Scaffold`. Keep `Scaffold(body: RefreshIndicator(...))`. Ensure the body's outer widget provides top safe-area (wrap the `SingleChildScrollView` in `SafeArea` if not already, or keep the existing padding and add `SafeArea`).

- [ ] **Step 2: Add the header as the first body child** — inside the existing `Column(children: [...])` (currently starting with the guardian switcher / greeting Text at ~70-77), replace the plain `Text('مرحباً، ${currentUser?.name ...}')` block with:

```dart
              AppGreetingHeader(
                greeting: 'السلام عليكم',
                title: currentUser?.name ?? 'الطالب',
                trailing: CircleAvatar(
                  radius: 18,
                  backgroundColor: context.tokens.primaryContainer,
                  child: Text(
                    (currentUser?.name ?? '؟').characters.first,
                    style: TextStyle(color: context.tokens.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
```

Add `import '../../../shared/widgets/app_greeting_header.dart';` and ensure `import '../../../core/theme/app_tokens.dart';` is present. Keep the `_GuardianChildSwitcher` above the header if guardian.

- [ ] **Step 3: Analyze + run student flow test**

Run: `flutter analyze lib/features/student/screens/student_dashboard_screen.dart && flutter test test/e2e/student_flow_test.dart`
Expected: No analyzer issues; student flow passes (or fails only where it asserted the old title — update that assertion to `find.text('الراسخون')` → the wordmark is gone; assert on the name greeting instead).

- [ ] **Step 4: Commit**

```bash
git add lib/features/student/screens/student_dashboard_screen.dart test/e2e/student_flow_test.dart
git commit -m "feat(student): greeting header on dashboard, drop green AppBar (al_rasikhoon-759)"
```

---

### Task 6: Apply greeting header to the supervisor dashboard

**Files:**
- Modify: `lib/features/supervisor/screens/supervisor_dashboard_screen.dart` (appBar ~28-33; body top)

**Interfaces:**
- Consumes: `AppGreetingHeader`. Uses `currentUserProvider` for the supervisor name; existing supervisor stats/exam-queue providers for the trailing chip if trivially available, else avatar only.

- [ ] **Step 1: Remove the AppBar** — delete `appBar: AppBar(... title: const Text('الراسخون - المشرف'))` and its comment.

- [ ] **Step 2: Add header** — as the first child of the dashboard `Column`, insert:

```dart
              AppGreetingHeader(
                greeting: 'مشرف',
                title: currentUser?.name ?? 'المشرف',
                trailing: CircleAvatar(
                  radius: 18,
                  backgroundColor: context.tokens.primaryContainer,
                  child: Text(
                    (currentUser?.name ?? '؟').characters.first,
                    style: TextStyle(color: context.tokens.green, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
```

Add the `app_greeting_header.dart` and `app_tokens.dart` imports; read `currentUser` from `ref.watch(currentUserProvider)` at the top of `build` if not already present. Wrap the scroll body in `SafeArea` for top inset.

- [ ] **Step 3: Analyze + supervisor flow test**

Run: `flutter analyze lib/features/supervisor/screens/supervisor_dashboard_screen.dart && flutter test test/e2e/supervisor_flow_test.dart`
Expected: clean; update any assertion on the old title.

- [ ] **Step 4: Commit**

```bash
git add lib/features/supervisor/screens/supervisor_dashboard_screen.dart test/e2e/supervisor_flow_test.dart
git commit -m "feat(supervisor): greeting header on dashboard, drop green AppBar (al_rasikhoon-759)"
```

---

### Task 7: Apply greeting header to the admin dashboard

**Files:**
- Modify: `lib/features/admin/screens/admin_dashboard_screen.dart` (appBar ~21; `_buildBody` ~26+)

**Interfaces:**
- Consumes: `AppGreetingHeader`. Wordmark title "الراسخون", eyebrow "مدير النظام".

- [ ] **Step 1: Remove the AppBar** — change `Scaffold(appBar: AppBar(title: const Text('الراسخون')), body: _buildBody(context, ref))` to `Scaffold(body: _buildBody(context, ref))`.

- [ ] **Step 2: Add header** — at the top of `_buildBody`'s scrolling `Column`, insert (wrap body in `SafeArea` for top inset):

```dart
        AppGreetingHeader(
          greeting: 'مدير النظام',
          title: 'الراسخون',
        ),
        const SizedBox(height: 16),
```

Add `import '../../../shared/widgets/app_greeting_header.dart';`.

- [ ] **Step 3: Analyze + admin flow test**

Run: `flutter analyze lib/features/admin/screens/admin_dashboard_screen.dart && flutter test test/e2e/admin_flow_test.dart`
Expected: clean; update any assertion on the old bar.

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin/screens/admin_dashboard_screen.dart test/e2e/admin_flow_test.dart
git commit -m "feat(admin): greeting header on dashboard, drop green AppBar (al_rasikhoon-759)"
```

---

### Task 8: Adopt `AppTopBar` on the teacher list root + audit action widgets

**Files:**
- Modify: `lib/features/teacher/screens/teacher_students_screen.dart:32`
- Audit (read, fix only if broken): `lib/features/teacher/screens/new_memorization_screen.dart:34`, `session_summary_screen.dart:58`, `talqeen_session_screen.dart:92` (all use `ActiveLessonTimer` as an AppBar action)

**Interfaces:**
- Consumes: `AppTopBar` (Task 3).

- [ ] **Step 1: Swap the teacher students AppBar** — change `appBar: AppBar(title: const Text('طلابي')),` to:

```dart
      appBar: const AppTopBar(title: 'طلابي'),
```

Add `import '../../../shared/widgets/app_top_bar.dart';`.

- [ ] **Step 2: Audit action widgets for white-on-green assumptions** — open each audited file and check whether `ActiveLessonTimer` (and any `actions:` children) sets an explicit light/white color that assumed the old green bar. If it uses `Theme.of(context)` / token colors or inherits, leave it. If it hardcodes `Colors.white`, change to `context.tokens.ink`. Record findings; most likely no change needed.

Run: `grep -n "Colors.white\|onGreen\|Color(0xFFFFFF" lib/shared/widgets/session_timer.dart lib/features/teacher/screens/new_memorization_screen.dart`

- [ ] **Step 3: Analyze + teacher flow test**

Run: `flutter analyze lib/features/teacher/screens/teacher_students_screen.dart && flutter test test/e2e/teacher_flow_test.dart`
Expected: clean; teacher flow passes.

- [ ] **Step 4: Commit**

```bash
git add lib/features/teacher/
git commit -m "feat(teacher): adopt AppTopBar on students list; audit bar actions (al_rasikhoon-759)"
```

---

### Task 9: Full verification pass (light + dark, all roles)

**Files:**
- Modify (only if a test asserted old chrome): any `test/**` file surfaced below.

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: No issues (or only pre-existing unrelated ones — do not fix unrelated warnings here).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All pass. If any test fails because it asserted `BottomNavigationBar`, the green `AppBar`, or an old dashboard title, update the assertion to the new widget (`NavigationBar`) / new header text, and re-run. Do not weaken a test to pass — update it to assert the new, correct chrome.

- [ ] **Step 3: Launch the app and verify visually** — use the `run` skill (or `flutter run`) to drive one screen per role in **both** light and dark, RTL:
  - Dashboard greeting header renders, no green bar, header scrolls away.
  - Bottom nav shows the pill on the active tab; tapping swaps tabs and keeps the pill.
  - A detail screen (e.g. `تفاصيل الحلقة`) shows the page-colored bar with back button on the right and readable ink title.
  - Teacher 2-tab nav looks balanced.
  Capture a screenshot of the student dashboard (light) and a detail screen (dark) as proof.

- [ ] **Step 4: Commit any test updates**

```bash
git add test/
git commit -m "test(nav): update assertions for NavigationBar + page-colored bars (al_rasikhoon-759)"
```

---

## Self-Review

**Spec coverage:** ① NavigationBar + pill → Tasks 1–2. ② Greeting header on dashboards → Tasks 4–7. ③ Slim page-colored top bar → Tasks 1 (theme, all 38) + 3 + 8. ④ No green anywhere → Task 1. ⑤ Gold/green discrepancy fix → Task 2 (removed per-instance colors). ⑥ Two shared widgets → Tasks 3–4. ⑦ Dark mode + RTL + verification → Task 9. All spec sections covered.

**Placeholder scan:** No TBD/TODO; every code step shows full code; audit step (Task 8.2) is a concrete grep with a decision rule, not a vague "handle edge cases."

**Type consistency:** `AppNavBar(currentIndex/onTap/role)`, `AppTopBar(title/actions/leading/showDivider)`, `AppGreetingHeader(greeting/title/trailing)` used identically across tasks. `context.tokens` accessor used consistently. `destinationsFor(role)` unchanged.
