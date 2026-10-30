#!/usr/bin/env bash
# Run `swift <subcommand> ...` with the shared fork scratch path so every gate
# build reuses one 37 GiB-class build directory instead of a fresh .build.
# Usage: Scripts/fork/swift_scratch.sh build|test [swift args...]
# Override the location with CODEXBAR_SWIFT_SCRATCH.
set -euo pipefail

SCRATCH=${CODEXBAR_SWIFT_SCRATCH:-$HOME/Library/Caches/codexbar-swift-scratch}
if [[ $# -lt 1 ]]; then
  echo "usage: $0 <swift-subcommand> [args...]" >&2
  exit 2
fi
sub=$1
shift
exec swift "$sub" --scratch-path "$SCRATCH" "$@"
