# Session Duration Timer — Design

**Date:** 2026-07-15
**Status:** Approved

## Problem

When a teacher runs a session there is no record of how long it took. We want to:

1. Start a timer when the teacher starts a session.
2. Stop it when the session ends and record the elapsed duration on the session record.
3. Show the duration on the log card, with a flag for whether the session ran over or under its expected length.
4. Show a live, always-visible timer during the session so the teacher sees the time remaining and is reminded to end the session.

A session's expected length scales with the student's pace: ~20 minutes for a 1x student, ~40 minutes for 2x, i.e. **20 minutes × pace**.

## Ubiquitous language

- **Session duration** — the wall-clock elapsed time from when a session starts until its record is saved.
- **Target duration** — the expected length of a session: `20 minutes × pace`. Only paced sessions (lessons, تلقين) have one; assessments (سرد, اختبار) do not.
- **Duration status** — the judgment of a measured duration against its target: `under`, `onTarget`, `over`, or `none` (no target).
- **Sanity cap** — the maximum duration we will record: `3 × target`. A session left open (e.g. overnight) is clamped to this rather than recording an absurd number.

## Scope

- All session types are timed: lessons, تلقين, سرد, اختبار.
- Lessons and تلقين are paced → they get a target, a duration status, and an over/under flag on the card.
- Assessments (سرد, اختبار) are timed and their duration is recorded, but they carry **no target and no flag** (duration-only). They are not currently rendered in a log card; their duration persists for when such a card exists.
- The over/under flag is shown on **every** log card — in both the teacher's history and the student's history. No role gating.

## Domain model

### `SessionDuration` value object

Immutable. Encapsulates a measured elapsed duration and, optionally, a target, and computes its own status and display. Pure — no framework or infrastructure dependencies.

Responsibilities:

- Hold `elapsed` (a `Duration`).
- Hold an optional `target` (a `Duration`), null for assessments.
- **Cap on construction:** when a target is present, clamp `elapsed` to `3 × target`. (No cap without a target — assessments store raw elapsed.)
- Expose `status`:
  - `none` when there is no target.
  - `under` when `elapsed < target × (1 − 0.25)`.
  - `over` when `elapsed > target × (1 + 0.25)`.
  - `onTarget` otherwise (within the ±25% tolerance band).
- Expose a formatted display for the card (e.g. Arabic "٢٢ دقيقة") and for the live timer (`mm:ss`).

Constants (single source, easy to tune):

- `kMinutesPerPace = 20`
- `kToleranceFraction = 0.25`
- `kCapMultiple = 3`

### Target derivation

- Lessons / تلقين: `target = kMinutesPerPace × paceAtTime` minutes.
- Assessments: no target → `SessionDuration` with `target = null`.

## Persistence

Each record model gains a nullable `Duration? duration`, persisted as an integer field `duration_seconds`.

Nullable because:

- Records written before this feature have no duration.
- A record whose `startedAt` was missing saves with `duration = null`.

Affected models:

- `SessionRecordModel` (lesson / تلقين)
- `SardRecordModel`
- `ExamRecordModel`

`toFirestore` / `fromJson` round-trip `duration_seconds` (int seconds ↔ `Duration`), null-safe.

## Capture across the three flows

Wall-clock: capture a `startedAt` timestamp at start; at save compute `elapsed = now − startedAt`; build a `SessionDuration` (which applies the cap) and store `duration`.

A shared helper builds the `SessionDuration` from `startedAt`, `now`, and an optional pace, so all three flows apply identical cap/target logic.

### Lesson / تلقين

- Add `startedAt` to `ActiveSessionState`, set in `ActiveSessionNotifier.startSession()`.
- In `completeSession()` and `completeTalqeenSession()`, compute elapsed from `startedAt` and pass `duration` into the repository create call.

### سرد

- Capture `startedAt` in `SardSessionScreen.initState()` — opening the assessment screen is the start.
- Thread `startedAt` to `SardResultScreen` as a constructor argument (alongside `errorCount`).
- Compute elapsed in `_saveSard()` and pass `duration` into `createSardRecord`.

### اختبار

- Same pattern: capture in `ExamSessionScreen.initState()`, thread to `ExamResultScreen`, compute at save into `createExamRecord`.

### Killed-app caveat

If the app is killed mid-session the in-memory `startedAt` is lost — but so is the whole session (nothing is written until save), so no half-timed record can exist. Acceptable; matches current behavior.

## Live in-session timer

A `SessionTimer` widget in the app-bar title area of every active-session screen: the recitation / تلقين screens, `SardSessionScreen`, and `ExamSessionScreen`.

- Counts up from `startedAt`, ticking every second via a `Timer.periodic` disposed with the widget. It computes elapsed itself and never mutates stored state — no writes while ticking.
- Paced sessions show `elapsed / target` (e.g. `12:30 / 20:00`); assessments show elapsed only (e.g. `08:12`).
- Color states:
  - within target → neutral.
  - at/over target → warning color.
  - approaching the 3× cap → error color — a strong "end the session" signal.
- If `startedAt` is null, the widget hides itself.

## The log card

`SessionRecordRow` gains, under the existing subtitle/date lines:

- **Duration** — formatted elapsed, shown only when the record has a duration. Records without a duration render nothing (no layout shift beyond the absent line).
- **Over/under flag** — a small colored indicator driven by `SessionDuration.status`: `under` (fast), `onTarget`, `over`. Status `none` (assessments) renders the duration with no flag.

Shown in both the teacher history and the student history (same widget, no gating).

## Error handling

- Duration is nullable end to end; a missing/absent duration never blocks a save and simply renders nothing.
- The cap clamps beyond-target values; there is no failure path — a bad clock or forgotten session degrades to a clamped number, never an exception.
- The live timer is display-only and hides itself when it has no `startedAt`.

## Testing (TDD, domain language)

- **`SessionDuration`** (pure, no mocks): formatting; status boundaries at the ±25% band; cap clamping at 3× target; assessment "no target" → status `none`; pace scaling (2x target = 40 minutes).
- **Repository**: each create method persists and round-trips `duration`, including null.
- **Provider**: `completeSession` / `completeTalqeenSession` compute elapsed from `startedAt` and pass it through.
- **Widget**: `SessionRecordRow` shows/hides the duration line and renders each flag state; `SessionTimer` formats elapsed and switches color state at target and near the cap.
