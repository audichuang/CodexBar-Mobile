#!/usr/bin/env bash
# Consistency test for the fork identity across project.yml, Fork.xcconfig, entitlements, Info.plists,
# package_app.sh, version files and the apply_fork_identity.sh skip list. Read-only.
# Swift twin: Tests/CodexBarTests/ForkIdentityConsistencyTests.swift.
# Usage: Scripts/test_fork_identity.sh   (BASE_TAG=<tag> overrides the detected upstream base tag)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

EXPECT_TEAM=37HFR5V2JJ
EXPECT_PREFIX=com.audichuang.codexbar
EXPECT_CONTAINER=iCloud.com.audichuang.codexbar
UPSTREAM_TEAM=3TUERHN53E

fail=0
check() { # check <description> <command...>
  local desc=$1; shift
  if ! "$@"; then echo "FAIL: $desc"; fail=1; fi
}
eq() { # eq <description> <actual> <expected>
  if [[ "$2" != "$3" ]]; then echo "FAIL: $1: got '$2', want '$3'"; fail=1; fi
}
kv() { # kv <file> <KEY>: value of KEY = / KEY= in an xcconfig or env file
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | head -1
}

XCCONFIG=CodexBarMobile/Config/Fork.xcconfig
TEAM=$(kv "$XCCONFIG" FORK_TEAM)
PREFIX=$(kv "$XCCONFIG" FORK_BUNDLE_PREFIX)
GROUP=$(kv "$XCCONFIG" FORK_APP_GROUP)
CONTAINER=$(kv "$XCCONFIG" FORK_ICLOUD_CONTAINER)
eq "Fork.xcconfig FORK_TEAM" "$TEAM" "$EXPECT_TEAM"
eq "Fork.xcconfig FORK_BUNDLE_PREFIX" "$PREFIX" "$EXPECT_PREFIX"
eq "Fork.xcconfig FORK_APP_GROUP" "$GROUP" "group.$EXPECT_PREFIX"
eq "Fork.xcconfig FORK_ICLOUD_CONTAINER" "$CONTAINER" "$EXPECT_CONTAINER"

# project.yml: prefix, every target on Fork.xcconfig, ids and teams derived from it (no literals).
YML=CodexBarMobile/project.yml
eq "project.yml bundleIdPrefix" "$(sed -n 's/^[[:space:]]*bundleIdPrefix:[[:space:]]*//p' "$YML" | head -1)" "$PREFIX"
n_ids=$(grep -c 'PRODUCT_BUNDLE_IDENTIFIER:' "$YML" || true)
n_cfg=$(grep -c 'Config/Fork.xcconfig' "$YML" || true)
eq "project.yml configFiles entries (2 per target)" "$n_cfg" "$((n_ids * 2))"
bad_ids=$(grep 'PRODUCT_BUNDLE_IDENTIFIER:' "$YML" | grep -v -e '\$(FORK_BUNDLE_PREFIX)' -e "$PREFIX" || true)
check "project.yml bundle ids must use FORK_BUNDLE_PREFIX: $bad_ids" test -z "$bad_ids"
bad_teams=$(grep 'DEVELOPMENT_TEAM:' "$YML" | grep -v -e '\$(FORK_TEAM)' -e "$TEAM" || true)
check "project.yml DEVELOPMENT_TEAM must be FORK_TEAM: $bad_teams" test -z "$bad_teams"

# Entitlements and Info.plists (plistlib; $(...) build variables stay literal strings).
python3 -I - "$GROUP" "$CONTAINER" "$PREFIX" <<'PY' || fail=1
import glob, plistlib, subprocess, sys
group, container, prefix = sys.argv[1:4]
tracked = subprocess.check_output(["git", "ls-files", "*.entitlements", "*Info.plist"], text=True).split()
ents = [p for p in tracked if p.endswith(".entitlements")]
infos = [p for p in tracked if p.endswith("Info.plist")]
errors = []
if len(ents) != 4:
    errors.append(f"expected 4 entitlements files, found {len(ents)}: {ents}")
seen_group = seen_container = False
for path in ents:
    d = plistlib.load(open(path, "rb"))
    groups = d.get("com.apple.security.application-groups")
    if groups is not None:
        seen_group = True
        if groups != [group]:
            errors.append(f"{path}: application-groups {groups} != [{group}]")
    containers = d.get("com.apple.developer.icloud-container-identifiers")
    if containers is not None:
        seen_container = True
        if containers != [container]:
            errors.append(f"{path}: icloud-container-identifiers {containers} != [{container}]")
if not (seen_group and seen_container):
    errors.append("no entitlements file declares the app group and the iCloud container")

def strings(node):
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for v in node.values():
            yield from strings(v)
    elif isinstance(node, list):
        for v in node:
            yield from strings(v)

for path in infos:
    for s in strings(plistlib.load(open(path, "rb"))):
        if "codexbar" in s.lower() and s.startswith("com.") and not s.startswith(prefix):
            errors.append(f"{path}: '{s}' is outside {prefix}")
for e in errors:
    print("FAIL:", e)
sys.exit(1 if errors else 0)
PY

# Sparkle key in package_app.sh must be the fork's key, never the upstream one.
SPARKLE_NEW=$(sed -n "s/^SPARKLE_NEW='\(.*\)'$/\1/p" Scripts/apply_fork_identity.sh)
SPARKLE_OLD=$(sed -n "s/^SPARKLE_OLD='\(.*\)'$/\1/p" Scripts/apply_fork_identity.sh)
check "SPARKLE_NEW/SPARKLE_OLD parsed from apply_fork_identity.sh" test -n "$SPARKLE_NEW" -a -n "$SPARKLE_OLD"
eq "package_app.sh SUPublicEDKey" \
  "$(sed -n 's/.*<key>SUPublicEDKey<\/key><string>\(.*\)<\/string>.*/\1/p' Scripts/package_app.sh | head -1)" "$SPARKLE_NEW"

