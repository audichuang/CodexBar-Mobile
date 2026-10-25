#!/usr/bin/env bash
# Rewrite the upstream (o1xhack) signing/bundle/container/repo identity to this fork's owner.
# Idempotent: safe to re-run after every merge from upstream.
# Author credits (x.com/o1xhack, @o1xhack, o1xhack@gmail.com, *.o1xhack.com, telegram-watch,
# "Yuxiao" credit text) and history/marketing files are intentionally left alone.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
SELF="Scripts/apply_fork_identity.sh"

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
trap 'rm -f "$KEYS_FILE"' EXIT
export KEYS_FILE
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
  case "$f" in
    "$SELF"|Scripts/test_apply_fork_identity.sh|*.md|Archive/*|appcast.xml|CodexBarMobile/Research/*|release-notes/*|CHANGELOG*|*/CHANGELOG*|CodexBarMobile/AppStoreMetadata/*|.github/FUNDING.yml|*.xcstrings) continue ;;
  esac
  # Skip binary files.
  grep -Iq . "$f" 2>/dev/null || continue
  before=$(cksum < "$f")
  case "$f" in
    Scripts/check_pr_review_gate.sh|Scripts/test_pr_review_gate.sh) owner=1 ;;
    *) owner=0 ;;
  esac
  # Catalog-key literals are swapped for placeholders, rewritten around, then restored.
  OWNER_RULES=$owner perl -pi -e '
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
  ' "$f"
  after=$(cksum < "$f")
  if [[ "$before" != "$after" ]]; then
    echo "changed: $f"
    changed=$((changed + 1))
    case "$f" in
      Sources/*.swift|Tests/*.swift) swift_changed+=("$f") ;;
    esac
  fi
done < <(git ls-files)

# Longer replacement strings can push a line past the formatter's width, which
# the macOS CI lint (swiftformat Sources Tests --lint) rejects. Reformat what we
# touched with the repo's pinned SwiftFormat so the rewrite stays lint-clean.
if (( ${#swift_changed[@]} > 0 )); then
  SWIFTFORMAT_BIN="${SWIFTFORMAT_BIN:-.build/lint-tools/bin/swiftformat}"
  if [[ ! -x "$SWIFTFORMAT_BIN" ]]; then
    echo "apply_fork_identity: $SWIFTFORMAT_BIN missing; run Scripts/install_lint_tools.sh, then rerun" >&2
    exit 1
  fi
  "$SWIFTFORMAT_BIN" --quiet "${swift_changed[@]}"
fi

echo "apply_fork_identity: $changed file(s) changed"
