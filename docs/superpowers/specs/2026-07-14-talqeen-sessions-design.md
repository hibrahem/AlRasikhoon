# Talqeen sessions and recitation counts

**Date:** 2026-07-14
**Status:** Approved

## The problem

Every unit of the curriculum currently opens with a lesson: the student is
expected to memorize a passage and recite it back on the first day he meets it,
having never heard it read correctly. Teachers do read the new passage to the
student in practice — the curriculum simply has no session for it, so the work
is invisible to the app.

Two things follow from that gap:

1. There is no session in which a teacher **teaches** the passage without
   grading the student on it.
2. There is no record of how many times teacher and student recited a passage
   together, nor of how many repetitions the student was told to do at home —
   both of which the teacher assigns verbally today and the app never sees.

## What we are building

### A fourth session kind: تلقين (talqeen)

A talqeen session is one where the teacher recites the new passage to the
student and repeats it with him until he can read it correctly. The student
memorizes nothing, recites nothing alone, and is graded on nothing. The
passage he will memorize in the *next* session is the passage the teacher
reads in this one.

One talqeen session is inserted at the start of every **unit** — the half-juz
block (a hizb in levels 1-2, a surah group in levels 3-10) that ends in its
own سرد and اختبار. Equivalently: a talqeen session precedes the first lesson
after every exam, and opens every level. Every unit in the curriculum
currently begins with a lesson, so the rule is total and has no exceptions.

That is **59 new sessions** — two units per juz, three juz per level, except
level 10's juz 3, which has a single unit.

| Level | Sessions today | Units | Sessions after |
|-------|---------------|-------|----------------|
| 1  | 204 | 6 | 210 |
| 2  | 148 | 6 | 154 |
| 3  | 93  | 6 | 99  |
| 4  | 87  | 6 | 93  |
| 5  | 65  | 6 | 71  |
| 6  | 76  | 6 | 82  |
| 7  | 54  | 6 | 60  |
| 8  | 61  | 6 | 67  |
| 9  | 61  | 6 | 67  |
| 10 | 44  | 5 | 49  |
| **Total** | **893** | **59** | **952** |

### Two counts on every teaching session

Before a teacher ends a talqeen or a lesson session, he records:

- **عدد مرات القراءة مع الطالب** — how many times he recited the passage
  through with the student.
- **عدد مرات التكرار في المنزل** — how many repetitions the student must do at
  home before the next session.

سرد and اختبار sessions are assessments and are unaffected: they carry errors
and a grade, as today.

The home-repetition figure is an assignment, not a note. The student sees it,
and his existing home-practice logging counts against it.

## Design

### 1. Curriculum data — deriving the talqeen sessions

`tools/curriculum/extract_curriculum.py` gains a derivation pass that runs
after extraction and before validation. For each `(level_id, juz_number,
unit_index)` group, it inserts a session immediately before that unit's first
lesson.

The derived session:

- `kind: "talqeen"`
- `current_level_content`: **copied verbatim** from the lesson it precedes —
  the passage the student will memorize next session.
- `recent_review_content`, `distant_review_content`: `null`. A talqeen session
  carries no review.
- `scope`: `null`, `assessed_by`: `null`. It is not an assessment.
- `unit_index`, `hizb_number`: inherited from the lesson it precedes.
- `source`: `{"derived_from": "<id of the following lesson>"}` rather than a
  spreadsheet file/sheet/row. Nothing in the source spreadsheets corresponds
  to this session, and the data must not claim otherwise.

After insertion, `session_number` (1..N within a juz) and `order_in_level`
(1..M within a level) are renumbered contiguously and document ids
(`L{level}_J{juz}_S{n}`) recomputed. `levels.json` follows: each `LevelJuz`'s
`session_count` and `first_order_in_level`, and each level's `session_count`.
`metadata.json` totals 952.

Renumbering is not optional bookkeeping. `order_in_level` is the sole
advancement key, and the ids are the identity of the session documents.

### 2. Domain — `SessionKind.talqeen`

`SessionKind` gains `talqeen` (`nameAr: 'تلقين'`). `SessionKindX.fromString`
accepts `'talqeen'`; unknown values still throw.

Two existing definitions are wrong the moment a fourth kind exists, and both
fail silently:

- `SessionModel.isAssessment` is `!isLesson`. A talqeen session would become an
  assessment — retried without limit, and surfaced in the supervisor's exam
  queue. It becomes `kind == sard || kind == exam`.
- `StudentModel.hasExceededAttempts` is `!isOnAssessment && currentAttempt >
  maxSessionAttempts`. A talqeen session would become attempt-limited and could
  lock a student out of a session he cannot fail. It becomes a test for a
  lesson specifically.

Added alongside: `isTalqeen`, and `teachesNewContent` (talqeen or lesson) —
the set of sessions that carry the two counts.

`AppConstants` gains `sessionKindTalqeen = 'talqeen'`.

### 3. Session records — the two counts

`SessionRecordModel.repetitions` exists today but no screen ever sets it; every
record is written with `0`. It is repurposed, not duplicated:

- `repetitionsWithTeacher` (`repetitions_with_teacher`) — recitations done
  together in the session.
- `homeRepetitionsRequired` (`home_repetitions_required`) — the assignment.

Both are required on talqeen and lesson records, and absent on سرد/اختبار
records.

A talqeen record carries no errors and no pass/fail: it is a record that the
session happened, for history and attendance.

### 4. Teacher flow

A talqeen session runs: overview → **talqeen screen** (the passage to read,
with the instruction to recite it with the student until he reads it
correctly; no error counters, no recitation step) → **counts step** → summary →
advance.

It always advances. There is no failure, no retry, no attempt increment.

A lesson session runs as it does today, with the counts step inserted before
the summary.

### 5. Student — the home-repetition target

`HomePracticeModel` is stamped today with the student's *current* position —
which, after the teacher advances him, is the session **after** the one the
homework came from. Every logged repetition is therefore attributed to the
wrong session.

`HomePracticeModel` gains `curriculumSessionId`: the session the assignment
came from, read from the student's latest session record rather than from his
current position.

The student's dashboard and home-practice screen then show the assignment and
his progress against it — the passage, the target, and the repetitions logged
so far (`٤ / ١٠`).

### 6. Migration

None. There are no real students yet: the curriculum is re-extracted,
re-imported (`tools/curriculum/import_curriculum.mjs`), and test students are
recreated.

## Testing

- **Extractor** (`test_extract_curriculum.py`): every unit's first session is a
  talqeen; its `current_level_content` equals the following session's; it has
  no review content, no scope; `session_number` and `order_in_level` are
  contiguous with no gaps or duplicates; level and juz session counts match the
  emitted sessions; 59 sessions derived, 952 total.
- **Models**: `fromString('talqeen')` round-trips; `isAssessment` is false for
  talqeen; a student standing on a talqeen session never exceeds attempts.
- **Repositories**: advancement steps from a talqeen session into the lesson it
  introduces, and from an exam into the next unit's talqeen.
- **Teacher**: the talqeen screen offers no error entry; ending a talqeen
  session writes a record with both counts and advances the student.
- **Student**: the home-repetition target is read from the last session record,
  and logged practice counts against it.

## Out of scope

- Any change to how سرد and اختبار sessions are assessed or graded.
- Teaching the talqeen passage from anything other than the following session's
  content (e.g. a whole-unit read-through).
- Enforcing the home-repetition target — the app shows progress against it; it
  does not block advancement on it.
