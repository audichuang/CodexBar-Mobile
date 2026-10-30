#!/usr/bin/env bash
# Fail-fast gate for upstream syncs and fork pushes.
#
# Usage: Scripts/fork_sync_gate.sh [--quick] [--ios] [--full] [--baseline <dir>] [--base-tag <tag>]
#   (default)   fast tier (~5 min): conflict markers, identity/readme/signing/workflow guards,
#               footprint, generated files, localization, version, lint on changed files,
#               swift build, and the fork-scoped swift test filter.
#   --quick     same as default; explicitly skips iOS (kept for scripts that pass it).
#   --ios       also run CodexBarMobileTests on the iOS simulator.
#   --full      release tier: also run the whole Mac swift test and the iOS tests.
#   --baseline <dir>  the full Mac / iOS runs pass when `comm -13 <dir>/baseline-{mac,ios}-fail.txt
#               <this run's fail list>` is empty; without it they require zero failures.
#   --base-tag <tag>  upstream-based fork tag the branch is rebased on
#               (default: $FORK_BASE_TAG, else the nearest reachable upstream v*-mobile.* tag, fork -audi.* tags excluded).
# Logs: ${CODEXBAR_GATE_DIR:-~/Library/Caches/codexbar-gate}/gate-<stage>.log
# Exit: 0 all stages passed, 1 first failing stage, 2 usage error.
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

# shellcheck source=fork/gate_lib.sh
source "$ROOT_DIR/Scripts/fork/gate_lib.sh"

IOS=0
FULL=0
BASELINE=""
BASE_TAG=${FORK_BASE_TAG:-}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) IOS=0 ;;
    --ios) IOS=1 ;;
    --full) FULL=1; IOS=1 ;;
    --baseline) BASELINE=${2:-}; shift ;;
    --base-tag) BASE_TAG=${2:-}; shift ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "usage: $0 [--quick] [--ios] [--full] [--baseline <dir>] [--base-tag <tag>]" >&2; exit 2 ;;
  esac
  shift
done
if [[ -n "$BASELINE" && ! -d "$BASELINE" ]]; then
  echo "ERROR: --baseline directory not found: $BASELINE" >&2
  exit 2
fi
if [[ -z "$BASE_TAG" ]]; then
  BASE_TAG=$(detect_base_tag)
fi
if [[ -z "$BASE_TAG" ]]; then
  echo "ERROR: cannot determine base tag; pass --base-tag or set FORK_BASE_TAG" >&2
  exit 2
fi

GATE_DIR=${CODEXBAR_GATE_DIR:-$HOME/Library/Caches/codexbar-gate}
mkdir -p "$GATE_DIR"
SWIFT=(Scripts/fork/swift_scratch.sh)
FORK_TEST_FILTER='CloudSync|SyncCoordinator|SyncModel|SyncWireFormat|V082SyncMetadata|CostUsageStore|CodexArchivedRollout|CostUsageForkParserRevision|ProviderArchitectureGatekeeper|ForkSyncIntegration|ForkIdentityConsistency'
IOS_DEST='platform=iOS Simulator,name=CB iPhone 18 Pro Max'
GATE_START=$SECONDS

# Run one stage: stage_run <name> <function>. Output goes to its log; first failure exits.
stage_run() {
  local name=$1 fn=$2 log="$GATE_DIR/gate-$1.log" start=$SECONDS rc
  echo "RUN   $name"
  "$fn" >"$log" 2>&1
  rc=$?
  local elapsed=$((SECONDS - start))
  if [[ $rc -eq 0 ]]; then
    echo "PASS  $name (${elapsed}s)"
  else
    echo "FAIL  $name (${elapsed}s, exit $rc) log: $log" >&2
    tail -n 15 "$log" >&2
    echo "GATE FAILED at stage: $name (total $((SECONDS - GATE_START))s)" >&2
    exit 1
  fi
}

s_conflict_markers() {
  if git grep -nE '^(<<<<<<<|>>>>>>>)' -- ':!*.md'; then
    echo "conflict markers found"
    return 1
  fi
}

