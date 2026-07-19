# Firebase App Testing agent — AI-guided release tests

[`testcases.yaml`](testcases.yaml) is the version-controlled source of truth
for the natural-language test cases stored in **Firebase console → App
Distribution → Test Cases** for the Android app
(`1:276199755113:android:4e857305eac385d32781f8`). The App Testing agent (an
AI tester running on real Firebase Test Lab devices) executes them against
every stakeholder release.

## How the tests run with each release

The **Distribute Android** GitHub Action (the "cut a release" button) does
this automatically:

1. Re-imports `apptesting/testcases.yaml` into the console. The import is an
   **upsert keyed on each case's `id`** — editing a case here and releasing
   updates the console copy; nothing is duplicated.
2. Distributes the APK, passing `--test-case-ids` so the App Testing agent
   runs the smoke suite on a real device against that exact release.
3. Blocks until the agent finishes. **A failed test fails the workflow run**
   (the build has already been distributed — treat a red run as a
   post-release smoke alarm). Results, including screen recordings and the
   agent's step-by-step reasoning, are in **Firebase console → App
   Distribution → the release → Tests**.

The workflow inputs `run_agent_tests` (default on) and `test_case_ids`
(default: the smoke suite) control this per release.

## The QA account (required for signed-in tests)

Signed-in tests use the credentials from the repo secrets
`APP_TESTING_USERNAME` / `APP_TESTING_PASSWORD` (Settings → Secrets and
variables → Actions). Until those are set, releases run only the signed-out
tests and the workflow prints a warning.

Set it up once:

1. Have an admin create a **dedicated QA account** in the app (any role;
   the smoke suite is role-agnostic — pick the role whose journeys you want
   covered by the role-specific cases).
2. Add its username and password as the two repo secrets above.

The agent runs against **production** data, so every test case is written to
be **read-only**: navigate and assert, never create/edit/delete. Keep new
test cases read-only too, and say so explicitly in the goal ("Do not save…").

## Editing / adding test cases

- Edit `testcases.yaml` and merge — the next release syncs the console
  automatically. To sync immediately without a release:

  ```bash
  firebase appdistribution:testcases:import apptesting/testcases.yaml \
    --app 1:276199755113:android:4e857305eac385d32781f8
  ```

- Schema: a top-level **list** of cases with `id`, `displayName`, optional
  `prerequisiteTestCaseId` (must reference an existing/earlier id), and
  `steps` of `goal` / optional `hint` / optional `successCriteria`. (This is
  the App Distribution import schema — not the `tests:`-wrapped format used
  by `firebase apptesting:execute`.)
- To pull the console state back into a file (e.g. after someone edits in
  the console UI): `firebase appdistribution:testcases:export <file> --app …`.
- Cases added to the file are **not** run on release until their id is added
  to the smoke lists in `.github/workflows/distribute-android.yml` (or passed
  via the `test_case_ids` workflow input). The role-specific cases
  (`teacher-*`, `student-*`, `supervisor-*`, `admin-*`) are meant to be run
  via the `test_case_ids` input with a QA account of the matching role, or
  on demand from the console's Test Cases page.

## Devices

Default device matrix: `model=tokay,version=36,locale=en,orientation=portrait`
(Pixel 9, Android 16) — override with the `TEST_DEVICES` env of
`scripts/distribute_android.sh`. List available devices with
`gcloud firebase test android models list`.
