# Talqeen Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a teacher-led تلقين session at the start of every curriculum unit (59 new sessions, 893 → 952), and record on every teaching session how many times teacher and student recited the passage together and how many repetitions the student owes at home.

**Architecture:** The 59 talqeen sessions are *derived* in the Python extractor, not hand-written: for each unit, a session is synthesized immediately before that unit's first lesson, carrying that lesson's `current_level_content`. Session numbers and `order_in_level` are then renumbered, so the whole app — which already advances by `order_in_level` and reads a session's kind from the document — needs no new advancement logic. Dart gains a fourth `SessionKind`, two counts on the session record, and one new teacher screen.

**Tech Stack:** Python 3 + pandas + pytest (extractor), Flutter + Riverpod + Firestore (app), `fake_cloud_firestore` + `flutter_test` (tests).

**Spec:** `docs/superpowers/specs/2026-07-14-talqeen-sessions-design.md`
**Issue:** `bd show al_rasikhoon-i00`

## Global Constraints

- A session's kind is **DATA**. Never infer a kind from a session number, and never rebuild an assessment's label from its numbers. This is a standing rule of this codebase, stated at the top of `lib/data/models/session_model.dart`.
- `order_in_level` is the **only** ordering key for advancement. Juz numbers cannot order sessions (level 10 teaches juz 1 → 2 → 3).
- The Arabic name of the new kind is **تلقين**; the code identifier is `talqeen`; the persisted `kind` value is the string `"talqeen"`.
- The two counts are Arabic-labelled **عدد مرات القراءة مع الطالب** (`repetitionsWithTeacher`) and **عدد مرات التكرار في المنزل** (`homeRepetitionsRequired`).
- Talqeen sessions are never graded, never failed, never attempt-limited, and always advance the student.
- The source spreadsheets in `../curriculum/` are **read-only**. Never write to them.
- Firestore field names are `snake_case`; Dart fields are `camelCase`.
- Domain layer stays free of framework concerns; business rules live in models, not screens (see `CLAUDE.md`).

## File Structure

**Extractor (Python)**
- Modify `tools/curriculum/extract_curriculum.py` — add `talqeen_of()` and `insert_talqeen_sessions()`, call from `extract()`, extend corpus validation and the report.
- Modify `tools/curriculum/test_extract_curriculum.py` — new talqeen tests; renumber existing golden assertions.

**Data (generated)**
- Regenerate `data/curriculum/sessions_level_{1..10}.json`, `levels.json`, `metadata.json`, `validation_report.json`.

**Domain / models (Dart)**
- Modify `lib/data/models/session_model.dart` — `SessionKind.talqeen`, fix `isAssessment`, add `isTalqeen` / `teachesNewContent`.
- Modify `lib/data/models/student_model.dart` — fix `hasReachedMaxAttempts`, add `isOnTalqeen`.
- Modify `lib/core/constants/app_constants.dart` — `sessionKindTalqeen`.
- Modify `lib/data/models/session_record_model.dart` — `repetitionsWithTeacher`, `homeRepetitionsRequired`.
- Modify `lib/data/models/home_practice_model.dart` — `curriculumSessionId`.

**Repositories**
- Modify `lib/data/repositories/session_repository.dart` — counts on `createSessionRecord`, new `createTalqeenRecord`, new `getLatestSessionRecord`.
- Modify `lib/data/repositories/home_practice_repository.dart` — `curriculumSessionId` on create.

**UI**
- Create `lib/features/teacher/widgets/recitation_counts_card.dart` — the two steppers, shared by the summary and talqeen screens.
- Create `lib/features/teacher/screens/talqeen_session_screen.dart` — the teacher-led session.
- Create `lib/features/student/widgets/home_assignment_card.dart` — the target and progress against it.
- Modify `lib/features/teacher/providers/teacher_provider.dart`, `lib/features/teacher/screens/session_overview_screen.dart`, `lib/features/teacher/screens/session_summary_screen.dart`, `lib/routing/app_router.dart`, `lib/features/student/providers/student_provider.dart`, `lib/features/student/screens/home_practice_screen.dart`.

**Tests**
- Modify `test/unit/data/repositories/curriculum_fixtures.dart` (seed talqeen), `test/unit/data/models/session_model_test.dart`, `student_model_test.dart`, `session_record_model_test.dart`, `test/unit/data/repositories/session_repository_test.dart`.
- Create `test/widget/talqeen_session_screen_test.dart`, `test/widget/recitation_counts_card_test.dart`.

---

## Task 1: Derive the talqeen sessions in the extractor

**Files:**
- Modify: `tools/curriculum/extract_curriculum.py`
- Test: `tools/curriculum/test_extract_curriculum.py`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `ex.talqeen_of(lesson: dict) -> dict` and `ex.insert_talqeen_sessions(sessions: list[dict]) -> list[dict]`; every emitted session dict may now carry `kind == "talqeen"` and a `source` of `{"derived_from": "<lesson id>"}` instead of file/sheet/row.

**Context you need:**
- Run tests from the tool directory: `cd tools/curriculum && python -m pytest test_extract_curriculum.py -v`. The tests call `ex.extract()`, which reads the real spreadsheets in `../curriculum/` (present in this checkout).
- `build_juz_sessions()` (line ~481) returns one juz's sessions with `session_number` and `id` set and `order_in_level: None`. `extract()` (line ~744) then assigns `order_in_level` sequentially across the level's juz and derives the `levels.json` metadata from the list it is handed. **So inserting into the list that `build_juz_sessions()` returns, before `extract()` numbers it, makes `order_in_level`, `session_count` and `first_order_in_level` all fall out correctly for free.**
- Every unit's first session is currently a lesson, and none of the five review-only lessons (`L7_J10_S16`, `L8_J7_S17`, `L9_J4_S16`, `L10_J2_S13`, `L10_J3_S5`) is a unit's first lesson — so every derived talqeen has content.
- Units: `unit_index` is 1 or 2, and `None` on juz-/cumulative-tier assessments. Level 10 juz 3 has a single unit. 59 units in total.

- [ ] **Step 1: Write the failing tests**

Add to the end of `tools/curriculum/test_extract_curriculum.py`:

```python
# ----------------------------------------------------------------- talqeen
def test_every_unit_opens_with_a_talqeen_session(corpus):
    """A تلقين session precedes the first lesson of every unit — equivalently,
    it opens every level and follows every exam that is followed by new
    content. 59 units in the curriculum, 59 talqeen sessions."""
    total = 0
    for level, sessions in corpus["sessions"].items():
        units = {}
        for s in sessions:
            if s["unit_index"] is None:
                continue
            units.setdefault((s["juz_number"], s["unit_index"]), []).append(s)
        for (juz, unit), members in units.items():
            first = members[0]
            assert first["kind"] == "talqeen", (
                f"L{level} J{juz} unit {unit} opens with {first['kind']}, not talqeen"
            )
            total += 1
    assert total == 59


def test_a_talqeen_teaches_the_passage_of_the_session_that_follows_it(corpus):
    for sessions in corpus["sessions"].values():
        by_order = sorted(sessions, key=lambda s: s["order_in_level"])
        for i, s in enumerate(by_order):
            if s["kind"] != "talqeen":
                continue
            nxt = by_order[i + 1]
            assert nxt["kind"] == "lesson"
            assert s["current_level_content"] == nxt["current_level_content"]
            assert s["current_level_content"] is not None


def test_a_talqeen_carries_no_review_no_scope_and_no_assessor(corpus):
    for sessions in corpus["sessions"].values():
        for s in sessions:
            if s["kind"] != "talqeen":
                continue
            assert s["recent_review_content"] is None
            assert s["distant_review_content"] is None
            assert s["scope"] is None
            assert s["assessed_by"] is None


def test_a_talqeen_declares_itself_derived_not_extracted(corpus):
    """Nothing in the source spreadsheets is a talqeen row. The provenance must
    say so rather than claim a file/sheet/row it did not come from."""
    for sessions in corpus["sessions"].values():
        for s in sessions:
            if s["kind"] == "talqeen":
                assert set(s["source"]) == {"derived_from"}
                assert s["source"]["derived_from"].startswith("L")
            else:
                assert isinstance(s["source"]["row"], int)


def test_the_curriculum_has_952_sessions(corpus):
    per_level = {
        level: len(sessions) for level, sessions in corpus["sessions"].items()
    }
    assert per_level == {
        1: 210, 2: 154, 3: 99, 4: 93, 5: 71,
        6: 82, 7: 60, 8: 67, 9: 67, 10: 49,
    }
    assert sum(per_level.values()) == 952
    for level, sessions in corpus["sessions"].items():
        assert corpus["levels"][level]["session_count"] == len(sessions)
        assert [s["order_in_level"] for s in sessions] == list(
            range(1, len(sessions) + 1)
        )


def test_level_1_juz_30_talqeen_sessions_open_both_hizbs(corpus):
    s = by_number(juz_sessions(corpus, 1, 30))
    assert len(s) == 70
    assert s[1]["kind"] == "talqeen"
    assert s[1]["unit_index"] == 1
    assert s[1]["hizb_number"] == 59
    assert s[1]["current_level_content"] == s[2]["current_level_content"]
    assert s[33]["kind"] == "talqeen"
    assert s[33]["unit_index"] == 2
    assert s[33]["hizb_number"] == 60
    assert s[33]["current_level_content"] == s[34]["current_level_content"]


def test_the_juz_metadata_counts_the_talqeen_sessions(corpus):
    juz_30 = corpus["levels"][1]["juz"][0]
    assert juz_30["juz_number"] == 30
    assert juz_30["session_count"] == 70
    assert juz_30["first_order_in_level"] == 1
    juz_29 = corpus["levels"][1]["juz"][1]
    assert juz_29["juz_number"] == 29
    assert juz_29["first_order_in_level"] == 71
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd tools/curriculum && python -m pytest test_extract_curriculum.py -k talqeen -v`
Expected: FAIL — `test_every_unit_opens_with_a_talqeen_session` reports "opens with lesson, not talqeen".

- [ ] **Step 3: Implement the derivation**

In `tools/curriculum/extract_curriculum.py`, add these two functions immediately after `build_juz_sessions()` ends (just before the `# ---- Driver` banner comment, around line 707):

