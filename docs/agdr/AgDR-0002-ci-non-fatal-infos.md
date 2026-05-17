# AgDR-0002 — CI `flutter analyze` non-fatal on infos; sealed-class mock warnings fixed inline

> In the context of the #6 CI pipeline turning `main` red because
> `flutter analyze` is fatal-on-infos-and-warnings by default and the repo
> carries 123 pre-existing whole-project analyzer issues (121 info + 2
> warning, 0 error), facing a blocked `main` CI where the Unit-tests step is
> skipped on every push, I decided to (a) fix the 2 real
> `subtype_of_sealed_class` **warnings** properly with narrowly-scoped inline
> `// ignore:` + justification on the two mocktail test doubles, and (b) make
> CI analyze non-fatal on **infos only** (`flutter analyze --no-fatal-infos`,
> warnings/errors stay fatal) while tracking the 106-site `withOpacity`
> migration debt as follow-up issue #13, to unblock `main` CI with a small
> reviewable diff without masking real signal, accepting that the 121 infos
> remain as known, tracked debt until #13 lands.

Refs: issue #12. Follow-up debt: issue #13.

## Context

- The #6 CI pipeline (`.github/workflows/ci.yml`, AgDR-0001) is now on `main`.
  Its `flutter` job runs `flutter analyze` then `flutter test test/`.
- `flutter analyze` is **fatal on infos and warnings by default**. The
  fan-out agents that built the feature code ran per-file
  `flutter analyze <changed files>`, which never surfaced whole-project debt.
- First whole-project run on `main` (run 26005087961) reported **123 issues**:

  | Count | Severity | Rule | Nature |
  |------:|----------|------|--------|
  | 106 | info | `deprecated_member_use` | `withOpacity` → `.withValues()`, 31 files under `lib/features/**` + `lib/shared/widgets/**` — mechanical, pre-existing |
  | 10 | info | `unnecessary_underscores` | style, pre-existing |
  | 3 | info | `unintended_html_in_doc_comment` | doc-comment `<...>`, pre-existing |
  | 1 | info | `use_build_context_synchronously` | `reset_password_dialog.dart` |
  | 1 | info | `unnecessary_import` | redundant import in a test |
  | **2** | **warning** | **`subtype_of_sealed_class`** | mocktail doubles implementing sealed `cloud_firestore` types — **real signal** |
  | | | **0 error** | |

  Reproduced locally at this HEAD: identical 121 info + 2 warning + 0 error.
- The 2 warnings are in `test/unit/data/repositories/user_repository_test.dart`
  (declarations at lines 29 and 46). `cloud_firestore ^6.1.2` marks `Query`
  (ancestor of `CollectionReference`) and `DocumentReference` as `sealed`.
  `mocktail`'s only test-double mechanism is `extends Mock implements <type>`,
  which trips `subtype_of_sealed_class`. The mocks (`_DeleteDeniedCollection`,
  `_DeleteDeniedDocument`) deliberately simulate a `permission-denied` failure
  on `delete()` during legacy-doc migration — there is **no non-sealed seam**
  to inject that failure. (`_DeleteDeniedFirestore implements FirebaseFirestore`
  does NOT warn — `FirebaseFirestore` is not sealed.)
- Effect: Analyze step fails → Unit-tests step **skipped** → no test coverage
  runs on any push/PR to `main`. Severity High.

## Options Considered

### The 2 `subtype_of_sealed_class` warnings (real signal)

| Option | Pros | Cons |
|--------|------|------|
| **Narrowly-scoped inline `// ignore: subtype_of_sealed_class` + one-line justification on each of the 2 class declarations** | Keeps the rule globally active (future accidental sealed-subtyping still caught); the suppression is visible, auditable, and explained at the exact site; zero behaviour change; idiomatic for mocking sealed Firestore types | Two small inline comments to maintain |
| Project-wide disable of `subtype_of_sealed_class` in `analysis_options.yaml` | One line | Masks the rule everywhere — a future real misuse (non-test code subtyping a sealed class) would pass silently. Explicitly rejected by issue #12 ("do NOT blanket-suppress"). |
| Rewrite mocks to avoid `implements` of the sealed type | Removes the warning at the root | Not possible: the sealed types have no public non-sealed interface to mock; rewriting to a hand-rolled fake of the whole Firestore surface is large, fragile, and out of scope for a CI fix |
| `// ignore_for_file:` at top of the test | One line, file-scoped | Broader than necessary — would also hide a genuinely-wrong future sealed subtype added elsewhere in the same file |

