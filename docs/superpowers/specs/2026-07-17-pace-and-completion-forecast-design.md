# Design: Pace up to 10× + Quran Completion Forecast (متى الختم؟)

**Issue:** al_rasikhoon-yhq · **Date:** 2026-07-17

## Goal

1. Teachers/supervisors can set a student's memorization pace anywhere from 1× to 10× (today: three segmented buttons, 1–3), with a UI that scales — no row of ten buttons.
2. Every role (student, teacher, supervisor, guardian, admin) can see **how long it takes to finish the whole Quran** at a chosen pace × meetings-per-week, as an interactive what-if calculator.
3. The student's home dashboard shows the remaining time to الختم based on **their own configured** pace and meetings-per-week.

## Part 1 — Pace 1×..10×

**Domain** — `CurriculumPace` gains `maxMultiplier = 10`; the constructor and
`fromJson` reject anything above it (same posture as the existing `< 1` guard:
a stored 99 is corruption and must surface). All stored values today are 1–3,
so no migration.

**UI** — `StudentPaceControl` replaces the `SegmentedButton` with a discrete
`Slider` (min 1, max 10, 9 divisions) beside a prominent `N×` value badge.
The write fires on `onChangeEnd` (drag release), not every tick; the widget
holds an optimistic local value while dragging and reverts on failure with the
existing snackbar. Microcopy stays: "عدد الحلقات في اللقاء الواحد". Hosts
(teacher profile, supervisor students sheet, supervisor progress screen via
router injection) are unchanged — same widget contract.

## Part 2 — Meetings per week (اللقاءات في الأسبوع)

There is no schedule concept in the app today, but the forecast on the student
home needs a per-student cadence. New value object `MeetingsPerWeek`
(1..7, `standard = 2`, absence in Firestore → standard, same pattern as
`CurriculumPace`). Stored on the student doc as `meetings_per_week`; a stepper
(− / +) in the same `StudentPaceControl` card sets it — the card becomes the
student's **خطة الحفظ** (pace + cadence). Repository:
`setStudentMeetingsPerWeek`. Firestore rules are role-scoped, not
field-whitelisted — no rule change needed.

## Part 3 — Completion forecast

### Domain (`lib/domain/curriculum/completion_forecast.dart`)

Meetings-to-finish is NOT `ceil(remainingRows / pace)`: only **lessons** batch;
a تلقين/سرد/اختبار always stands alone, batches never cross a level boundary,
and `PacedSessionComposer._batch` also breaks at holes in `order_in_level`.

- **`RemainingCurriculum`** — a run-length encoding of everything ahead of the
  student: `standaloneCount` (تلقين/سرد/اختبار rows remaining) +
  `lessonRuns` (lengths of maximal runs of *consecutive-by-order* lessons,
  computed per level so runs never span levels).
  Factory takes the levels catalog + per-level ordered `SessionModel` lists +
  the student position (`currentLevel`, `currentOrderInLevel`,
  `curriculumCompleted`).
  `meetingsAtPace(pace) = standaloneCount + Σ ceil(run / pace)`. Exact replay
  of the composer's batching, O(runs) per evaluation — so the what-if slider
  recomputes instantly with no refetch.
- **`CompletionForecast`** — `remainingMeetings` + `MeetingsPerWeek` →
  `weeks = ceil(remaining / perWeek)`; `completionDate(from)` adds
  `weeks × 7` days. Pure; the caller supplies "today".

### Provider (`lib/shared/providers/completion_forecast_provider.dart`)

`remainingCurriculumProvider` — family keyed by a record
`({int level, int order, bool completed})` (records give structural equality).
Watches `levelsProvider` plus `levelSessionsProvider(n)` for each remaining
level; Riverpod caches per level, so the worst case (a level-1 student, ~955
docs) is fetched once per app session and reused by every host and every
slider tick.

### UI (`lib/shared/widgets/completion_forecast_card.dart`)

One shared card, all roles:

- **Headline** (student's actual config): "المتوقع ختم القرآن خلال سنة
  و٣ أشهر تقريبًا" + expected Gregorian date (intl `ar`) + remaining meetings
  count.
- **Expandable simulator** ("جرّب وتيرة أخرى"): local pace slider (1..10) +
  meetings/week stepper (1..7), initialised from the student's config, purely
  local state — changing them **never writes**; a caption says so. Result line
  updates live.
- States: curriculum completed → celebration line; catalog loading → skeleton;
  zero remaining handled.

Duration copy: weeks → "X سنة وY شهر (~N أسبوعًا)" via a small Arabic
formatter (`forecast_copy.dart` beside `assessment_copy.dart`), with proper
dual/plural forms (أسبوع/أسبوعان/أسابيع…).

### Hosts

| Surface | Role(s) | Placement |
|---|---|---|
| `StudentProgressScreen` (shared) | admin, supervisor | rendered by the screen itself (role-agnostic, read-only) |
| `StudentProfileScreen` (teacher) | teacher | below `StudentPaceControl` |
| `StudentDashboardScreen` | student, guardian | card in the dashboard column |

## Testing

- Domain: `completion_forecast_test.dart` — run encoding (breaks at
  non-lessons, level bounds, order holes; mid-level position; enrollment-credit
  irrelevant since position already encodes it), `meetingsAtPace` vs a
  brute-force `_batch` replay on synthetic levels, forecast weeks/date math.
  `meetings_per_week_test.dart`, `curriculum_pace_test.dart` max-bound cases.
- Widget: updated `student_pace_control_test.dart` (slider), forecast card
  rendering (headline, simulator recompute, no-write guarantee).

## Alternatives considered

- **Precomputed per-level meeting-count tables on level docs** (import-time):
  avoids fetching sessions but adds import tooling + drift risk for deployed
  data, and the current level still needs its session list for mid-level
  positions. Rejected — fetch-and-cache is simpler and exact.
- **Deriving cadence from history** (records carry dates): clever but opaque
  and unstable for new/irregular students. Rejected in favour of an explicit
  stored config (matches the request: "based on his configuration").
- **Stepper-only pace UI**: precise but 1→10 needs 9 taps. Slider with 10
  detents + big value badge is one gesture and reads instantly.