```python
# --------------------------------------------------------------------------
# Derived sessions: تلقين
# --------------------------------------------------------------------------
# A تلقين session is one where the teacher recites the new passage TO the
# student and repeats it with him; the student memorizes nothing and is graded
# on nothing. It opens every unit — equivalently, it opens every level and
# follows every exam that is followed by new content.
#
# Nothing in the source spreadsheets is a تلقين row. These sessions are DERIVED,
# and say so: their `source` names the lesson they were derived from, never a
# file/sheet/row they did not come from.
def talqeen_of(lesson: dict) -> dict:
    """The تلقين session that introduces `lesson`.

    It teaches exactly the passage the student will memorize in `lesson`, and
    carries no review content, no scope and no assessor.
    """
    return {
        "id": None,             # assigned by insert_talqeen_sessions
        "level_id": lesson["level_id"],
        "juz_number": lesson["juz_number"],
        "session_number": None,  # assigned by insert_talqeen_sessions
        "order_in_level": None,  # filled by the caller, as for every session
        "kind": "talqeen",
        "assessed_by": None,
        "unit_index": lesson["unit_index"],
        "hizb_number": lesson["hizb_number"],
        "scope": None,
        "current_level_content": lesson["current_level_content"],
        "recent_review_content": None,
        "distant_review_content": None,
        "source": {"derived_from": lesson["id"]},
    }


def insert_talqeen_sessions(sessions: list[dict]) -> list[dict]:
    """Open every unit of one juz with a تلقين, and renumber the juz 1..N.

    Renumbering is not bookkeeping: the document id and `session_number` are
    the session's identity, and `order_in_level` (assigned by the caller from
    the list this returns) is the sole advancement key.
    """
    out: list[dict] = []
    opened: set[int] = set()
    for s in sessions:
        unit = s["unit_index"]
        if s["kind"] == "lesson" and unit is not None and unit not in opened:
            opened.add(unit)
            out.append(talqeen_of(s))
        out.append(s)

    level = out[0]["level_id"]
    juz = out[0]["juz_number"]
    for i, s in enumerate(out):
        s["session_number"] = i + 1
        s["id"] = f"L{level}_J{juz}_S{i + 1}"
    return out
```

- [ ] **Step 4: Call it from `extract()`**

In `extract()`, replace this (around line 747):

```python
            juz_sessions = build_juz_sessions(
                src, pos, list(taught), errors, warnings, anomalies
            )
            first_order = len(level_sessions) + 1
```

with:

```python
            juz_sessions = build_juz_sessions(
                src, pos, list(taught), errors, warnings, anomalies
            )
            # A تلقين opens every unit. Inserted BEFORE order_in_level is
            # assigned, so the level ordering, the level session_count and
            # first_order_in_level all account for them without a second pass.
            juz_sessions = insert_talqeen_sessions(juz_sessions)
            first_order = len(level_sessions) + 1
```

- [ ] **Step 5: Teach corpus validation about the derived sessions**

In `extract()`'s corpus-wide validation block, replace the provenance check:

```python
            if not s["source"] or s["source"]["row"] is None:
                errors.append(f"{s['id']}: missing source provenance")
```

with:

```python
            if s["kind"] == "talqeen":
                if not s["source"].get("derived_from"):
                    errors.append(f"{s['id']}: talqeen without a derived_from")
                if not s["current_level_content"]:
                    errors.append(f"{s['id']}: talqeen teaches no passage")
                if s["scope"] or s["assessed_by"]:
                    errors.append(f"{s['id']}: talqeen is not an assessment")
            elif not s["source"] or s["source"]["row"] is None:
                errors.append(f"{s['id']}: missing source provenance")
```

And add, after the `by_juz` density check at the end of the same loop:

```python
        # Every unit opens with a تلقين that teaches the passage of the lesson
        # it precedes. A unit that opens with anything else is a derivation bug.
        by_order = sorted(sessions, key=lambda s: s["order_in_level"])
        units_opened: set[tuple[int, int]] = set()
        for i, s in enumerate(by_order):
            unit = s["unit_index"]
            if unit is None:
                continue
            key = (s["juz_number"], unit)
            if key in units_opened:
                continue
            units_opened.add(key)
            if s["kind"] != "talqeen":
                errors.append(
                    f"L{level} J{s['juz_number']} unit {unit}: opens with "
                    f"{s['kind']} ({s['id']}), not a talqeen"
                )
                continue
            following = by_order[i + 1]
            if s["current_level_content"] != following["current_level_content"]:
                errors.append(
                    f"{s['id']}: talqeen does not teach the passage of "
                    f"{following['id']}"
                )
```

- [ ] **Step 6: Count talqeen in the report**

In `print_report()`, replace the header line and the per-juz print:

```python
    print(f"{'level':>5} {'juz':>4} {'sessions':>9} {'lessons':>8} {'sard':>5} {'exam':>5}  tiers")
```

with:

```python
    print(f"{'level':>5} {'juz':>4} {'sessions':>9} {'talqeen':>8} {'lessons':>8} {'sard':>5} {'exam':>5}  tiers")
```

and

```python
            print(
                f"{level:>5} {juz:>4} {len(ss):>9} "
                f"{sum(1 for s in ss if s['kind'] == 'lesson'):>8} "
                f"{sum(1 for s in ss if s['kind'] == 'sard'):>5} "
                f"{sum(1 for s in ss if s['kind'] == 'exam'):>5}  {', '.join(tiers)}"
            )
```

with

```python
            print(
                f"{level:>5} {juz:>4} {len(ss):>9} "
                f"{sum(1 for s in ss if s['kind'] == 'talqeen'):>8} "
                f"{sum(1 for s in ss if s['kind'] == 'lesson'):>8} "
                f"{sum(1 for s in ss if s['kind'] == 'sard'):>5} "
                f"{sum(1 for s in ss if s['kind'] == 'exam'):>5}  {', '.join(tiers)}"
            )
```

- [ ] **Step 7: Bump the schema version**

In `main()`, in the `metadata.json` payload, change `"schema_version": 2` to `"schema_version": 3`.

- [ ] **Step 8: Fix the existing golden tests, which now assert stale numbers**

Session numbers shift by one at the first talqeen and by two after the second. In `test_extract_curriculum.py`:

`test_every_session_carries_its_source_row` — a talqeen has no source row. Replace the whole test with:

```python
def test_every_extracted_session_carries_its_source_row(corpus):
    """Every session read FROM the spreadsheets carries its provenance. Derived
    talqeen sessions are covered by test_a_talqeen_declares_itself_derived."""
    for sessions in corpus["sessions"].values():
        for s in sessions:
            if s["kind"] == "talqeen":
                continue
            assert s["source"]["file"] and s["source"]["sheet"]
            assert isinstance(s["source"]["row"], int)
```

`test_no_session_is_typed_by_number` — its `else` branch asserts `kind == "lesson"`. Change that branch to:

```python
            else:
                assert s["kind"] in ("lesson", "talqeen")
                assert s["scope"] is None
```

`test_level_1_juz_30_has_68_sessions` — rename and renumber:

```python
def test_level_1_juz_30_has_70_sessions(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    assert len(sessions) == 70  # 68 from the source + 2 derived talqeen
    assert [s["session_number"] for s in sessions] == list(range(1, 71))
```

`test_level_1_juz_30_unit_pairs_land_on_30_31_and_65_66` — rename to `..._land_on_31_32_and_67_68` and change the four subscripts: `s[30]` → `s[31]`, `s[31]` → `s[32]`, `s[65]` → `s[67]`, `s[66]` → `s[68]`. Nothing else in it changes.

`test_level_1_juz_30_juz_pair_lands_on_67_68` — rename to `..._lands_on_69_70`; `s[67]` → `s[69]`, `s[68]` → `s[70]`.

`test_level_1_juz_30_has_no_lesson_typed_as_an_assessment` — the assessment numbers shift and the `kind != "lesson"` filter now catches talqeen. Replace its body with:

```python
def test_level_1_juz_30_has_no_lesson_typed_as_an_assessment(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    assessments = [
        s["session_number"] for s in sessions if s["kind"] in ("sard", "exam")
    ]
    assert assessments == [31, 32, 67, 68, 69, 70]
    for s in sessions:
        if s["kind"] == "lesson":
            assert s["current_level_content"] or s["recent_review_content"]
```

`test_level_2_juz_27_concatenates_hizb_54_before_hizb_53` — 51 → 53 sessions, and `sessions[0]` is now the talqeen (whose source has no `file`). Replace its body with:

```python
def test_level_2_juz_27_concatenates_hizb_54_before_hizb_53(corpus):
    sessions = juz_sessions(corpus, 2, 27)
    assert len(sessions) == 53  # 25 + 26 source rows + 2 derived talqeen
    assert [s["session_number"] for s in sessions] == list(range(1, 54))

    extracted = [s for s in sessions if s["kind"] != "talqeen"]
    first_file = extracted[0]["source"]["file"]
    last_file = extracted[-1]["source"]["file"]
    assert "54" in first_file.rsplit("/", 1)[-1]
    assert "53" in last_file.rsplit("/", 1)[-1]

    assert sessions[0]["kind"] == "talqeen"
    assert sessions[0]["hizb_number"] == 54
    assert sessions[0]["unit_index"] == 1
    assert extracted[-1]["source"]["raw_session_number"] == 27  # each half restarts at 2
```

`test_level_3_juz_22_reads_both_sheet1_pages_of_one_workbook` — 32 → 34, and the source assertions must skip talqeen. Replace its body with:

```python
def test_level_3_juz_22_reads_both_sheet1_pages_of_one_workbook(corpus):
    sessions = juz_sessions(corpus, 3, 22)
    assert len(sessions) == 34  # 32 from the source + 2 derived talqeen
    extracted = [s for s in sessions if s["kind"] != "talqeen"]
    assert {s["source"]["sheet"] for s in extracted} == {"Sheet1", "Sheet1 (2)"}
    # the stale per-file Sheet2 drafts are never read
    assert all(s["source"]["sheet"].startswith("Sheet1") for s in extracted)
    # both workbooks of the pair carry identical Sheet1* content; one is used
    assert len({s["source"]["file"] for s in extracted}) == 1
```

