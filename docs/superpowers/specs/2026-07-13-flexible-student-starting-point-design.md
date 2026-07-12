# Flexible Student Starting Point (and Curriculum Order Correction) — Design

**Date:** 2026-07-13
**Status:** Approved design, pending implementation plan

## Problem

A student must currently begin the curriculum at its very first session. Real students arrive
having already memorized part of the Quran — two juz, five juz, twenty juz — and forcing them
to start from session 1 makes the app unusable for them.

A teacher or supervisor must be able to admit a student at **any point in the curriculum**,
matching their current level, and the app must keep **all of its functionality** afterwards:
progress screens, session history, Sard, Exam, the exam queue, and the teacher/supervisor
reports must all behave as if the student had reached that point normally.

Investigating this surfaced a prerequisite: **the app's notion of curriculum order is wrong**,
so "everything before the starting point" is currently undefined. This spec covers both.

## Domain background

The curriculum (`منهج الراسخون`) is 10 levels. Each level spans 3 juz = 6 hizbs. A hizb's
sessions are numbered within 1–36, where 35 is the Sard and 36 is the Exam.

`StudentModel` holds the student's position in `current_level / current_juz / current_hizb /
current_session` and their credit in `completed_levels` and `unlocked_levels`. Today
`createStudent` hardcodes the start at level 1, juz 30, hizb 59, session 1.

### Confirmed curriculum order

- Levels ascend 1 → 10. Level *L* owns juz `33−3L, 32−3L, 31−3L` (level 1: 30, 29, 28).
- **Within a level, juz descend** (level 1: 30, then 29, then 28).
- **Within a juz, hizbs ascend**: juz *j* is hizb `2j−1`, then hizb `2j`.
- Within a hizb, sessions ascend over the numbers that actually exist.

So level 1 runs **59, 60, 57, 58, 55, 56**; level 2 runs 53, 54, 51, 52, 49, 50; level 10 runs
5, 6, 3, 4, 1, 2.

Derived: `juz(h) = (h+1) ÷ 2`; `firstHizbOfLevel(L) = 65 − 6L` (59, 53, … 5);
`lastHizbOfLevel(L) = 62 − 6L` (56, 50, … 2); `nextHizb(h) = h+1` when *h* is odd, `h−3` when
*h* is even.

### The two defects this exposes

1. **Advancement walks the wrong path.** `advanceStudentSession` *decrements* the hizb
   (59 → 58) rather than following the traversal order (59 → 60). It then compares the result
   against `_getFirstHizbOfLevel(level)` — the level's *first* hizb — so 58 < 59 promotes the
   student out of level 1 immediately. **A student completes a level after one of its six
   hizbs**, skipping juz 29 and 28 entirely — roughly 180 of level 1's 219 sessions.
   `test/unit/data/repositories/student_repository_test.dart:392` asserts this behavior as if
   intended.

2. **Session numbers are sparse.** The seeded sessions are not a contiguous 1–36 per hizb:
   level 2 / hizb 49 has 18 sessions whose numbers scatter across 2–36; level 10 / hizb 6 has
   7. Level totals are 219, 150, 198 … 76 — never 216. Blind `session + 1` therefore asks for
   sessions that do not exist.

Placement cannot be built on this: "credit everything before the anchor" is meaningless while
the traversal itself skips five sixths of every level.

### Data anomalies (tolerated, not fixed)

The `sessions` data was heuristically extracted from Excel and carries noise: a stray
`L1_J29_H59` pair of sessions whose juz contradicts its hizb, a session numbered 0, and a
`statistics` session type the app does not model. **Decision: tolerate in the app** — filter
sessions whose `juz_number ≠ juz(hizb_number)`, ignore session number 0, map unknown session
types to `regular`. No re-import, no change to the seed data.

### Migration

**None.** There is no production student progress yet, so correcting the traversal does not
require rewriting existing records.

## Decisions

**Placement is chosen precisely, as Level → Hizb → Session.** A derived "how many juz have you
memorized" input was considered and rejected: it silently assumes the student memorized in
curriculum order and gives the teacher no way to correct the guess.

**Sard (35) and Exam (36) are selectable starting points.** A teacher may want to place a
student directly onto the assessment of a hizb they claim to have finished.

**The skipped curriculum is credited as completed.** Placing a student at position *P* asserts
they have memorized everything before *P*, in curriculum order. That assumption is what makes
each session's `recent_review_content` / `distant_review_content` coherent for a placed student.

**Approach: placement anchor + derived credit.** The enrollment point is stored as an immutable
anchor; credit for everything before it is *derived*, not duplicated. Two alternatives were
rejected:

- *Backfill the credit lists only* (no anchor): lossy — a student placed at level 5 becomes
  indistinguishable from one who worked their way there, and a partially-credited level has
  nowhere to live.
- *Materialize credited session records*: thousands of synthetic documents per student and a
  session history that does not reflect reality.

The anchor keeps *earned in the app* and *brought with them* distinguishable — which the reports
need — and makes later repositioning a matter of moving the anchor.

## Design

### Part 1 — Curriculum order (new, framework-free)

A new `lib/domain/curriculum/` module with no Firebase or Flutter imports:

- **`CurriculumOrder`** — the arithmetic above: `juzOfHizb`, `hizbsOfJuz`, `juzOfLevel`,
  `firstHizbOfLevel`, `lastHizbOfLevel`, `levelOfHizb`, `nextHizb`. One place, unit-testable
  without a database.
- **`CurriculumPosition`** — an immutable value object of `(level, juz, hizb, session)`, the
  same four fields the student record already carries. It validates its own invariants (level
  1–10, hizb belongs to that level, juz consistent with hizb, session 1–36) and answers
  `isBefore(other)` in true curriculum order. It represents both the current position and the
  enrollment point; they are the same kind of thing.

The private helpers `_getFirstHizbOfLevel` / `_getFirstJuzOfLevel` are removed from
`StudentRepository` — business rules do not belong in the persistence layer — and their callers
use `CurriculumOrder`.

### Part 2 — Advancement fix

`StudentRepository.advanceStudentSession` is corrected to:

1. advance to the next session number that **actually exists** in the current hizb (looked up
   through `CurriculumRepository`, since the data is sparse);
2. when the hizb's sessions are exhausted, move to `CurriculumOrder.nextHizb` and its first
   existing session;
3. complete the level only when leaving its **last** hizb (`62 − 6L`), then unlock and enter the
   next level at its first hizb's first session;
4. leave level 10's end as a terminal state (no level 11).

The three advancement tests that encode the old behavior are corrected, not deleted.

### Part 3 — Placement anchor

`StudentModel` gains `enrollmentPosition: CurriculumPosition`, persisted as an
`enrollment_position` map (`{level, juz, hizb, session}`).

A new intention-revealing factory, `StudentModel.enrolledAt(position, …)`, sets the current
position to the anchor and backfills:

- `completedLevels` — every level entirely before the anchor's level,
- `unlockedLevels` — 1 through the anchor's level,
- `current_level / current_juz / current_hizb / current_session` — the anchor.

Existing screens therefore read correct values with no changes. Students created before this
feature have no `enrollment_position` and read back as the level-1 / juz-30 / hizb-59 /
session-1 anchor — exactly what they were.

Advancement is unchanged by placement: a placed student advances by the same corrected rules as
anyone else.

### Part 4 — The picker (UI)

`AddStudentScreen` — already shared by the teacher route and the supervisor route
(`asSupervisor: true`) — gains a starting-point section below the account fields:

- **Level** (1–10), labelled with the level's Arabic name and juz range, from `levelsProvider`.
- **Hizb** — the level's six hizbs **in traversal order** (59, 60, 57, 58, 55, 56 for level 1),
  each labelled with its juz. Resets when the level changes.
- **Session** — only the sessions that exist in that hizb, each shown with its real title and
  Quran range (e.g. `الحلقة ١٢ — الحزب ٥٣: النبأ ١–٢٠`), with Sard (35) and Exam (36) selectable
  and visibly marked.

Below the dropdowns, a confirmation line restates the choice and its consequence in plain
language:

> سيبدأ الطالب من الحلقة ١٢، الحزب ٥٣، المستوى ٢ — ويُعتبر ما قبلها من المنهج محفوظًا ومعتمدًا.

This is what stops a mis-click from silently crediting twenty juz.

The default selection is level 1 / juz 30 / hizb 59 / first session — today's behavior — so an
operator who ignores the section gets exactly the current outcome.

The section renders identically in teacher and supervisor mode: both place a student against the
same curriculum. The platform **admin** has no add-student flow today and does not gain one here.

`StudentRepository.createStudent(...)` takes the chosen `CurriculumPosition` as a new optional
parameter defaulting to the level-1 start, so every existing caller and test keeps compiling.

### Part 5 — Downstream behavior

**Progress percentage.** `levelProgressPercentage` measures the session within its hizb, which
stays correct for a placed student. No change.

**Session history.** A placed student's history starts empty and fills as they recite. The
credited portion shows as level-complete state, never as fabricated session records.

**Sard / Exam.** Eligibility is gated purely on `currentSession == 35 / 36`, and the supervisor's
exam queue queries `current_session == 36`. Session records are only read as history lists, where
an empty list renders fine. A student placed directly on session 35 or 36 therefore enters the
Sard/Exam flow correctly with no prior records — verified against the current code; no work needed.

**Firestore rules.** Student creation is already permitted for teachers and institute-scoped
supervisors, and the rules do not validate document schema, so `enrollment_position` needs no rule
change. To be confirmed against `test/rules` during implementation rather than assumed.

## Testing

Per the layer conventions in CLAUDE.md:

- **Unit (domain, no mocks)** — `CurriculumOrder` traversal across all six hizbs of a level, across
  a level boundary, and at level 10's terminal end; `CurriculumPosition` invariants and `isBefore`
  ordering.
- **Unit (persistence, fake Firestore)** — corrected advancement, including a jump over missing
  session numbers in a sparse hizb, and level completion only at the last hizb;
  `StudentModel.enrolledAt` backfill for a mid-level anchor, a level-1 anchor, and a Sard/Exam
  anchor; a pre-feature student document with no `enrollment_position` reading back as the level-1
  anchor.
- **Widget** — the picker cascades (changing level resets hizb and session), lists hizbs in
  traversal order, and defaults to today's starting point.
- **Integration** — a student placed at level 2 / hizb 53 / session 35 persists the right anchor and
  credit lists, and appears in the supervisor's Sard flow.

## Out of scope

- **Repositioning an existing student** after enrollment. Deferred by decision; the anchor model
  makes it a self-contained later addition (move the anchor, recompute the credit lists). To be
  filed as a follow-up issue.
- **Cleaning the seeded curriculum data.** The anomalies are tolerated in the app, not fixed at the
  source.
- **An admin-side add-student flow.** None exists today.
