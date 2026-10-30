#!/usr/bin/env bash
# Rewrite the upstream (o1xhack) signing/bundle/container/repo identity to this fork's owner.
# Idempotent: safe to re-run after every merge from upstream.
# Usage: apply_fork_identity.sh [--check]
#   --check  read-only: list files that would change and exit 1 if any (no writes).
# Files it never touches are listed in Scripts/fork_identity_excludes.txt.
# Author credits (x.com/o1xhack, @o1xhack, o1xhack@gmail.com, *.o1xhack.com, telegram-watch,
# "Yuxiao" credit text) and history/marketing files are intentionally left alone.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
EXCLUDES_FILE="Scripts/fork_identity_excludes.txt"

CHECK=0
case "${1:-}" in
  "") ;;
  --check) CHECK=1 ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

EXCLUDES=()
while IFS= read -r pattern || [[ -n "$pattern" ]]; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  EXCLUDES+=("$pattern")
done < "$EXCLUDES_FILE"
if (( ${#EXCLUDES[@]} == 0 )); then
  echo "apply_fork_identity: no patterns in $EXCLUDES_FILE" >&2
  exit 1
fi

SPARKLE_OLD='eBPpE8Yx+2Dbl/viiieSBqdfSC8t20g657Dgas+Xw3o='
SPARKLE_NEW='Ap5ROjdeTY0W74UZvHhNXUquirI11sGKZBBr+g8yu2M='
export SPARKLE_OLD SPARKLE_NEW

# String literals whose exact content is a key in a tracked *.xcstrings catalog must stay
# byte-identical to the (excluded) catalog: SwiftUI looks them up implicitly (Text("..."),
# Label("..."), Section("..."), String(localized: "...")), so rewriting them drops every
# translation. Collect the catalog keys that contain an identity string, in Swift source form.
# Not handled: keys with "\\(...)" interpolation (catalog stores %@/%lld), multi-line literals,
# raw "#...#" strings, unicode escapes. A key containing both an identity string and one of
# those stays rewritable (and is then caught by Scripts/audit_localized_keys.py).
KEYS_FILE=$(mktemp)
# --check writes the would-be rewrite here and compares it with the original instead of editing in place.
OUT_FILE=$(mktemp)
trap 'rm -f "$KEYS_FILE" "$OUT_FILE"' EXIT
export KEYS_FILE
if (( CHECK )); then PERL_EDIT=-p; else PERL_EDIT=-pi; fi
git ls-files -z '*.xcstrings' | python3 -I -c '
import json, re, sys
ident = re.compile(r"o1xhack|3TUERHN53E|Yuxiao Wang|" + re.escape("eBPpE8Yx+2Dbl/viiieSBqdfSC8t20g657Dgas+Xw3o="))
out = set()
for path in filter(None, sys.stdin.read().split("\0")):
    with open(path, encoding="utf-8") as fh:
        keys = json.load(fh).get("strings", {})
    for k in keys:
        if not ident.search(k):
            continue
        out.add(k)
        out.add(k.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t"))
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    for k in sorted(out, key=len, reverse=True):
        if "\n" not in k:
            fh.write(k + "\n")
' "$KEYS_FILE"

changed=0
swift_changed=()
while IFS= read -r f; do
  [[ -f "$f" && ! -L "$f" ]] || continue
  for pattern in "${EXCLUDES[@]}"; do
    # shellcheck disable=SC2053
    [[ "$f" == $pattern ]] && continue 2
  done
  # Skip binary files.
  grep -Iq . "$f" 2>/dev/null || continue
  before=$(cksum < "$f")
  case "$f" in
    Scripts/check_pr_review_gate.sh|Scripts/test_pr_review_gate.sh) owner=1 ;;
    *) owner=0 ;;
  esac
  # Catalog-key literals are swapped for placeholders, rewritten around, then restored.
  OWNER_RULES=$owner perl "$PERL_EDIT" -e '
    BEGIN {
      open(my $kf, "<", $ENV{KEYS_FILE}) or die "keys: $!";
      chomp(@keys = <$kf>);
      @keys = grep { length } @keys;
    }
    for my $i (0 .. $#keys) { s/\Q"$keys[$i]"\E/\x01$i\x02/g; }
    s/Developer ID Application: Yuxiao Wang \(3TUERHN53E\)/Developer ID Application: Yung Chun Chuang (37HFR5V2JJ)/g;
    s/com\.o1xhack\.codexbar/com.audichuang.codexbar/g;
    s/com\.o1xhack\.CodexBar/com.audichuang.CodexBar/g;
    s/3TUERHN53E/37HFR5V2JJ/g;
    s{o1xhack/CodexBar-Mobile}{audichuang/CodexBar-Mobile}g;
    s/\Q$ENV{SPARKLE_OLD}\E/$ENV{SPARKLE_NEW}/g;
    if ($ENV{OWNER_RULES}) {
      s/owner: "o1xhack"/owner: "audichuang"/g;
      s/login == "o1xhack"/login == "audichuang"/g;
      s/== "o1xhack"/== "audichuang"/g;
      s/\{"login":"o1xhack"\}/{"login":"audichuang"}/g;
      s/login:"o1xhack"/login:"audichuang"/g;
      s/"login":"o1xhack"/"login":"audichuang"/g;
    }
    s/\x01(\d+)\x02/"$keys[$1]"/g;
  ' "$f" > "$OUT_FILE"
  if (( CHECK )); then after=$(cksum < "$OUT_FILE"); else after=$(cksum < "$f"); fi
  if [[ "$before" != "$after" ]]; then
    if (( CHECK )); then echo "would change: $f"; else echo "changed: $f"; fi
    changed=$((changed + 1))
    case "$f" in
      Sources/*.swift|Tests/*.swift) swift_changed+=("$f") ;;
    esac
  fi
done < <(git ls-files)

# Longer replacement strings can push a line past the formatter's width, which
# the macOS CI lint (swiftformat Sources Tests --lint) rejects. Reformat what we
# touched with the repo's pinned SwiftFormat so the rewrite stays lint-clean.
if (( CHECK )); then
  if (( changed > 0 )); then
    echo "apply_fork_identity --check: $changed file(s) need Scripts/apply_fork_identity.sh" >&2
    exit 1
  fi
  echo "apply_fork_identity --check: clean"
  exit 0
fi
if (( ${#swift_changed[@]} > 0 )); then
  SWIFTFORMAT_BIN="${SWIFTFORMAT_BIN:-.build/lint-tools/bin/swiftformat}"
  if [[ ! -x "$SWIFTFORMAT_BIN" ]]; then
    echo "apply_fork_identity: $SWIFTFORMAT_BIN missing; run Scripts/install_lint_tools.sh, then rerun" >&2
    exit 1
  fi
  "$SWIFTFORMAT_BIN" --quiet "${swift_changed[@]}"
fi

echo "apply_fork_identity: $changed file(s) changed"
