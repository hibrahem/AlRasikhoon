# Skip empty evaluation parts + talqeen the next passage before closing

**Date:** 2026-07-15
**Status:** Approved (design)

## Problem

Two rough edges in the teacher's recitation (تسميع) flow:

1. **Empty parts still get evaluated.** A meeting has three parts — الحفظ الجديد
   (new), المراجعة القريبة (recent review), المراجعة البعيدة (distant review).
   The flow always walks all three, showing "لا يوجد محتوى" and a grade for a
   part with no content. Evaluating an absent part is meaningless.

2. **No talqeen of the upcoming passage.** The methodology requires the teacher
   to recite the *next* passage with the student (تلقين) before closing today's
   session. The app closes the session straight from the summary with no such
   step.

## Scope

- **Part A:** skip the recent/distant evaluation part (screen + result +
  summary card) when that part has no content. الحفظ الجديد (part 1) always
  shows, even on a review-only lesson.
- **Part B:** move the session-ending action off the summary onto a new talqeen
  screen that shows the next passage to recite, then closes the session.

Out of scope: cross-level preview (see Known Limitations).

## Domain facts this builds on

- `PacedSession` already exposes `hasNewContent` / `hasRecentReview` /
  `hasDistantReview` and the merged display strings `newContentAr` /
  `recentReviewAr` / `distantReviewAr` (`lib/domain/curriculum/paced_session.dart`).
- The recitation flow: `session_overview` → `recitation/:part` →
  `recitation/:part/result` → … → `session_summary` (closes here today).
- `ActiveSessionState` (`teacher_provider.dart`) holds `meeting`
  (the `PacedSession` being taught, with `toOrderInLevel`), the per-part errors,
  `notes`, and `passesForLevel(level)`. It survives navigation, so notes/counts
  set on the summary are still present on a later screen.
- A meeting is composed via `composeMeetingFor(ref, student)` — a pure
  composition from the level's curriculum rows + the student's pace. The next
  meeting can be composed the same way at a different start order.
- On a **fail** the student does **not** advance — they repeat the same session.
  On a **pass** they advance to `toOrderInLevel + 1` (next level at a boundary).

## Part A — Skip empty recent/distant parts

Treat the parts present in a meeting as a computed list:

```
presentParts = [1, if hasRecentReview → 2, if hasDistantReview → 3]
```

Part 1 is always present (per decision — الحفظ الجديد always shows, even when
empty on a review-only lesson).

Navigation walks `presentParts` in order instead of `part + 1`:

- **`RecitationScreen`**
  - "التالي" navigates to the result of the **current** part; unchanged. The
    result screen decides where "next" goes.
  - Final-part button label ("إنهاء التسميع" vs "التالي") is driven by whether
    the current part is the last in `presentParts`.
  - The "الجزء X من 3" chip becomes "الجزء {position} من {presentParts.length}"
    where `position = presentParts.indexOf(part) + 1`, so a skipped part never
    miscounts.
- **`RecitationResultScreen`**
  - "التالي: {title}" points at the **next present** part. After the last
    present part it shows "عرض ملخص الحلقة" → summary.
  - The "ملخص الأجزاء السابقة" block lists only present parts.
  - The same "الجزء X من 3" → "من {presentParts.length}" fix.
- **`SessionSummaryScreen`**
  - The part-by-part `_PartResultCard`s render only present parts (this is the
    "…or the result for them" the user asked to hide).
  - **Grades are unaffected:** a skipped part carries 0 errors, which already
    passes, so `calculateSessionGrade` yields the same result whether or not the
    empty part is displayed. No grade logic changes.

The present-parts list is derived from `activeSession.meeting`. All these
screens already read the meeting (directly or via
`studentCurrentMeetingProvider`); a small shared helper computes `presentParts`
and the next present part so the three screens stay consistent.

### Example

- `hasRecentReview = false`, `hasDistantReview = true` → `presentParts = [1, 3]`.
  Flow: part 1 → result → **part 3** (recent skipped) → result → summary. The
  summary shows the الحفظ الجديد and المراجعة البعيدة cards only.

## Part B — Talqeen the next passage, then close

