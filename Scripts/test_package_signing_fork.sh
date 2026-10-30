#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE_SCRIPT="$ROOT/Scripts/package_app.sh"

python3 - "$PACKAGE_SCRIPT" <<'PY'
import datetime
import itertools
import os
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

source = Path(sys.argv[1]).read_text()
start = source.index('BUNDLE_ID="com.audichuang.codexbar"')
end = source.index('BUILD_TIMESTAMP=', start)
generation = source[start:end]
assert source.index('validate_cloudkit_profile.py') < source.index('  swift build'), 'profile must be checked before compilation'
start = source.index('PROVISION_PROFILE="$ROOT/Provisioning/CodexBar_Dev.provisionprofile"')
end = source.index('\nfi', start) + len('\nfi')
validation = source[start:end]
start = source.index('if [[ "${CONF}" == "release" && "${SIGNING_MODE:-}" != "adhoc" ]]; then\n  cp ')
end = source.index('\nfi', source.index('elif [[ -f "$PROVISION_PROFILE" ]]', start)) + len('\nfi')
embedding = source[start:end]

profile_cases = ['production', 'missing-push', 'development', 'expired', 'wrong-app', 'wrong-team',
                 'no-cloudkit', 'wrong-container', 'wrong-environment', 'corrupt']
for configuration, signing, profile_present, allow_lldb, profile_case in itertools.product(
    ['release', 'debug'], ['identity', 'adhoc'], [False, True], ['0', '1'], profile_cases,
):
    with tempfile.TemporaryDirectory(prefix='codexbar-entitlement-test-') as directory:
        root = Path(directory)
        app = root / 'CodexBar.app'
        (app / 'Contents').mkdir(parents=True)
        (root / 'Scripts').mkdir()
        validator = Path(sys.argv[1]).parent / 'validate_cloudkit_profile.py'
        if validator.exists():
            (root / 'Scripts/validate_cloudkit_profile.py').write_bytes(validator.read_bytes())
        mock_bin = root / 'bin'
        mock_bin.mkdir()
        security = mock_bin / 'security'
        security.write_text('#!/bin/bash\n[[ "$1 $2 $3" == "cms -D -i" ]] || exit 99\ncat "$4"\n')
        security.chmod(0o755)
        profile = root / 'Provisioning/CodexBar_Dev.provisionprofile'
        if profile_present:
            profile.parent.mkdir(parents=True)
            entitlements = {
                'com.apple.application-identifier': '37HFR5V2JJ.com.audichuang.codexbar',
                'com.apple.developer.team-identifier': '37HFR5V2JJ',
                'com.apple.developer.aps-environment': 'production',
                'com.apple.developer.icloud-services': '*',
                'com.apple.developer.icloud-container-identifiers': ['iCloud.com.audichuang.codexbar'],
                'com.apple.developer.icloud-container-environment': 'Production',
            }
            overrides = {
                'development': ('com.apple.developer.aps-environment', 'development'),
                'wrong-app': ('com.apple.application-identifier', '37HFR5V2JJ.com.example.other'),
                'wrong-team': ('com.apple.developer.team-identifier', 'TESTTEAM01'),
                'no-cloudkit': ('com.apple.developer.icloud-services', ['CloudDocuments']),
                'wrong-container': ('com.apple.developer.icloud-container-identifiers', ['iCloud.example.other']),
                'wrong-environment': ('com.apple.developer.icloud-container-environment', 'Development'),
            }
            if profile_case in overrides:
                key, value = overrides[profile_case]
                entitlements[key] = value
            if profile_case == 'missing-push':
                del entitlements['com.apple.developer.aps-environment']
            expiry = datetime.datetime(2000 if profile_case == 'expired' else 2099, 1, 1)
            profile.write_bytes(plistlib.dumps({'Entitlements': entitlements, 'ExpirationDate': expiry}))
            if profile_case == 'corrupt':
                profile.write_text('invalid profile')
        # An upstream profile must never satisfy the fork's provisioning requirement.
        upstream = root / 'Scripts/profiles/CodexBar-DeveloperID.provisionprofile'
        upstream.parent.mkdir(parents=True)
        upstream.write_text('incompatible upstream profile marker\n')
        env = dict(os.environ, ROOT=str(root), APP=str(app), APP_TEAM_ID='37HFR5V2JJ',
                   CONF=configuration, LOWER_CONF=configuration, SIGNING_MODE=signing, ALLOW_LLDB=allow_lldb,
                   PATH=str(mock_bin) + os.pathsep + os.environ['PATH'])
        result = subprocess.run(['bash', '-eu', '-c', validation + '\n' + generation + '\n' + embedding],
                                env=env, capture_output=True, text=True)
        release_identity = configuration == 'release' and signing == 'identity'
        if allow_lldb == '1' and configuration != 'debug':
            assert result.returncode != 0, (configuration, signing, profile_present, allow_lldb)
            continue
        if release_identity and not profile_present:
            assert result.returncode != 0 and 'not found' in result.stderr, result.stderr
            continue
        if release_identity and profile_case != 'production':
            assert result.returncode != 0, f'{profile_case} profile unexpectedly accepted'
            assert 'Push Notifications' in result.stderr and str(profile) in result.stderr, result.stderr
            continue
        assert result.returncode == 0, result.stderr
        app_entitlements = plistlib.loads((root / '.build/entitlements/CodexBar.entitlements').read_bytes())
        widget_entitlements = plistlib.loads((root / '.build/entitlements/CodexBarWidget.entitlements').read_bytes())
        cli_entitlements = plistlib.loads((root / '.build/entitlements/CodexBarCLI.entitlements').read_bytes())
        cloudkit = signing == 'identity'
        if cloudkit:
            assert app_entitlements['com.apple.developer.team-identifier'] == '37HFR5V2JJ'
            assert app_entitlements['com.apple.developer.icloud-container-environment'] == 'Production'
            assert app_entitlements['com.apple.developer.icloud-container-identifiers'] == ['iCloud.com.audichuang.codexbar']
            group = '37HFR5V2JJ.com.steipete.codexbar' + ('.debug' if configuration == 'debug' else '')
            assert app_entitlements['com.apple.security.application-groups'] == [group]
            assert widget_entitlements['com.apple.security.application-groups'] == [group]
            assert cli_entitlements['com.apple.security.application-groups'] == [group]
            assert 'com.apple.developer.icloud-services' not in widget_entitlements
            assert 'com.apple.developer.icloud-services' not in cli_entitlements
            if release_identity:
                assert app_entitlements['com.apple.developer.aps-environment'] == 'production'
            else:
                assert 'com.apple.developer.aps-environment' not in app_entitlements
        else:
            assert 'com.apple.developer.icloud-services' not in app_entitlements
            assert 'com.apple.developer.aps-environment' not in app_entitlements
            assert 'com.apple.security.application-groups' not in cli_entitlements
        assert widget_entitlements['com.apple.security.app-sandbox'] is True
        embedded = app / 'Contents/embedded.provisionprofile'
        assert embedded.exists() == profile_present
        if embedded.exists():
            assert embedded.read_bytes() == profile.read_bytes()
print(f'{16 * len(profile_cases)} entitlement/profile configuration cases passed.')
PY

echo "Fork package signing tests passed."
