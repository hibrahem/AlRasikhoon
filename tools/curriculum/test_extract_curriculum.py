"""Golden tests over three real juz that exercise all three source layouts.

  * Level 1 juz 30  — one merged sheet, halves ascending by hizb (59 then 60).
  * Level 2 juz 27  — two half-workbooks, DESCENDING (hizb 54 taught first),
                      carrying the known contradictory hizb marker text.
  * Level 3 juz 22  — the duplicate-workbook layout (Sheet1 + 'Sheet1 (2)' are
                      identical in both files) with surah-scoped labels.

Every number asserted here was read off the source spreadsheets, not assumed.
"""

import pytest

import extract_curriculum as ex


@pytest.fixture(scope="session")
def corpus():
    levels, sessions_by_level, errors, warnings, anomalies = ex.extract()
    return {
        "levels": levels,
        "sessions": sessions_by_level,
        "errors": errors,
        "warnings": warnings,
        "anomalies": anomalies,
    }


def juz_sessions(corpus, level, juz):
    return [s for s in corpus["sessions"][level] if s["juz_number"] == juz]


def by_number(sessions):
    return {s["session_number"]: s for s in sessions}


# ---------------------------------------------------------------- corpus-wide
def test_extraction_of_the_whole_curriculum_is_valid(corpus):
    assert corpus["errors"] == []


def test_document_ids_are_unique_across_the_corpus(corpus):
    ids = [s["id"] for ss in corpus["sessions"].values() for s in ss]
    assert len(ids) == len(set(ids))


def test_every_session_carries_its_source_row(corpus):
    for sessions in corpus["sessions"].values():
        for s in sessions:
            assert s["source"]["file"] and s["source"]["sheet"]
            assert isinstance(s["source"]["row"], int)


def test_no_session_is_typed_by_number(corpus):
    """The old extractor typed 34/35/36 as statistics/sard/exam. Nothing may."""
    for sessions in corpus["sessions"].values():
        for s in sessions:
            if s["kind"] in ("sard", "exam"):
                assert s["scope"] is not None
                assert s["scope"]["label_ar"].startswith(("سرد", "اختبار"))
            else:
                assert s["kind"] == "lesson"
                assert s["scope"] is None


