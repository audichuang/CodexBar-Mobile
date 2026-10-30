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

# Markers a crashed, restarted or timed-out test run leaves in its log. Any of them fails the stage
# whatever the exit code or parsed failure list says: a run that dies after printing one
# baseline-known failure must not read as "no new failures".
CRASH_MARKER_RE='Exited with (unexpected )?signal|unexpected signal code|Restarting after unexpected exit|[Ee]arly unexpected exit|Test crashed with signal|encountered an error \(|Fatal error:|::warning::Command timed out'

# Did the run finish? check_test_completion <label> <log>
# ios: xcodebuild verdict plus the XCTest and swift-testing summaries.
# mac: either the grouped runner (Scripts/fork/gate_mac_groups.py) reached its BADGROUPS summary having
# started every group 1..K, or a plain `swift test` printed both of its summaries.
check_test_completion() {
  local label=$1 log=$2 total
  if [[ "$label" == ios ]]; then
    grep -qE '\*\* TEST (FAILED|SUCCEEDED) \*\*' "$log" &&
      grep -qE "^Test Suite 'All tests' (passed|failed)" "$log" &&
      grep -qE '^(✔|✘) Test run with [0-9]+ tests?' "$log" && return 0
    echo "$label: run did not complete (missing xcodebuild verdict, XCTest summary or swift-testing summary; see $log)"
    return 1
  fi
  if grep -qE '^::group::Swift test group [0-9]+/[0-9]+' "$log"; then
    total=$(grep -oE '^::group::Swift test group [0-9]+/[0-9]+' "$log" | head -1 | sed -E 's|.*/||')
    if grep -q '^BADGROUPS ' "$log" &&
       [[ $(grep -oE '^::group::Swift test group [0-9]+/' "$log" | grep -oE '[0-9]+' | sort -un | wc -l | tr -d ' ') -eq $total ]]; then
      return 0
    fi
    echo "$label: grouped run did not complete all $total groups (see $log)"
    return 1
  fi
  grep -qE "^Test Suite 'All tests' (passed|failed)" "$log" && grep -qE '^(✔|✘) Test run with [0-9]+ tests?' "$log" && return 0
  echo "$label: run did not complete (no group summary and no swift-testing summary; see $log)"
  return 1
}

# Decide a test stage: check_test_outcome <label:mac|ios> <tool-rc> <fail-list> <baseline-file-or-empty> <log>
# 1. A crash/timeout marker in the log fails. 2. The run must have completed. 3. A non-zero tool exit
# with no parsed failure (compile error, crashed runner) fails with or without a baseline.
# 4. Otherwise new failures are judged against the baseline.
check_test_outcome() {
  local label=$1 rc=$2 list=$3 base=${4:-} log=${5:-}
  if grep -qE "$CRASH_MARKER_RE" "$log"; then
    echo "$label: crash or timeout marker in $log:"
    grep -E "$CRASH_MARKER_RE" "$log" | head -5
    return 1
  fi
  check_test_completion "$label" "$log" || return 1
  if [[ $rc -ne 0 && ! -s "$list" ]]; then
    echo "$label: tool exited $rc without a parsable test failure (see $log)"
    return 1
  fi
  check_new_failures "$label" "$list" "$base"
}