`test_level_3_juz_22_tiers_are_derived_structurally` — every subscript shifts: `14→15, 15→16, 27→29, 28→30, 29→31, 30→32, 31→33, 32→34`.

`test_level_3_juz_22_labels_are_stored_verbatim_and_name_no_hizb` — `s[14]→s[15]`, `s[27]→s[29]`, `s[29]→s[31]`, and the loop `for n in (14, 27, 29, 31)` becomes `for n in (15, 29, 31, 33)`.

`test_level_3_juz_22_cumulative_covers_the_whole_level` — `s[31]` → `s[33]`.

`test_level_3_cumulative_labels_name_no_juz` — `cumulative = [s[29], s[30], s[31], s[32]]` becomes `cumulative = [s[31], s[32], s[33], s[34]]`.

- [ ] **Step 9: Run the whole extractor test suite**

Run: `cd tools/curriculum && python -m pytest test_extract_curriculum.py -v`
Expected: PASS, all tests green (including `test_extraction_of_the_whole_curriculum_is_valid`, which asserts the corpus validation produced zero errors).

- [ ] **Step 10: Run the extractor dry and read the report**

Run: `cd tools/curriculum && python extract_curriculum.py`
Expected: the table shows a `talqeen` column with 2 per juz (1 for L10 J3), level totals 210/154/99/93/71/82/60/67/67/49, and the final line reads `VALIDATION PASSED — 952 sessions across 10 levels.`

- [ ] **Step 11: Commit**

```bash
git add tools/curriculum/extract_curriculum.py tools/curriculum/test_extract_curriculum.py
git commit -m "feat(curriculum): derive a تلقين session at the start of every unit"
```

---

## Task 2: Regenerate the curriculum data

**Files:**
- Modify (generated): `data/curriculum/sessions_level_{1..10}.json`, `data/curriculum/levels.json`, `data/curriculum/metadata.json`, `data/curriculum/validation_report.json`

**Interfaces:**
- Consumes: `insert_talqeen_sessions()` from Task 1.
- Produces: the JSON the app is seeded from — 952 sessions, `kind: "talqeen"` on 59 of them, `schema_version: 3`.

- [ ] **Step 1: Regenerate**

Run: `cd tools/curriculum && python extract_curriculum.py --write`
Expected: `VALIDATION PASSED — 952 sessions across 10 levels.` then `Wrote .../data/curriculum`

- [ ] **Step 2: Verify the emitted data**

Run:

```bash
python3 - <<'EOF'
import json, glob
total = 0
for f in sorted(glob.glob('data/curriculum/sessions_level_*.json')):
    s = json.load(open(f))
    total += len(s)
    talqeen = [x for x in s if x['kind'] == 'talqeen']
    for t in talqeen:
        assert t['scope'] is None and t['recent_review_content'] is None
        assert t['source'] == {'derived_from': t['source']['derived_from']}
        assert t['current_level_content']
    print(f, len(s), 'talqeen:', len(talqeen))
print('TOTAL', total)
print('metadata', json.load(open('data/curriculum/metadata.json'))['total_sessions'])
EOF
```

Expected: 59 talqeen in total, `TOTAL 952`, `metadata 952`.

- [ ] **Step 3: Commit**

```bash
git add data/curriculum
git commit -m "chore(curriculum): regenerate with 59 تلقين sessions (893 → 952)"
```

---

## Task 3: `SessionKind.talqeen` and the two definitions it breaks

**Files:**
- Modify: `lib/data/models/session_model.dart`
- Modify: `lib/data/models/student_model.dart:283-297`
- Modify: `lib/core/constants/app_constants.dart:20-23`
- Test: `test/unit/data/models/session_model_test.dart`, `test/unit/data/models/student_model_test.dart`

**Interfaces:**
- Consumes: the `"talqeen"` kind string from Task 2's data.
- Produces: `SessionKind.talqeen`; `SessionModel.isTalqeen`, `SessionModel.teachesNewContent`, `SessionModel.isAssessment` (now `sard || exam`); `StudentModel.isOnTalqeen`; `AppConstants.sessionKindTalqeen`.

**Context you need:**
- `isAssessment` is currently `!isLesson`. Adding a fourth kind silently makes a talqeen an "assessment": it would be retried without limit and, worse, `StudentModel.isOnAssessment`-driven queues would treat the student as awaiting assessment.
- `StudentModel.hasReachedMaxAttempts` is `!isOnAssessment && currentAttempt > 3` — the mirror image of the same bug: a talqeen, which cannot be failed, would become attempt-limited.
- Run Dart tests with `flutter test test/unit/data/models/session_model_test.dart`.

- [ ] **Step 1: Write the failing tests**

Append to the top-level `main()` group in `test/unit/data/models/session_model_test.dart`:

```dart
  group('SessionKind.talqeen', () {
    SessionModel talqeen() => SessionModel.fromJson('L1_J30_S1', {
      'level_id': 1,
      'juz_number': 30,
      'session_number': 1,
      'order_in_level': 1,
      'kind': 'talqeen',
      'assessed_by': null,
      'unit_index': 1,
      'hizb_number': 59,
      'scope': null,
      'current_level_content': {
        'from_surah': 'النبأ',
        'from_verse': 1,
        'to_surah': 'النبأ',
        'to_verse': 11,
      },
      'recent_review_content': null,
      'distant_review_content': null,
    });

    test('a talqeen session is read from the curriculum, not guessed', () {
      expect(SessionKindX.fromString('talqeen'), SessionKind.talqeen);
      expect(SessionKind.talqeen.nameAr, 'تلقين');
      expect(talqeen().kind, SessionKind.talqeen);
      expect(talqeen().isTalqeen, isTrue);
    });

    test('a talqeen session is not an assessment', () {
      final session = talqeen();
      expect(session.isAssessment, isFalse);
      expect(session.isSard, isFalse);
      expect(session.isExam, isFalse);
      expect(session.isLesson, isFalse);
    });

    test('a talqeen session teaches new content, as a lesson does', () {
      expect(talqeen().teachesNewContent, isTrue);
    });

    test('a talqeen session round-trips through Firestore', () {
      final json = talqeen().toFirestore();
      expect(json['kind'], 'talqeen');
      expect(SessionModel.fromJson('L1_J30_S1', json).isTalqeen, isTrue);
    });
  });
```

Append to `test/unit/data/models/student_model_test.dart`:

```dart
  group('a student standing on a talqeen session', () {
    StudentModel onTalqeen({int attempt = 1}) => StudentModel(
      id: 's1',
      userId: 'u1',
      instituteId: 'i1',
      currentSessionId: 'L1_J30_S1',
      currentSessionKind: SessionKind.talqeen,
      currentAttempt: attempt,
      createdAt: DateTime(2026, 1, 1),
    );

    test('is not on an assessment', () {
      expect(onTalqeen().isOnAssessment, isFalse);
      expect(onTalqeen().isOnTalqeen, isTrue);
      expect(onTalqeen().canTakeSard, isFalse);
      expect(onTalqeen().canTakeExam, isFalse);
    });

    test('can never exhaust attempts at a session that cannot be failed', () {
      expect(onTalqeen(attempt: 9).hasReachedMaxAttempts, isFalse);
      expect(onTalqeen(attempt: 9).canStartSession, isTrue);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/data/models/session_model_test.dart test/unit/data/models/student_model_test.dart`
Expected: FAIL — compile errors, `The getter 'isTalqeen' isn't defined`, and `SessionKindX.fromString('talqeen')` throws `ArgumentError`.

- [ ] **Step 3: Add the kind**

In `lib/data/models/session_model.dart`, extend the enum and its extension. The doc comment above `enum SessionKind` gains a sentence; the enum becomes:

```dart
/// What a curriculum session IS. Read from the session's `kind` field, which the
/// extractor took verbatim from the source spreadsheets — except [talqeen],
/// which the extractor DERIVES at the start of every unit and marks as derived.
///
/// A session's kind is NEVER inferred from its number. The curriculum used to be
/// modelled as "36 sessions per hizb, 35 = sard, 36 = exam"; the real curriculum
/// runs 1..N continuously across a whole juz and puts assessments wherever the
/// source puts them.
enum SessionKind { talqeen, lesson, sard, exam }
```

In `SessionKindX`, add the three switch arms:

```dart
  String get nameAr {
    switch (this) {
      case SessionKind.talqeen:
        return 'تلقين';
      case SessionKind.lesson:
        return 'حلقة';
      case SessionKind.sard:
        return 'سرد';
      case SessionKind.exam:
        return 'اختبار';
    }
  }

  String get nameEn {
    switch (this) {
      case SessionKind.talqeen:
        return 'Talqeen';
      case SessionKind.lesson:
        return 'Lesson';
      case SessionKind.sard:
        return 'Sard';
      case SessionKind.exam:
        return 'Exam';
    }
  }
```

and in `fromString`:

```dart
    switch (value) {
      case 'talqeen':
        return SessionKind.talqeen;
      case 'lesson':
        return SessionKind.lesson;
      case 'sard':
        return SessionKind.sard;
      case 'exam':
        return SessionKind.exam;
      default:
        throw ArgumentError.value(value, 'kind', 'Unknown session kind');
    }
```

- [ ] **Step 4: Fix `isAssessment` and add the new predicates**

In `SessionModel`, replace:

```dart
  bool get isLesson => kind == SessionKind.lesson;

  /// A سرد or an اختبار — the two kinds that are assessed and retried without
  /// limit.
  bool get isAssessment => !isLesson;
```

with:

```dart
  bool get isLesson => kind == SessionKind.lesson;

  /// A تلقين: the teacher recites the new passage to the student and repeats it
  /// with him. Nothing is memorized, recited alone, or graded.
  bool get isTalqeen => kind == SessionKind.talqeen;

  /// A سرد or an اختبار — the two kinds that are assessed and retried without
  /// limit.
  ///
  /// This is NOT `!isLesson`: a تلقين is neither a lesson nor an assessment, and
  /// defining it by negation is how one would silently acquire an assessment's
  /// unlimited retries and land in the supervisor's exam queue.
  bool get isAssessment => kind == SessionKind.sard || kind == SessionKind.exam;

  /// The sessions that teach new memorization content — a تلقين and a lesson.
  /// These, and only these, carry the recitation counts.
  bool get teachesNewContent => isTalqeen || isLesson;
```

