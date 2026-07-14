# Paced curriculum (NX) — plan: docs/superpowers/plans/2026-07-14-paced-curriculum-nx.md
# Issue: al_rasikhoon-g63
# Worktree: .claude/worktrees/paced-curriculum-nx
# Branch: feat/paced-curriculum-nx (base ad03308, off feat/talqeen-sessions)
# NOTE: a parallel Claude session holds uncommitted SessionRecordModel work
#       (kind + juzNumber) in the MAIN checkout. This worktree does not have it.
#       Task 6 rewrites the same model -> expect a merge reconciliation at the end.
# Baseline: 615 tests passing at ad03308.
Task 1: complete (commit 6f52bff, review clean) — CurriculumPace value object; validating ctor (not const/assert), fromJson(null)=standard
  Minor (final review): fromJson rejects a double (e.g. 3.0); correct per spec, but note if a write path ever serializes pace as double
Task 2: complete (commits 72b70e8, d1581eb — impl + fix, review clean) — PacedSession + PacedSessionComposer
  Reviewer mutation-tested the composer and simulated it over the real 952 rows. pace-1 verbatim early return
  is intact and PROVEN load-bearing (deleting it fails a test). Fixed: vacuous سرد test (asserted nothing),
  no اختبار coverage, _unitStart clamp now stops at an assessment (latent trap for a future curriculum re-import).
  Minor (final review): F3 levelId!=start.levelId guard in _batch is unreachable (byOrder keyed on order alone);
    F4 recent-window loop bound `order < start` protected only by rule 3, not pinned directly;
    F6 taught-today exclusion is exact-equality only (safe today: all 59 تلقين duplicate their lesson exactly);
    at a unit start the composed recent lists the تلقين block TWICE (per brief's own expected output) —
    PRESENTATION (Task 9) should de-duplicate before showing a student.
  NEW SOURCE-DATA DEFECT found by reviewer: L4 order 6 authored recent is `السجدة 21-11` — INVERTED
    (from_verse 21 > to_verse 11). Add to al_rasikhoon-drw.
Task 3: complete (commit dedb615, review clean) — 952 real sessions walked; pace-1 verbatim PASSES on all 10 levels
  Reviewer MUTATION-PROVED the test has teeth: deleting the pace-1 early return fails group 1 on ALL 10 levels;
  deleting the !isLesson batch guard fails group 3 on all 10.
  *** MAJOR FINDING: the early return protects far MORE than the ~8 anomalous rows. Composition represents
  recent review as DISCRETE ADJACENT BLOCKS [لقمان 20-28, لقمان 29-34] while the curriculum authors the same
  span as ONE MERGED RANGE [لقمان 20-34]. So at pace 1 composition would differ on NEARLY EVERY row.
  => Open design question for pace>1 presentation: composed recent is fragmented, and at a unit start it also
     lists the تلقين block TWICE. A 2x student would see "النبأ 1-11 • النبأ 1-11 • النبأ 12-20 • النبأ 21-30"
     instead of the curriculum's own idiom "النبأ 1-30". ESCALATED TO USER before Task 4.
  RESOLVED by user: de-dupe + merge contiguous blocks, ALL THREE streams (new too: 2x new = "النبأ 31 - 40").
  Controller decision: do it in the DISPLAY getters (Task 8), NOT in the composer. Rationale: the composer's
  discrete lists are what give Task 2/3's mutation-proven tests their teeth (the "recent never intersects
  today's new" assertion compares discrete blocks; merging inside the composer would make it never match and
  silently go toothless). Domain keeps truth; presentation merges. Merge rule = the curriculum's own:
  span(first.from -> last.to) per contiguous run, after de-dupe. No verse number is ever computed.
