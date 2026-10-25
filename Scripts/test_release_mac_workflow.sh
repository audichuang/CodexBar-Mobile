#!/usr/bin/env bash
# Contract: a Mac release must never ship without the strict launch-survival
# check. GitHub does not start release-mac-verify.yml for releases created with
# github.token, so the in-workflow check is the only launch gate.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKFLOW="$ROOT/.github/workflows/release-mac.yml"
SIGN="$ROOT/Scripts/sign-and-notarize.sh"

fail() {
  echo "release-mac workflow test failed: $*" >&2
  exit 1
}

grep -Eq '^[[:space:]]*CODEXBAR_REQUIRE_LAUNCH_SURVIVAL=1 \\$' "$SIGN" || \
  fail "sign-and-notarize.sh must hard-code CODEXBAR_REQUIRE_LAUNCH_SURVIVAL=1"
if grep -Fq 'CODEXBAR_REQUIRE_LAUNCH_SURVIVAL=0' "$WORKFLOW"; then
  fail "release-mac.yml must not relax the launch-survival check"
fi
grep -Fq '!= "Aqua"' "$WORKFLOW" || \
  fail "release-mac.yml must refuse to release without an Aqua session"

grep -Eq '^[[:space:]]+ARCHES: arm64$' "$WORKFLOW" || \
  fail "release-mac.yml must build arm64 only (ARCHES: arm64)"

echo "release-mac workflow contract passed"
