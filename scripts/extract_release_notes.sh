#!/usr/bin/env bash
# Print the body of the TOPMOST section of a "Keep a Changelog"-style file —
# i.e. everything after the first `## ` heading and before the next `## `
# heading (or end of file). Used to feed stakeholder-facing release notes into
# Firebase App Distribution.
#
# It is heading-name agnostic: the top section may be labelled `## Unreleased`,
# `## [1.2.0] - 2026-07-15`, or anything else — its body is what gets shipped.
# The heading line itself is NOT printed (testers see the notes, not a version
# header), and surrounding blank lines are trimmed.
#
# Usage:
#   scripts/extract_release_notes.sh [CHANGELOG_PATH]   # defaults to CHANGELOG.md
#
# Exit codes:
#   0  notes printed to stdout
#   1  changelog file missing, has no `## ` section, or the top section is empty
#      — CI treats this as a hard failure so a forgotten changelog never ships
#      an empty set of notes.

set -euo pipefail

CHANGELOG="${1:-CHANGELOG.md}"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "ERROR: changelog not found at '$CHANGELOG'." >&2
  exit 1
fi

# awk: capture the lines strictly between the 1st and 2nd `## ` headings,
# buffering them so leading/trailing blank lines can be trimmed before output.
# Portable across GNU and BSD/macOS awk (no gensub, no non-POSIX features).
notes="$(
  awk '
    /^## / {
      count++
      if (count == 1) { grab = 1; next }   # skip the top heading line itself
      if (count >= 2) { exit }              # stop at the next section
    }
    grab { buf[n++] = $0 }
    END {
      # first non-blank line
      start = -1
      for (i = 0; i < n; i++) if (buf[i] ~ /[^[:space:]]/) { start = i; break }
      if (start == -1) exit                  # section is all blank
      # last non-blank line
      for (i = n - 1; i >= 0; i--) if (buf[i] ~ /[^[:space:]]/) { end = i; break }
      for (i = start; i <= end; i++) print buf[i]
    }
  ' "$CHANGELOG"
)"

if [[ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]]; then
  echo "ERROR: the top section of '$CHANGELOG' has no release notes. Add a bullet before shipping." >&2
  exit 1
fi

printf '%s\n' "$notes"
