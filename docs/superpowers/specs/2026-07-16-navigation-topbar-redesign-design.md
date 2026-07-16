# Navigation & Top-Bar Redesign — Design Spec

- **Date:** 2026-07-16
- **Issue:** al_rasikhoon-759
- **Status:** Approved (design validated via visual companion)
- **Scope:** Navigation chrome only — bottom navigation + top bars. Screen *content* (cards, lists, forms) is out of scope.

## Problem

The app's navigation reads as dated and unprofessional:

1. **Green toolbar slab.** Every screen builds its own `AppBar`, globally themed with a solid dark-green background (`#1B5E20`) sitting on a warm parchment body. This "colored toolbar on cream page" is the single biggest visual problem — it's the Material 1 (2016) pattern.
2. **Flat stock bottom nav.** `BottomNavigationBar` (fixed) with no active indicator, generic outline icons. Looks like an unstyled default.
3. **A latent bug.** `AppBottomNavBar` sets the selected item color to `gold`, while the global `bottomNavigationBarTheme` sets it to `green` — the two contradict, so "selected" styling is ambiguous.
4. **No shared top-bar component.** 38 hand-rolled `AppBar`s across the app, each relying entirely on the global theme; no consistent slot for back button, title style, or actions.

The underlying architecture is sound: a token system (`AppTokens`), light + dark themes, a `RoleShell` + `go_router` `StatefulShellRoute` per role, and RTL Arabic throughout. This redesign changes only the *surface* of the nav and top bars.

## Chosen Direction — "A: Blended header + pill nav" (pure tabs)

One rule, stated once:

- **Bottom nav** = Material 3 `NavigationBar` with a green **pill** active indicator, **filled** icon when selected / outline when not, label beneath. Per-role tabs unchanged (2–4). **Pure tabs — no center action button** in any role.
- **Top bar** = **greeting header** on dashboard roots (student, guardian, supervisor, admin); **slim page-colored bar** (title + optional search/action) on list & detail screens.
- **No green toolbar anywhere.** Green stays the brand/primary for buttons, active states, and accents — just off the top bar.

Directions B (branded green hero + center FAB) and C (slim bar on every screen, wordmark) were considered and rejected: B reintroduces green on every detail screen; C is more consistent but keeps a persistent bar where the dashboards read better without one.

## Design Tokens Used

All from `AppTokens` (`context.tokens`), light/dark aware — no new colors introduced:

| Purpose | Token |
| --- | --- |
| Page / bar background | `page` (`#F4EEE1` / `#14110B`) |
| Nav bar surface | `card` (`#FBF7ED` / `#1E1A12`) |
| Active pill fill | `primaryContainer` (`#DCE9D8` / `#25341F`) |
| Active icon/label, back button, title | `green` (light `#1B5E20`) / `ink` for title text |
| Inactive icon/label | `sepia` |
| Hairline divider | `hairline` |
| Body/title text | `ink` |

Note the light-theme `green` (`#1B5E20`) has strong contrast on the pale `primaryContainer` pill; dark-theme `green` (`#8FBF7F`) on `primaryContainer` (`#25341F`) also passes. Title text uses `ink` for maximum legibility; active nav elements use `green`.

## Components

### 1. `AppNavBar` (rewrite of `lib/shared/widgets/bottom_nav_bar.dart`)

Replaces `BottomNavigationBar` with Material 3 `NavigationBar`.

- **Interface unchanged:** `AppNavBar({required int currentIndex, required ValueChanged<int> onTap, required UserRole role})`. `RoleShell` keeps calling it exactly as today. (Class may be renamed `AppNavBar`; `RoleShell` updated to match. The old name `AppBottomNavBar` is the only caller.)
- Renders one `NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.activeIcon), label: d.label)` per `destinationsFor(role)`.
- `selectedIndex: currentIndex`, `onDestinationSelected: onTap`.
- Styling comes from the shared `NavigationBarThemeData` (below), so the widget itself carries no per-instance colors. **This removes the gold-vs-green discrepancy** — one source of truth in the theme.
- `nav_destinations.dart` is unchanged (still the source of truth for tabs per role); its existing `icon` + `activeIcon` map cleanly to `icon` + `selectedIcon`.

### 2. `AppGreetingHeader` (new — `lib/shared/widgets/app_greeting_header.dart`)

A scrolling header widget placed at the top of each dashboard body (not an `AppBar`; no `appBar:` on dashboard scaffolds). It scrolls away with content — the modern "content-first" home.

```
AppGreetingHeader(
  greeting: 'السلام عليكم',        // small sepia eyebrow line (optional)
  title: 'محمد الأحمد',            // name or wordmark, ink, Amiri, bold
  trailing: <Widget>?,             // avatar + optional chip/action, right side (RTL)
)
```

