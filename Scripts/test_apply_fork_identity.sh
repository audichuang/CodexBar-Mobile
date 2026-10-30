#!/usr/bin/env bash
# Offline test for apply_fork_identity.sh: catalog-key literals must survive, runtime identity
# strings must be rewritten, and a second run must be a no-op.
# Usage: Scripts/test_apply_fork_identity.sh [path/to/apply_fork_identity.sh]
set -euo pipefail

SCRIPT=$(cd "$(dirname "${1:-$(dirname "$0")/apply_fork_identity.sh}")" && pwd)/$(basename "${1:-apply_fork_identity.sh}")
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# The repo's pinned SwiftFormat (Scripts/install_lint_tools.sh) keeps the width check honest.
SWIFTFORMAT_BIN="$REPO_ROOT/.build/lint-tools/bin/swiftformat"
[[ -x "$SWIFTFORMAT_BIN" ]] || { echo "SKIP width case: run Scripts/install_lint_tools.sh"; SWIFTFORMAT_BIN=""; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q
mkdir -p Scripts App Sources
cp "$SCRIPT" Scripts/apply_fork_identity.sh
cp "$(dirname "$SCRIPT")/fork_identity_excludes.txt" Scripts/fork_identity_excludes.txt
cp "$REPO_ROOT/.swiftformat" .swiftformat
# 119 columns before the rewrite, 122 after: the rewrite must re-wrap it.
cat > Sources/Long.swift <<'SWIFT'
func openReadme() {
    guard let url = URL(string: "https://github.com/o1xhack/CodexBar-Mobile/blob/mobile-dev/README-longer-x.md") else {
        return
    }
    _ = url
}
SWIFT

cat > App/Views.swift <<'SWIFT'
Text("Get it from github.com/o1xhack/CodexBar-Mobile/releases.")
Label("Quote \"o1xhack/CodexBar-Mobile\" here", systemImage: "x")
Text("Line one o1xhack/CodexBar-Mobile\nline two")
let a = String(localized: "See github.com/o1xhack/CodexBar-Mobile for o1xhack/CodexBar-Mobile details")
SWIFT
cat > App/Constants.swift <<'SWIFT'
static let id = "group.com.o1xhack.codexbar"
let u = URL(string: "https://github.com/o1xhack/CodexBar-Mobile")
Text("Get it from github.com/o1xhack/CodexBar-Mobile/releases.") // same line has a url below
let v = URL(string: "https://github.com/o1xhack/CodexBar-Mobile/x"); Text("Get it from github.com/o1xhack/CodexBar-Mobile/releases.")
SWIFT
cat > App/Localizable.xcstrings <<'JSON'
{"sourceLanguage":"en","version":"1.0","strings":{
"Get it from github.com/o1xhack/CodexBar-Mobile/releases.":{},
"Quote \"o1xhack/CodexBar-Mobile\" here":{},
"Line one o1xhack/CodexBar-Mobile\nline two":{},
"See github.com/o1xhack/CodexBar-Mobile for o1xhack/CodexBar-Mobile details":{}}}
JSON
git add -A
cp App/Views.swift /tmp/_views.$$

fail=0
check() { if ! "$@"; then echo "FAIL: $*"; fail=1; fi; }

SWIFTFORMAT_BIN="$SWIFTFORMAT_BIN" bash Scripts/apply_fork_identity.sh >/dev/null
check grep -q 'github.com/audichuang/CodexBar-Mobile/blob/mobile-dev/README-longer-x.md' Sources/Long.swift
if [[ -n "$SWIFTFORMAT_BIN" ]]; then
  check "$SWIFTFORMAT_BIN" --quiet --lint Sources/Long.swift
fi
check cmp -s /tmp/_views.$$ App/Views.swift
rm -f /tmp/_views.$$
check grep -q 'static let id = "group.com.audichuang.codexbar"' App/Constants.swift
check grep -q 'URL(string: "https://github.com/audichuang/CodexBar-Mobile")' App/Constants.swift
check grep -q 'URL(string: "https://github.com/audichuang/CodexBar-Mobile/x"); Text("Get it from github.com/o1xhack/CodexBar-Mobile/releases.")' App/Constants.swift
check grep -q '^Text("Get it from github.com/o1xhack/CodexBar-Mobile/releases.") //' App/Constants.swift

cp -R App /tmp/_app.$$
SWIFTFORMAT_BIN="$SWIFTFORMAT_BIN" bash Scripts/apply_fork_identity.sh >/dev/null
check diff -r /tmp/_app.$$ App >/dev/null
rm -rf /tmp/_app.$$

# --check: clean tree passes; a stray upstream string fails and nothing is written.
check bash Scripts/apply_fork_identity.sh --check >/dev/null
printf 'static let id = "group.com.o1xhack.codexbar"\n' > App/Stray.swift
git add App/Stray.swift
if bash Scripts/apply_fork_identity.sh --check >/dev/null 2>&1; then echo "FAIL: --check missed a stray identity string"; fail=1; fi
check grep -q 'group.com.o1xhack.codexbar' App/Stray.swift

if [[ $fail -eq 0 ]]; then echo "PASS: apply_fork_identity"; else echo "FAILED: apply_fork_identity"; exit 1; fi