# ------------------------------------------------- Level 1, juz 30 (merged sheet)
def test_level_1_juz_30_has_68_sessions(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    assert len(sessions) == 68
    assert [s["session_number"] for s in sessions] == list(range(1, 69))


def test_level_1_juz_30_unit_pairs_land_on_30_31_and_65_66(corpus):
    s = by_number(juz_sessions(corpus, 1, 30))

    assert s[30]["kind"] == "sard"
    assert s[30]["assessed_by"] == "teacher"
    assert s[30]["scope"]["tier"] == "unit"
    assert s[30]["scope"]["hizb_number"] == 59
    assert s[30]["unit_index"] == 1
    assert s[31]["kind"] == "exam"
    assert s[31]["assessed_by"] == "supervisor"
    assert s[31]["scope"]["tier"] == "unit"

    assert s[65]["kind"] == "sard"
    assert s[65]["scope"]["tier"] == "unit"
    assert s[65]["scope"]["hizb_number"] == 60
    assert s[65]["unit_index"] == 2
    assert s[66]["kind"] == "exam"
    assert s[66]["scope"]["tier"] == "unit"


def test_level_1_juz_30_juz_pair_lands_on_67_68(corpus):
    s = by_number(juz_sessions(corpus, 1, 30))
    assert s[67]["kind"] == "sard"
    assert s[67]["scope"]["tier"] == "juz"
    assert s[67]["scope"]["juz_numbers"] == [30]
    assert s[67]["scope"]["hizb_number"] is None
    assert s[67]["hizb_number"] is None  # a juz-tier assessment belongs to no half
    assert s[68]["kind"] == "exam"
    assert s[68]["scope"]["tier"] == "juz"


def test_level_1_juz_30_teaches_hizb_59_before_60(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    lessons = [s for s in sessions if s["kind"] == "lesson"]
    assert lessons[0]["hizb_number"] == 59
    assert lessons[-1]["hizb_number"] == 60


def test_level_1_juz_30_has_no_lesson_typed_as_an_assessment(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    assessments = [s["session_number"] for s in sessions if s["kind"] != "lesson"]
    assert assessments == [30, 31, 65, 66, 67, 68]
    for s in sessions:
        if s["kind"] == "lesson":
            assert s["current_level_content"] or s["recent_review_content"]


def test_level_1_juz_30_is_taught_first_so_carries_no_cumulative(corpus):
    tiers = {s["scope"]["tier"] for s in juz_sessions(corpus, 1, 30) if s["scope"]}
    assert tiers == {"unit", "juz"}
    assert corpus["levels"][1]["juz_numbers"] == [30, 29, 28]


# --------------------------------------------- Level 2, juz 27 (two half-files)
def test_level_2_juz_27_concatenates_hizb_54_before_hizb_53(corpus):
    sessions = juz_sessions(corpus, 2, 27)
    assert len(sessions) == 51  # 25 rows (hizb 54 file) + 26 rows (hizb 53 file)
    assert [s["session_number"] for s in sessions] == list(range(1, 52))

    first_file = sessions[0]["source"]["file"]
    last_file = sessions[-1]["source"]["file"]
    assert "54" in first_file.rsplit("/", 1)[-1]
    assert "53" in last_file.rsplit("/", 1)[-1]

    assert sessions[0]["hizb_number"] == 54
    assert sessions[0]["unit_index"] == 1
    assert sessions[-1]["source"]["raw_session_number"] == 27  # each half restarts at 2


def test_level_2_juz_27_juz_tier_pair_lands_last(corpus):
    sessions = juz_sessions(corpus, 2, 27)
    assert sessions[-2]["kind"] == "sard"
    assert sessions[-2]["scope"]["tier"] == "juz"
    assert sessions[-2]["scope"]["juz_numbers"] == [27]
    assert sessions[-1]["kind"] == "exam"
    assert sessions[-1]["scope"]["tier"] == "juz"
    # ... and it lives in the half that is taught last (the hizb-53 workbook)
    assert "53" in sessions[-2]["source"]["file"].rsplit("/", 1)[-1]


def test_level_2_juz_27_unit_pairs_are_structural_not_textual(corpus):
    units = [
        s for s in juz_sessions(corpus, 2, 27)
        if s["scope"] and s["scope"]["tier"] == "unit" and s["kind"] == "sard"
    ]
    assert len(units) == 2
    # structure (file order) says 54 then 53 ...
    assert [u["hizb_number"] for u in units] == [54, 53]
    # ... while the source text says the opposite. Stored verbatim, never trusted.
    assert [u["scope"]["hizb_number"] for u in units] == [53, 54]
    assert units[0]["scope"]["label_ar"] == "سرد الحزب رقم 53 كاملًا على المحفظ المتابع"


def test_level_2_hizb_label_contradiction_is_reported(corpus):
    contradictions = [w for w in corpus["warnings"] if "HIZB LABEL CONTRADICTION" in w]
    assert len(contradictions) == 6  # both units of all three juz in level 2
    assert all("L2 " in w for w in contradictions)


# ------------------------------- Level 3, juz 22 (duplicate workbooks, surah labels)
def test_level_3_juz_22_reads_both_sheet1_pages_of_one_workbook(corpus):
    sessions = juz_sessions(corpus, 3, 22)
    assert len(sessions) == 32
    assert {s["source"]["sheet"] for s in sessions} == {"Sheet1", "Sheet1 (2)"}
    # the stale per-file Sheet2 drafts are never read
    assert all(s["source"]["sheet"].startswith("Sheet1") for s in sessions)
    # both workbooks of the pair carry identical Sheet1* content; one is used
    assert len({s["source"]["file"] for s in sessions}) == 1


def test_level_3_juz_22_tiers_are_derived_structurally(corpus):
    s = by_number(juz_sessions(corpus, 3, 22))
    assert (s[14]["kind"], s[14]["scope"]["tier"], s[14]["unit_index"]) == ("sard", "unit", 1)
    assert (s[15]["kind"], s[15]["scope"]["tier"]) == ("exam", "unit")
    assert (s[27]["kind"], s[27]["scope"]["tier"], s[27]["unit_index"]) == ("sard", "unit", 2)
    assert (s[28]["kind"], s[28]["scope"]["tier"]) == ("exam", "unit")
    assert (s[29]["kind"], s[29]["scope"]["tier"]) == ("sard", "juz")
    assert (s[30]["kind"], s[30]["scope"]["tier"]) == ("exam", "juz")
    assert (s[31]["kind"], s[31]["scope"]["tier"]) == ("sard", "cumulative")
    assert (s[32]["kind"], s[32]["scope"]["tier"]) == ("exam", "cumulative")


def test_level_3_juz_22_labels_are_stored_verbatim_and_name_no_hizb(corpus):
    s = by_number(juz_sessions(corpus, 3, 22))
    assert s[14]["scope"]["label_ar"] == "سرد سورتي سبأ وفاطرعلى المحفظ المتابع"
    assert s[27]["scope"]["label_ar"] == "سرد سورة الأحزاب على المحفظ المتابع"
    assert s[29]["scope"]["label_ar"] == "سرد سور الأحزاب وسبأ وفاطرعلى المحفظ المتابع"
    for n in (14, 27, 29, 31):
        assert s[n]["scope"]["hizb_number"] is None
        assert s[n]["hizb_number"] is None  # levels 3-10 never name a hizb


def test_level_3_juz_22_cumulative_covers_the_whole_level(corpus):
    s = by_number(juz_sessions(corpus, 3, 22))
    assert s[31]["scope"]["juz_numbers"] == [22, 23, 24]
    assert corpus["levels"][3]["juz_numbers"] == [24, 23, 22]
    # juz 24 is taught first and therefore has no cumulative pair
    first = juz_sessions(corpus, 3, 24)
    assert not any(s["scope"] and s["scope"]["tier"] == "cumulative" for s in first)


# ------------------------------------------------------------- documentation
def test_level_3_cumulative_labels_name_no_juz(corpus):
    """Levels 3-10 label their cumulative (and juz-tier) assessments by SURAH,
    never by juz number — so `JUZ_WORD_RE` ("الجزء" / "الجزئين" / "الأجزاء")
    never matches them, and the cumulative cross-check in
    `build_juz_sessions()` (which only fires when a label names a juz) is
    silently skipped for every level but 1-2. This is the concrete case that
    made the old `juz_teaching_order()` comment's claim false.
    """
    s = by_number(juz_sessions(corpus, 3, 22))
    cumulative = [s[29], s[30], s[31], s[32]]
    for session in cumulative:
        assert not ex.JUZ_WORD_RE.search(session["scope"]["label_ar"])


def test_juz_teaching_order_comment_does_not_overstate_verification():
    """`juz_teaching_order()`'s header comment must not claim a blanket
    machine cross-check that does not exist: the automatic cumulative
    cross-check only fires when a label names a juz (true for levels 1-2
    only — see `test_level_3_cumulative_labels_name_no_juz`). The level-10
    ascending order is a human derivation recorded in the comment, not
    something `extract()` re-derives or re-checks. Reading the module's own
    source (rather than duplicating the sentence here) means the comment
    cannot silently drift back to overstating its guarantee.
    """
    import inspect

    source = inspect.getsource(ex)
    assert "The validator re-derives and re-checks this." not in source