- Layout: a `Row` — leading column (`greeting` eyebrow + `title`) on the start side, `trailing` on the end side. Standard `space16` padding.
- No background fill, no divider — it sits directly on `page`.
- Reused across student, guardian, supervisor, and admin dashboards with role-appropriate text/trailing.

### 3. `AppTopBar` (new — `lib/shared/widgets/app_top_bar.dart`)

A `PreferredSizeWidget` wrapping `AppBar`, for list & detail screens that want the consistent slim bar with actions. Usable directly as `appBar: AppTopBar(...)`.

```
AppTopBar({
  required String title,
  List<Widget>? actions,      // e.g. search, filter, overflow
  Widget? leading,            // defaults to the automatic back button
  bool showDivider = true,    // hairline under the bar
})
```

- Background `page` (blends with body), foreground `ink`, `elevation: 0`, `centerTitle: false` (start-aligned → right in RTL), Amiri title.
- Optional bottom hairline (`hairline`) via a 1px `PreferredSize` bottom.
- Because the **global `AppBarTheme` is also updated** (below), screens that keep a plain `AppBar(title: Text(...))` still render correctly (page-colored, ink foreground). `AppTopBar` is therefore an *opt-in consistency wrapper*, not a forced migration of all 38 call sites.

## Theme Changes — `lib/core/theme/app_theme.dart`

### `appBarTheme` (replaces the green version)

```
appBarTheme: AppBarTheme(
  elevation: 0,
  scrolledUnderElevation: 0,
  backgroundColor: t.page,          // was t.green
  foregroundColor: t.ink,           // was onGreen (white)
  surfaceTintColor: Colors.transparent,
  centerTitle: false,               // was true → start-aligned title
  titleTextStyle: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, color: t.ink),
  iconTheme: IconThemeData(color: t.ink),
)
```

This single change restyles **all 38 existing `AppBar`s at once** — no green slab anywhere, including screens not otherwise touched.

### Bottom nav theme

Remove `bottomNavigationBarTheme` (BottomNavigationBar is gone) and add:

```
navigationBarTheme: NavigationBarThemeData(
  backgroundColor: t.card,
  indicatorColor: t.primaryContainer,          // the pill
  elevation: 0,
  height: 72,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
    color: s.contains(WidgetState.selected) ? t.green : t.sepia)),
  labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
    color: s.contains(WidgetState.selected) ? t.green : t.sepia)),
)
```

## Screen-Level Changes

**Dashboard roots (3 files, guardian shares student):** remove `appBar:`, add `AppGreetingHeader` as the first child of the existing scrolling body.
- `student_dashboard_screen.dart` — greeting + student name; trailing avatar + streak chip. (Guardian variant already handled inside this screen.)
- `supervisor_dashboard_screen.dart` — "مشرف · <institute>" eyebrow + name; trailing avatar + pending-exams chip.
- `admin_dashboard_screen.dart` — "مدير النظام" eyebrow + "الراسخون" wordmark; trailing avatar.

**List & detail screens:** no per-file change is required for correctness — the theme update restyles them. Adopt `AppTopBar` opportunistically where a screen already has (or wants) actions/search, starting with the role list roots: `teacher_students_screen.dart` (add search field slot), `supervisor_students_screen.dart`, `session_history_screen.dart`. Screens with existing `actions:` (e.g. `ActiveLessonTimer`) keep them; verify those action widgets don't assume a white-on-green foreground.

**`RoleShell`:** update the widget name reference if `AppBottomNavBar` is renamed. No structural change.

## Risks & Mitigations

- **Action widgets assuming white foreground.** `ActiveLessonTimer` and a few `actions:` were built against a green bar. After the foreground flips to `ink`, verify they read correctly on the page-colored bar; fix any hardcoded white.
- **Two-tab NavigationBar balance.** Teacher has 2 tabs; `NavigationBar` centers fixed destinations and looks fine — confirm visually.
- **Dashboard scroll behavior.** Removing `appBar:` means no persistent bar on dashboards; the greeting scrolls away. This is intended. Ensure `SafeArea`/top padding so the header clears the status bar.
- **Dark mode.** Verify pill contrast and title legibility in dark theme (tokens already defined).

## Testing / Verification

- `flutter analyze` clean.
- Existing widget/golden tests pass; update any that assert on `BottomNavigationBar` or the green `AppBar`.
- Manual (or golden) check per role: dashboard header, a list screen, a detail screen, bottom nav active state — in **both** light and dark, RTL.

## Out of Scope

- Screen content redesign (cards, forms, list rows).
- Adding new destinations/tabs or changing per-role tab sets.
- Any center action / FAB (explicitly rejected — pure tabs).
- Routing changes.