Chosen: **narrowly-scoped inline `// ignore:` + justification on the two
declarations.** The mocks are legitimate, unavoidable, and the standard
mocktail idiom for sealed `cloud_firestore` types; line-scoped suppression
keeps the rule's protective value everywhere else.

### The 121 pre-existing infos

| Option | Pros | Cons |
|--------|------|------|
| **CI `flutter analyze --no-fatal-infos` (warnings/errors stay fatal) + tracked follow-up issue #13 for the `withOpacity` migration** | Smallest, most reviewable diff (1 line in `ci.yml`); unblocks `main` CI now; real signal (warnings/errors) still blocks merges; debt is explicitly tracked, not silently dropped; CI fix and product-code refactor stay separate concerns / separate PRs | The 121 infos remain visible-but-non-blocking until #13 lands; CI is temporarily looser on infos |
| Do the 106-site `withOpacity` → `withValues` migration now in this PR | Pays the debt immediately; could restore strict fatal-infos | 106 sites across 31 UI files — product-code churn far larger than the CI fix it accompanies; mixes a CI-pipeline change with a large UI refactor in one PR; alpha-compositing migration across 31 files is hard to review for guaranteed behaviour preservation; issue #12 itself scopes this as "CI behaviour + a small warning fix … not product code" and lists the migration as *optional* |
| Suppress each info rule project-wide in `analysis_options.yaml` | Keeps analyze fatal-on-warnings while greening infos | Disables the rules everywhere including future code; `deprecated_member_use` is genuinely useful signal to keep on going forward; harder to ever re-tighten |
| Leave CI fatal-on-infos and fix all 121 infos (incl. the ~15 non-`withOpacity` ones) | Cleanest end state | Largest possible blast radius for a High-severity "unblock CI now" fix; delays restoring test execution on `main` |

Chosen: **CI `flutter analyze --no-fatal-infos` + follow-up issue #13.**
`--no-fatal-warnings` is deliberately **left OFF** so warnings and errors
remain fatal — the just-fixed mock issue (and any future real warning) still
blocks CI and cannot silently regress.

## Decision

Chosen:

1. **Warnings:** narrowly-scoped inline `// ignore: subtype_of_sealed_class`
   with a one-line justification on `_DeleteDeniedCollection` (line 29) and
   `_DeleteDeniedDocument` (line 46) in
   `test/unit/data/repositories/user_repository_test.dart`. The rule stays
   globally active.
2. **Infos:** change the CI Analyze step from `flutter analyze` to
   `flutter analyze --no-fatal-infos` in `.github/workflows/ci.yml`. Warnings
   and errors stay fatal (`--no-fatal-warnings` intentionally NOT added).
3. **Debt tracking:** the 106-site `withOpacity` → `Color.withValues()`
   migration is filed as follow-up issue **#13**, referenced from `ci.yml`
   and this AgDR, so the relaxation is paired with a tracked paydown path.

Because it unblocks `main` CI (restoring the skipped Unit-tests step) with a
minimal, reviewable diff while keeping every real `warning`/`error` signal
fatal and the info debt explicitly tracked rather than silently masked.

## Consequences

- `main` CI `Flutter` job goes green; the previously-skipped **Unit tests**
  step now actually runs (`flutter test test/`) on every push/PR.
- `subtype_of_sealed_class` remains globally enforced — a future genuine
  sealed-class misuse (in non-test code, or a new test) is still caught.
- The 121 infos remain reported by `flutter analyze` locally and in CI logs
  but no longer fail the job. They are known, tracked debt (#13 for the 106
  `withOpacity` sites; the remaining ~15 infos can be filed separately if/when
  prioritised).
- CI is temporarily looser on infos. Tightening back toward fatal-infos is a
  separate future decision, gated on #13 (and the residual infos) landing.
- No product/runtime behaviour changes in this PR — only a test-file comment
  addition and a one-flag CI change.
- `analysis_options.yaml` is intentionally **unchanged** — no rule was
  globally disabled; the IDE/local analyzer keeps surfacing all infos and the
  sealed-class rule so the debt stays visible to developers.

## Artifacts

- `.github/workflows/ci.yml` (Analyze step → `flutter analyze --no-fatal-infos`)
- `test/unit/data/repositories/user_repository_test.dart` (2 inline `// ignore:` + justification)
- `docs/agdr/AgDR-0002-ci-non-fatal-infos.md` (this file)
- Branch: `fix/#12-ci-analyze-fatal-infos`
- Issue: https://github.com/hibrahem/AlRasikhoon/issues/12
- Follow-up debt issue: https://github.com/hibrahem/AlRasikhoon/issues/13