Also extend `titleEn` so it does not call a talqeen a "Session":

```dart
  String get titleEn {
    if (isAssessment) return '${kind.nameEn} - Juz $juzNumber';
    if (isTalqeen) return 'Talqeen - Juz $juzNumber';
    return 'Session $sessionNumber - Juz $juzNumber';
  }
```

- [ ] **Step 5: Fix the student's attempt cap**

In `lib/data/models/student_model.dart`, replace:

```dart
  /// Whether the student stands on an assessment of any tier.
  bool get isOnAssessment => canTakeSard || canTakeExam;

  /// Assessments — سرد and اختبار alike, at every tier — may be retried without
  /// limit: a student who cannot yet recite a juz keeps working at it. The
  /// 3-attempt cap belongs to ordinary lessons alone.
  bool get hasReachedMaxAttempts =>
      !isOnAssessment && currentAttempt > AppConstants.maxSessionAttempts;
```

with:

```dart
  /// Whether the student stands on an assessment of any tier.
  bool get isOnAssessment => canTakeSard || canTakeExam;

  /// Whether the student stands on a تلقين — a session the teacher reads TO
  /// them, which cannot be failed.
  bool get isOnTalqeen => currentSessionKind == SessionKind.talqeen;

  /// The 3-attempt cap belongs to ordinary lessons ALONE, and is tested for
  /// positively.
  ///
  /// Assessments — سرد and اختبار alike, at every tier — may be retried without
  /// limit: a student who cannot yet recite a juz keeps working at it. A تلقين
  /// has no attempts to exhaust: it is never graded and never failed. Written
  /// as `!isOnAssessment && ...`, this would have capped it and locked the
  /// student out of a session they cannot fail.
  bool get hasReachedMaxAttempts =>
      currentSessionKind == SessionKind.lesson &&
      currentAttempt > AppConstants.maxSessionAttempts;
```

- [ ] **Step 6: Add the constant**

In `lib/core/constants/app_constants.dart`, in the "Session kinds" block:

```dart
  // Session kinds
  static const String sessionKindTalqeen = 'talqeen';
  static const String sessionKindLesson = 'lesson';
  static const String sessionKindSard = 'sard';
  static const String sessionKindExam = 'exam';
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/unit/data/models/`
Expected: PASS.

- [ ] **Step 8: Check nothing else switched exhaustively on `SessionKind`**

Run: `flutter analyze`
Expected: no errors. A non-exhaustive `switch` on `SessionKind` anywhere in the app is a compile error, and fixing it means adding the talqeen arm — do that where analyze points, showing the talqeen the same treatment as a lesson unless a later task says otherwise.

- [ ] **Step 9: Commit**

```bash
git add lib/data/models/session_model.dart lib/data/models/student_model.dart lib/core/constants/app_constants.dart test/unit/data/models/
git commit -m "feat(curriculum): add SessionKind.talqeen and stop defining assessments by negation"
```

---

## Task 4: The two counts on the session record

**Files:**
- Modify: `lib/data/models/session_record_model.dart`
- Modify: `lib/data/repositories/session_repository.dart:31-77`
- Test: `test/unit/data/models/session_record_model_test.dart`, `test/unit/data/repositories/session_repository_test.dart`

**Interfaces:**
- Consumes: `SessionKind.talqeen` (Task 3).
- Produces:
  - `SessionRecordModel.repetitionsWithTeacher` (int, was `repetitions`) and `SessionRecordModel.homeRepetitionsRequired` (int), persisted as `repetitions_with_teacher` and `home_repetitions_required`.
  - `SessionRepository.createSessionRecord({..., required int repetitionsWithTeacher, required int homeRepetitionsRequired, String? notes})` — the old `int repetitions = 0` parameter is gone.
  - `SessionRepository.createTalqeenRecord({required String studentId, required String teacherId, required String curriculumSessionId, required int levelId, int? hizbNumber, required int sessionNumber, required int repetitionsWithTeacher, required int homeRepetitionsRequired, String? notes}) -> Future<SessionRecordModel>`.
  - `SessionRepository.getLatestSessionRecord(String studentId) -> Future<SessionRecordModel?>`.

**Context you need:**
- `repetitions` exists on the model today but **no screen ever sets it** — every record is written with 0. It is being repurposed, not duplicated. There is no data to migrate (see the spec: no real students yet).
- A talqeen record carries `SessionGrades(0, 0, 0)` and `passed: true`. It is a record that the session happened, not a grade.

- [ ] **Step 1: Write the failing tests**

In `test/unit/data/models/session_record_model_test.dart`, add:

```dart
  group('recitation counts', () {
    test('a record carries what was recited together and what is owed at home', () {
      final record = SessionRecordModel(
        id: 'r1',
        studentId: 's1',
        teacherId: 't1',
        curriculumSessionId: 'L1_J30_S2',
        levelId: 1,
        sessionNumber: 2,
        date: DateTime(2026, 7, 14),
        attemptNumber: 1,
        grades: const SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        ),
        passed: true,
        repetitionsWithTeacher: 5,
        homeRepetitionsRequired: 10,
        createdAt: DateTime(2026, 7, 14),
      );

      final json = record.toFirestore();
      expect(json['repetitions_with_teacher'], 5);
      expect(json['home_repetitions_required'], 10);
    });
  });
```

In `test/unit/data/repositories/session_repository_test.dart`, add inside the `SessionRepository` group:

```dart
    group('createTalqeenRecord', () {
      test('records a talqeen as happened, with no errors and no failure', () async {
        final record = await sessionRepository.createTalqeenRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'L1_J30_S1',
          levelId: 1,
          hizbNumber: 59,
          sessionNumber: 1,
          repetitionsWithTeacher: 4,
          homeRepetitionsRequired: 10,
        );

        expect(record.passed, isTrue);
        expect(record.grades.totalErrors, 0);
        expect(record.attemptNumber, 1);
        expect(record.repetitionsWithTeacher, 4);
        expect(record.homeRepetitionsRequired, 10);

        final stored = await fakeFirestore
            .collection('session_records')
            .doc(record.id)
            .get();
        expect(stored.data()!['home_repetitions_required'], 10);
      });
    });

    group('getLatestSessionRecord', () {
      test('returns the most recent record, which carries the home assignment', () async {
        await sessionRepository.createTalqeenRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'L1_J30_S1',
          levelId: 1,
          sessionNumber: 1,
          repetitionsWithTeacher: 3,
          homeRepetitionsRequired: 7,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final newer = await sessionRepository.createTalqeenRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'L1_J30_S2',
          levelId: 1,
          sessionNumber: 2,
          repetitionsWithTeacher: 2,
          homeRepetitionsRequired: 12,
        );

        final latest = await sessionRepository.getLatestSessionRecord('student1');
        expect(latest!.id, newer.id);
        expect(latest.curriculumSessionId, 'L1_J30_S2');
        expect(latest.homeRepetitionsRequired, 12);
      });

      test('returns null for a student with no records', () async {
        expect(await sessionRepository.getLatestSessionRecord('nobody'), isNull);
      });
    });
```

Every existing `createSessionRecord(...)` call in this test file must gain `repetitionsWithTeacher: 0, homeRepetitionsRequired: 0` — the parameters are required.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/data/models/session_record_model_test.dart test/unit/data/repositories/session_repository_test.dart`
Expected: FAIL — `The named parameter 'repetitionsWithTeacher' isn't defined`, `The method 'createTalqeenRecord' isn't defined`.

- [ ] **Step 3: Change the model**

In `lib/data/models/session_record_model.dart`, replace the `repetitions` field with the two counts. The field declaration:

```dart
  /// How many times teacher and student recited the passage through TOGETHER in
  /// the session. Carried by the sessions that teach new content — a تلقين and
  /// a lesson.
  final int repetitionsWithTeacher;

  /// How many repetitions the student owes at home before the next session. An
  /// assignment, not a note: the student sees it and their home practice counts
  /// against it.
  final int homeRepetitionsRequired;
```

The constructor parameters `this.repetitions = 0,` become:

```dart
    this.repetitionsWithTeacher = 0,
    this.homeRepetitionsRequired = 0,
```

`fromFirestore`: `repetitions: data['repetitions'] ?? 0,` becomes:

```dart
      repetitionsWithTeacher: data['repetitions_with_teacher'] ?? 0,
      homeRepetitionsRequired: data['home_repetitions_required'] ?? 0,
```

`toFirestore`: `'repetitions': repetitions,` becomes:

```dart
      'repetitions_with_teacher': repetitionsWithTeacher,
      'home_repetitions_required': homeRepetitionsRequired,
```

`copyWith`: the parameter `int? repetitions,` becomes `int? repetitionsWithTeacher,` and `int? homeRepetitionsRequired,`, and the body line becomes:

```dart
      repetitionsWithTeacher: repetitionsWithTeacher ?? this.repetitionsWithTeacher,
      homeRepetitionsRequired: homeRepetitionsRequired ?? this.homeRepetitionsRequired,
```

- [ ] **Step 4: Change the repository**

In `lib/data/repositories/session_repository.dart`, in `createSessionRecord`, replace the parameter `int repetitions = 0,` with:

```dart
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
```

and in the `SessionRecordModel(...)` construction, replace `repetitions: repetitions,` with:

```dart
      repetitionsWithTeacher: repetitionsWithTeacher,
      homeRepetitionsRequired: homeRepetitionsRequired,
