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

IOS_DONE=$'Test Suite \'All tests\' passed at 2026-01-01 00:00:00.000.\n✔ Test run with 3 tests in 1 suite passed after 0.1 seconds.\n** TEST SUCCEEDED **'
IOS_DONE_FAILED=$'Test Suite \'All tests\' failed at 2026-01-01 00:00:00.000.\n✘ Test run with 3 tests in 1 suite failed after 0.1 seconds with 1 issue.\n** TEST FAILED **'
MAC_DONE=$'::group::Swift test group 1/2\n::group::Swift test group 2/2\nGROUPRESULT 2 0\nBADGROUPS []'
MAC_DONE_BAD=$'::group::Swift test group 1/2\n::group::Swift test group 2/2\nGROUPRESULT 2 1\nBADGROUPS [2]'
IOS_COMPILE_ERR=$'error: cannot find type Foo in scope\nTesting failed:\n\tCannot find type Foo\n** TEST FAILED **'
MAC_CRASH=$'Fatal error: signal 11\nerror: fatalError'
MAC_FAIL=$'✘ Test foo() failed after 0.1 seconds.'
IOS_FAIL=$'✘ Test foo() failed after 0.1 seconds.'

run ios 65 "$IOS_COMPILE_ERR" -;           expect "ios compile error, no baseline fails" 1 $? "$LAST_OUT"
run ios 65 "$IOS_COMPILE_ERR" "✘ Test old() failed"; expect "ios compile error, with baseline fails" 1 $? "$LAST_OUT"
run mac 1 "$MAC_CRASH" -;                  expect "mac crash, no baseline" 1 $? "$LAST_OUT"
run mac 1 "$MAC_CRASH" "✘ Test old() failed"; expect "mac crash, with baseline" 1 $? "$LAST_OUT"
run mac 1 "$MAC_DONE_BAD"$'\n'"$MAC_FAIL" "✘ Test foo() failed"; expect "mac baseline-tolerated failure passes" 0 $? "$LAST_OUT"
run mac 1 "$MAC_DONE_BAD"$'\n'"$MAC_FAIL" "✘ Test other() failed"; expect "mac new failure fails" 1 $? "$LAST_OUT"
run mac 0 "$MAC_DONE" -;                   expect "mac clean grouped run passes" 0 $? "$LAST_OUT"
run mac 0 $'Test Suite \'All tests\' passed at x\n✔ Test run with 3 tests in 1 suite passed after 1 seconds.' -
expect "mac clean plain swift test run passes" 0 $? "$LAST_OUT"
run ios 0 "$IOS_DONE" -;                   expect "ios clean run passes" 0 $? "$LAST_OUT"
run ios 65 "$IOS_DONE_FAILED"$'\n'"$IOS_FAIL" "✘ Test foo() failed"; expect "ios baseline-tolerated failure passes" 0 $? "$LAST_OUT"

# A known (baseline) failure followed by a crash or timeout must not pass as "no new failures".
for marker in 'Exited with unexpected signal code 11' 'Exited with signal code 11' 'Restarting after unexpected exit' \
  'Early unexpected exit' 'Test crashed with signal segv' 'encountered an error (Crash)' 'Fatal error: boom' \
  '::warning::Command timed out after 180s: swift test'; do
  run mac 1 "$MAC_DONE_BAD"$'\n'"$MAC_FAIL"$'\n'"$marker" "✘ Test foo() failed"
  expect "mac known failure + crash marker fails ($marker)" 1 $? "$LAST_OUT"
  run mac 0 "$MAC_DONE"$'\n'"$marker" -
  expect "mac rc 0 + crash marker fails ($marker)" 1 $? "$LAST_OUT"
  run ios 65 "$IOS_DONE_FAILED"$'\n'"$IOS_FAIL"$'\n'"$marker" "✘ Test foo() failed"
  expect "ios known failure + crash marker fails ($marker)" 1 $? "$LAST_OUT"
