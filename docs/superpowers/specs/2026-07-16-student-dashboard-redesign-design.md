# Student dashboard redesign — design

Date: 2026-07-16
Screen: `lib/features/student/screens/student_dashboard_screen.dart`

## Problem

The student dashboard stacks nine sections and shows the same figures in several
places. Concretely:

- **Completed levels** (`X/10`) appears three times — the progress-card gold
  badge, the level-progression grid header, and the `إحصائياتي` "المستويات" tile.
- **Current level** appears twice — the progress card title and the highlighted
  tile in the level grid.
- **Current juz** appears twice — the progress card subtitle and the current
  session card subtitle.
- **Home repetition** is split across two back-to-back cards with nearly
  identical Arabic titles: `واجب التكرار في المنزل` (the assignment) and
  `التكرار في المنزل` (today/streak/total counters).
- Two different progress axes — the sessions-within-level bar and the
  levels-completed grid — sit directly on top of each other, which is the main
  reason the screen reads as disorganized.

There is no single, motivating "how far through the Qur'an am I" figure. The
earlier Juz-ring hero was removed (commit `ab413a7`) because its math was wrong,
not because progress should not lead.

## Goal

Lead with a single, honest progress hero (progress/motivation is the screen's
primary job), remove every duplicated figure, and merge the two home-repetition
cards — while keeping the current session reachable and the manuscript visual
language intact.

## Non-goals

- No change to the underlying curriculum, advancement, or grading logic.
- No change to the teacher/supervisor/admin dashboards.
- No new backend fields or Firestore schema changes — every figure below is
  derivable from data the app already loads.

## The redesigned screen (top to bottom)

1. **Greeting** — one line, `مرحباً، {name}`. The generic subtitle
   (`تقدمك في حفظ القرآن الكريم`) is removed.

2. **Progress hero** — a single card (manuscript green wash, `tokens.green` @ 5%):
   - A ring whose **fill is the curriculum-completion fraction** (0..1, smooth),
     with the center label showing that as an integer **percent** (`٢٧٪`) over
     `من المنهج`.
   - A secondary caption line: `حفظت {juzMemorized} من ٣٠ جزءاً · تتقدّم في الجزء {currentJuz}`.
   - Three supporting stat chips: `المستوى {currentLevel}` ·
     `{streakDays} يوماً متتالية` · `{passedSessions} حلقة ناجحة`.

3. **Current session** — the existing `الحلقة الحالية` card, unchanged in its
   talqeen/exam/sard/lesson branching, titled `حلقتك الحالية · الحلقة {n}` with
   the session kind as a small badge. **The juz is shown here only** (removed
   from the hero). A primary `ابدأ الحلقة` action leads into the session.

