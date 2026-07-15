# Al Rasikhoon — Manuscript UI Design (al_rasikhoon-5ss, pass 1)

Status: approved design, ready for implementation planning
Date: 2026-07-15
Branch: `worktree-al_rasikhoon-5ss-ui-overhaul`
Beads: al_rasikhoon-5ss

## Purpose

Give Al Rasikhoon (الراسخون — a Qur'an memorization / recitation tracker, Arabic-first,
RTL, `Cairo` font, Material 3) a distinctive, subject-grounded visual identity, replacing
the current templated Material defaults. The app must ship a **real** dark theme (today
`AppTheme.darkTheme` just returns `lightTheme`).

This spec covers **pass 1 only**: the design-token foundation, both themes, the shared
component library, and one full vertical slice — the **student** flow. The other four roles
(teacher, admin, supervisor, auth) inherit the token system but keep their screen-level
polish for follow-up child issues.

Chosen aesthetic direction: **A · Manuscript** — an illuminated Qur'anic manuscript. Warm
parchment and ink in light mode; an illuminated-manuscript-by-lamplight metaphor in dark
mode (deep warm ink-black surfaces where gold genuinely glows). Boldness is spent in a
single signature element; everything else stays quiet and disciplined.

## Constraints (non-negotiable)

- **Arabic-first, RTL** must stay correct on every screen and every new widget.
- `GoogleFonts.config.allowRuntimeFetching = false` (`lib/main.dart`). Any new font MUST be
  bundled into the `google_fonts/` asset directory (like the existing `Cairo-*.ttf`), never
  fetched at runtime.
- Follow project DDD / Clean Architecture: theme + widgets are **presentation layer only**.
- **No behavior/logic changes.** Providers, routing, domain, repositories untouched. This is
  a visual/UX layer pass.
- Quality floor: visible keyboard/focus states, reduced-motion respected, readable in both
  themes.

## Key existing-code fact that shapes the architecture

Screens and shared widgets currently reference `AppColors.*` **static constants directly**
(e.g. `AppColors.primary`), not the theme. Static constants cannot flip with brightness, so
a real dark theme requires routing every color that must adapt through the theme. This
migration (widgets read tokens instead of raw constants) is core work, not a side effect.

## Design tokens

### Color — light ("daylight manuscript / parchment")

| Role | Hex |
|---|---|
| Page (parchment) | `#F4EEE1` |
| Card / vellum | `#FBF7ED` |
| Surface variant | `#EDE4D2` |
| Ink (text primary) | `#1C2A24` |
| Sepia (text secondary) | `#6B5D46` |
| Heritage green (primary) | `#1B5E20` |
| Primary container | `#DCE9D8` |
| Illumination gold (accent) | `#C9A227` |
| Rubrication maroon (emphasis) | `#7A3B2E` |
| Hairline / border | `#E0D4BC` |

### Color — dark ("illuminated manuscript by lamplight")

A genuine dark theme, not a dimmed parchment.

| Role | Hex |
|---|---|
| Page (deep ink) | `#14110B` |
| Card | `#1E1A12` |
| Elevated surface | `#2A2318` |
| Warm parchment-white (text primary) | `#EDE4CE` |
| Aged sepia (text secondary) | `#B8A681` |
| Green (lightened) | `#8FBF7F` |
| Gold (glows) | `#E0B84A` |
| Maroon (lightened) | `#C98A6E` |
| Hairline / border | `#3A3222` |

Grade colors (راسخ · متقن · حافظ · مجتهد · محب) keep their semantic order (best→lowest),
retuned per mode so they read on parchment and on ink.

### Type

- **Body / UI:** `Cairo` (unchanged — already bundled, excellent RTL).
- **Display / headings:** `Amiri` (elegant Naskh, Qur'anic heritage, legible at heading
  sizes). Bundled into `google_fonts/`.
- **Hero wordmark only:** `Aref Ruqaa`, reserved for the single most decorative moment.
  Bundled into `google_fonts/`.
- **Numbers** (durations mm:ss, counts, grades): tabular/utility treatment for alignment.
- Intentional type scale with deliberate weights; display face used with restraint.

### Shape / elevation

- Cards `12px`, controls `8px`.
- Light mode elevation = hairline border + very soft shadow.
- Dark mode elevation = surface-step lightening (page → card → elevated), not shadow.
- One special **illuminated frame**: hairline gold inner border + subtle corner devices,
  reserved for the signature element.

### Motion