done
# Completion markers are required even when the tool exits 0 or the known failure was parsed.
run mac 1 $'::group::Swift test group 1/3\n::group::Swift test group 2/3\nBADGROUPS []' -; expect "mac missing group 3/3 fails" 1 $? "$LAST_OUT"
run mac 1 $'::group::Swift test group 1/2\n::group::Swift test group 2/2' -; expect "mac no BADGROUPS summary fails" 1 $? "$LAST_OUT"
run mac 1 "$MAC_FAIL" "✘ Test foo() failed"; expect "mac known failure without completion marker fails" 1 $? "$LAST_OUT"
run ios 65 $'✘ Test foo() failed after 1 seconds.\n** TEST FAILED **' "✘ Test foo() failed"; expect "ios known failure without suite/run markers fails" 1 $? "$LAST_OUT"
run ios 0 $'** TEST SUCCEEDED **' -;       expect "ios verdict only fails" 1 $? "$LAST_OUT"

# Checked-in excerpts of real logs (Scripts/fork/fixtures): completion markers and failure lines only.
FX="$ROOT_DIR/Scripts/fork/fixtures"
fixture() { # name want-rc label rc baseline-file-or-self log
  local name=$1 want=$2 label=$3 rc=$4 base=$5 log="$FX/$6" got=0 out
  if [[ $label == mac ]]; then mac_fail_list "$log" >"$TMP/fx.list"; else ios_fail_list "$log" >"$TMP/fx.list"; fi
  [[ $base == self ]] && { cp "$TMP/fx.list" "$TMP/fx.base"; base="$TMP/fx.base"; } || base="$FX/$base"
  out=$(check_test_outcome "$label" "$rc" "$TMP/fx.list" "$base" "$log") || got=1
  expect "fixture $name" "$want" $got "$out"
}
fixture "mac grouped, complete" 0 mac 1 self mac-grouped-complete.log
fixture "mac grouped, aborted before group 3" 1 mac 1 self mac-grouped-aborted.log
fixture "mac plain swift test, complete" 0 mac 1 self mac-plain-complete.log
fixture "ios complete, baseline-tolerated" 0 ios 65 ios-baseline-fail.txt ios-complete.log
fixture "ios complete, new failure" 1 ios 65 /dev/null ios-complete.log

# Opt-in: replay real logs kept in the gate cache (FORK_GATE_REPLAY=1; not part of the required run).
G=${CODEXBAR_GATE_DIR:-$HOME/Library/Caches/codexbar-gate}
replay() { # name want-rc label rc baseline-fail-file log...
  local name=$1 want=$2 label=$3 rc=$4 base=$5 f out got=0 G=$G; shift 5
  for f in "$@"; do [[ -f "$G/$f" ]] || { echo "SKIP real-log $name: $G/$f not present"; return; }; done
  [[ $base == self || -f "$G/$base" ]] || { echo "SKIP real-log $name: $G/$base not present"; return; }
  : >"$TMP/real.log"; for f in "$@"; do cat "$G/$f" >>"$TMP/real.log"; done
  if [[ $label == mac ]]; then mac_fail_list "$TMP/real.log" >"$TMP/real.list"; else ios_fail_list "$TMP/real.log" >"$TMP/real.list"; fi
  # "self": judge the log against its own failure list, so only the crash/completion rules decide
  # (plain `swift test` on this machine has hundreds of environment failures no baseline file lists).
  [[ $base == self ]] && cp "$TMP/real.list" "$TMP/self.base" && base=self.base G=$TMP
  out=$(check_test_outcome "$label" "$rc" "$TMP/real.list" "$G/$base" "$TMP/real.log") || got=1
  expect "real-log $name" "$want" $got "$out"
}
if [[ ${FORK_GATE_REPLAY:-0} == 1 ]]; then
  # baseline-mac.log stops at the first failing group (fail-fast); the tail log finishes groups 134..165.
  replay "baseline-mac + tail (grouped, complete)" 0 mac 1 self baseline-mac.log baseline-mac-tail.log
  replay "T2-mac-raw" 0 mac 1 self T2-mac-raw.log
  replay "baseline-ios" 0 ios 65 baseline-ios-fail.txt baseline-ios.log
  replay "gate-ios-raw" 0 ios 65 baseline-ios-fail.txt gate-ios-raw.log
  replay "baseline-mac-run4-aborted" 1 mac 1 self baseline-mac-run4-aborted.log
  replay "baseline-mac alone (aborted at group 134/165)" 1 mac 1 self baseline-mac.log
fi

