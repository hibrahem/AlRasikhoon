#!/usr/bin/env python3
"""Faithful extraction of the الراسخون Quran curriculum from the source spreadsheets.

Design contract (see tools/curriculum/README section in the report):

  * STRUCTURE decides what a row is. The Arabic text is a LABEL that we store
    verbatim and use only to CROSS-CHECK the structural decision.
  * Nothing is ever inferred from a session number, and nothing is ever
    fabricated. Every emitted session carries a `source` provenance record
    pointing at the exact file / sheet / row it came from.
  * The script VALIDATES first and writes nothing unless validation passes.
    `--write` emits JSON only after a clean report.

Usage:
    python extract_curriculum.py            # validate only, print report
    python extract_curriculum.py --write    # validate, then emit data/curriculum/*.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[2]          # al_rasikhoon/
CURRICULUM_DIR = REPO_ROOT.parent / "curriculum"          # ../curriculum (read-only source)
OUTPUT_DIR = REPO_ROOT / "data" / "curriculum"

# --------------------------------------------------------------------------
# Level definitions
# --------------------------------------------------------------------------
# A level owns 3 juz. Juz are taught in DESCENDING order in levels 1-9
# (level 1 teaches 30, then 29, then 28).
#
# LEVEL 10 IS ASCENDING IN THE SOURCE (juz 1, then 2, then 3). This is not a
# guess: juz 1 carries no cumulative pair, juz 2's cumulative covers
# "البقرة 1 : 252" (= juz 1 + 2) and juz 3's covers "البقرة 1 : 286"
# (= juz 1 + 2 + 3). Cumulative scope strictly grows in that order, so that is
# the teaching order. The validator re-derives and re-checks this.
LEVEL_NAMES_AR = {
    1: "المستوى الأول",
    2: "المستوى الثاني",
    3: "المستوى الثالث",
    4: "المستوى الرابع",
    5: "المستوى الخامس",
    6: "المستوى السادس",
    7: "المستوى السابع",
    8: "المستوى الثامن",
    9: "المستوى التاسع",
    10: "المستوى العاشر",
}

LEVEL_NAMES_EN = {
    1: "Level 1", 2: "Level 2", 3: "Level 3", 4: "Level 4", 5: "Level 5",
    6: "Level 6", 7: "Level 7", 8: "Level 8", 9: "Level 9", 10: "Level 10",
}

LEVEL_FOLDERS = {
    "المستوى الأول جاهز للمنسق": 1,
    "المستوى الثاني جاهز للمنسق": 2,
    "المستوى الثالث جاهز للمنسق": 3,
    "المستوى الرابع جاهز للمنسق": 4,
    "المستوى الخامس جاهز للمنسق": 5,
    "المستوى السادس جاهز للمنسق": 6,
    "المستوى السابع جاهز للمنسق": 7,
    "المستوى الثامن جاهز للمنسق": 8,
    "المستوى التاسع جاهز للمنسق": 9,
    "المستوى العاشر جاهز للمنسق": 10,
}


def juz_teaching_order(level: int) -> list[int]:
    """Juz numbers of a level, in TEACHING order."""
    if level == 10:
        return [1, 2, 3]  # source-verified ascending; see note above
    return [33 - 3 * level, 32 - 3 * level, 31 - 3 * level]


# --------------------------------------------------------------------------
# Documented source defects / deviations.
# An UNLISTED violation of a structural invariant aborts the run.
# --------------------------------------------------------------------------
@dataclass(frozen=True)
class Exception_:
    reason: str


# keyed by (level, juz)
EXPECTED_EXCEPTIONS: dict[tuple[int, int], dict[str, Any]] = {
    (10, 3): {
        "unit_pairs": 1,
        "juz_pairs": 0,
        "cumulative_pairs": 1,
        "second_pair_tier": "cumulative",
        "reason": (
            "Source juz 3 of level 10 has a single teaching block (سورة البقرة 253:286, "
            "5 lessons) followed by ONE unit pair and then a pair over the whole of "
            "سورة البقرة 1:286 (= juz 1+2+3), i.e. the level cumulative. There is no "
            "second unit block and no juz-tier pair. Its first sheet is stamped 'لاغي' "
            "(void) and is empty."
        ),
    },
}

# Raw (as-printed) session numbering that is not a clean +1 run. Renumbering is
# dense regardless; these are the ones we tolerate instead of aborting.
EXPECTED_NUMBERING_GAPS: dict[tuple[int, int], str] = {
    (10, 2): (
        "Raw 'الحصة رقم' column jumps 7 -> 11 and 16 -> 19 (sheet 'Sheet1 (2)' of the "
        "level-10 juz-2 workbook, which is additionally mis-titled 'المستوى التاسع'). "
        "Rows are otherwise in order; sessions are renumbered densely 1..N."
    ),
}

# Level 2's in-sheet hizb markers contradict the workbook they sit in (the file
# whose content is hizb 53 carries 'سرد الحزب رقم 54' and vice versa). We take the
# STRUCTURE (filename + juz-pair-comes-last) as truth and report the contradiction.
KNOWN_HIZB_LABEL_DEFECT_LEVELS = {2}

# --------------------------------------------------------------------------
# Cell / text helpers
# --------------------------------------------------------------------------
PLACEHOLDER_RE = re.compile(r"^[ـ_\-\s\.]*$")  # tatweel / underscore / dash runs
MARKER_RE = re.compile(r"^\s*(سرد|اختبار)")
HIZB_IN_TEXT_RE = re.compile(r"الحزب\s*(?:رقم\s*)?(\d+)")
JUZ_IN_TEXT_RE = re.compile(r"(\d+)")
LEVEL_WORD_RE = re.compile(r"المستوى")
JUZ_WORD_RE = re.compile(r"الجزء|الجزئين|الأجزاء")


def norm_cell(value: Any) -> Optional[str]:
    """Normalise a raw cell to a string, or None for empty/placeholder cells."""
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return None
    try:
        if pd.isna(value):
            return None
    except (TypeError, ValueError):
        pass
    text = str(value).strip()
    if not text or text.lower() == "nan":
        return None
    if PLACEHOLDER_RE.match(text):
        return None
    return text


def as_int(value: Any) -> Optional[int]:
    text = norm_cell(value)
    if text is None:
        return None
    try:
        return int(float(text))
    except (TypeError, ValueError):
        return None


def is_marker(text: Optional[str]) -> bool:
    return bool(text) and bool(MARKER_RE.match(text)) and len(text) > 6


# --------------------------------------------------------------------------
# Sheet parsing
# --------------------------------------------------------------------------
@dataclass
class RawRow:
    file: str
    sheet: str
    row: int  # 0-based sheet row index
    raw_session_number: Optional[int]
    marker_text: Optional[str]
    marker_col: Optional[int]
    current: Optional[dict]
    recent: Optional[dict]
    distant: Optional[dict]


BLOCK_HEADERS = {
    "current": "مقرر المستوى الحالي",
    "recent": "مقرر تثبيت المستوى الحالي",
    "distant": "مقرر تثبيت المستوىات السابقة",
}
SESSION_HEADER = "الحصة رقم"


def locate_columns(df: pd.DataFrame) -> Optional[dict]:
    """Find the header row and the column index of each logical block."""
    for idx in range(min(12, len(df))):
        row = df.iloc[idx]
        cells = {j: norm_cell(v) for j, v in enumerate(row)}
        session_col = next((j for j, t in cells.items() if t and SESSION_HEADER in t), None)
        if session_col is None:
            continue
        cols = {"header_row": idx, "session": session_col}
        for key, label in BLOCK_HEADERS.items():
            col = next(
                (j for j, t in cells.items() if t and t.replace(" ", "").startswith(label.replace(" ", ""))),
                None,
            )
            if col is None:
                # tolerate the 'المستوىات' typo variants
                col = next((j for j, t in cells.items() if t and label[:12] in t), None)
            if col is None:
                return None
            cols[key] = col
        return cols
    return None


def read_block(row: pd.Series, start: int, exclude_col: Optional[int]) -> Optional[dict]:
    """A content block is 4 consecutive cells: from_surah, from_verse, to_surah, to_verse."""
    def cell(offset: int):
        col = start + offset
        if col >= len(row) or col == exclude_col:
            return None
        return row.iloc[col]

    from_surah = norm_cell(cell(0))
    from_verse = as_int(cell(1))
    to_surah = norm_cell(cell(2))
    to_verse = as_int(cell(3))
    if from_surah is None or to_surah is None or from_verse is None or to_verse is None:
        return None
    if is_marker(from_surah) or is_marker(to_surah):
        return None
    return {
        "from_surah": from_surah,
        "from_verse": from_verse,
        "to_surah": to_surah,
        "to_verse": to_verse,
    }


def parse_sheet(path: Path, sheet: str, df: pd.DataFrame, anomalies: list[str]) -> list[RawRow]:
    cols = locate_columns(df)
    if cols is None:
        return []

    title = " ".join(
        t for t in (norm_cell(v) for v in df.iloc[: cols["header_row"]].to_numpy().ravel()) if t
    )
    if "لاغي" in title:
        anomalies.append(
            f"{path.name} / {sheet}: sheet is stamped 'لاغي' (void) in its title — skipped"
        )
        return []

    rows: list[RawRow] = []
    for idx in range(cols["header_row"] + 1, len(df)):
        row = df.iloc[idx]
        session_num = as_int(row.iloc[cols["session"]]) if cols["session"] < len(row) else None

        marker_col = None
        marker_text = None
        for j, value in enumerate(row):
            text = norm_cell(value)
            if is_marker(text):
                marker_col = j
                marker_text = text
                break

        current = read_block(row, cols["current"], marker_col)
        recent = read_block(row, cols["recent"], marker_col)
        distant = read_block(row, cols["distant"], marker_col)

        if session_num is None and marker_text is None and current is None:
            continue  # blank / decorative row
        if session_num is None:
            anomalies.append(
                f"{path.name} / {sheet} row {idx}: row has content but no session number "
                f"(marker={marker_text!r}, current={current!r}) — skipped"
            )
            continue

        rows.append(
            RawRow(
                file=str(path.relative_to(CURRICULUM_DIR.parent)),
                sheet=sheet,
                row=idx,
                raw_session_number=session_num,
                marker_text=marker_text,
                marker_col=marker_col,
                current=current,
                recent=recent,
                distant=distant,
            )
        )
    return rows


def content_sheets(path: Path) -> list[tuple[str, pd.DataFrame]]:
    """The canonical sheets of a workbook are the 'Sheet1*' ones, in book order.

    Levels 3-10 split one juz across 'Sheet1' and 'Sheet1 (2)' with continuous
    session numbering. Every such workbook also carries a stale 'Sheet2' draft
    (different content between the two files of a pair, wrong titles, partial
    numbering); it is deliberately ignored.
    """
    xl = pd.ExcelFile(path)
    out = []
    for name in xl.sheet_names:
        if not name.startswith("Sheet1"):
            continue
        df = pd.read_excel(path, sheet_name=name, header=None)
        if df.empty:
            continue
        out.append((name, df))
    return out


def hizb_from_filename(name: str) -> Optional[int]:
    match = re.search(r"الحزب\s*(?:ال|الــ|الـــ|الـ)?\s*(\d+)", name)
    if match:
        return int(match.group(1))
    match = re.search(r"الــ\s*(\d+)", name)
    if match:
        return int(match.group(1))
    return None


# --------------------------------------------------------------------------
# Juz assembly
# --------------------------------------------------------------------------
@dataclass
class JuzSource:
    level: int
    juz: int
    rows: list[RawRow]
    files: list[str]
    notes: list[str] = field(default_factory=list)
    half_hizbs: Optional[list[int]] = None  # teaching-ordered hizb numbers, level 2 only


class Abort(Exception):
    pass


def rows_signature(rows: list[RawRow]) -> list[tuple]:
    return [
        (r.raw_session_number, r.marker_text, json.dumps(r.current, ensure_ascii=False),
         json.dumps(r.recent, ensure_ascii=False), json.dumps(r.distant, ensure_ascii=False))
        for r in rows
    ]


def load_juz(level: int, juz: int, juz_dir: Path, anomalies: list[str]) -> JuzSource:
    files = sorted(f for f in juz_dir.glob("*.xlsx") if not f.name.startswith("~$"))
    if not files:
        raise Abort(f"Level {level} juz {juz}: no .xlsx files in {juz_dir}")

    parsed = {}
    for f in files:
        rows: list[RawRow] = []
        for sheet, df in content_sheets(f):
            rows.extend(parse_sheet(f, sheet, df, anomalies))
        parsed[f] = rows

    notes: list[str] = []

    if len(files) == 1:
        f = files[0]
        if not parsed[f]:
            raise Abort(f"Level {level} juz {juz}: {f.name} produced no rows")
        notes.append(f"single workbook; sheets used: {sorted({r.sheet for r in parsed[f]})}")
        return JuzSource(level, juz, parsed[f], [f.name], notes)

    if len(files) == 2:
        a, b = files
        if rows_signature(parsed[a]) == rows_signature(parsed[b]):
            # Same content in both files -> that IS the full-juz sheet.
            notes.append(
                f"two workbooks with identical Sheet1* content ({a.name!r} == {b.name!r}); "
                "using the first, ignoring the stale per-file Sheet2 drafts"
            )
            return JuzSource(level, juz, parsed[a], [a.name, b.name], notes)

        # Genuinely different -> the two halves of the juz (level 2).
        hizbs = {f: hizb_from_filename(f.name) for f in files}
        if any(h is None for h in hizbs.values()):
            raise Abort(
                f"Level {level} juz {juz}: two differing workbooks but no hizb number in the "
                f"filenames: {[f.name for f in files]}"
            )
        # Teaching order: level 1 ascends hizb, levels 2+ descend.
        ordered = sorted(files, key=lambda f: hizbs[f], reverse=(level != 1))
        # Corroboration: the half that carries the juz-tier pair must come LAST.
        carriers = [f for f in files if any(
            r.marker_text and JUZ_WORD_RE.search(r.marker_text) for r in parsed[f]
        )]
        if len(carriers) != 1:
            raise Abort(
                f"Level {level} juz {juz}: expected exactly one half to carry the juz-tier "
                f"pair, found {len(carriers)}: {[f.name for f in carriers]}"
            )
        if carriers[0] != ordered[-1]:
            raise Abort(
                f"Level {level} juz {juz}: teaching order by hizb says {ordered[-1].name!r} is "
                f"last, but the juz-tier pair lives in {carriers[0].name!r}. Refusing to guess."
            )
        notes.append(
            "two half-workbooks; teaching order "
            f"{[hizbs[f] for f in ordered]} (hizb {'ascending' if level == 1 else 'descending'}), "
            f"corroborated by the juz-tier pair living in the last half ({carriers[0].name!r})"
        )
        return JuzSource(
            level, juz,
            [r for f in ordered for r in parsed[f]],
            [f.name for f in ordered],
            notes,
            half_hizbs=[hizbs[f] for f in ordered],
        )

    raise Abort(
        f"Level {level} juz {juz}: {len(files)} workbooks found, cannot decide layout: "
        f"{[f.name for f in files]}"
    )


# --------------------------------------------------------------------------
# Classification & tiers
# --------------------------------------------------------------------------
def kind_of(row: RawRow) -> str:
    if row.marker_text:
        if row.marker_text.startswith("سرد"):
            return "sard"
        return "exam"
    if row.current or row.recent or row.distant:
        # A lesson with only review content is a real, taught consolidation session
        # (no new memorisation that day). It is reported, never dropped.
        return "lesson"
    return "anomaly"


def assessed_by(text: str) -> Optional[str]:
    if "المحفظ المتابع" in text:
        return "teacher"
    if "إدارة الحلقات" in text:
        return "supervisor"
    return None


def hizb_in_text(text: str) -> Optional[int]:
    match = HIZB_IN_TEXT_RE.search(text)
    return int(match.group(1)) if match else None


def juz_numbers_in_text(text: str) -> list[int]:
    if not JUZ_WORD_RE.search(text):
        return []
    tail = text[JUZ_WORD_RE.search(text).start():]
    tail = tail.split("على المحفظ")[0].split("من قِبل")[0]
    return [int(n) for n in JUZ_IN_TEXT_RE.findall(tail) if 1 <= int(n) <= 30]


@dataclass
class Pair:
    sard: int  # index into the juz's row list
    exam: int
    tier: str = ""
    unit_index: Optional[int] = None


def build_juz_sessions(
    src: JuzSource,
    juz_index_in_level: int,          # 0-based position in the level's teaching order
    juz_taught_so_far: list[int],     # including this juz
    errors: list[str],
    warnings: list[str],
    anomalies: list[str],
) -> list[dict]:
    level, juz = src.level, src.juz
    rows = src.rows
    kinds = [kind_of(r) for r in rows]

    for i, (r, k) in enumerate(zip(rows, kinds)):
        if k == "anomaly":
            anomalies.append(
                f"L{level} J{juz} {r.file} / {r.sheet} row {r.row}: session "
                f"{r.raw_session_number} has neither an assessment marker nor Quran content"
            )
            errors.append(f"L{level} J{juz}: un-classifiable row at {r.sheet}:{r.row}")
        elif k == "lesson" and not r.current:
            anomalies.append(
                f"L{level} J{juz} {r.file} / {r.sheet} row {r.row}: review-only lesson "
                f"(raw session {r.raw_session_number}) — no new مقرر, review content only"
            )

    # --- pairs: every assessment must be a (sard, exam) in that order --------
    pairs: list[Pair] = []
    i = 0
    while i < len(rows):
        if kinds[i] == "sard":
            if i + 1 < len(rows) and kinds[i + 1] == "exam":
                pairs.append(Pair(sard=i, exam=i + 1))
                i += 2
                continue
            errors.append(
                f"L{level} J{juz}: sard at {rows[i].sheet}:{rows[i].row} is not followed by an exam"
            )
            i += 1
            continue
        if kinds[i] == "exam":
            errors.append(
                f"L{level} J{juz}: exam at {rows[i].sheet}:{rows[i].row} is not preceded by a sard"
            )
        i += 1

    # --- structural tiers ---------------------------------------------------
    # A pair preceded by lesson rows is a `unit` pair. A pair immediately
    # following another pair is the `juz` pair; a further one is `cumulative`.
    exc = EXPECTED_EXCEPTIONS.get((level, juz))
    unit_counter = 0
    for p_i, pair in enumerate(pairs):
        previous_pair = pairs[p_i - 1] if p_i else None
        follows_pair = previous_pair is not None and previous_pair.exam == pair.sard - 1
        if not follows_pair:
            unit_counter += 1
            pair.tier = "unit"
            pair.unit_index = unit_counter
        elif previous_pair.tier == "unit":
            pair.tier = "juz"
        else:
            pair.tier = "cumulative"

    if exc and exc.get("second_pair_tier") and len(pairs) >= 2:
        if pairs[1].tier != exc["second_pair_tier"]:
            pairs[1].tier = exc["second_pair_tier"]
            warnings.append(
                f"L{level} J{juz}: applying documented exception — second pair re-tiered as "
                f"{exc['second_pair_tier']!r}. {exc['reason']}"
            )

    n_unit = sum(1 for p in pairs if p.tier == "unit")
    n_juz = sum(1 for p in pairs if p.tier == "juz")
    n_cum = sum(1 for p in pairs if p.tier == "cumulative")

    expect = exc or {"unit_pairs": 2, "juz_pairs": 1}
    if n_unit != expect.get("unit_pairs", 2) or n_juz != expect.get("juz_pairs", 1):
        msg = (
            f"L{level} J{juz}: found {n_unit} unit pair(s) and {n_juz} juz pair(s); "
            f"expected {expect.get('unit_pairs', 2)} / {expect.get('juz_pairs', 1)}"
        )
        (warnings if exc else errors).append(msg)

    # cumulative rules
    expected_cum = 0 if juz_index_in_level == 0 else 1
    if exc and "cumulative_pairs" in exc:
        expected_cum = exc["cumulative_pairs"]
    if n_cum != expected_cum:
        errors.append(
            f"L{level} J{juz}: {n_cum} cumulative pair(s), expected {expected_cum} "
            f"(juz #{juz_index_in_level + 1} taught in the level)"
        )

    # --- unit membership for lessons ---------------------------------------
    unit_pair_positions = [p.sard for p in pairs if p.tier == "unit"]

    def unit_of_row(i: int) -> Optional[int]:
        for n, pos in enumerate(unit_pair_positions, start=1):
            if i <= pos:
                return n
        return None

    # --- hizb labels --------------------------------------------------------
    # Level 1: the unit pair's own text names the hizb.
    # Level 2: the text is KNOWN-BAD (swapped between the two half files), so the
    #          structural filename order is truth; the text is reported.
    # Levels 3-10: the source never names a hizb -> null.
    unit_hizb: dict[int, Optional[int]] = {1: None, 2: None}
    if src.half_hizbs:
        for n, h in enumerate(src.half_hizbs, start=1):
            unit_hizb[n] = h
    else:
        for p in pairs:
            if p.tier == "unit":
                unit_hizb[p.unit_index] = hizb_in_text(rows[p.sard].marker_text or "")

    for p in pairs:
        if p.tier != "unit":
            continue
        text_hizb = hizb_in_text(rows[p.sard].marker_text or "")
        structural = unit_hizb.get(p.unit_index)
        if text_hizb and structural and text_hizb != structural:
            warnings.append(
                f"L{level} J{juz}: HIZB LABEL CONTRADICTION — unit {p.unit_index} is structurally "
                f"hizb {structural} (file {rows[p.sard].file}) but its text says hizb {text_hizb}: "
                f"{rows[p.sard].marker_text!r}"
            )
            if level not in KNOWN_HIZB_LABEL_DEFECT_LEVELS:
                errors.append(
                    f"L{level} J{juz}: undocumented hizb label contradiction on unit {p.unit_index}"
                )

    # --- text cross-checks of the structural tier ---------------------------
    for p in pairs:
        text = rows[p.sard].marker_text or ""
        if p.tier == "unit":
            if JUZ_WORD_RE.search(text) or LEVEL_WORD_RE.search(text):
                errors.append(
                    f"L{level} J{juz}: unit-tier pair whose text is juz/level scoped: {text!r}"
                )
        elif p.tier == "juz":
            if hizb_in_text(text):
                errors.append(
                    f"L{level} J{juz}: juz-tier pair whose text names a hizb: {text!r}"
                )
            nums = juz_numbers_in_text(text)
            if nums and nums != [juz]:
                errors.append(
                    f"L{level} J{juz}: juz-tier pair whose text names juz {nums}: {text!r}"
                )
        elif p.tier == "cumulative":
            nums = juz_numbers_in_text(text)
            if nums and sorted(nums) != sorted(juz_taught_so_far):
                errors.append(
                    f"L{level} J{juz}: cumulative pair names juz {sorted(nums)} but the juz taught "
                    f"so far are {sorted(juz_taught_so_far)}: {text!r}"
                )

    pair_of_row: dict[int, Pair] = {}
    for p in pairs:
        pair_of_row[p.sard] = p
        pair_of_row[p.exam] = p

    # --- raw numbering sanity ----------------------------------------------
    raw = [r.raw_session_number for r in rows]
    if len(src.files) == 1 or src.half_hizbs is None:
        breaks = [
            (raw[i - 1], raw[i]) for i in range(1, len(raw)) if raw[i] != raw[i - 1] + 1
        ]
        if breaks:
            gap_note = EXPECTED_NUMBERING_GAPS.get((level, juz))
            msg = f"L{level} J{juz}: raw session numbers do not increment by 1: {breaks}"
            if gap_note:
                warnings.append(f"{msg} — documented: {gap_note}")
            else:
                errors.append(msg)

    # --- emit ---------------------------------------------------------------
    sessions = []
    for i, r in enumerate(rows):
        kind = kinds[i]
        pair = pair_of_row.get(i)
        unit_index = pair.unit_index if pair else unit_of_row(i)
        scope = None
        if pair:
            label = rows[pair.sard].marker_text if kind == "sard" else r.marker_text
            if pair.tier == "unit":
                juz_numbers = [juz]
            elif pair.tier == "juz":
                juz_numbers = [juz]
            else:
                juz_numbers = sorted(juz_taught_so_far)
            scope = {
                "tier": pair.tier,
                "label_ar": label,
                "hizb_number": hizb_in_text(label or ""),
                "juz_numbers": juz_numbers,
            }
        hizb = unit_hizb.get(unit_index) if unit_index else None

        sessions.append({
            "id": f"L{level}_J{juz}_S{i + 1}",
            "level_id": level,
            "juz_number": juz,
            "session_number": i + 1,
            "order_in_level": None,  # filled by the caller
            "kind": kind,
            "assessed_by": assessed_by(r.marker_text) if r.marker_text else None,
            "unit_index": unit_index if (kind == "lesson" or (pair and pair.tier == "unit")) else None,
            "hizb_number": hizb if (kind == "lesson" or (pair and pair.tier == "unit")) else None,
            "scope": scope,
            "current_level_content": r.current,
            "recent_review_content": r.recent,
            "distant_review_content": r.distant,
            "source": {
                "file": r.file,
                "sheet": r.sheet,
                "row": r.row,
                "raw_session_number": r.raw_session_number,
            },
        })

    # unit labels for levels.json
    src.notes.append(
        "tiers: " + ", ".join(f"{p.tier}{p.unit_index or ''}" for p in pairs)
    )
    return sessions


# --------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------
def extract() -> tuple[dict, dict, list[str], list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    anomalies: list[str] = []

    levels: dict[int, dict] = {}
    sessions_by_level: dict[int, list[dict]] = {}

    for folder, level in sorted(LEVEL_FOLDERS.items(), key=lambda kv: kv[1]):
        level_dir = CURRICULUM_DIR / folder
        if not level_dir.is_dir():
            raise Abort(f"Level {level}: folder not found: {level_dir}")

        order = juz_teaching_order(level)
        juz_dirs: dict[int, Path] = {}
        for d in level_dir.iterdir():
            if not d.is_dir():
                continue
            match = re.search(r"الجزء\s*ال[ـ\s]*(\d+)", d.name)
            if not match:
                raise Abort(f"Level {level}: cannot read a juz number from folder {d.name!r}")
            juz_dirs[int(match.group(1))] = d

        if sorted(juz_dirs) != sorted(order):
            raise Abort(
                f"Level {level}: expected juz {sorted(order)}, found {sorted(juz_dirs)}"
            )

        level_sessions: list[dict] = []
        juz_meta: list[dict] = []
        taught: list[int] = []

        for pos, juz in enumerate(order):
            src = load_juz(level, juz, juz_dirs[juz], anomalies)
            taught.append(juz)
            juz_sessions = build_juz_sessions(
                src, pos, list(taught), errors, warnings, anomalies
            )
            first_order = len(level_sessions) + 1
            for s in juz_sessions:
                s["order_in_level"] = len(level_sessions) + 1
                level_sessions.append(s)

            unit_labels = [
                s["scope"]["label_ar"]
                for s in juz_sessions
                if s["scope"] and s["scope"]["tier"] == "unit" and s["kind"] == "sard"
            ]
            hizbs = sorted({s["hizb_number"] for s in juz_sessions if s["hizb_number"]})
            juz_meta.append({
                "juz_number": juz,
                "session_count": len(juz_sessions),
                "unit_labels": unit_labels,
                "hizb_numbers": hizbs or None,
                "first_order_in_level": first_order,
                "source_files": src.files,
                "notes": src.notes,
            })

        levels[level] = {
            "id": level,
            "name_ar": LEVEL_NAMES_AR[level],
            "name_en": LEVEL_NAMES_EN[level],
            "order": level,
            "juz_numbers": order,
            "session_count": len(level_sessions),
            "juz": juz_meta,
        }
        sessions_by_level[level] = level_sessions

    # ---- corpus-wide validation -------------------------------------------
    seen_ids: set[str] = set()
    for level, sessions in sessions_by_level.items():
        if len(levels[level]["juz"]) != 3:
            errors.append(f"L{level}: has {len(levels[level]['juz'])} juz, expected 3")
        for juz_meta in levels[level]["juz"]:
            if juz_meta["session_count"] < 1:
                errors.append(f"L{level} J{juz_meta['juz_number']}: no sessions")
        by_juz: dict[int, list[int]] = {}
        for s in sessions:
            if s["id"] in seen_ids:
                errors.append(f"duplicate document id {s['id']}")
            seen_ids.add(s["id"])
            by_juz.setdefault(s["juz_number"], []).append(s["session_number"])
            if s["kind"] == "lesson" and not any((
                s["current_level_content"], s["recent_review_content"], s["distant_review_content"],
            )):
                errors.append(f"{s['id']}: lesson with no Quran content at all")
            if s["kind"] in ("sard", "exam") and not s["scope"]:
                errors.append(f"{s['id']}: assessment without a scope")
            if not s["source"] or s["source"]["row"] is None:
                errors.append(f"{s['id']}: missing source provenance")
        for juz, nums in by_juz.items():
            if nums != list(range(1, len(nums) + 1)):
                errors.append(f"L{level} J{juz}: session numbers are not dense 1..N: {nums}")

    return levels, sessions_by_level, errors, warnings, anomalies


def print_report(levels, sessions_by_level, errors, warnings, anomalies) -> None:
    print("\n" + "=" * 96)
    print(f"{'level':>5} {'juz':>4} {'sessions':>9} {'lessons':>8} {'sard':>5} {'exam':>5}  tiers")
    print("-" * 96)
    for level in sorted(levels):
        for juz_meta in levels[level]["juz"]:
            juz = juz_meta["juz_number"]
            ss = [s for s in sessions_by_level[level] if s["juz_number"] == juz]
            tiers = [
                f"{s['scope']['tier']}{s['unit_index'] or ''}"
                for s in ss if s["kind"] == "sard"
            ]
            print(
                f"{level:>5} {juz:>4} {len(ss):>9} "
                f"{sum(1 for s in ss if s['kind'] == 'lesson'):>8} "
                f"{sum(1 for s in ss if s['kind'] == 'sard'):>5} "
                f"{sum(1 for s in ss if s['kind'] == 'exam'):>5}  {', '.join(tiers)}"
            )
        print(f"{'':>5} {'':>4} {levels[level]['session_count']:>9}  (level total)")
    print("=" * 96)

    print(f"\nanomalies ({len(anomalies)}):")
    for a in anomalies:
        print(f"  - {a}")
    print(f"\nwarnings ({len(warnings)}):")
    for w in warnings:
        print(f"  ! {w}")
    print(f"\nerrors ({len(errors)}):")
    for e in errors:
        print(f"  X {e}")
    print()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="emit JSON after a clean validation")
    args = parser.parse_args()

    try:
        levels, sessions_by_level, errors, warnings, anomalies = extract()
    except Abort as exc:
        print(f"ABORT: {exc}", file=sys.stderr)
        return 2

    print_report(levels, sessions_by_level, errors, warnings, anomalies)

    total = sum(len(v) for v in sessions_by_level.values())
    report = {
        "generated_from": str(CURRICULUM_DIR),
        "levels": len(levels),
        "total_sessions": total,
        "per_level": {
            str(level): {
                "session_count": levels[level]["session_count"],
                "juz": {
                    str(j["juz_number"]): {
                        "session_count": j["session_count"],
                        "source_files": j["source_files"],
                        "notes": j["notes"],
                        "hizb_numbers": j["hizb_numbers"],
                    }
                    for j in levels[level]["juz"]
                },
            }
            for level in sorted(levels)
        },
        "expected_exceptions": {
            f"L{lvl}_J{juz}": exc for (lvl, juz), exc in EXPECTED_EXCEPTIONS.items()
        },
        "expected_numbering_gaps": {
            f"L{lvl}_J{juz}": note for (lvl, juz), note in EXPECTED_NUMBERING_GAPS.items()
        },
        "anomalies": anomalies,
        "warnings": warnings,
        "errors": errors,
        "passed": not errors,
    }

    if errors:
        print(f"VALIDATION FAILED with {len(errors)} error(s). Nothing was written.", file=sys.stderr)
        if args.write:
            return 1
        return 1

    print(f"VALIDATION PASSED — {total} sessions across {len(levels)} levels.")
    if not args.write:
        print("(dry run; pass --write to emit JSON)")
        return 0

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUTPUT_DIR / "levels.json").write_text(
        json.dumps([levels[l] for l in sorted(levels)], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for level, sessions in sessions_by_level.items():
        (OUTPUT_DIR / f"sessions_level_{level}.json").write_text(
            json.dumps(sessions, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    (OUTPUT_DIR / "metadata.json").write_text(
        json.dumps(
            {
                "source": "curriculum/ (read-only spreadsheets)",
                "extractor": "tools/curriculum/extract_curriculum.py",
                "levels": len(levels),
                "total_sessions": total,
                "sessions_per_level": {
                    str(l): levels[l]["session_count"] for l in sorted(levels)
                },
                "schema_version": 2,
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    (OUTPUT_DIR / "validation_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote {OUTPUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