Gentle, ink-like, all tokenized durations, all gated on reduced-motion
(`MediaQuery.disableAnimations`):

- Soft fade + rise page transitions.
- Progress bars fill "like ink."
- Brief gold shimmer on grade award.

### Spacing

4 / 8 / 12 / 16 / 24 / 32 scale, exposed as tokens.

## Theme architecture

- New `AppTokens` **ThemeExtension** (`lib/core/theme/`) holding semantic, brightness-aware
  colors + spacing + radius + motion durations. Two instances: light and dark.
- `AppTheme` builds **both** `lightTheme` and a genuine `darkTheme` from the token sets.
- `AppColors` remains the raw palette source the tokens reference. Widgets stop reading raw
  constants for anything that must flip; they read
  `Theme.of(context).extension<AppTokens>()` and `colorScheme`.
- Theme mode **light / dark / system**, persisted, exposed via a Riverpod provider wired to
  `MaterialApp.themeMode`. Toggle added to the existing Settings screen.

## Signature element

**The Illuminated Juz Ring (حلقة الجزء).** A circular progress medallion rendered like a
manuscript *shamsa* (illumination roundel): gold hairline frame with small corner devices,
heritage green filling the ring as memorization advances, current juz + percent at center.
Custom-painted. Anchors the student dashboard hero; appears nowhere else.

**Mastery ladder** (secondary structural device): an honest 5-rung indicator of the grade
scale راسخ · متقن · حافظ · مجتهد · محب, used only where a grade genuinely sits on that scale.
Custom-painted; replaces the current `student_level_progress` / `level_progression_widget`
treatment.

These two are the only custom-painted pieces; everything else is retheming existing widgets.

## Shared component restyle (`lib/shared/widgets/`)

All read tokens so they flip light/dark:

- `app_card` — vellum surface + hairline; new `illuminated` variant for hero/signature.
- `app_button` — green primary, gold accent variant, outline; ink-appropriate pressed states.
- `stat_card` — quieter metric tiles (label + tabular number).
- `grade_display` — gold stars / grade chip in manuscript register.
- `progress_bar` — ink-fill animation.
- `student_level_progress` + `level_progression_widget` — become the mastery ladder.
- `bottom_nav_bar` + `nav_destinations` — gold selected indicator, themed surfaces.
- `role_shell` — scaffold wrapper adopts parchment/ink background per mode.
- `app_text_field`, `session_timer`, `session_record_row`, `error_counter`, `student_card`,
  `confirm_sign_out` — themed to tokens.

## Student slice (`lib/features/student/screens/`)

- `student_dashboard_screen` — Illuminated Juz Ring hero; Amiri greeting; quiet stat tiles;
  mastery ladder; restyled home-assignment card.
- `session_detail_screen` — recitation session in manuscript register; grade + error counter
  themed; timer / record rows use tokens.
- `session_history_screen` — past sessions as vellum rows with gold grade markers; tabular
  durations.
- `home_practice_screen` — practice logging themed to match.

## Empty / error / loading states

One shared set of state widgets, used across the student screens, with in-voice Arabic copy:

- Empty history is an invitation to record the first session, not an apology.
- Errors state what happened and how to retry; no raw exception strings.
- Loading uses a calm shimmer on vellum.

## Out of scope this pass (follow-up child issues under al_rasikhoon-5ss)

- Teacher screens (11), admin (12), supervisor (5), auth (2).
- Settings screen polish beyond adding the theme toggle.

These inherit the token system automatically but get screen-level polish later.

## Verification (definition of done)

- `flutter analyze` clean.
- `flutter test` — existing tests/widget tests pass (no regressions).
- Manual drive on a phone viewport: all 4 student screens in **light**, **dark**, and
  **Arabic RTL**, plus the theme toggle. Screenshots captured as evidence.
- Both themes render with no hardcoded-color leaks (nothing invisible in dark mode).

## Suggested implementation order

1. Bundle fonts (Amiri, Aref Ruqaa) into `google_fonts/`; update pubspec asset note.
2. `AppTokens` ThemeExtension + spacing/radius/motion tokens.
3. `AppTheme` light + real dark; theme-mode provider + persistence + `MaterialApp` wiring;
   Settings toggle.
4. Shared component restyle (retheme pass).
5. Custom paint: Illuminated Juz Ring + mastery ladder.
6. Shared empty/error/loading state widgets.
7. Student screens adopt everything.
8. Verify (analyze, test, manual light/dark/RTL drive + screenshots).
9. File follow-up child issues for the remaining roles.
