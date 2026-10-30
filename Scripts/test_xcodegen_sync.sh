#!/usr/bin/env bash
# Verify that CodexBarMobile.xcodeproj matches CodexBarMobile/project.yml,
# and that all tracked or present .swift files under the iOS app source dirs
# appear in the generated project.pbxproj.
#
# Usage: Scripts/test_xcodegen_sync.sh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SPEC_DIR="$ROOT_DIR/CodexBarMobile"
SPEC_FILE="$SPEC_DIR/project.yml"
PBXPROJ="$SPEC_DIR/CodexBarMobile.xcodeproj/project.pbxproj"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: xcodegen is required but not found in PATH" >&2
  exit 1
fi

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "ERROR: project spec missing at $SPEC_FILE" >&2
  exit 1
fi

# 1. Regenerate Xcode project from project.yml
(cd "$SPEC_DIR" && xcodegen generate --spec project.yml)

# 2. Verify CodexBarMobile.xcodeproj has no unstaged/uncommitted diff
if ! git -C "$ROOT_DIR" diff --exit-code -- CodexBarMobile/CodexBarMobile.xcodeproj; then
  echo "ERROR: CodexBarMobile/CodexBarMobile.xcodeproj is out of sync with project.yml." >&2
  echo "Run 'cd CodexBarMobile && xcodegen generate' and commit the resulting project file." >&2
  exit 1
fi

# 3. Check every tracked-or-present .swift file under the iOS app source dirs
SOURCE_DIRS=(
  "CodexBarMobile/CodexBarMobile"
  "CodexBarMobile/CodexBarMobilePushExtension"
  "CodexBarMobile/CodexBarMobileWidgets"
  "CodexBarMobile/CodexBarWidgetShared"
  "CodexBarMobile/CodexBarMobileWidgetOptions"
  "CodexBarMobile/CodexBarMobileTests"
  "CodexBarMobile/CodexBarMobileUITests"
  "Shared"
)

files=()
for rel_dir in "${SOURCE_DIRS[@]}"; do
  full_dir="$ROOT_DIR/$rel_dir"
  if [[ -d "$full_dir" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("$f")
    done < <(
      {
        git -C "$ROOT_DIR" ls-files -- "$rel_dir" 2>/dev/null | grep '\.swift$' || true
        find "$full_dir" -type f -name '*.swift' | sed "s|^$ROOT_DIR/||"
      } | sort -u
    )
  fi
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ERROR: No .swift files found under source directories" >&2
  exit 1
fi

python3 - "$PBXPROJ" "$SPEC_FILE" "${files[@]}" <<'PY'
import fnmatch
import os
import sys
from pathlib import Path

pbx_path = sys.argv[1]
spec_path = sys.argv[2]
file_paths = sys.argv[3:]

if not os.path.isfile(pbx_path):
    print(f"ERROR: project.pbxproj missing at {pbx_path}", file=sys.stderr)
    sys.exit(1)

pbx_content = Path(pbx_path).read_text(encoding="utf-8")

# Attempt to parse target excludes from project.yml
targets = {}
try:
    import yaml
    with open(spec_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    targets = data.get("targets", {})
except Exception:
    targets = {}

missing = []
for f in file_paths:
    basename = Path(f).name
    if basename in pbx_content:
        continue

    # File not found in project.pbxproj: check if intentionally excluded in project.yml
    rel_under_mobile = f[len("CodexBarMobile/"):] if f.startswith("CodexBarMobile/") else f
    is_covered = False
    all_excluded = True

    for tname, target in targets.items():
        for src in target.get("sources", []):
            src_path = src.get("path") if isinstance(src, dict) else src
            if not src_path:
                continue
            norm_src = "Shared" if src_path == "../Shared" else src_path
            covers = False
            if f.startswith(norm_src) or rel_under_mobile.startswith(norm_src):
                covers = True
            elif norm_src.startswith("CodexBarMobile/") and f.startswith(norm_src):
                covers = True

            if covers:
                is_covered = True
                excludes = src.get("excludes", []) if isinstance(src, dict) else []
                matched = any(
                    fnmatch.fnmatch(f, pat) or
                    fnmatch.fnmatch(rel_under_mobile, pat) or
                    fnmatch.fnmatch(basename, pat)
                    for pat in excludes
                )
                if not matched:
                    all_excluded = False

    if not (is_covered and all_excluded):
        missing.append(f)

if missing:
    print(f"ERROR: {len(missing)} .swift file(s) missing from {pbx_path}:", file=sys.stderr)
    for m in missing:
        print(f"  {m}", file=sys.stderr)
    sys.exit(1)

print(f"xcodegen sync test passed: all {len(file_paths)} .swift files present in project.pbxproj and project is clean")
PY
