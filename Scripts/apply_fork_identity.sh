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

changed=0
while IFS= read -r f; do
  [[ -f "$f" && ! -L "$f" ]] || continue
  case "$f" in
    "$SELF"|*.md|Archive/*|appcast.xml|CodexBarMobile/Research/*|release-notes/*|CHANGELOG*|*/CHANGELOG*|CodexBarMobile/AppStoreMetadata/*|.github/FUNDING.yml|*.xcstrings) continue ;;
  esac
  # Skip binary files.
  grep -Iq . "$f" 2>/dev/null || continue
  before=$(cksum < "$f")
  case "$f" in
    Scripts/check_pr_review_gate.sh|Scripts/test_pr_review_gate.sh) owner=1 ;;
    *) owner=0 ;;
  esac
  # Swift localized-string keys must stay byte-identical to the (excluded) .xcstrings catalogs.
  OWNER_RULES=$owner perl -pi -e '
    next if /localized:\s*"/;
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
  ' "$f"
  after=$(cksum < "$f")
  if [[ "$before" != "$after" ]]; then
    echo "changed: $f"
    changed=$((changed + 1))
  fi
done < <(git ls-files)

echo "apply_fork_identity: $changed file(s) changed"