4. **Home practice — one merged card** (replaces sections 5 and 6 of the old
   screen):
   - When an assignment is active: the assignment progress (`{done} / {required}`
     + capped bar, reusing `HomeAssignmentCard`'s existing display rules) *and* a
     caption of today/streak counters (`اليوم {todayRepetitions} تكرارات ·
     متتالية {streakDays} يوماً`).
   - When there is no active assignment: the card degrades to just the
     today/streak/total counters (the old home-practice card's content).
   - A single `سجّل تكراراً` action routes to `AppRoutes.homePractice`.

5. **Level journey — collapsed by default.** A row reading
   `رحلة المستويات · {completedLevels}/10 مكتمل` with a small status strip;
   expanding it reveals the full `LevelProgressionWidget` (the 10-tile grid +
   legend). **This is the only place completed-levels is shown.**

6. **إحصائياتي — collapsed by default.** Expands to the full stat set. The
   `المستويات` tile is removed (that figure now lives in the hero chip and the
   journey row); the remaining tiles (`الحلقات`, `الناجحة`, …) stay.

## De-duplication scorecard

| Data | Before | After |
|------|--------|-------|
| Completed levels | 3× | 1× (journey row) |
| Current level | 2× | 1× (hero chip) |
| Current juz | 2× | 1× (session card) |
| Home repetition | 2 cards | 1 merged card |

## The hero metric — honest derivation

Two figures, both derived from the **same curriculum position**, so they can
never disagree:

- **Curriculum percent** (ring fill + center label) =
  `sessionsCompleted / totalCurriculumSessions`.
- **Juz memorized** (secondary caption) = count of juz whose session block sits
  entirely behind the student's current position.

### Why the naive formulas are wrong

- `30 - currentJuz` is **incorrect**. `currentJuz` is the juz being *worked on*,
  not a completed one; the app teaches juz descending in levels 1–9 but
  **ascending in level 10** (juz 1→2→3, because سورة البقرة is memorized front to
  back); and flexibly-enrolled students have pre-enrollment juz credited without
  ever "completing" them in-app.
- `completedLevels.length * 3` **undercounts** flexibly-enrolled students, whose
  lower levels are credited as memorized but may not appear in `completedLevels`.

### The correct, position-based definitions

The catalog (`LevelModel` / `LevelJuz`) gives, per level, the three juz in
teaching order and each juz's `firstOrderInLevel` / `lastOrderInLevel` within the
level's continuous `1..sessionCount` ordering. Total curriculum sessions = the
sum of every level's `sessionCount` (955 today; **read from the catalog, never
hardcoded**).

```
sessionsCompleted =
    (sum of level.sessionCount for every level < currentLevel)
  + (currentOrderInLevel - 1)                     // sessions passed in the current level

curriculumPercent = curriculumCompleted ? 1.0
                  : sessionsCompleted / totalCurriculumSessions

juzMemorized =
    curriculumCompleted ? 30
  : (currentLevel - 1) * 3                         // every level below the frontier: 3 juz each
  + count(juz in currentLevel where juz.lastOrderInLevel < currentOrderInLevel)
```

Notes and invariants:

- Prior levels are all behind the frontier: a student cannot stand in
  `currentLevel` without every lower level being memorized (taught or credited),
  so `(currentLevel - 1) * 3` is exact given every level holds exactly three juz
  (catalog invariant).
- The current-level term is **direction-agnostic** — it counts juz whose session
  block is fully passed, so level 10's ascending juz are handled correctly.
- `curriculumCompleted == true` (graduated) short-circuits both figures to
  100% / 30 juz.
- While the catalog is still loading, or if it holds no entry for a level, the
  hero reports no progress rather than a fabricated denominator — the same rule
  `StudentLevelProgress` already follows.

### Where it lives

This is domain/application logic, not widget logic (the earlier ring failed by
computing in the widget). Add:

- A **domain service / pure function** — e.g.
  `CurriculumProgress.of(position, levels)` returning
  `{ sessionsCompleted, totalSessions, juzMemorized }` — that takes the student's
  position and the levels catalog and returns the derived figures. No Flutter,
  no Riverpod, fully unit-testable.
- New read-only fields on `StudentStats` (`curriculumPercent`, `juzMemorized`)
  or a small sibling provider that composes `studentStatsProvider` with
  `levelsProvider`. The widget only reads finished numbers.

## Data sources (all existing)

| Figure | Source |
|--------|--------|
| curriculum percent, juz memorized | new `CurriculumProgress` over `StudentStats` position + `levelsProvider` |
| current level, current juz | `studentStatsProvider` (`currentLevel`, `currentJuz`) |
| passed sessions | `studentStatsProvider.passedSessions` |
| streak, today, total reps | `homePracticeStatsProvider` |
| home assignment | `homeAssignmentProvider` |
| current session | `studentDashboardMeetingProvider` / `currentStudentProvider` |
| level journey | `studentStatsProvider` (`completedLevelsList`, `unlockedLevelsList`, `currentLevel`) |

## Visual language

Unchanged manuscript tokens (`context.tokens`): `green` for the hero/positive,
`gold` for milestone/current, `maroon` for the streak accent, `sepia` for
captions, `hairline` for dividers. Amiri wordmark in the AppBar via the shared
title style. RTL throughout. Light and dark both derive from `AppTokens`.

## Components

- **Rework** `StudentDashboardScreen` section order and content per the layout
  above. The guardian child-switcher stays at the very top, unchanged.
- **New** `ProgressHeroCard` widget — ring (curriculum percent) + juz caption +
  three stat chips. Ring fill is fractional; center label is
  `Math`-rounded percent.
- **New** `CurriculumProgress` domain service (pure) + its unit tests.
- **New** `HomePracticeCard` (merged) — folds `HomeAssignmentCard` and the old
  `_buildHomePracticeCard` into one card with the assignment-present /
  assignment-absent branches above. `HomeAssignmentCard`'s capped-count display
  rules are preserved.
- **New** collapsible wrappers for the level-journey row and the `إحصائياتي`
  block (expander pattern; both collapsed by default). `LevelProgressionWidget`
  is reused unchanged inside the expanded journey.
- **Remove** the old `_buildProgressCard` (level/juz/badge + in-level bar), the
  always-visible `LevelProgressionWidget` placement, the standalone
  `_buildHomePracticeCard`, and the always-visible `_buildQuickStats` placement.

## Error / loading / empty states

- Each async section keeps its existing `.when(loading/error)` treatment
  (`LoadingState` / `ErrorState`), so a failure in one section never blanks the
  screen.
- Hero while catalog loads: show the ring at zero / a `LoadingState`, never a
  guessed denominator.
- No active assignment: home-practice card shows counters only (no empty card,
  no duplicate).
- New student (0% / 0 juz): the percent ring still advances via
  `currentOrderInLevel`, so day one shows movement rather than a frozen zero.

## Testing

- **Domain (no mocks):** `CurriculumProgress` — new student (L1/J30/order 1) → 0
  juz, ~0%; mid-level; level boundary; graduated (`curriculumCompleted`) → 30 /
  100%; **level 10 ascending juz** counts correctly; flexibly-enrolled student
  (high `currentLevel`, empty `completedLevels`) counts lower levels as
  memorized; empty/loading catalog → zero, not a crash.
- **Widget:** hero renders percent + juz caption + three chips; the merged
  home-practice card renders both branches; journey/stats expanders toggle;
  no figure appears in two places (assert single occurrence of completed-levels
  and juz).

## Open decisions (resolved)

- Primary job of the screen: **progress/motivation**.
- Hero framing: **combined** — curriculum-percent headline, juz-memorized
  secondary, level/streak/passed chips.
- Journey grid + full stats: **collapsed by default.**
- New-student hero: **percent of curriculum** headline (smooth from day one),
  juz-memorized as the secondary line.
