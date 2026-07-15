#!/usr/bin/env bash
# lib-hash.sh — deterministic content hash of the compiled functions/lib.
#
# WHY THIS EXISTS
#   Two checks need to hash the compiled artifact the SAME way:
#     - verify-build-fresh.sh   (build-freshness check, al_rasikhoon-x9v)
#     - build-stamp.sh          (deployed-build identity, al_rasikhoon-5a0)
#   Keeping the hashing in one place guarantees they agree byte-for-byte.
#
# BEHAVIOUR
#   Prints a stable sha256 over every file under functions/lib (each file's
#   path relative to lib/ followed by its bytes, files sorted). The result is
#   identical across runs and machines for the same compiled output.
#   *.tsbuildinfo is a tsc cache, not a shipped artifact, so it is excluded.
#   Prints the sentinel "__NO_LIB__" when functions/lib does not exist.
#
# USE AS A LIBRARY   (defines hash_lib / _sha256, runs nothing):
#   . "$(dirname "${BASH_SOURCE[0]}")/lib-hash.sh"
#   my_hash="$(hash_lib)"
#
# USE AS A COMMAND   (prints the hash to stdout):
#   functions/scripts/lib-hash.sh

set -euo pipefail

_LIB_HASH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_HASH_FUNCTIONS_DIR="$(cd "$_LIB_HASH_SCRIPT_DIR/.." && pwd)"
# Respect a caller-provided LIB_DIR; otherwise default to functions/lib.
LIB_DIR="${LIB_DIR:-$_LIB_HASH_FUNCTIONS_DIR/lib}"

# Portable sha256: prefer sha256sum (Linux/CI), fall back to shasum (macOS).
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  else
    shasum -a 256
  fi
}

# Deterministic content hash of every compiled artifact under lib/.
# Sorted file list -> per-file path + bytes -> single sha256.
hash_lib() {
  if [ ! -d "$LIB_DIR" ]; then
    echo "__NO_LIB__"
    return 0
  fi
  # Stream each artifact's path (relative to lib/, for machine independence)
  # followed by its bytes into a single sha256. Piping into the _sha256 shell
  # function is required — `xargs` cannot invoke a shell function.
  (
    cd "$LIB_DIR"
    find . -type f ! -name '*.tsbuildinfo' -print0 \
      | LC_ALL=C sort -z \
      | while IFS= read -r -d '' f; do
          printf '%s\0' "$f"
          cat "$f"
        done
  ) | _sha256 | awk '{print $1}'
}

# When executed directly (not sourced), print the hash.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  hash_lib
fi
