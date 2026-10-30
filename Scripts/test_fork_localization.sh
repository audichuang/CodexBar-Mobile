#!/usr/bin/env bash
# Verify that localized keys are audited against the catalog, app locales match,
# widget locales are synchronized, and no catalogs are left dirty.
#
# Usage: Scripts/test_fork_localization.sh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "Auditing localized keys..."
python3 "$ROOT_DIR/Scripts/audit_localized_keys.py" \
  "${1:-$ROOT_DIR/CodexBarMobile/CodexBarMobile/Localizable.xcstrings}" \
  "${2:-$ROOT_DIR/CodexBarMobile/CodexBarMobile}"

echo "Checking app locales..."
node "$ROOT_DIR/Scripts/check-app-locales.mjs"

echo "Synchronizing widget locales..."
node "$ROOT_DIR/Scripts/sync-widget-locales.mjs"

echo "Verifying working tree is clean..."
if ! git -C "$ROOT_DIR" diff --exit-code -- \
  '*.xcstrings' '*.strings' '*.stringsdict'; then
  echo "ERROR: Localization catalogs or files changed after running audit and sync." >&2
  echo "Review the diff above and commit the updated catalogs." >&2
  exit 1
fi

echo "fork localization check passed: all keys and locales verified without changes"
