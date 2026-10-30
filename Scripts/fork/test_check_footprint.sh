#!/usr/bin/env bash
# Mutation tests for check_footprint.sh using synthetic commits (branch and worktree stay untouched).
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CHECK="$ROOT_DIR/Scripts/fork/check_footprint.sh"
cd "$ROOT_DIR"
# Base tag: $1, else $FORK_BASE_TAG, else the nearest upstream-based tag (fork -audi.* tags excluded).
BASE=${1:-${FORK_BASE_TAG:-$(git describe --tags --abbrev=0 --match 'v*-mobile.*' --exclude '*-audi.*' 2>/dev/null || true)}}
[[ -n "$BASE" ]] || { echo "ERROR: cannot determine base tag; pass it as \$1 or set FORK_BASE_TAG" >&2; exit 2; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_INDEX_FILE="$TMP/index"

# Build a commit on top of HEAD with one file appended; prints the commit sha.
mutate() {
  local file=$1 line=$2
  git read-tree HEAD
  local blob
  blob=$( { git show "HEAD:$file"; printf '%s\n' "$line"; } | git hash-object -w --stdin)
  git update-index --cacheinfo "100644,$blob,$file"
  git commit-tree "$(git write-tree)" -p HEAD -m "synthetic mutation"
}

expect() { # name expected-exit sha-or-HEAD
  local name=$1 want=$2 sha=$3 out rc=0
  out=$(FOOTPRINT_HEAD=$sha "$CHECK" "$BASE" 2>&1) || rc=$?
  if [[ $rc -ne $want ]]; then
    echo "FAIL $name: exit $rc, want $want"; echo "$out"; exit 1
  fi
  echo "ok   $name (exit $rc)"
  printf '%s\n' "$out" | sed 's/^/       /'
}

expect "clean HEAD passes" 0 HEAD
# Package.resolved exists in the base and is not declared; Package.swift is declared with a budget.
undeclared=Package.resolved
if grep -q "^$undeclared	" fork/footprint.tsv; then echo "test setup: $undeclared is declared"; exit 1; fi
expect "undeclared upstream file fails" 1 "$(mutate "$undeclared" '// extra')"
expect "over-budget declared file fails" 1 "$(mutate Package.swift '// extra')"
