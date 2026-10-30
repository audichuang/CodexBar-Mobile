#!/usr/bin/env bash
# Pure helpers for Scripts/fork_sync_gate.sh; sourced by it and by Scripts/fork/test_fork_sync_gate.sh.

# Nearest reachable upstream-based tag; the fork's own release tags (-audi.N) are not a rebase base.
detect_base_tag() {
  git describe --tags --abbrev=0 --match 'v*-mobile.*' --exclude '*-audi.*' "$@" 2>/dev/null || true
}

# Print failing test names the way the baseline files were produced.
mac_fail_list() { grep -E '✘ Test .* failed|Test [Cc]ase .* failed' "$1" | sed -E 's/ (after|\().*//' | sort -u; }
ios_fail_list() { grep -E 'Test [Cc]ase .* failed|✘ Test .* failed' "$1" | sed -E 's/ (after|on |\().*//' | sort -u; }

# Compare a failure list against its baseline file, or require it to be empty.
check_new_failures() {
  local label=$1 list=$2 base=${3:-} new
  if [[ -n "$base" ]]; then
    [[ -f "$base" ]] || { echo "baseline file missing: $base"; return 1; }
    # The "Test run with N tests ... failed" summary line changes whenever tests are added; drop it.
    new=$(comm -13 <(grep -v 'Test run with' "$base") <(grep -v 'Test run with' "$list"))
  else
    new=$(grep -v 'Test run with' "$list")
  fi
  if [[ -n "$new" ]]; then
    echo "$label: new failing tests:"
    echo "$new"
    return 1
  fi
  echo "$label: no new failures ($(wc -l <"$list" | tr -d ' ') failing, baseline-tolerated)"
}

# Decide a test stage: check_test_outcome <label> <tool-rc> <fail-list> <baseline-file-or-empty> <log>
# A non-zero tool exit with no parsed failure (compile error, crashed runner) always fails,
# with or without a baseline; otherwise new failures are judged against the baseline.
check_test_outcome() {
  local label=$1 rc=$2 list=$3 base=${4:-} log=${5:-}
  if [[ $rc -ne 0 && ! -s "$list" ]]; then
    echo "$label: tool exited $rc without a parsable test failure (see $log)"
    return 1
  fi
  check_new_failures "$label" "$list" "$base"
}