s_identity_and_guards() {
  Scripts/apply_fork_identity.sh --check &&
    Scripts/test_apply_fork_identity.sh &&
    Scripts/test_fork_identity.sh &&
    Scripts/check_fork_readme.sh &&
    Scripts/test_fork_readme_guard.sh &&
    Scripts/test_package_signing.sh &&
    Scripts/test_package_signing_fork.sh &&
    Scripts/test_release_mac_workflow.sh &&
    Scripts/fork/test_fork_sync_gate.sh
}

s_footprint() {
  Scripts/fork/check_footprint.sh "$BASE_TAG" && Scripts/fork/test_check_footprint.sh "$BASE_TAG"
}

s_generated_files() {
  Scripts/regenerate-codex-parser-hash.sh check &&
    Scripts/test_xcodegen_sync.sh &&
    Scripts/test_fork_localization.sh
}

s_version() {
  git merge-base --is-ancestor "$BASE_TAG" HEAD || { echo "$BASE_TAG is not an ancestor of HEAD"; return 1; }
  local up
  up=$(sed -n 's/^UPSTREAM_VERSION=//p' version.env)
  [[ -n "$up" ]] || { echo "UPSTREAM_VERSION missing in version.env"; return 1; }
  [[ "$BASE_TAG" == "$up".* ]] || { echo "base tag $BASE_TAG does not match UPSTREAM_VERSION=$up"; return 1; }
  grep -qE '^FORK_PATCH=[0-9]*$' version.fork.env || { echo "FORK_PATCH malformed in version.fork.env"; return 1; }
}

# Lint changed swift files and fail when any lint rule has MORE violations than at the base tag.
# Upstream's own files carry known violations, and code moved into fork-owned files keeps them, so the
# comparison is per rule across the changed files (path, line and counts inside messages are ignored).
lint_rule_counts() {
  # lint_rule_counts <dir> <config-root> <files...>; prints "<count> <rule>" per rule.
  local dir=$1 cfg=$2
  shift 2
  (
    cd "$dir" || exit 1
    "$LINT_BIN/swiftformat" --config "$cfg/.swiftformat" --lint "$@" 2>&1
    "$LINT_BIN/swiftlint" lint --quiet --config "$cfg/.swiftlint.yml" "$@" 2>&1
  ) | grep -E ': (error|warning): ' | grep -oE '\([A-Za-z_]+\)' | sort | uniq -c | awk '{print $1, $2}'
}

