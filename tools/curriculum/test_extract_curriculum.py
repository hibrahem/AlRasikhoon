"""Golden tests over real juz that exercise every source layout.

The authoritative table of a workbook is its COLOUR-FILLED tab, whatever it is
called: 'Sheet1' for levels 1-2, 'Sheet2' for levels 3-10. The other tabs are
abandoned drafts (al_rasikhoon-hk0).

  * Level 1 juz 30  — SINGLE workbook, both halves on one tab, ascending by hizb
                      (59 then 60).
  * Level 2 juz 27  — CONCATENATED: two half-workbooks, each renumbering from
                      scratch, DESCENDING (hizb 54 taught first), carrying the
                      known contradictory hizb marker text.
  * Level 3 juz 22  — CONCATENATED with surah-scoped labels.
  * Level 3 juz 24  — CONTAINED: one workbook holds the whole juz, the other a
                      renumbered copy of part of it.
  * Level 4 juz 19  — MERGED: two workbooks holding disjoint halves of ONE
                      continuous numbering, the LOWER hizb holding the HIGHER
                      session range.

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


# ------------------------------------------------- authoritative tab selection
def test_the_authoritative_tab_is_the_colour_filled_one_whatever_it_is_called():
    """al_rasikhoon-hk0: the corrected table is the tab that was FORMATTED, and
    it is 'Sheet1' in levels 1-2 but 'Sheet2' in levels 3-10. Selecting by name
    (the old `content_sheets()` took 'Sheet1*' and discarded 'Sheet2') read the
    abandoned drafts for eight levels out of ten. Nor can the tab be selected by
    xlsx tab colour: no workbook in the corpus sets one.
    """
    from openpyxl import load_workbook

    cases = {
        1: ("المستوى الأول جاهز للمنسق/الجزء الــــ 30 جاهز للمنسق/"
            "منهج الراسخون المستوى الاول الجزء  رقم  1.xlsx", "Sheet1"),
        4: ("المستوى الرابع جاهز للمنسق/الجزء الــــ 19جاهز للمنسق/"
            "الحزب 37.xlsx", "Sheet2"),
    }
    for level, (relative, expected) in cases.items():
        path = ex.CURRICULUM_DIR / relative
        chosen, _ = ex.authoritative_sheet(path)
        assert chosen == expected, f"level {level}"

        workbook = load_workbook(path)
        fills = {ws.title: ex.fill_count(ws) for ws in workbook.worksheets}
        assert all(ws.sheet_properties.tabColor is None for ws in workbook.worksheets)
        workbook.close()
        # the winner is not merely first: it is formatted, and the drafts are not
        assert fills[expected] >= ex.MIN_AUTHORITATIVE_FILLS
        others = [n for t, n in fills.items() if t != expected]
        assert max(others) * ex.FILL_DOMINANCE < fills[expected]


def test_no_session_comes_from_a_draft_tab(corpus):
    """Levels 1-2 are authored on 'Sheet1' and levels 3-10 on 'Sheet2'. Nothing
    may come off 'Sheet1 (2)', which exists only on the drafts."""
    for level, sessions in corpus["sessions"].items():
        expected = "Sheet1" if level <= 2 else "Sheet2"
        sheets = {s["source"]["sheet"] for s in sessions if s["kind"] != "talqeen"}
        assert sheets == {expected}, f"level {level}"


# ---------------------------------------------------------------- corpus-wide
def test_extraction_of_the_whole_curriculum_is_valid(corpus):
    assert corpus["errors"] == []


def test_no_passage_runs_backwards_within_one_surah(corpus):
    """The draft tabs were full of inverted ranges (e.g. الحشر 13 : 12). The
    authoritative tabs have NONE, corpus-wide. This is the regression oracle for
    al_rasikhoon-hk0: if a passage ever starts and ends in the same surah with
    `to_verse < from_verse`, we are reading a draft again."""
    inverted = []
    for sessions in corpus["sessions"].values():
        for s in sessions:
            for block in (
                "current_level_content", "recent_review_content", "distant_review_content",
            ):
                passage = s[block]
                if not passage:
                    continue
                if (
                    ex.normalise_surah(passage["from_surah"])
                    == ex.normalise_surah(passage["to_surah"])
                    and passage["to_verse"] < passage["from_verse"]
                ):
                    inverted.append((s["id"], block, passage))
    assert inverted == []


def test_every_surah_named_by_the_curriculum_is_one_of_the_114(corpus):
    """No passage may name something that is not a surah.

    Eight cells in the source did; all eight are repaired on the way in by
    CELL_CORRECTIONS (al_rasikhoon-n85), so the corpus itself must now be clean.
    """
    assert len(ex.SURAH_NAMES) == 114
    unknown = set()
    for sessions in corpus["sessions"].values():
        for s in sessions:
            for block in (
                "current_level_content", "recent_review_content", "distant_review_content",
            ):
                passage = s[block]
                if not passage:
                    continue
                for key in ("from_surah", "to_surah"):
                    if not ex.is_known_surah(passage[key]):
                        unknown.add(passage[key])
    assert unknown == set()


def test_the_four_source_typos_are_corrected_to_what_the_curriculum_demands(corpus):
    """The repaired cells, and WHY each reads what it reads (al_rasikhoon-n85).

    الروم is the one that matters. Its cell reads 'النكبوت', which looks like
    العنكبوت — but the recent window carries the two preceding sessions' new
    content (الروم 51-60), and الروم has exactly 60 verses. 'العنكبوت 60' would
    run BACKWARDS through the mushaf (العنكبوت #29 precedes الروم #30).
    """
    by_id = {s["id"]: s for sessions in corpus["sessions"].values() for s in sessions}
    expected = {
        # id, block, (from_surah, from_verse, to_surah, to_verse)
        ("L1_J29_S22", "current_level_content"): ("المعارج", 1, "المعارج", 10),
        ("L1_J29_S26", "current_level_content"): ("المعارج", 40, "المعارج", 44),
        ("L1_J29_S65", "distant_review_content"): ("الإخلاص", 1, "الناس", 6),
        ("L4_J21_S16", "recent_review_content"): ("الروم", 51, "الروم", 60),
        ("L4_J21_S26", "distant_review_content"): ("الشورى", 20, "الشورى", 51),
    }
    for (session_id, block), want in expected.items():
        passage = by_id[session_id][block]
        got = (
            passage["from_surah"], passage["from_verse"],
            passage["to_surah"], passage["to_verse"],
        )
        assert got == want, f"{session_id}.{block}"


def test_every_declared_correction_actually_fires(corpus):
    """A correction whose file/sheet/cell no longer matches would silently do
    nothing, leaving the typo in the output while the table claims it is fixed.
    Extraction aborts in that case — this pins that the guard is wired in."""
    assert ex.APPLIED_CORRECTIONS == set(ex.CELL_CORRECTIONS)
    ex.assert_every_correction_fired()  # must not raise
    # Every correction is also reported, so a silent rewrite is impossible.
    for wrong, right, _why in ex.CELL_CORRECTIONS.values():
        assert any(
            repr(wrong) in a and repr(right) in a and "corrected" in a
            for a in corpus["anomalies"]
        ), f"{wrong!r} -> {right!r} was not reported as an anomaly"


def test_orthographic_variants_of_a_surah_name_are_not_typos():
    """The workbooks spell hamza and ta-marbuta inconsistently. Those are the
    same surah. A stray SPACE is not: 'المعار ج' must stay a reported typo."""
    for variant in ("سبا", "الانشقاق", "الانفطار", "الانعام"):
        assert ex.is_known_surah(variant)
    assert not ex.is_known_surah("المعار ج")


def test_document_ids_are_unique_across_the_corpus(corpus):
    ids = [s["id"] for ss in corpus["sessions"].values() for s in ss]
    assert len(ids) == len(set(ids))


def test_every_extracted_session_carries_its_source_row(corpus):
    """Every session read FROM the spreadsheets carries its provenance. Derived
    talqeen sessions are covered by test_a_talqeen_declares_itself_derived."""
    for sessions in corpus["sessions"].values():
        for s in sessions:
            if s["kind"] == "talqeen":
                continue
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
                assert s["kind"] in ("lesson", "talqeen")
                assert s["scope"] is None


# ------------------------------------------------- Level 1, juz 30 (merged sheet)
def test_level_1_juz_30_has_70_sessions(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    assert len(sessions) == 70  # 68 from the source + 2 derived talqeen
    assert [s["session_number"] for s in sessions] == list(range(1, 71))


def test_level_1_juz_30_unit_pairs_land_on_31_32_and_67_68(corpus):
    s = by_number(juz_sessions(corpus, 1, 30))

    assert s[31]["kind"] == "sard"
    assert s[31]["assessed_by"] == "teacher"
    assert s[31]["scope"]["tier"] == "unit"
    assert s[31]["scope"]["hizb_number"] == 59
    assert s[31]["unit_index"] == 1
    assert s[32]["kind"] == "exam"
    assert s[32]["assessed_by"] == "supervisor"
    assert s[32]["scope"]["tier"] == "unit"

    assert s[67]["kind"] == "sard"
    assert s[67]["scope"]["tier"] == "unit"
    assert s[67]["scope"]["hizb_number"] == 60
    assert s[67]["unit_index"] == 2
    assert s[68]["kind"] == "exam"
    assert s[68]["scope"]["tier"] == "unit"


def test_level_1_juz_30_juz_pair_lands_on_69_70(corpus):
    s = by_number(juz_sessions(corpus, 1, 30))
    assert s[69]["kind"] == "sard"
    assert s[69]["scope"]["tier"] == "juz"
    assert s[69]["scope"]["juz_numbers"] == [30]
    assert s[69]["scope"]["hizb_number"] is None
    assert s[69]["hizb_number"] is None  # a juz-tier assessment belongs to no half
    assert s[70]["kind"] == "exam"
    assert s[70]["scope"]["tier"] == "juz"


def test_level_1_juz_30_teaches_hizb_59_before_60(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    lessons = [s for s in sessions if s["kind"] == "lesson"]
    assert lessons[0]["hizb_number"] == 59
    assert lessons[-1]["hizb_number"] == 60


def test_level_1_juz_30_has_no_lesson_typed_as_an_assessment(corpus):
    sessions = juz_sessions(corpus, 1, 30)
    assessments = [
        s["session_number"] for s in sessions if s["kind"] in ("sard", "exam")
    ]
    assert assessments == [31, 32, 67, 68, 69, 70]
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


# --------------------------- Level 3, juz 22 (concatenated, surah labels)
def test_level_3_juz_22_reads_only_the_colour_filled_tab_of_each_workbook(corpus):
    sessions = juz_sessions(corpus, 3, 22)
    assert len(sessions) == 35  # 33 from the source + 2 derived talqeen
    extracted = [s for s in sessions if s["kind"] != "talqeen"]
    # ONE tab per workbook: the colour-filled one, which for levels 3-10 is
    # 'Sheet2'. The 'Sheet1' / 'Sheet1 (2)' drafts are never read.
    assert {s["source"]["sheet"] for s in extracted} == {"Sheet2"}
    # ... and both workbooks of the juz contribute: they are two hizbs.
    files = {s["source"]["file"].rsplit("/", 1)[-1] for s in extracted}
    assert files == {"الحزب  43.xlsx", "الحزب  44.xlsx"}


def test_level_3_juz_22_concatenates_hizb_44_before_hizb_43(corpus):
    """Two colour-filled tabs, each renumbering FROM SCRATCH (raw 2..17 and
    2..18) over DIFFERENT content. They are two hizbs and are concatenated in
    teaching order, never unioned on session number — a union would have kept
    one of each identically-numbered pair and thrown half the juz away."""
    extracted = [s for s in juz_sessions(corpus, 3, 22) if s["kind"] != "talqeen"]
    assert "44" in extracted[0]["source"]["file"].rsplit("/", 1)[-1]
    assert "43" in extracted[-1]["source"]["file"].rsplit("/", 1)[-1]
    # each half restarts its raw numbering at 2
    raw_44 = [s["source"]["raw_session_number"] for s in extracted
              if "44" in s["source"]["file"].rsplit("/", 1)[-1]]
    raw_43 = [s["source"]["raw_session_number"] for s in extracted
              if "43" in s["source"]["file"].rsplit("/", 1)[-1]]
    assert raw_44 == list(range(2, 18))
    assert raw_43 == list(range(2, 19))


def test_level_3_juz_22_tiers_are_derived_structurally(corpus):
    s = by_number(juz_sessions(corpus, 3, 22))
    assert (s[16]["kind"], s[16]["scope"]["tier"], s[16]["unit_index"]) == ("sard", "unit", 1)
    assert (s[17]["kind"], s[17]["scope"]["tier"]) == ("exam", "unit")
    assert (s[30]["kind"], s[30]["scope"]["tier"], s[30]["unit_index"]) == ("sard", "unit", 2)
    assert (s[31]["kind"], s[31]["scope"]["tier"]) == ("exam", "unit")
    assert (s[32]["kind"], s[32]["scope"]["tier"]) == ("sard", "juz")
    assert (s[33]["kind"], s[33]["scope"]["tier"]) == ("exam", "juz")
    assert (s[34]["kind"], s[34]["scope"]["tier"]) == ("sard", "cumulative")
    assert (s[35]["kind"], s[35]["scope"]["tier"]) == ("exam", "cumulative")


def test_level_3_juz_22_labels_are_stored_verbatim_and_name_no_hizb(corpus):
    s = by_number(juz_sessions(corpus, 3, 22))
    assert s[16]["scope"]["label_ar"] == "سرد سورتي سبأ وفاطرعلى المحفظ المتابع"
    assert s[30]["scope"]["label_ar"] == "سرد سورة الأحزاب على المحفظ المتابع"
    assert s[32]["scope"]["label_ar"] == "سرد سور الأحزاب وسبأ وفاطرعلى المحفظ المتابع"
    for n in (16, 30, 32, 34):
        assert s[n]["scope"]["hizb_number"] is None
        # Levels 3-10 teach SURAHS: their labels never name a hizb, and the hizb
        # number in the workbook's FILENAME is not attributed to the sessions.
        assert s[n]["hizb_number"] is None


def test_level_3_juz_22_cumulative_covers_the_whole_level(corpus):
    s = by_number(juz_sessions(corpus, 3, 22))
    assert s[34]["scope"]["juz_numbers"] == [22, 23, 24]
    assert corpus["levels"][3]["juz_numbers"] == [24, 23, 22]
    # juz 24 is taught first and therefore has no cumulative pair
    first = juz_sessions(corpus, 3, 24)
    assert not any(s["scope"] and s["scope"]["tier"] == "cumulative" for s in first)


# ------------------------------------- Level 3, juz 24 (contained workbook)
def test_level_3_juz_24_drops_the_workbook_that_merely_copies_the_other(corpus):
    """The colour-filled tab of 'الحزب  48' is a renumbered copy of the first 19
    of the 33 rows of 'الحزب  47''s, which holds the WHOLE juz (both units and
    the juz pair). Concatenating the two would teach فصلت/غافر twice."""
    sessions = juz_sessions(corpus, 3, 24)
    assert len(sessions) == 35  # 33 from the source + 2 derived talqeen
    extracted = [s for s in sessions if s["kind"] != "talqeen"]
    assert {s["source"]["file"].rsplit("/", 1)[-1] for s in extracted} == {"الحزب  47.xlsx"}
    assert [s["source"]["raw_session_number"] for s in extracted] == list(range(1, 34))

    juz_meta = next(j for j in corpus["levels"][3]["juz"] if j["juz_number"] == 24)
    assert juz_meta["source_files"] == ["الحزب  47.xlsx"]
    assert any("CONTAINED" in note for note in juz_meta["notes"])
    assert any("renumbered COPY" in a and "L3 J24" in a for a in corpus["anomalies"])


# --------------------------------------- Level 4, juz 19 (merged workbooks)
def test_level_4_juz_19_merges_two_disjoint_halves_of_one_numbering(corpus):
    """The two colour-filled tabs hold DISJOINT halves of ONE continuous run:
    raw 1-13 and raw 14-27. The session number is the order, not the file — the
    workbook with the LOWER hizb in its name (37) holds the HIGHER range."""
    sessions = juz_sessions(corpus, 4, 19)
    assert len(sessions) == 29  # 27 from the source + 2 derived talqeen
    extracted = [s for s in sessions if s["kind"] != "talqeen"]
    assert [s["source"]["raw_session_number"] for s in extracted] == list(range(1, 28))

    def name(session):
        return session["source"]["file"].rsplit("/", 1)[-1]

    assert {name(s) for s in extracted if s["source"]["raw_session_number"] <= 13} == {
        "الحزب 38.xlsx"
    }
    assert {name(s) for s in extracted if s["source"]["raw_session_number"] >= 14} == {
        "الحزب 37.xlsx"
    }
    juz_meta = next(j for j in corpus["levels"][4]["juz"] if j["juz_number"] == 19)
    assert juz_meta["source_files"] == ["الحزب 38.xlsx", "الحزب 37.xlsx"]
    assert any("MERGED" in note for note in juz_meta["notes"])


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
    cumulative = [s[32], s[33], s[34], s[35]]
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
    seen = 0
    for sessions in corpus["sessions"].values():
        for s in sessions:
            if s["kind"] != "talqeen":
                continue
            seen += 1
            assert s["recent_review_content"] is None
            assert s["distant_review_content"] is None
            assert s["scope"] is None
            assert s["assessed_by"] is None
    assert seen == 59  # must not pass vacuously on a corpus with no talqeen


def test_a_talqeen_declares_itself_derived_not_extracted(corpus):
    """Nothing in the source spreadsheets is a talqeen row. The provenance must
    say so rather than claim a file/sheet/row it did not come from -- and
    `derived_from` must name the FINAL id (post-renumbering) of the lesson the
    talqeen actually introduces, never a stale pre-renumbering id (a talqeen's
    insertion shifts every id/session_number that follows it in its juz)."""
    seen = 0
    for sessions in corpus["sessions"].values():
        by_order = sorted(sessions, key=lambda s: s["order_in_level"])
        for i, s in enumerate(by_order):
            if s["kind"] != "talqeen":
                assert isinstance(s["source"]["row"], int)
                continue
            seen += 1
            assert set(s["source"]) == {"derived_from"}
            following = by_order[i + 1]
            assert s["source"]["derived_from"] == following["id"]
            assert following["kind"] == "lesson"
            assert following["current_level_content"] == s["current_level_content"]
    assert seen == 59  # must not pass vacuously on a corpus with no talqeen


def test_the_curriculum_has_955_sessions(corpus):
    per_level = {
        level: len(sessions) for level, sessions in corpus["sessions"].items()
    }
    assert per_level == {
        1: 210, 2: 154, 3: 100, 4: 94, 5: 71,
        6: 82, 7: 60, 8: 67, 9: 67, 10: 50,
    }
    assert sum(per_level.values()) == 955
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
