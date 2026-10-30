#!/usr/bin/env bash
# Fail when the fork changes an upstream-owned file that is not declared in
# fork/footprint.tsv, or exceeds the declared line budget.
# Usage: Scripts/fork/check_footprint.sh <base-tag> [manifest]
# Files that do not exist in <base-tag> are fork-owned and always allowed.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BASE=${1:-}
MANIFEST=${2:-"$ROOT_DIR/fork/footprint.tsv"}
HEAD_REF=${FOOTPRINT_HEAD:-HEAD}  # tests override this to check a synthetic commit

if [[ -z "$BASE" ]]; then
  echo "usage: $0 <base-tag> [manifest]" >&2
  exit 2
fi
if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: footprint manifest missing: $MANIFEST" >&2
  exit 2
fi
if ! git -C "$ROOT_DIR" rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null; then
  echo "ERROR: base ref not found: $BASE" >&2
  exit 2
fi

# --diff-filter=MDT: only paths that exist in the base (modified, deleted, type change).
# --no-renames: a rename away from an upstream path shows up as a delete.
# Binary files report "-" and count as 1 changed line.
git -C "$ROOT_DIR" -c core.quotepath=off diff --numstat --no-renames --diff-filter=MDT "${BASE}..${HEAD_REF}" |
  awk -F'\t' -v manifest="$MANIFEST" '
    BEGIN {
      while ((getline line < manifest) > 0) {
        if (line ~ /^#/ || line ~ /^[[:space:]]*$/) continue
        n = split(line, f, "\t")
        if (n < 3 || f[2] !~ /^[0-9]+$/ || f[3] == "") {
          printf "ERROR: malformed manifest row (need path, numeric budget, purpose): %s\n", line
          bad = 1
          continue
        }
        if (f[1] in budget) {
          printf "ERROR: duplicate manifest row: %s\n", f[1]
          bad = 1
        }
        budget[f[1]] = f[2] + 0
      }
    }
    {
      path = $3
      changed = ($1 == "-" ? 1 : $1 + $2)
      seen[path] = 1
      total++
      if (!(path in budget)) {
        printf "FAIL undeclared upstream file changed: %s (%d lines). Move the logic into a fork-owned file and keep at most a one-line hook, then declare it in fork/footprint.tsv.\n", path, changed
        fail = 1
      } else if (changed > budget[path]) {
        printf "FAIL over budget: %s changed %d lines, budget %d\n", path, changed, budget[path]
        fail = 1
      }
    }
    END {
      for (p in budget) if (!(p in seen)) printf "note: manifest row has no diff vs base (can be removed): %s\n", p
      if (bad || fail) exit 1
      printf "fork footprint check passed: %d upstream files changed, all declared within budget\n", total
    }'
