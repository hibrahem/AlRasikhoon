# functions/scripts

Maintenance scripts for the Cloud Functions package.

## `verify-build-fresh.sh` — build-freshness guard

Fails if the compiled `functions/lib` is stale relative to `functions/src`.

### Why it exists

`firebase deploy --only functions` ships whatever sits in `functions/lib` on the
deploying machine. Between **2026-05-10 and 2026-07-14** `firebase.json` had no
predeploy build hook, so every deploy shipped a `lib` last built on 2026-05-10.
Three merged `functions/src` changes were therefore never live and then all went
out at once, unexercised, on 2026-07-14. Full write-up:
[`docs/audits/2026-07-15-functions-dormant-deploy-audit.md`](../../docs/audits/2026-07-15-functions-dormant-deploy-audit.md)
(issue `al_rasikhoon-fh2`, root cause `al_rasikhoon-vep`).

`firebase.json` now carries a predeploy hook that rebuilds before every deploy —
that is the primary fix. This script is the independent **verification** that the
artifact actually matches source, so the gap can never silently reopen.

### How it works

`functions/lib` is gitignored, so `git diff -- functions/lib` cannot see it.
Instead the script hashes the existing `lib`, runs `npm run build`, hashes the
rebuilt `lib`, and compares:

| Situation | Result |
| --- | --- |
| `lib` existed and the hash changed | **FAIL (exit 1)** — lib was stale |
| `lib` existed and the hash is identical | PASS (exit 0) — fresh |
| `lib` absent (clean CI checkout) | PASS (exit 0) — built fresh, nothing stale possible |
| `tsc` / deps failure | exit 2 |

### Run it

```bash
functions/scripts/verify-build-fresh.sh     # from anywhere in the repo
# or
cd functions && npm run verify:build-fresh
```

### Wiring it in

- **Pre-deploy (belt-and-suspenders):** run it right before `firebase deploy`.
  `firebase.json`'s predeploy hook already rebuilds `lib`; this script turns a
  silent stale-artifact into a loud non-zero exit. It pairs naturally with
  `scripts/deploy_functions.sh` (which already runs a post-deploy IAM audit).

- **CI:** add a step to the existing `functions` job in
  `.github/workflows/ci.yml`, after `npm install`:

  ```yaml
        - name: Verify build is fresh
          run: npm run verify:build-fresh
  ```

  On a clean CI checkout `lib` is absent, so this simply proves `src` compiles
  (equivalent to the existing `Build` step). Its real value is on any machine
  that both edits `src` and deploys — it catches an out-of-date `lib` before it
  ships.
