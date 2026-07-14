# Paced curriculum (NX): letting a fast memorizer run at 2x, 3x, or N×

**Date:** 2026-07-14
**Status:** Approved, not yet implemented

## The problem

The curriculum is authored for the average student: one meeting, one session. A
gifted student who memorizes quickly is held to that pace and wastes his talent.
The teacher wants to give such a student double (2x), triple (3x), or N× the
content, with the teacher's agreement.

Doubling the **new** memorization is obvious. The question this spec answers is
what happens to the **recent review** (المراجعة القريبة) and the **distant
review** (المراجعة البعيدة) — do they change, and can they be computed?

## What the curriculum data actually says

Every session row carries three content blocks: `current_level_content` (new),
`recent_review_content`, and `distant_review_content`. They are authored, not
computed. But they are not arbitrary — each follows a rule, and the two review
streams follow **completely different** rules.

### Recent review is a sliding window

`recent(K) = new(K-2) ∪ new(K-1)` — the previous two sessions' new content.

Verified mechanically across all ten levels: of the 672 sessions carrying a recent
block, **659 match this exactly**. The 13 that do not are **noise in the source
spreadsheet**, not structural exceptions:

| | count | example |
|---|---|---|
| surah-name typos (match once whitespace/spelling is normalized) | 5 | `المعار ج` with a stray space; `النكبوت` for `العنكبوت` |
| duplicated lesson rows in the source | 2 | L5 order 32: `new(K-2) == new(K-1)` |
| genuine ±1 verse drift in the source | 6 | L3 order 9: authored recent starts فصلت 48, `new(K-2)` starts فصلت 47 |
| unit resets | **0** | — |

