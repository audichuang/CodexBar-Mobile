#!/usr/bin/env bash
# Every Swift file in Sources/CodexBarWidget must be listed in the tracked widget Xcode project.
# Release builds compile the widget from that project, while `swift build` and the fork tests use
# SwiftPM, which picks up the whole directory. A file missing from the project still passes every
# SwiftPM stage and only drops out of the shipped widget (ForkIOSStyleWidgets.swift, 2026-11-15).
# The project is not regenerated here: xcodegen also rewrites the checkout folder reference.
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT="$ROOT/WidgetExtension/CodexBarWidgetExtension.xcodeproj/project.pbxproj"
missing=0
while IFS= read -r file; do
  name=$(basename "$file")
  if ! grep -qF "/* $name in Sources */" "$PROJECT"; then
    echo "missing from widget project Sources: $name (add its PBXFileReference, group child and build file to $PROJECT)"
    missing=1
  fi
done < <(find "$ROOT/Sources/CodexBarWidget" -name '*.swift' -type f | sort)
exit "$missing"