s_lint() {
  # Pinned versions, same as Scripts/lint.sh; install once with Scripts/install_lint_tools.sh.
  LINT_BIN="$ROOT_DIR/.build/lint-tools/bin"
  if [[ ! -x "$LINT_BIN/swiftformat" || ! -x "$LINT_BIN/swiftlint" ]]; then
    Scripts/install_lint_tools.sh swiftformat && Scripts/install_lint_tools.sh swiftlint || return 1
  fi
  local files=() existing=() tmp
  while IFS= read -r f; do files+=("$f"); done < <(git diff --name-only --diff-filter=AMR "$BASE_TAG" -- '*.swift')
  if [[ ${#files[@]} -eq 0 ]]; then echo "no changed swift files"; return 0; fi
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/fork-gate-lint.XXXXXX")
  for f in "${files[@]}"; do
    if git cat-file -e "$BASE_TAG:$f" 2>/dev/null; then
      mkdir -p "$tmp/$(dirname "$f")"
      git show "$BASE_TAG:$f" >"$tmp/$f"
      existing+=("$f")
    fi
  done
  lint_rule_counts "$ROOT_DIR" "$ROOT_DIR" "${files[@]}" >"$tmp/head.txt"
  if [[ ${#existing[@]} -gt 0 ]]; then
    lint_rule_counts "$tmp" "$ROOT_DIR" "${existing[@]}" >"$tmp/base.txt"
  else
    : >"$tmp/base.txt"
  fi
  local worse allow="$ROOT_DIR/fork/lint-allowance.tsv"
  # allowance rows: (rule)<TAB>extra violations tolerated over the base tag<TAB>reason
  if [[ -f "$allow" ]]; then
    awk -F'\t' '$0 !~ /^#/ && NF >= 2 { print $2, $1 }' "$allow" >"$tmp/allow.txt"
  else
    : >"$tmp/allow.txt"
  fi
  worse=$(awk 'FILENAME == ARGV[1] { extra[$2] = $1; next }
    FILENAME == ARGV[2] { base[$2] = $1; next }
    { n = $1 - (base[$2] + 0) - (extra[$2] + 0)
      if (n > 0) printf "%s: %d at HEAD vs %d at base (+%d allowed)\n", $2, $1, base[$2] + 0, extra[$2] + 0 }' \
    "$tmp/allow.txt" "$tmp/base.txt" "$tmp/head.txt")
  echo "rules with violations: head=$(wc -l <"$tmp/head.txt" | tr -d ' ') base=$(wc -l <"$tmp/base.txt" | tr -d ' ')"
  rm -rf "$tmp"
  if [[ -n "$worse" ]]; then
    echo "lint rules with more violations than $BASE_TAG:"
    echo "$worse"
    return 1
  fi
}

s_swift_build() { "${SWIFT[@]}" build; }

s_fork_tests() { "${SWIFT[@]}" test --filter "$FORK_TEST_FILTER"; }

s_mac_full() {
  local log="$GATE_DIR/gate-mac-full-raw.log" list="$GATE_DIR/gate-mac-fail.txt"
  # Plain `swift test` gives hundreds of false failures here, so use the grouped runner, but through
  # a wrapper that keeps going after a failing group: collect every failure, then diff against the baseline.
  # The runner swaps HOME per group, so the scratch path must be absolute.
  local py=/opt/homebrew/bin/python3.15
  [[ -x "$py" ]] || py=python3
  CODEXBAR_SWIFT_SCRATCH=${CODEXBAR_SWIFT_SCRATCH:-$HOME/Library/Caches/codexbar-swift-scratch} \
  GATE_PY=$py GATE_SWIFT="$ROOT_DIR/fork/swift_scratch.sh" GATE_GROUPS="$ROOT_DIR/fork/gate_mac_groups.py" \
    bash -c 'source Scripts/test_environment.sh; exec "$GATE_PY" "$GATE_GROUPS" "$GATE_SWIFT" 12 180' >"$log" 2>&1
  local rc=$?
  mac_fail_list "$log" >"$list"
  check_test_outcome "mac" "$rc" "$list" "${BASELINE:+$BASELINE/baseline-mac-fail.txt}" "$log"
}

s_ios_tests() {
  local log="$GATE_DIR/gate-ios-raw.log" list="$GATE_DIR/gate-ios-fail.txt"
  (cd CodexBarMobile && xcodebuild test -project CodexBarMobile.xcodeproj -scheme CodexBarMobile \
    -destination "$IOS_DEST" -only-testing:CodexBarMobileTests) >"$log" 2>&1
  local rc=$?
  ios_fail_list "$log" >"$list"
  check_test_outcome "ios" "$rc" "$list" "${BASELINE:+$BASELINE/baseline-ios-fail.txt}" "$log"
}

echo "fork gate: base=$BASE_TAG tier=$([[ $FULL -eq 1 ]] && echo full || echo fast)$([[ $IOS -eq 1 && $FULL -eq 0 ]] && echo +ios) logs=$GATE_DIR"
stage_run 1-conflict-markers s_conflict_markers
stage_run 2-identity-and-guards s_identity_and_guards
stage_run 3-footprint s_footprint
stage_run 4-generated-files s_generated_files
stage_run 5-version s_version
stage_run 6-lint s_lint
stage_run 7-swift-build s_swift_build
stage_run 8-fork-tests s_fork_tests
[[ $FULL -eq 1 ]] && stage_run 9-mac-full s_mac_full
[[ $IOS -eq 1 ]] && stage_run 10-ios-tests s_ios_tests
echo "GATE PASSED (total $((SECONDS - GATE_START))s)"