This matters for the design: because ~8 rows of the source disagree with its own
rule, a composed block would **not** equal the authored block on those rows. See
[At N=1, do not compose](#at-n1-do-not-compose).

Level 1, orders 3-6:

| order | new | recent |
|---|---|---|
| 3 | النبأ 12-20 | النبأ 1-11 |
| 4 | النبأ 21-30 | النبأ 1-20 |
| 5 | النبأ 31-37 | النبأ 12-30 |
| 6 | النبأ 38-40 | النبأ 21-37 |

`recent(5)` = النبأ 12-30 = `new(3)` (12-20) ∪ `new(4)` (21-30).

### Distant review is a cursor, not a window

Distant review sweeps **contiguously through everything already memorized**, one
non-overlapping chunk per session, in mushaf order. It has nothing to do with the
session's current content.

In level 1 it begins at order 73 — once the student leaves juz 30 — and walks the
whole of juz 30 (النبأ 1 → الناس 6) a chunk at a time. In level 2 it begins at
order 2 and sweeps everything level 1 taught (juz 28 → 29 → 30). Level 2's distant
blocks are 0-for-117 against level 2's own content: it is reviewing earlier levels.

## Why naive concatenation is wrong

The tempting implementation — "a 2x meeting is just two rows glued together" —
produces **incorrect recent review**.

Take a 2x meeting batching sessions {5, 6}. The union of their authored recent
blocks is النبأ 12-37, which contains النبأ 31-37 — that is session 5's **new**
content, memorized thirty minutes earlier in the same meeting. The student would
be asked to "review" a passage he has not slept on, let alone practised at home.
The blocks also overlap: `recent(5)` and `recent(6)` share `new(4)`.

Distant has neither problem. Its chunks are non-overlapping and independent of
today's content, so they concatenate cleanly.

## The NX rule

For a meeting batching N lessons starting at `orderInLevel = K`:

| stream | rule |
|---|---|
| **new** | ∪ `current_level_content` of the N batched lessons |
| **distant** | ∪ `distant_review_content` of the N batched lessons |
| **recent** | ∪ `current_level_content` of sessions `[K-2N, K-1]` — the previous **two meetings'** new content — clamped at the unit boundary and excluding any session whose new content this meeting is itself teaching |

All three streams double at 2x: the student memorizes two sessions' new content,
reviews four sessions' worth as recent, and sweeps two distant chunks. The whole
meeting is genuinely 2x, not just the new part.

**Nothing is invented.** No Qur'an range is computed, chunked, or re-derived. Every
range in a composed meeting is a range the source curriculum already states; the
rule only decides *which rows' blocks a meeting draws from*. This preserves the
codebase's standing rule that the app never authors curriculum content — the same
reason `titleAr` returns the source's verbatim label rather than rebuilding
`'سرد الحزب $hizb'` from numbers.

### At N=1, do not compose

**A pace of 1 reads the session's authored blocks verbatim. Composition runs only
when N > 1.**

The tempting alternative — "composition is a strict generalization, so just always
compose" — is *wrong on this data*. Because ~8 source rows disagree with the
source's own rule (see the table above), always-composing would silently rewrite
those 8 rows for every 1x student in the system: a stray-space surah name would be
corrected, a ±1 verse boundary would shift. That is the app authoring curriculum
content, which is precisely what this codebase forbids.

So the guarantee for a 1x student is **structural, not statistical**: their content
is untouched because the composition code never runs for them, not because a rule
happens to hold for 98.8% of rows.

The 659/672 figure is therefore *evidence that the window rule is the right
generalization to N > 1* — it is not an invariant the implementation leans on.

Pin it with a test: `compose(startOrder: K, pace: 1)` returns exactly the blocks of
the row at K, for every session of every level, by construction.

### Reproducing the unit reset

A lesson at the start of a unit carries **no recent block at all** — level 1's
order 34 is a lesson with `recent: —`. You cannot review what you are learning
right now: the تلقين at order 33 taught the very same passage the lesson at 34 is
teaching.

Composition must reproduce this. The recent window therefore excludes:

1. sessions with no new content (a سرد or an اختبار contributes nothing);
2. sessions before the تلقين that opens the current unit — the window never
   reaches back into the previous unit. At N=1 the سرد/اختبار pair naturally
   blocks the window, but at N≥3 it would otherwise reach past them;
3. **sessions whose new content is already part of this meeting's own new
   content** — this is what zeroes the recent block for the unit's first lesson,
   whose window would otherwise pull in the تلقين's duplicate of its own passage.

## Batching rules

> **Only lessons batch.** A تلقين, a سرد, and an اختبار is each always its own
> meeting, at any pace.

A batch takes up to N consecutive lessons and never crosses a تلقين, an
assessment, a unit boundary, or a level boundary. A short final batch of fewer
than N is normal and correct.

A 2x student's unit therefore runs:

```
{talqeen}  {lesson,lesson}  {lesson,lesson}  …  {sard}  {exam}
```

He reaches the سرد in half the meetings. The سرد itself is unchanged — its scope
was always the whole unit, so pace does not touch it. The same holds for the
اختبار.

## Data model

### The pace lives on the student

A `CurriculumPace` value object in the domain: immutable, validates `N >= 1`,
defaults to 1. Stored on `StudentModel` beside `enrollmentPosition`, which is the
existing precedent for a per-student curriculum configuration the domain honours.

Every existing student reads back as pace 1 — exactly as students created before
flexible placement read back as `CurriculumPosition.start`.

Either a **teacher or a supervisor** may change a student's pace, and it may change
**mid-level**.

### A meeting is derived, never stored

The curriculum collection is untouched: no new rows, no new content. A pure domain
service composes the meeting on demand from the level's catalog, the starting
order, and the pace:

```
PacedSession compose(catalog, startOrder K, pace N) → {
  sessions:      the N lessons covered (fromOrder .. toOrder)
  newContent:    ∪ current_level_content  of those N rows
  distantReview: ∪ distant_review_content of those N rows
  recentReview:  ∪ current_level_content  of sessions [K-2N, K-1]
}
```

If the session at `K` is a تلقين, a سرد or an اختبار, the batch is that session
alone regardless of N, and its blocks are the row's own authored blocks — the
pace is ignored, not applied. `compose` is therefore total: it is called for every
meeting at every pace, and gates simply compose to themselves.

No infrastructure dependency; unit-testable with no mocks.

### The student stores where a meeting *starts*, never how far it extends

The extent is always derived from the live pace. This is what makes a mid-level
pace change work: when a teacher moves a student from 1x to 2x, the pending
meeting **recomposes on the next read** — new, recent and distant all widen
immediately. There is no stored extent to migrate and no state to fix up.

The denormalized `current_session_*` fields on `StudentModel` continue to describe
the **first** session of the meeting.

### The session record spans the meeting

One record per **meeting**, not per curriculum session. The teacher grades one
recitation; writing N records from one grading event would fabricate observations
that never happened, and `attemptNumber` would lie — a failing 2x student repeats
the *meeting*, not half of it.

`SessionRecordModel` gains:

- `coversSessionIds: List<String>` — the N curriculum sessions this meeting discharged
- `fromOrderInLevel` / `toOrderInLevel` — `orderInLevel` becomes `toOrderInLevel`
- `paceAtTime: int` — the N in force when recorded. History must not be rewritten
  when a student's pace later changes.

At N=1: `covers = [id]`, `from == to`, `pace == 1`. **Every existing record reads
back identically.**

### Advancement is unchanged

`next = toOrderInLevel + 1`. The existing advancement primitive
(`CurriculumRepository.sessionAt(level, orderInLevel)`) is untouched; it is simply
fed the batch's last order instead of the single session's order.

## Testing

- **Domain, no mocks:** `compose` at N=1 returns the row's authored blocks
  verbatim, for every session of every level — including the ~8 rows where the
  source disagrees with its own window rule, which must pass through unchanged.
- **Domain, no mocks:** at N=2, recent review never intersects the meeting's own
  new content — the bug that naive concatenation would introduce.
- **Domain:** batching stops at a تلقين, a سرد, an اختبار, and a level boundary.
- **Domain:** a short final batch before a gate is composed correctly.
- **Domain:** `CurriculumPace` rejects N < 1.
- **Application:** changing pace mid-level recomposes the pending meeting without
  touching stored state; records already written keep their `paceAtTime`.
- **Application:** a 2x meeting writes one record covering N sessions, and
  advancement lands on `toOrderInLevel + 1`.

## Out of scope

- **Cleaning the ~8 noisy source rows.** The surah-name typos (`المعار ج`), the
  duplicated lesson rows, and the ±1 verse drift are real defects in the source
  spreadsheet, surfaced by this analysis. They are tracked separately; this
  feature is designed to be correct without them being fixed, and reads authored
  blocks verbatim at N=1 precisely so it does not paper over them.
- Any change to curriculum data or the extractor.
- Changing the scope or content of a سرد or an اختبار.
- Per-teacher or per-institute default pace. Pace is per-student.
- A fractional or sub-1 pace (a *slower* student). The value object validates
  `N >= 1`; slowing a student down is a different problem.