# The gate script must point GATE_SWIFT / GATE_GROUPS at files that exist (they live in Scripts/fork/).
for var in GATE_SWIFT GATE_GROUPS; do
  rel=$(grep -oE "$var=\"[$]ROOT_DIR/[^\"]+\"" Scripts/fork_sync_gate.sh | head -1 | sed -E 's|.*ROOT_DIR/||; s|"$||')
  [[ -n "$rel" && -f "$ROOT_DIR/$rel" ]]; expect "gate script $var resolves to an existing file (${rel:-none})" 0 $?
done

# A group killed by a signal must fail the stage even when an earlier group had a baseline-known failure.
# Stub swift: group listing, then CLIEntryTests fails (known), any other group SIGKILLs itself.
cat >"$TMP/swiftstub.sh" <<'STUB'
#!/bin/bash
if [[ "$1 $2" == "test list" ]]; then
  echo "CodexBarTests.CLIEntryTests/testA"
  echo "CodexBarTests.ZTests/testB"
  exit 0
fi
case "$*" in
  *CLIEntryTests*) echo "Test Case '-[CodexBarTests.CLIEntryTests testA]' failed (0.1 seconds)."; exit 1;;
  *) kill -9 $$;;
esac
STUB
chmod +x "$TMP/swiftstub.sh"
PY=/opt/homebrew/bin/python3.15; [[ -x "$PY" ]] || PY=python3
"$PY" "$ROOT_DIR/Scripts/fork/gate_mac_groups.py" "$TMP/swiftstub.sh" 1 30 >"$TMP/kill.log" 2>&1
mac_fail_list "$TMP/kill.log" >"$TMP/kill.list"; cp "$TMP/kill.list" "$TMP/kill.base"
check_test_outcome mac 1 "$TMP/kill.list" "$TMP/kill.base" "$TMP/kill.log" >"$TMP/kill.out" 2>&1; expect "group kill -9 beside known failure fails" 1 $? "$(cat "$TMP/kill.out")"
# The wrapper's own verdict counts too, with no marker line and a clean-looking failure list.
for code in -9 124; do
  run mac 1 "$MAC_DONE_BAD"$'\n'"$MAC_FAIL"$'\nGROUPRESULT 2 '"$code" "✘ Test foo() failed"
  expect "GROUPRESULT $code beside known failure fails" 1 $? "$LAST_OUT"
done

# A baseline stored in en_US order must compare cleanly against a fresh list under LC_ALL=C.
printf '%s\n' '✘ Test ab failed' '✘ Test a-c failed' '✘ Test B failed' >"$TMP/enus.base"
printf '%s\n' '✘ Test B failed' '✘ Test a-c failed' '✘ Test ab failed' >"$TMP/c.list"
out=$(LC_ALL=C check_new_failures mac "$TMP/c.list" "$TMP/enus.base"); expect "baseline en_US order vs LC_ALL=C list: no new failures" 0 $? "$out"
out=$(LC_ALL=en_US.UTF-8 check_new_failures mac "$TMP/c.list" "$TMP/enus.base"); expect "baseline en_US order vs en_US list: no new failures" 0 $? "$out"

# Base tag detection must skip the fork's own -audi.N release tags.
if git rev-parse -q --verify 'refs/tags/v0.81.0.1-mobile.3.1.0-audi.5' >/dev/null &&
   git rev-parse -q --verify 'refs/tags/v0.79.0.1-mobile.3.1.0' >/dev/null; then
  got=$(detect_base_tag 'v0.81.0.1-mobile.3.1.0-audi.5^{commit}')
  [[ "$got" == v0.79.0.1-mobile.3.1.0 ]]; expect "base tag skips -audi tags (got $got)" 0 $?
else
  echo "SKIP base tag detection: fork/upstream tags not fetched"
fi

# A passing parameterized test whose argument contains "failed" prints a
# "◇ Test case passing ... failed... started." line; it is not a failure.
printf '%s\n' '◇ Test case passing 1 argument failedStage → 2 to "x" started.' '✔ Test run with 1 test passed after 0.1 seconds.' >"$TMP/started.log"
for kind in mac ios; do
  if [[ $kind == mac ]]; then n=$(mac_fail_list "$TMP/started.log" | grep -c .); else n=$(ios_fail_list "$TMP/started.log" | grep -c .); fi
  expect "$kind fail list ignores started lines that mention failed" 0 "$n"
done

exit $fails