The close action moves to a new screen. The summary no longer ends the session.

### Flow

```
session_summary  ── "التالي: تلقين المقطع القادم" ──▶  next-content talqeen  ── "إنهاء الحلقة" ──▶  teacher students
   (edit notes/counts,                                  (recite next passage,
    NO completeSession)                                  THEN completeSession)
```

### `SessionSummaryScreen` changes

- Primary button label: **"التالي: تلقين المقطع القادم"**.
- On tap: write the notes field into the active-session provider (`setNotes`),
  then `context.push` the new route. It **does not** call `completeSession`.
- "العودة للتعديل" stays.
- The `_saveSession` logic (setNotes + `completeSession` + `advanceOutcome`
  handling + snackbar + navigate) moves to the new screen.

### New `NextContentTalqeenScreen`

- Route: `/teacher/session/:studentId/next-content`
  (`AppRoutes.nextContentTalqeen`), added to the teacher branch in
  `app_router.dart`.
- Styled like `talqeen_session_screen.dart` (record-voice icon, "المقطع الجديد"
  label, the passage, an instruction line — no error counter, no grade).
- **What passage it shows** (the "content to recite"):
  - **Failed** → the **current** meeting's `newContentAr` (the student repeats
    the same session, so the teacher recites the same new passage again).
  - **Passed + next meeting has new content** → the **next** meeting's
    `newContentAr`.
  - **Passed + next is سرد/اختبار or end of level (no new content)** → a short
    note: "الحلقة القادمة: سرد/اختبار — لا يوجد حفظ جديد للتلقين" (wording per
    what the next session is, or a generic "لا يوجد حفظ جديد للتلقين").
  - **Fallback** — if the resolved passage is empty for any reason (e.g. a
    review-only lesson that failed), show the generic no-new-content note.
- Button **"إنهاء الحلقة"** runs the moved close logic and is the only place the
  session ends.

### Next-meeting composition

A new helper (alongside `composeMeetingFor` in `meeting_provider.dart`), e.g.
`composeNextMeetingAfter(ref, student, currentMeeting)`:

- Composes the meeting at `currentMeeting.toOrderInLevel + 1` in the student's
  **current** level, with the student's pace — same rule as `composeMeetingFor`.
- Returns `null` when that order is past the level's last session (end of
  level), which the screen renders as the no-new-content note.

The pass/fail branch chooses between the current meeting (already in
`activeSession.meeting`) and the composed next meeting. `level` comes from
`studentProvider`, as on the summary screen.

## Testing

- **Domain / helper (`presentParts`, next-present-part):** unit tests over the
  four shapes `{1}`, `{1,2}`, `{1,3}`, `{1,2,3}` — position/label/next resolve
  correctly.
- **`composeNextMeetingAfter`:** composes the correct next meeting within a
  level; returns null past the last session.
- **Flow (widget/feature):**
  - recent empty → flow skips part 2, summary hides its card.
  - distant empty → flow skips part 3.
  - both present → unchanged path.
  - summary button navigates to talqeen screen and does NOT complete the
    session; talqeen "إنهاء الحلقة" completes it and navigates to the list.
  - failed session → talqeen shows the current passage; passed → next passage;
    passed into سرد/اختبار → the note.

## Known Limitations

- **End-of-level preview.** At a level boundary the true next passage is in the
  next level's curriculum. This design shows the no-new-content note there
  instead of loading the next level. Can be extended later if needed.

## Files touched

- `lib/features/teacher/screens/recitation_screen.dart` — present-parts nav +
  chip.
- `lib/features/teacher/screens/recitation_result_screen.dart` — next-present
  nav, chip, previous-parts summary.
- `lib/features/teacher/screens/session_summary_screen.dart` — hide empty part
  cards; button → navigate (no complete).
- `lib/features/teacher/screens/next_content_talqeen_screen.dart` — **new.**
- `lib/shared/providers/meeting_provider.dart` — `composeNextMeetingAfter`.
- `lib/routing/app_router.dart` — new route.
- A small shared place for the `presentParts` / next-present helper (e.g. an
  extension on `PacedSession` or a util used by the three screens).