# macOS packaging defaults agree with the iOS side.
eq "package_app.sh APP_TEAM_ID default" \
  "$(sed -n 's/^APP_TEAM_ID="${APP_TEAM_ID:-\(.*\)}"$/\1/p' Scripts/package_app.sh)" "$TEAM"
eq "package_app.sh BUNDLE_ID" "$(sed -n 's/^BUNDLE_ID="\(.*\)"$/\1/p' Scripts/package_app.sh | head -1)" "$PREFIX"
check "package_app.sh iCloud container" grep -q "<string>$CONTAINER</string>" Scripts/package_app.sh

# No upstream identity outside the apply_fork_identity.sh skip list. Author credits
# (x.com/o1xhack, @o1xhack, o1xhack@gmail.com, *.o1xhack.com) are intentionally kept, so only the
# signing/bundle/key identifiers are scanned here; the repo slug is covered by `apply_fork_identity.sh --check`.
EXCLUDES=()
while IFS= read -r pattern || [[ -n "$pattern" ]]; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  EXCLUDES+=("$pattern")
done < Scripts/fork_identity_excludes.txt
check "excludes list is not empty" test "${#EXCLUDES[@]}" -gt 0
SPARKLE_OLD_RE=$(printf '%s' "$SPARKLE_OLD" | sed 's/[+\/]/\\&/g')
scan=()
while IFS= read -r f; do
  [[ -f "$f" && ! -L "$f" ]] || continue
  for pattern in "${EXCLUDES[@]}"; do
    # shellcheck disable=SC2053
    [[ "$f" == $pattern ]] && continue 2
  done
  scan+=("$f")
done < <(git ls-files)
# -I skips binary files; one grep over every scanned file keeps this fast.
leaks=$(printf '%s\0' "${scan[@]}" | xargs -0 grep -lIE -e "$UPSTREAM_TEAM" -e 'com\.o1xhack\.(codexbar|CodexBar)' -e "$SPARKLE_OLD_RE" | tr '\n' ' ' || true)
check "upstream identity (o1xhack team/bundle/Sparkle key) found in: $leaks" test -z "$leaks"

# ForkIdentity constants: the Mac (Core) and iOS (Shared) copies must be identical, and helpURL must point at a file
# that exists on mobile-dev (the fork README is .github/README.md; the root README.md is upstream's).
CORE_ID=Sources/CodexBarCore/Sync/ForkIdentity.swift
SHARED_ID=Shared/ForkIdentity.swift
check "ForkIdentity copies differ ($CORE_ID vs $SHARED_ID)" diff -q <(grep 'static let' "$CORE_ID") <(grep 'static let' "$SHARED_ID") >/dev/null
for id_file in "$CORE_ID" "$SHARED_ID"; do
  help_url=$(sed -n 's/.*helpURL = "\(.*\)".*/\1/p' "$id_file")
  help_path=${help_url#https://github.com/audichuang/CodexBar-Mobile/blob/mobile-dev/}
  if [[ "$help_path" == "$help_url" || "$help_path" == README.md ]]; then
    echo "FAIL: $id_file helpURL '$help_url' must point at the fork README (.github/README.md)"; fail=1
  else
    check "$id_file helpURL target $help_path is missing" test -f "$help_path"
  fi
done

# Version files.
for f in version.env version.fork.env; do
  patch=$(kv "$f" FORK_PATCH)
  if [[ -n "$patch" && ! "$patch" =~ ^[0-9]+$ ]]; then echo "FAIL: $f FORK_PATCH='$patch' is not numeric"; fail=1; fi
done
check "FORK_PATCH is set in version.env or version.fork.env" \
  grep -qE '^FORK_PATCH=[0-9]+$' version.env version.fork.env
UPSTREAM_VERSION=$(kv version.env UPSTREAM_VERSION)
MARKETING_VERSION=$(kv version.env MARKETING_VERSION)
MOBILE_VERSION=$(kv version.env MOBILE_VERSION)
BASE_TAG=${BASE_TAG:-$(git describe --tags --abbrev=0 --match 'v*-mobile.*' --exclude '*-audi.*' 2>/dev/null || true)}
if [[ -z "$BASE_TAG" ]]; then
  echo "SKIP: no v*-mobile.* tag reachable from HEAD; UPSTREAM_VERSION vs base tag not checked"
else
  # <upstream>[.<n>]-mobile.<mobile>[-audi.<n>]: the fork's own release tags carry the -audi suffix.
  if [[ ! "$BASE_TAG" =~ ^${UPSTREAM_VERSION//./\\.}(\.[0-9]+)?-mobile\.${MOBILE_VERSION//./\\.}(-audi\.[0-9]+)?$ ]]; then
    echo "FAIL: UPSTREAM_VERSION=$UPSTREAM_VERSION MOBILE_VERSION=$MOBILE_VERSION do not match base tag $BASE_TAG"
    fail=1
  fi
  [[ "$BASE_TAG" == v${MARKETING_VERSION}-mobile.* ]] || { echo "FAIL: MARKETING_VERSION=$MARKETING_VERSION does not match base tag $BASE_TAG"; fail=1; }
fi

if [[ $fail -eq 0 ]]; then echo "PASS: fork identity"; else echo "FAILED: fork identity"; exit 1; fi
