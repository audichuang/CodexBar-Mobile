#!/usr/bin/env bash
# Regression tests for the decision helpers in Scripts/fork/gate_lib.sh (no xcodebuild / swift test is run).
# GATE_LIB overrides the library path (used to prove the cases fail against the pre-fix logic).
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"
# shellcheck source=gate_lib.sh
source "${GATE_LIB:-$ROOT_DIR/Scripts/fork/gate_lib.sh}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fails=0

expect() { # name want-rc got-rc [output]
  if [[ $2 -eq $3 ]]; then echo "ok   $1"; else echo "FAIL $1: rc $3, want $2"; [[ -n "${4:-}" ]] && echo "$4"; fails=1; fi
}

# decide <label> <tool-rc> <log-text> <baseline-text|-> ; prints outcome, returns the decision rc
decide() {
  local label=$1 rc=$2 text=$3 base=$4 log="$TMP/raw.log" list="$TMP/list.txt" bf=""
  printf '%s\n' "$text" >"$log"
  if [[ "$label" == mac ]]; then mac_fail_list "$log" >"$list"; else ios_fail_list "$log" >"$list"; fi
  if [[ "$base" != "-" ]]; then printf '%s\n' "$base" >"$TMP/base.txt"; bf="$TMP/base.txt"; fi
  check_test_outcome "$label" "$rc" "$list" "$bf" "$log"
}
run() { local out rc=0; out=$(decide "$@") || rc=$?; LAST_OUT=$out; return $rc; }

IOS_COMPILE_ERR=$'error: cannot find type Foo in scope\nTesting failed:\n\tCannot find type Foo\n** TEST FAILED **'
MAC_CRASH=$'Fatal error: signal 11\nerror: fatalError'
MAC_FAIL=$'✘ Test foo() failed after 0.1 seconds.'

run ios 65 "$IOS_COMPILE_ERR" -;           expect "ios compile error, no baseline fails" 1 $? "$LAST_OUT"
run ios 65 "$IOS_COMPILE_ERR" "✘ Test old() failed"; expect "ios compile error, with baseline fails" 1 $? "$LAST_OUT"
run mac 1 "$MAC_CRASH" -;                  expect "mac crash, no baseline" 1 $? "$LAST_OUT"
run mac 1 "$MAC_CRASH" "✘ Test old() failed"; expect "mac crash, with baseline" 1 $? "$LAST_OUT"
run mac 1 "$MAC_FAIL" "✘ Test foo() failed"; expect "mac baseline-tolerated failure passes" 0 $? "$LAST_OUT"
run mac 1 "$MAC_FAIL" "✘ Test other() failed"; expect "mac new failure fails" 1 $? "$LAST_OUT"
run mac 0 "all good" -;                    expect "mac clean run passes" 0 $? "$LAST_OUT"
run ios 0 $'** TEST SUCCEEDED **' -;       expect "ios clean run passes" 0 $? "$LAST_OUT"

# Base tag detection must skip the fork's own -audi.N release tags.
if git rev-parse -q --verify 'refs/tags/v0.81.0.1-mobile.3.1.0-audi.5' >/dev/null &&
   git rev-parse -q --verify 'refs/tags/v0.79.0.1-mobile.3.1.0' >/dev/null; then
  got=$(detect_base_tag 'v0.81.0.1-mobile.3.1.0-audi.5^{commit}')
  [[ "$got" == v0.79.0.1-mobile.3.1.0 ]]; expect "base tag skips -audi tags (got $got)" 0 $?
else
  echo "SKIP base tag detection: fork/upstream tags not fetched"
fi

exit $fails
