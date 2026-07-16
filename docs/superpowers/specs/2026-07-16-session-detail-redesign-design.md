# Session Detail Screen Redesign — Design

**Date:** 2026-07-16
**Screen:** `lib/features/student/screens/session_detail_screen.dart` (`تفاصيل الحلقة`)
**Status:** Approved design, pending implementation plan

## Problem

The student-facing session detail screen shows a session's result but is missing
information that already exists in the data, and uses ambiguous labels:

1. **Part cards omit the Qur'an content.** Each part (الحفظ الجديد / المراجعة
   القريبة / المراجعة البعيدة) shows only an error count and grade — never the
   ayah range that was recited.
2. **Session duration is never shown**, though it is recorded (`duration`).
3. **The "repeats" label is ambiguous.** The screen shows a single
   «التكرارات» row backed by `repetitionsWithTeacher`, while a second, distinct
   field — `homeRepetitionsRequired` (what the student owes at home) — is not
   shown at all. A reader cannot tell which repetition «التكرارات» means.
4. **"Attempt" (المحاولة) reads unclearly** — it is the retry number, but the
   bare label invites confusion with a count of recitations.
5. **The session pace is not shown** — whether the meeting was a normal,
   double, or triple portion (`paceAtTime`).
6. The overall layout can be tightened and made more legible.

The teacher comment (`notes`) already renders correctly and is **out of scope**.

## Data sources (no model changes required)

All fields already exist; this is a **presentation-only** change.

**From `SessionRecordModel`** (`lib/data/models/session_record_model.dart`),
loaded via `sessionRecordByIdProvider`:

| Concept | Field | Notes |
|---|---|---|
| Attempt/retry number | `attemptNumber` | integer, ≥ 1 |
| Pace | `paceAtTime` | 1 = normal, 2 = double, 3 = triple |
| Duration | `duration` (`Duration?`) | null on old / untimed records |
| Repetitions with teacher | `repetitionsWithTeacher` | in-session |
| Home repetitions required | `homeRepetitionsRequired` | assignment |
| Present parts | `presentParts` (`List<int>`) | which parts to render |
| Per-part errors | `grades.errorsForPart(part)` | |
| Pass/fail | `grades.passesForLevel(levelId)` | binary, unchanged |
| Session kind | `kind` / `isTalqeen` | talqeen has special treatment |
| Notes | `notes` | unchanged |

**From the curriculum `SessionModel`** (`lib/data/models/session_model.dart`),
loaded via `curriculumSessionByIdProvider(record.curriculumSessionId)` — already
watched today to resolve the title:

| Part | Content field | Rendered via |
|---|---|---|
| 1 (الحفظ الجديد) | `currentLevelContent` | `QuranContent.rangeAr` |
| 2 (المراجعة القريبة) | `recentReviewContent` | `QuranContent.rangeAr` |
| 3 (المراجعة البعيدة) | `distantReviewContent` | `QuranContent.rangeAr` |

Each content block is nullable and `QuranContent.rangeAr` returns `''` when empty.

## Design

The layout follows the "Refined cards + stat chips" direction (mockup in
`.superpowers/brainstorm/34139-1784172050/content/final-a.html`).

### 1. Header card
Book icon + session title (`session?.titleAr ?? record.curriculumSessionId`) +
formatted date. **No kind badge** for lessons — the title already carries
«الحلقة …». A تلقين keeps its existing distinct info banner (unchanged).

### 2. Stat chips
A wrapping 2-column chip grid replaces the two `_InfoRow`s. Each chip renders a
small label + bold value, and appears **only when it carries a value**:

| Chip label | Value | Visibility condition |
|---|---|---|
| `رقم المحاولة` | `attemptNumber` | always |
| `المقدار` | `2 → «ضعف الكمّ»`, `3 → «ثلاثة أضعاف»` | `paceAtTime > 1` |
| `المدة` | formatted duration | `duration != null` |
| `التكرار مع المعلم` | `repetitionsWithTeacher` | `> 0` |
| `التكرار المطلوب في البيت` | `«$n مرات»` | `homeRepetitionsRequired > 0` |

**Duration formatting** — Arabic unit words:
- `>= 1 minute` → `«$m د $s ث»` (e.g. «٧ د ١٢ ث»); omit the seconds segment when
  it is zero (e.g. «٧ د»).
- `< 1 minute` → `«$s ث»` (e.g. «٤٥ ث»).
- A dedicated formatter (e.g. `formatSessionDurationAr(Duration)`) placed with
  the existing duration domain code (`lib/domain/session/session_duration.dart`)
  or a UI helper, unit-tested independently.

For a تلقين (not graded, no attempt semantics), the `رقم المحاولة` chip is
omitted; the المقدار / المدة / التكرار chips still apply when their conditions
hold.

### 3. Overall result banner
Unchanged. «ناجح / راسب» from `grades.passesForLevel(record.levelId)`. Not shown
for a تلقين (existing behavior).

### 4. Part cards (`تفاصيل الأجزاء`)
For each `part in record.presentParts`, a card showing:
- Pass/fail dot/icon (existing `GradeCalculator.calculateForLevel` colour logic).
- Part title (`_partTitleAr(part)`).
- «`$errors أخطاء` · `gradeInfo.nameAr`».
- **New:** an ayah-range line (`rangeAr`) for that part's content, rendered
  **only when the range is non-empty**. The range is resolved from the
  curriculum `SessionModel` via a part→content mapping:
  `1 → currentLevelContent`, `2 → recentReviewContent`,
  `3 → distantReviewContent`.

If the curriculum `SessionModel` is not yet loaded or is missing, part cards
render exactly as today (no range line) — the range is additive and never
blocks.

### 5. Teacher comment
Unchanged. «ملاحظات المعلم» card shown when `notes` is non-empty.

## Constraints & known limitations

- **Presentation-only.** No changes to models, repositories, providers, or
  Firestore schema.
- **Ayah ranges depend on the curriculum `SessionModel`**, already fetched for
  the title. Absent/loading → range line simply omitted.
- **Batched sessions** (`coversSessionIds.length > 1`): only the resolved
  `curriculumSessionId`'s content is shown. Accepted as a known limitation for
  this change; not expanded here.
- **Pace at 1× is hidden**, so a normal-pace record shows no المقدار chip.

## Testing

- **Duration formatter** (unit): minutes+seconds, whole-minute (no seconds),
  sub-minute, and zero/edge inputs.
- **Widget tests** for `SessionDetailScreen` covering:
  - Pace chip hidden at 1×, «ضعف الكمّ» at 2×, «ثلاثة أضعاف» at 3×.
  - Duration chip hidden when `duration == null`, shown formatted otherwise.
  - Both repetition chips: hidden at 0, shown with correct labels/values.
  - Part card shows the ayah range when content is present, hides the line when
    the content is empty/absent.
  - No kind badge for a lesson; تلقين path unchanged (no banner, no attempt
    chip).
  - `رقم المحاولة` always present for a graded lesson.
- Reuse existing widget-test scaffolding for this screen where present.

## Out of scope

- Teacher comment write-side overwrite edge (`setNotes("")`) — the comment
  displays correctly; not part of this change.
- Per-part teacher comments (would require a new data field).
- Batched-session multi-range display.