```

Then add, immediately after `createSessionRecord`:

```dart
  /// Records that a تلقين happened.
  ///
  /// A تلقين is not graded: the teacher recites the new passage to the student
  /// and repeats it with him. There are no errors to count and nothing to fail,
  /// so the record carries zeroed grades and passes unconditionally — it exists
  /// for history and attendance, and to carry the home assignment.
  Future<SessionRecordModel> createTalqeenRecord({
    required String studentId,
    required String teacherId,
    required String curriculumSessionId,
    required int levelId,
    int? hizbNumber,
    required int sessionNumber,
    required int repetitionsWithTeacher,
    required int homeRepetitionsRequired,
    String? notes,
  }) async {
    final docRef = _sessionRecordsCollection.doc();
    final record = SessionRecordModel(
      id: docRef.id,
      studentId: studentId,
      teacherId: teacherId,
      curriculumSessionId: curriculumSessionId,
      levelId: levelId,
      hizbNumber: hizbNumber,
      sessionNumber: sessionNumber,
      date: DateTime.now(),
      attemptNumber: 1,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: true,
      repetitionsWithTeacher: repetitionsWithTeacher,
      homeRepetitionsRequired: homeRepetitionsRequired,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await docRef.set(record.toFirestore());
    return record;
  }

  /// The student's most recent session record — the one carrying the home
  /// assignment they are currently working off.
  Future<SessionRecordModel?> getLatestSessionRecord(String studentId) async {
    final query = await _sessionRecordsCollection
        .where('student_id', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return SessionRecordModel.fromFirestore(query.docs.first);
  }
```

- [ ] **Step 5: Fix every remaining caller**

Run: `flutter analyze`
Expected: errors at `lib/features/teacher/providers/teacher_provider.dart` (`repetitions: state!.repetitions`) and `lib/features/student/screens/session_detail_screen.dart:80` (`record.repetitions`). Task 5 rewrites the provider; for now, in `session_detail_screen.dart`, replace the block:

```dart
                      if (record.repetitions > 0)
```

with

```dart
                      if (record.repetitionsWithTeacher > 0)
```

and its `value: '${record.repetitions}',` with `value: '${record.repetitionsWithTeacher}',`.

Leave the teacher_provider error standing — Task 5 fixes it. If you need a green tree to commit, do Task 5's Step 3 first and commit both together.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/unit/data/models/session_record_model_test.dart test/unit/data/repositories/session_repository_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models/session_record_model.dart lib/data/repositories/session_repository.dart lib/features/student/screens/session_detail_screen.dart test/unit/data/
git commit -m "feat(sessions): record recitations with the teacher and repetitions owed at home"
```

---

## Task 5: Teacher provider — carry the counts, complete a talqeen

**Files:**
- Modify: `lib/features/teacher/providers/teacher_provider.dart:87-264`
- Test: `test/unit/providers/teacher_session_counts_test.dart` (create)

**Interfaces:**
- Consumes: `createSessionRecord` / `createTalqeenRecord` (Task 4), `SessionModel.isTalqeen` (Task 3).
- Produces:
  - `ActiveSessionState.repetitionsWithTeacher` and `.homeRepetitionsRequired` (both `int`, default 0), replacing `.repetitions`.
  - `ActiveSessionNotifier.setRepetitionsWithTeacher(int)`, `.setHomeRepetitionsRequired(int)` (replacing `setRepetitions`).
  - `ActiveSessionNotifier.completeTalqeenSession() -> Future<SessionRecordModel?>`.

**Context you need:**
- `completeSession()` writes the record, then advances on a pass or increments the attempt on a fail. `completeTalqeenSession()` always advances: there is no pass to test.
- The curriculum session id is always `student.currentSessionId` — never rebuilt from numbers.

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/teacher_session_counts_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';

import '../data/repositories/curriculum_fixtures.dart';

/// The provider itself needs a full Riverpod + auth container to drive, which
/// the integration tests cover. What must be pinned here is the CONTRACT the
/// provider relies on: completing a talqeen writes a passing, error-free record
/// carrying both counts, against the student's own current session id.
void main() {
  group('completing a talqeen session', () {
    late FakeFirebaseFirestore firestore;
    late SessionRepository sessions;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      sessions = SessionRepository(firestore: firestore);
    });

    test('writes a passing record with both counts and no errors', () async {
      final record = await sessions.createTalqeenRecord(
        studentId: 'student1',
        teacherId: 'teacher1',
        curriculumSessionId: 'L1_J30_S1',
        levelId: 1,
        hizbNumber: 59,
        sessionNumber: 1,
        repetitionsWithTeacher: 6,
        homeRepetitionsRequired: 15,
      );

      expect(record.curriculumSessionId, 'L1_J30_S1');
      expect(record.passed, isTrue);
      expect(record.grades.totalErrors, 0);
      expect(record.repetitionsWithTeacher, 6);
      expect(record.homeRepetitionsRequired, 15);
    });
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/unit/providers/teacher_session_counts_test.dart`
Expected: PASS if Task 4 landed (this test pins Task 4's contract, which Task 5 consumes). If it fails, Task 4 is incomplete — stop and finish it.

- [ ] **Step 3: Rewrite the state and notifier**

In `lib/features/teacher/providers/teacher_provider.dart`:

Replace the field `final int repetitions;` in `ActiveSessionState` with:

```dart
  /// How many times teacher and student recited the passage through together.
  final int repetitionsWithTeacher;

  /// How many repetitions the student owes at home before the next session.
  final int homeRepetitionsRequired;
```

Replace `this.repetitions = 0,` in the constructor with:

```dart
    this.repetitionsWithTeacher = 0,
    this.homeRepetitionsRequired = 0,
```

Replace `int? repetitions,` in `copyWith`'s parameters with:

```dart
    int? repetitionsWithTeacher,
    int? homeRepetitionsRequired,
```

and `repetitions: repetitions ?? this.repetitions,` in its body with:

```dart
      repetitionsWithTeacher: repetitionsWithTeacher ?? this.repetitionsWithTeacher,
      homeRepetitionsRequired: homeRepetitionsRequired ?? this.homeRepetitionsRequired,
```

Replace the `setRepetitions` method with:

```dart
  void setRepetitionsWithTeacher(int repetitions) {
    if (state == null) return;
    state = state!.copyWith(repetitionsWithTeacher: repetitions);
  }

  void setHomeRepetitionsRequired(int repetitions) {
    if (state == null) return;
    state = state!.copyWith(homeRepetitionsRequired: repetitions);
  }
```

In `completeSession()`, replace `repetitions: state!.repetitions,` in the `createSessionRecord` call with:

```dart
      repetitionsWithTeacher: state!.repetitionsWithTeacher,
      homeRepetitionsRequired: state!.homeRepetitionsRequired,
```

- [ ] **Step 4: Add `completeTalqeenSession`**

Add to `ActiveSessionNotifier`, immediately after `completeSession()`:

```dart
  /// Completes a تلقين session: the teacher read the new passage to the student
  /// and repeated it with him.
  ///
  /// There is nothing to grade and nothing to fail, so the student ALWAYS
  /// advances — a تلقين has no attempts to exhaust.
  Future<SessionRecordModel?> completeTalqeenSession() async {
    if (state == null) return null;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return null;

    final studentId = state!.studentId;
    final studentAsync = await ref.read(studentProvider(studentId).future);
    if (studentAsync == null) return null;

    final student = studentAsync.student;
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final studentRepo = ref.read(studentRepositoryProvider);

    final record = await sessionRepo.createTalqeenRecord(
      studentId: student.id,
      teacherId: currentUser.id,
      curriculumSessionId: student.currentSessionId,
      levelId: student.currentLevel,
      hizbNumber: student.currentHizb,
      sessionNumber: student.currentSession,
      repetitionsWithTeacher: state!.repetitionsWithTeacher,
      homeRepetitionsRequired: state!.homeRepetitionsRequired,
      notes: state!.notes,
    );

    final advanceOutcome = await studentRepo.advanceStudentSession(student.id);

    state = state!.copyWith(isComplete: true, advanceOutcome: advanceOutcome);

    ref.invalidate(teacherStudentsProvider);
    ref.invalidate(studentProvider(studentId));

    return record;
  }
```

- [ ] **Step 5: Verify the tree compiles**

Run: `flutter analyze`
Expected: no errors (Task 4's `teacher_provider.dart` error is now resolved).

- [ ] **Step 6: Run the unit suite**

Run: `flutter test test/unit/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/teacher/providers/teacher_provider.dart test/unit/providers/teacher_session_counts_test.dart
git commit -m "feat(teacher): carry the recitation counts and complete a تلقين session"
```

---

## Task 6: The counts card, and the lesson summary screen that uses it

**Files:**
- Create: `lib/features/teacher/widgets/recitation_counts_card.dart`
- Modify: `lib/features/teacher/screens/session_summary_screen.dart`
- Test: `test/widget/recitation_counts_card_test.dart` (create)

**Interfaces:**
- Consumes: `ActiveSessionNotifier.setRepetitionsWithTeacher` / `.setHomeRepetitionsRequired` (Task 5).
- Produces: `RecitationCountsCard({Key? key, required int repetitionsWithTeacher, required int homeRepetitionsRequired, required ValueChanged<int> onRepetitionsWithTeacherChanged, required ValueChanged<int> onHomeRepetitionsRequiredChanged})` — a stateless card of two steppers, reused by Task 7's talqeen screen.

**Context you need:**
- The existing stepper idiom in this codebase is `IconButton(Icons.remove) / value / IconButton(Icons.add)` — see `lib/features/student/screens/home_practice_screen.dart:255-295`.
- Shared widgets: `AppCard` (`lib/shared/widgets/app_card.dart`), colors in `lib/core/constants/app_colors.dart`.
- Counts floor at 0; there is no maximum.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/recitation_counts_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/widgets/recitation_counts_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int withTeacher,
    required int atHome,
    required ValueChanged<int> onWithTeacher,
    required ValueChanged<int> onAtHome,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RecitationCountsCard(
              repetitionsWithTeacher: withTeacher,
              homeRepetitionsRequired: atHome,
              onRepetitionsWithTeacherChanged: onWithTeacher,
              onHomeRepetitionsRequiredChanged: onAtHome,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows both counts under their Arabic labels', (tester) async {
    await pump(
      tester,
      withTeacher: 4,
      atHome: 10,
      onWithTeacher: (_) {},
      onAtHome: (_) {},
    );

    expect(find.text('عدد مرات القراءة مع الطالب'), findsOneWidget);
    expect(find.text('عدد مرات التكرار في المنزل'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('incrementing a count reports the new value', (tester) async {
    int? reported;
    await pump(
      tester,
      withTeacher: 4,
      atHome: 10,
      onWithTeacher: (v) => reported = v,
      onAtHome: (_) {},
    );

    await tester.tap(find.byKey(const Key('increment_repetitions_with_teacher')));
    expect(reported, 5);
  });

  testWidgets('a count never goes below zero', (tester) async {
    int? reported;
    await pump(
      tester,
      withTeacher: 0,
      atHome: 0,
      onWithTeacher: (v) => reported = v,
      onAtHome: (_) {},
    );

    await tester.tap(find.byKey(const Key('decrement_repetitions_with_teacher')));
    expect(reported, isNull);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/widget/recitation_counts_card_test.dart`
Expected: FAIL — `Target of URI doesn't exist: recitation_counts_card.dart`.

- [ ] **Step 3: Write the widget**

Create `lib/features/teacher/widgets/recitation_counts_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_card.dart';

/// The two counts a teacher records on every session that teaches new content —
/// a تلقين and a lesson alike.
///
/// The home figure is an ASSIGNMENT, not a note: the student sees it and their
/// home practice counts against it.
class RecitationCountsCard extends StatelessWidget {
  final int repetitionsWithTeacher;
  final int homeRepetitionsRequired;
  final ValueChanged<int> onRepetitionsWithTeacherChanged;
  final ValueChanged<int> onHomeRepetitionsRequiredChanged;

  const RecitationCountsCard({
    super.key,
    required this.repetitionsWithTeacher,
    required this.homeRepetitionsRequired,
    required this.onRepetitionsWithTeacherChanged,
    required this.onHomeRepetitionsRequiredChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountStepper(
            label: 'عدد مرات القراءة مع الطالب',
            keyPrefix: 'repetitions_with_teacher',
            value: repetitionsWithTeacher,
            onChanged: onRepetitionsWithTeacherChanged,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _CountStepper(
            label: 'عدد مرات التكرار في المنزل',
            keyPrefix: 'home_repetitions_required',
            value: homeRepetitionsRequired,
            onChanged: onHomeRepetitionsRequiredChanged,
          ),
        ],
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  final String label;
  final String keyPrefix;
  final int value;
  final ValueChanged<int> onChanged;

  const _CountStepper({
    required this.label,
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        IconButton(
          key: Key('decrement_$keyPrefix'),
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.textSecondary,
          // A count cannot go below zero: a session recited a negative number
          // of times is not a thing a teacher can report.
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        IconButton(
          key: Key('increment_$keyPrefix'),
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/widget/recitation_counts_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Put the card on the lesson summary screen**

In `lib/features/teacher/screens/session_summary_screen.dart`, add the import:

```dart
import '../widgets/recitation_counts_card.dart';
```

and insert this block in `build`, between the part-by-part results block and the `// Notes` section (i.e. after the `const SizedBox(height: 24),` that follows the grades `studentAsync.when(...)`):

```dart
            // The two counts. Recorded before the session is ended, on every
            // session that teaches new content.
            Text(
              'التكرار',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            RecitationCountsCard(
              repetitionsWithTeacher: activeSession.repetitionsWithTeacher,
              homeRepetitionsRequired: activeSession.homeRepetitionsRequired,
              onRepetitionsWithTeacherChanged: ref
                  .read(activeSessionProvider.notifier)
                  .setRepetitionsWithTeacher,
              onHomeRepetitionsRequiredChanged: ref
                  .read(activeSessionProvider.notifier)
                  .setHomeRepetitionsRequired,
            ),

            const SizedBox(height: 24),
```

- [ ] **Step 6: Run the widget suite**

Run: `flutter test test/widget/ && flutter analyze`
Expected: PASS, no analyzer errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/teacher/widgets/recitation_counts_card.dart lib/features/teacher/screens/session_summary_screen.dart test/widget/recitation_counts_card_test.dart
git commit -m "feat(teacher): record the recitation counts before ending a lesson"
```

---

## Task 7: The talqeen session screen

**Files:**
- Create: `lib/features/teacher/screens/talqeen_session_screen.dart`
- Modify: `lib/routing/app_router.dart`
- Modify: `lib/features/teacher/screens/session_overview_screen.dart`
- Test: `test/widget/talqeen_session_screen_test.dart` (create)

**Interfaces:**
- Consumes: `RecitationCountsCard` (Task 6), `ActiveSessionNotifier.completeTalqeenSession` (Task 5), `SessionModel.isTalqeen` (Task 3).
- Produces: route `AppRoutes.talqeenSession = '/teacher/session/:studentId/talqeen'`; screen `TalqeenSessionScreen({required String studentId})`.

**Context you need:**
- `session_overview_screen.dart` branches on kind at line ~138: `isExam` → exam card, `isSard` → sard card, otherwise the regular lesson card. A talqeen needs its own branch **before** the fallthrough, or it will be started as a graded recitation.
- Routes are declared in `AppRoutes` (line ~86) and registered in the teacher branch of the router (line ~356). Navigation is `context.push(AppRoutes.x.replaceFirst(':studentId', studentId))`.
- The screen shows the passage (`session.currentLevelContent!.rangeAr`), the two counts, and one save button. **No error counters and no grade** — a talqeen has neither.
- On save it calls `completeTalqeenSession()`, then `context.go(AppRoutes.teacherStudents)`, mirroring `session_summary_screen._saveSession()`'s handling of `StudentAdvanceOutcome.curriculumDataMissing` / `studentNotFound`.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/talqeen_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/teacher/screens/talqeen_session_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';

void main() {
  const session = SessionModel(
    id: 'L1_J30_S1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    orderInLevel: 1,
    kind: SessionKind.talqeen,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 11,
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCurrentSessionProvider('s1').overrideWith((ref) async => session),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: TalqeenSessionScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the passage the teacher reads to the student', (tester) async {
    await pump(tester);

    expect(find.text('تلقين'), findsWidgets);
    expect(find.text('النبأ: 1 - 11'), findsOneWidget);
  });

  testWidgets('offers the two counts and no error entry', (tester) async {
    await pump(tester);

    expect(find.text('عدد مرات القراءة مع الطالب'), findsOneWidget);
    expect(find.text('عدد مرات التكرار في المنزل'), findsOneWidget);
    // A تلقين is never graded: nothing on this screen counts errors.
    expect(find.textContaining('أخطاء'), findsNothing);
    expect(find.textContaining('نتيجة'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/widget/talqeen_session_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: talqeen_session_screen.dart`.

- [ ] **Step 3: Write the screen**

Create `lib/features/teacher/screens/talqeen_session_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_provider.dart';
import '../widgets/recitation_counts_card.dart';

/// A تلقين session: the teacher recites the new passage TO the student and
/// repeats it with him until he reads it correctly.
///
/// The student memorizes nothing here and recites nothing alone. There are no
/// errors to count, no grade, and no way to fail — the session always advances.
/// What the teacher records is how many times they read it through together,
/// and how many repetitions the student owes at home.
class TalqeenSessionScreen extends ConsumerStatefulWidget {
  final String studentId;

  const TalqeenSessionScreen({super.key, required this.studentId});

  @override
  ConsumerState<TalqeenSessionScreen> createState() =>
      _TalqeenSessionScreenState();
}

class _TalqeenSessionScreenState extends ConsumerState<TalqeenSessionScreen> {
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final record = await ref
          .read(activeSessionProvider.notifier)
          .completeTalqeenSession();

      final advanceOutcome = ref.read(activeSessionProvider)?.advanceOutcome;
      final progressNotAdvanced =
          advanceOutcome == StudentAdvanceOutcome.curriculumDataMissing ||
          advanceOutcome == StudentAdvanceOutcome.studentNotFound;

      if (record != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              progressNotAdvanced
                  ? 'تم حفظ التلقين، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
                        'تالية في المنهج.'
                  : 'تم حفظ التلقين',
            ),
            backgroundColor: progressNotAdvanced
                ? AppColors.error
                : AppColors.success,
          ),
        );
        context.go(AppRoutes.teacherStudents);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(
      studentCurrentSessionProvider(widget.studentId),
    );
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تلقين'),
        automaticallyImplyLeading: false,
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null || !session.isTalqeen) {
            return const Center(child: Text('لا توجد بيانات للتلقين'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المقطع الجديد',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.currentLevelContent?.rangeAr ?? '',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الجزء ${session.juzNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'اقرأ المقطع على الطالب وردده معه حتى يقرأه قراءة صحيحة. '
                        'لا يسمّع الطالب في هذه الحلقة.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'التكرار',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                RecitationCountsCard(
                  repetitionsWithTeacher:
                      activeSession?.repetitionsWithTeacher ?? 0,
                  homeRepetitionsRequired:
                      activeSession?.homeRepetitionsRequired ?? 0,
                  onRepetitionsWithTeacherChanged: ref
                      .read(activeSessionProvider.notifier)
                      .setRepetitionsWithTeacher,
                  onHomeRepetitionsRequiredChanged: ref
                      .read(activeSessionProvider.notifier)
                      .setHomeRepetitionsRequired,
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'حفظ وإنهاء التلقين',
                  onPressed: _save,
                  isLoading: _isSaving,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 4: Register the route**

In `lib/routing/app_router.dart`, add to `AppRoutes` beside the other teacher session routes (~line 92):

```dart
  static const String talqeenSession = '/teacher/session/:studentId/talqeen';
```

Import the screen at the top of the file, alongside the other teacher screen imports:

```dart
import '../features/teacher/screens/talqeen_session_screen.dart';
```

and register it in the teacher branch, immediately after the `AppRoutes.sessionSummary` route:

```dart
              GoRoute(
                path: AppRoutes.talqeenSession,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return TalqeenSessionScreen(studentId: studentId);
                },
              ),
```

- [ ] **Step 5: Branch the session overview onto it**

In `lib/features/teacher/screens/session_overview_screen.dart`, inside `sessionAsync.when(data: (session) {...})`, add a talqeen branch **before** the `isExam` check:

```dart
                    // What this session IS comes from the curriculum's own
                    // `kind`, never from its number.
                    if (session.isTalqeen) {
                      return _buildTalqeenCard(context, session, studentId, ref);
                    }

                    if (session.isExam) {
```

and add this method to the class, beside `_buildRegularSessionCard`:

```dart
  Widget _buildTalqeenCard(
    BuildContext context,
    SessionModel session,
    String studentId,
    WidgetRef ref,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.record_voice_over,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تلقين',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'الجزء ${session.juzNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'المقطع الجديد',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session.currentLevelContent?.rangeAr ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'يقرأ المعلّم المقطع على الطالب ويردده معه. لا تسميع ولا تقييم في '
            'هذه الحلقة.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          // No attempt cap: a تلقين cannot be failed, so it cannot be exhausted.
          AppButton(
            text: 'بدء التلقين',
            onPressed: () {
              ref.read(activeSessionProvider.notifier).startSession(studentId);
              context.push(
                AppRoutes.talqeenSession.replaceFirst(':studentId', studentId),
              );
            },
            isFullWidth: true,
            icon: Icons.play_arrow,
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/widget/talqeen_session_screen_test.dart && flutter analyze`
Expected: PASS, no analyzer errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/teacher/screens/talqeen_session_screen.dart lib/features/teacher/screens/session_overview_screen.dart lib/routing/app_router.dart test/widget/talqeen_session_screen_test.dart
git commit -m "feat(teacher): teach a تلقين session — read the passage, record the counts, advance"
```

---

## Task 8: Attribute home practice to the session it was assigned in

**Files:**
- Modify: `lib/data/models/home_practice_model.dart`
- Modify: `lib/data/repositories/home_practice_repository.dart:23-46`
- Modify: `lib/features/student/providers/student_provider.dart:212-250`
- Test: `test/unit/data/repositories/home_practice_repository_test.dart` (create)

**Interfaces:**
- Consumes: `SessionRepository.getLatestSessionRecord` (Task 4).
- Produces:
  - `HomePracticeModel.curriculumSessionId` (`String`, persisted as `curriculum_session_id`, defaults to `''` for a practice logged with no assignment).
  - `HomePracticeRepository.createHomePractice({..., required String curriculumSessionId})`.
  - `homeAssignmentProvider` — a `FutureProvider<HomeAssignment?>` exposing the current assignment (Task 9 renders it).

**Context you need — this is a real bug, not a nicety:**
`HomePracticeNotifier.addPractice` stamps each practice with `student.currentLevel / currentJuz / currentSession`. But the teacher **advances** the student when the session ends, so by the time the student practises at home, `currentSession` is the session *after* the one the homework came from. Every logged repetition is filed against the wrong session today. The assignment lives on the student's latest session record, and that is what the practice must be attributed to.

- [ ] **Step 1: Write the failing test**

Create `test/unit/data/repositories/home_practice_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';

void main() {
  group('HomePracticeRepository', () {
    late FakeFirebaseFirestore firestore;
    late HomePracticeRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = HomePracticeRepository(firestore: firestore);
    });

    test('a practice is attributed to the session it was assigned in', () async {
      // The student was told to repeat L1_J30_S2's passage 10 times at home,
      // and has since been advanced to S3. The practice belongs to S2.
      final id = await repository.createHomePractice(
        studentId: 'student1',
        curriculumSessionId: 'L1_J30_S2',
        levelId: 1,
        juzNumber: 30,
        hizbNumber: 59,
        sessionNumber: 2,
        repetitions: 4,
      );

      final stored = await firestore.collection('home_practice').doc(id).get();
      expect(stored.data()!['curriculum_session_id'], 'L1_J30_S2');

      final practices = await repository.getHomePracticesForStudent('student1');
      expect(practices.single.curriculumSessionId, 'L1_J30_S2');
      expect(practices.single.repetitions, 4);
    });
  });
}
```

Confirm the collection name in `home_practice_repository.dart` (`_collection`) and use it in the assertion above if it is not `home_practice`.

- [ ] **Step 2: Run it**

Run: `flutter test test/unit/data/repositories/home_practice_repository_test.dart`
Expected: FAIL — `The named parameter 'curriculumSessionId' isn't defined`.

- [ ] **Step 3: Add the field to the model**

In `lib/data/models/home_practice_model.dart`, add the field after `studentId`:

```dart
  /// The curriculum session this practice was ASSIGNED in — the session whose
  /// record carries `home_repetitions_required`.
  ///
  /// Not the student's current session: the teacher advances the student when
  /// the session ends, so by the time they practise at home their current
  /// session is the one AFTER the assignment. Attributing practice to the
  /// current position files every repetition against the wrong session.
  final String curriculumSessionId;
```

Add `required this.curriculumSessionId,` to the constructor, `curriculumSessionId: data['curriculum_session_id'] ?? '',` to `fromFirestore`, and `'curriculum_session_id': curriculumSessionId,` to `toFirestore`.

- [ ] **Step 4: Add it to the repository**

In `createHomePractice`, add the parameter `required String curriculumSessionId,` and the field `'curriculum_session_id': curriculumSessionId,` to the document written.

- [ ] **Step 5: Stamp it from the latest record**

In `lib/features/student/providers/student_provider.dart`, add near the other providers:

```dart
/// The home assignment the student is currently working off: the passage, how
/// many repetitions they owe, and how many they have logged against it.
class HomeAssignment {
  final String curriculumSessionId;
  final int repetitionsRequired;
  final int repetitionsDone;

  const HomeAssignment({
    required this.curriculumSessionId,
    required this.repetitionsRequired,
    required this.repetitionsDone,
  });

  bool get isComplete => repetitionsDone >= repetitionsRequired;
}

/// Null when the student has no record yet, or when their last session assigned
/// no home repetitions.
final homeAssignmentProvider = FutureProvider<HomeAssignment?>((ref) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) return null;

  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final record = await sessionRepo.getLatestSessionRecord(student.id);
  if (record == null || record.homeRepetitionsRequired <= 0) return null;

  final practices = await ref
      .watch(homePracticeRepositoryProvider)
      .getHomePracticesForStudent(student.id);

  final done = practices
      .where((p) => p.curriculumSessionId == record.curriculumSessionId)
      .fold<int>(0, (total, p) => total + p.repetitions);

  return HomeAssignment(
    curriculumSessionId: record.curriculumSessionId,
    repetitionsRequired: record.homeRepetitionsRequired,
    repetitionsDone: done,
  );
});
```

Add the import for `sessionRepositoryProvider` if it is not already present:

```dart
import '../../../data/repositories/session_repository.dart';
```

Then rewrite `HomePracticeNotifier.addPractice` to attribute the practice to the assignment rather than the student's current position:

```dart
  Future<bool> addPractice({required int repetitions, String? notes}) async {
    state = const AsyncValue.loading();

    try {
      final student = await ref.read(currentStudentProvider.future);
      if (student == null) {
        state = AsyncValue.error('Student not found', StackTrace.current);
        return false;
      }

      // The practice belongs to the session it was ASSIGNED in, which is the
      // student's last completed session — NOT the session they now stand on.
      // The teacher advanced them when that session ended.
      final sessionRepo = ref.read(sessionRepositoryProvider);
      final lastRecord = await sessionRepo.getLatestSessionRecord(student.id);

      final repo = ref.read(homePracticeRepositoryProvider);
      await repo.createHomePractice(
        studentId: student.id,
        curriculumSessionId: lastRecord?.curriculumSessionId ?? '',
        levelId: lastRecord?.levelId ?? student.currentLevel,
        juzNumber: student.currentJuz,
        hizbNumber: lastRecord?.hizbNumber ?? student.currentHizb,
        sessionNumber: lastRecord?.sessionNumber ?? student.currentSession,
        repetitions: repetitions,
        notes: notes,
      );

      ref.invalidate(studentHomePracticesProvider);
      ref.invalidate(todaysPracticesProvider);
      ref.invalidate(thisWeeksPracticesProvider);
      ref.invalidate(homePracticeStatsProvider);
      ref.invalidate(homeAssignmentProvider);

      state = const AsyncValue.data(null);
      return true;
```

- [ ] **Step 6: Fix the remaining callers**

Run: `flutter analyze`
Expected: errors wherever `HomePracticeModel(...)` is constructed or `createHomePractice` is called without `curriculumSessionId` — including `test/widget/home_practice_hizb_test.dart`. Add the parameter at each site; in tests, a literal like `'L1_J30_S2'` is right.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/unit/ test/widget/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/data/models/home_practice_model.dart lib/data/repositories/home_practice_repository.dart lib/features/student/providers/student_provider.dart test/unit/data/repositories/home_practice_repository_test.dart test/widget/home_practice_hizb_test.dart
git commit -m "fix(student): attribute home practice to the session it was assigned in"
```

---

## Task 9: Show the student what they owe

**Files:**
- Create: `lib/features/student/widgets/home_assignment_card.dart`
- Modify: `lib/features/student/screens/home_practice_screen.dart`
- Test: `test/widget/home_assignment_card_test.dart` (create)

**Interfaces:**
- Consumes: `homeAssignmentProvider` and `HomeAssignment` (Task 8).
- Produces: `HomeAssignmentCard()` — a `ConsumerWidget` that renders the assignment, or nothing when there is none.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget/home_assignment_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/widgets/home_assignment_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, HomeAssignment? assignment) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeAssignmentProvider.overrideWith((ref) async => assignment),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: HomeAssignmentCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the repetitions owed and those already done', (tester) async {
    await pump(
      tester,
      const HomeAssignment(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 10,
        repetitionsDone: 4,
      ),
    );

    expect(find.text('واجب التكرار في المنزل'), findsOneWidget);
    expect(find.text('4 / 10'), findsOneWidget);
  });

  testWidgets('says so when the assignment is done', (tester) async {
    await pump(
      tester,
      const HomeAssignment(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 10,
        repetitionsDone: 10,
      ),
    );

    expect(find.text('اكتمل الواجب'), findsOneWidget);
  });

  testWidgets('renders nothing when no repetitions were assigned', (tester) async {
    await pump(tester, null);

    expect(find.text('واجب التكرار في المنزل'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/widget/home_assignment_card_test.dart`
Expected: FAIL — `Target of URI doesn't exist: home_assignment_card.dart`.

- [ ] **Step 3: Write the widget**

Create `lib/features/student/widgets/home_assignment_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/student_provider.dart';

/// What the teacher told the student to repeat at home, and how far they have
/// got. Renders nothing when the last session assigned no repetitions.
class HomeAssignmentCard extends ConsumerWidget {
  const HomeAssignmentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(homeAssignmentProvider);

    return assignmentAsync.when(
      data: (assignment) {
        if (assignment == null) return const SizedBox.shrink();

        final progress =
            (assignment.repetitionsDone / assignment.repetitionsRequired)
                .clamp(0.0, 1.0);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'واجب التكرار في المنزل',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${assignment.repetitionsDone} / '
                    '${assignment.repetitionsRequired}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: assignment.isComplete
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    assignment.isComplete
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ),
              if (assignment.isComplete) ...[
                const SizedBox(height: 8),
                Text(
                  'اكتمل الواجب',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
```

Note: `4 / 10` must render as a single `Text` for the test's `find.text('4 / 10')` to match — the interpolation above produces exactly that string.

- [ ] **Step 4: Put it on the home practice screen**

In `lib/features/student/screens/home_practice_screen.dart`, import the widget:

```dart
import '../widgets/home_assignment_card.dart';
```

and insert `const HomeAssignmentCard(),` followed by `const SizedBox(height: 16),` as the first children of the screen's main scrolling `Column` — above the repetition entry, so the student sees what they owe before they log against it.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/widget/ && flutter analyze`
Expected: PASS, no analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/student/widgets/home_assignment_card.dart lib/features/student/screens/home_practice_screen.dart test/widget/home_assignment_card_test.dart
git commit -m "feat(student): show the home repetitions owed and the progress against them"
```

---

## Task 10: Fixtures, integration tests, and the reseed

**Files:**
- Modify: `test/unit/data/repositories/curriculum_fixtures.dart`
- Modify: `test/unit/data/repositories/curriculum_repository_test.dart`, `student_repository_test.dart`
- Modify: `integration_test/student_flow_test.dart`, `integration_test/supervisor_flow_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: a test corpus whose shape matches the regenerated data — units open with a talqeen.

**Context you need:**
- `seedSession()` already takes `String kind = 'lesson'`, so seeding a talqeen is `seedSession(..., kind: 'talqeen', unitIndex: 1)`.
- The level-1 fixtures mirror the REAL numbering, and every number in them has shifted. The authoritative new numbering for level 1 (verified against the regenerated data):

| | juz 30 | juz 29 | juz 28 |
|---|---|---|---|
| sessions | 70 | 71 | 69 |
| `first_order_in_level` | 1 | 71 | 142 |

  Within juz 30: **S1** the تلقين opening hizb 59, S2..S30 its lessons, **S31** the hizb-59 سرد, **S32** its اختبار, **S33** the تلقين opening hizb 60, S34..S66 its lessons, **S67/S68** the hizb-60 pair, **S69/S70** the juz-30 pair. Level 1 totals **210**; its last two sessions (the cumulative pair, in juz 28) are S68/S69 at orders 209/210. Level 2 totals **154**, its juz 27 **53**.
- `advanceStudentSession` moves to `order_in_level + 1` and reads the session there — it needs no change, but a test proving a student steps *out of* a talqeen and *into* the lesson it introduces is what pins the whole feature end to end.
- `seedStudent` is a local helper inside `student_repository_test.dart` (~line 100) and already takes a `kind` — no change needed to it.

- [ ] **Step 1: Renumber the curriculum fixtures**

In `test/unit/data/repositories/curriculum_fixtures.dart`:

Replace the level-1 layout paragraph of the header comment with:

```dart
/// Level 1, juz 30 (as extracted):
/// - S1 the تلقين that opens hizb 59, S2..S30 its lessons,
/// - S31 the hizb-59 سرد, S32 its اختبار,
/// - S33 the تلقين that opens hizb 60, S34..S66 its lessons,
/// - S67/S68 the hizb-60 pair, S69 the juz-30 سرد, S70 its اختبار.
/// Level 1's juz run 30 → 29 → 28 (orders 1-70, 71-141, 142-210).
/// Level 10's juz run 1 → 2 → 3 — ASCENDING.
/// A تلقين opens every unit: the teacher reads the next lesson's passage to the
/// student, who memorizes and recites nothing.
```

In `seedLevelOneJuz30`, prepend the talqeen and renumber everything after it. The whole function becomes:

```dart
Future<void> seedLevelOneJuz30(FakeFirebaseFirestore firestore) async {
  // Every unit opens with a تلقين: the teacher reads the next lesson's passage
  // to the student.
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 1,
    order: 1,
    kind: 'talqeen',
    hizb: 59,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 2,
    order: 2,
    hizb: 59,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 3,
    order: 3,
    hizb: 59,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 31,
    order: 31,
    kind: 'sard',
    assessedBy: 'teacher',
    unitIndex: 1,
    hizb: 59,
    tier: 'unit',
    labelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 32,
    order: 32,
    kind: 'exam',
    assessedBy: 'supervisor',
    unitIndex: 1,
    hizb: 59,
    tier: 'unit',
    labelAr: 'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
  );
  // The اختبار of hizb 59 is followed by the تلقين that opens hizb 60.
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 33,
    order: 33,
    kind: 'talqeen',
    hizb: 60,
    unitIndex: 2,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 69,
    order: 69,
    kind: 'sard',
    assessedBy: 'teacher',
    tier: 'juz',
    labelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 70,
    order: 70,
    kind: 'exam',
    assessedBy: 'supervisor',
    tier: 'juz',
    labelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
  );
}
```

In `seedLevelOneJuz29`, juz 29 now opens with a تلقين and its orders start at 71. Its doc comment's "runs on from 69" becomes "runs on from 71", and the body becomes:

```dart
  await seedSession(
    firestore,
    level: 1,
    juz: 29,
    session: 1,
    order: 71,
    kind: 'talqeen',
    hizb: 57,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 29,
    session: 2,
    order: 72,
    hizb: 57,
    unitIndex: 1,
  );
```

In `seedLevelOneTail`, the cumulative pair moves from S66/S67 at orders 203/204 to **S68/S69 at orders 209/210** (change `session:` and `order:` on both calls; its doc comment's "at order 204" becomes "at order 210"). Nothing else in it changes.

In `seedLevelTwoHead`, juz 27 now opens with a تلقين — add `kind: 'talqeen',` to its single `seedSession` call.

In `seedLevels`, level 1's `session_count` becomes `210`, and its juz entries become `{30: 70, first_order 1}`, `{29: 71, first_order 71}`, `{28: 69, first_order 142}`. Level 2's `session_count` becomes `154` and its juz-27 `session_count` becomes `53`.

Then run `flutter test test/unit/data/repositories/` and fix the assertions that named the old numbers (e.g. any test expecting a level-1 progress denominator of 204, or the juz-30 اختبار at S68). The numbers change; the assertions must not be weakened.

- [ ] **Step 2: Write the failing advancement test**

Add to `test/unit/data/repositories/student_repository_test.dart`, in the `advanceStudentSession` group:

```dart
      test('a student steps out of a talqeen into the lesson it introduces', () async {
        await seedSession(
          fakeFirestore,
          level: 1,
          juz: 30,
          session: 1,
          order: 1,
          kind: 'talqeen',
          unitIndex: 1,
          hizb: 59,
        );
        await seedSession(
          fakeFirestore,
          level: 1,
          juz: 30,
          session: 2,
          order: 2,
          kind: 'lesson',
          unitIndex: 1,
          hizb: 59,
        );
        await seedStudent(
          fakeFirestore,
          id: 'student1',
          level: 1,
          juz: 30,
          session: 1,
          order: 1,
          kind: 'talqeen',
        );

        final outcome = await studentRepository.advanceStudentSession('student1');
        expect(outcome, StudentAdvanceOutcome.advanced);

        final student = await studentRepository.getStudentById('student1');
        expect(student!.currentSessionId, 'L1_J30_S2');
        expect(student.currentSessionKind, SessionKind.lesson);
        expect(student.currentOrderInLevel, 2);
      });
```

Match `seedStudent`'s real signature in that file — if it does not take a `kind`, seed the student document directly the way the neighbouring tests do, with `current_session_kind: 'talqeen'`.

- [ ] **Step 3: Run it**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart`
Expected: PASS — advancement is by `order_in_level` and already kind-agnostic. If it fails, something in Task 3 broke the advance path; fix that before continuing.

- [ ] **Step 4: Run the whole suite**

Run: `flutter test`
Expected: PASS. Any remaining failures will be tests that hard-code the old session numbering or construct `SessionRecordModel` / `HomePracticeModel` without the new fields — update them to the new shape; do not weaken the assertions.

- [ ] **Step 5: Reseed the curriculum**

The importer already knows a re-import must purge first — stale documents under superseded ids would still satisfy every `level_id` / `juz_number` query. Dry-run it, then purge and write:

```bash
cd tools/curriculum
node import_curriculum.mjs --dry-run
node import_curriculum.mjs --purge --write
```

Expected: the dry run reports 952 sessions across 10 levels; the write purges the `sessions` collection and imports them.

Then delete and recreate any test students, so their `current_session_id` and `current_order_in_level` refer to the new numbering. **Do not attempt a partial update:** every session id after a unit boundary has shifted.

Verify afterwards: a student placed at the start of level 1 stands on `L1_J30_S1` with `current_session_kind: 'talqeen'`.

- [ ] **Step 6: Run the integration tests**

Run: `flutter test integration_test/` (start the Firebase emulators first if the helpers require them — see `integration_test/helpers/firebase_emulator_app.dart`).
Expected: PASS.

- [ ] **Step 7: Commit and close the issue**

```bash
git add test/ integration_test/
git commit -m "test: pin the تلقين numbering and advancement across the suite"
bd close al_rasikhoon-i00
git pull --rebase && bd dolt push && git push
```

---

## Verification

After Task 10, the following must all be true:

1. `cd tools/curriculum && python -m pytest test_extract_curriculum.py -v` — green, including the 59-talqeen and 952-session assertions.
2. `flutter test` — green.
3. `flutter analyze` — no errors.
4. `data/curriculum/metadata.json` reads `"total_sessions": 952`, `"schema_version": 3`.
5. In the running app, a student at the start of level 1 stands on a تلقين: the teacher's session overview offers "بدء التلقين", the screen shows النبأ 1-11 with no error counters, and saving it records both counts and advances the student to the lesson that memorizes the same passage.
