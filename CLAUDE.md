# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

### Changelog (stakeholder release notes)

Stakeholder test builds are cut **on demand** — a maintainer clicks "Run
workflow" on the **Distribute Android** GitHub Action, which builds an Android
APK and ships it via Firebase App Distribution. The release notes stakeholders
read come **verbatim from the top section of `CHANGELOG.md`**, so the top
section must always reflect everything merged since the last distribution.

**Rule:** For any change that affects what a user can see or do, add a bullet to
the top (`## Unreleased`) section of `CHANGELOG.md` **in the same change**,
written for a non-technical business stakeholder — describe the outcome, not the
implementation.

- Write outcomes, not commits: ✅ "Teachers can now see a student's full history
  on one screen." — ❌ "Refactor StudentProfileScreen to use shared providers."
- Skip purely internal work (refactors, tests, CI, dependency bumps, chores)
  that a stakeholder would never notice — those need no changelog entry.
- The distribution run fails if the top section is empty, so don't leave it
  blank when user-facing work has landed.

See `docs/superpowers/specs/2026-07-15-android-firebase-distribution-design.md`
and `docs/agdr/AgDR-0004-android-firebase-distribution.md`.
