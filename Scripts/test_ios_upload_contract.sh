#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$ROOT/Scripts/upload_ios_testflight.sh" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
commands = re.findall(r'^(?:PATH=\S+ )?xcodebuild\b.*?(?=\n\s*\|)', text, re.M | re.S)
assert len(commands) == 2, 'Archive and export commands must both be checked'
for command in commands:
    assert '-packageAuthorizationProvider netrc' in command, 'Release package resolution must not use Keychain'
    assert '-authenticationKeyPath' not in command and '-authenticationKeyID' not in command, 'Keep Xcode session cloud signing'
assert re.search(r'<key>manageAppVersionAndBuildNumber</key>\s*<false/>', text), 'Preserve the reviewed build number'
assert 'SCRATCH_ROOT="${CODEXBAR_BUILD_SCRATCH:-$HOME/Library/Developer/CodexBarBuildScratch}"' in text, 'Scratch root must be configurable and default under ~/Library'
assert 'StudioSSD' not in text and 'EXPECTED_VOLUME_UUID' not in text, 'No hardcoded external volume'
assert '-exportPath "$EXPORT_PATH"' in text, 'Export staging must stay under the scratch root'
export = [c for c in commands if '-exportArchive' in c]
assert len(export) == 1 and export[0].startswith('PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild'), 'exportArchive must run with the system PATH (Homebrew rsync breaks IPA packaging)'
assert '"/tmp/' not in text, 'Do not stage iOS release files on the internal disk'
print('iOS upload contract passed: netrc, Xcode session signing, exact build, configurable scratch staging, system PATH export')
PY
