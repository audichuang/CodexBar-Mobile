#!/usr/bin/env python3
from pathlib import Path
import tempfile,subprocess,os,shutil,json
repo=Path(__file__).resolve().parent.parent; root=Path(tempfile.gettempdir())
release_source=(repo/'Scripts/release.sh').read_text()
dispatch='\ncase "${1:-phase1}" in'
assert release_source.count(dispatch)==1, 'release dispatcher changed; refuse to source executable entrypoint'
source=release_source.split(dispatch)[0]
results=[]
expected_codes={'phase1-success-after-return':0,'phase1-missing-stage':1,'phase1-probe-failure':17,
 'phase2-missing-stage':1,'phase2-appcast-failure':18,'phase2-post-verify-publish-failure':19,'metadata-parse-failure':1}
for case,expected_exit in expected_codes.items():
 with tempfile.TemporaryDirectory(prefix="release-cleanup-space'quote-",dir=root) as folder:
  b=Path(folder);s=b/'Scripts';s.mkdir();tmp=b/'tmp';tmp.mkdir();stage=b/'stage';bindir=b/'bin';bindir.mkdir()
  if not case.endswith('missing-stage'):stage.mkdir()
  (s/'functions.sh').write_text(source)
  for name in ['sparkle_helpers.sh','release_dsym_paths.sh']:shutil.copy(repo/'Scripts'/name,s/name)
  (s/'load-release-secrets.sh').write_text('')
  (b/'version.env').write_text('MARKETING_VERSION=0.0.0.1\nBUILD_NUMBER=1.1\nMOBILE_VERSION=0.0.1\n')
  (b/'appcast.xml').write_text('<rss><channel/></rss>')
  (b/'key').write_text('synthetic-fixture-key\n')
  for name in ['lint.sh','sign-and-notarize.sh']:
   (s/name).write_text('#!/bin/bash\nexit 0\n');(s/name).chmod(0o755)
  (s/'make_appcast.sh').write_text('#!/bin/bash\nexit 18\n');(s/'make_appcast.sh').chmod(0o755)
  for command in ['git','gh','swift','xcrun','codesign','security','defaults','curl','op','osascript']:
   (bindir/command).write_text('#!/bin/bash\nexit 99\n');(bindir/command).chmod(0o755)
  (bindir/'sign_update').write_text('#!/bin/bash\nexit 0\n');(bindir/'sign_update').chmod(0o755)
  # Model BSD stat for this macOS-only release helper on portable CI hosts.
  (bindir/'stat').write_text('#!/usr/bin/env python3\nimport pathlib,sys\nassert sys.argv[1] == "-f%z"\nprint(pathlib.Path(sys.argv[2]).stat().st_size)\n');(bindir/'stat').chmod(0o755)
  if case=='phase2-post-verify-publish-failure':
   (s/'make_appcast.sh').write_text("#!/bin/bash\ncat > appcast.xml <<'XML'\n<rss xmlns:s=\"http://www.andymatuschak.org/xml-namespaces/sparkle\"><channel><item><s:shortVersionString>0.0.0.1</s:shortVersionString><enclosure url=\"https://github.com/audichuang/CodexBar-Mobile/releases/download/v0.0.0.1-mobile.0.0.1/CodexBar-0.0.0.1-mobile.0.0.1.zip\" s:edSignature=\"fixture\" length=\"7\"/></item></channel></rss>\nXML\n")
  driver='''#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/functions.sh"
require_clean_worktree() { :; }
ensure_changelog_finalized() { :; }
ensure_appcast_monotonic() { :; }
require_finalize_checkout() { :; }
artifact_matches_current_inputs() { return 0; }
artifact_pair_matches() { return 0; }
require_remote_asset_matches_local() { :; }
clear_sparkle_caches() { :; }
extract_notes_from_changelog() { printf fixture > "$2"; }
check_assets() { :; }
git() { printf '%s\\n' fixture-commit; }
gh() { if [[ "$*" == *isDraft* ]]; then printf 'true\\n'; else printf 'https://example.invalid/draft\\n'; fi; }
'''
  if case=='phase1-probe-failure':driver+='probe_sparkle_key() { exit 17; }\n'
  if case=='phase2-post-verify-publish-failure':driver+='gh() { if [[ "$*" == *isDraft* ]]; then printf "true\\n"; elif [[ "$*" == *--draft=false* ]]; then [[ -f "$KEY_FILE" ]] || exit 29; exit 19; else exit 27; fi; }\n'
  if case.startswith('phase1'):driver+='DRAFT_NO_TAG_PUSH=1 phase1\nprintf "Returned from phase1 before EXIT cleanup\\n"\n'
  elif case.startswith('phase2'):
   for suffix in ['.zip','.dSYM.zip']:(b/('CodexBar-0.0.0.1-mobile.0.0.1'+suffix)).write_text('fixture')
   driver+='phase2\n'
  else:driver+='verify_local_appcast_artifact fixture.zip "$SPARKLE_PRIVATE_KEY_FILE"\n'
  (s/'driver.sh').write_text(driver)
  env=dict(os.environ,RUN_SWIFT_TEST='0',TMPDIR=str(tmp),CODEXBAR_RELEASE_STAGE_BASE=str(stage),SPARKLE_PRIVATE_KEY_FILE=str(b/'key'),PATH=str(bindir)+':'+os.environ['PATH'])
  run=subprocess.run(['bash',str(s/'driver.sh')],env=env,capture_output=True,text=True)
  assert run.returncode==expected_exit,(case,run.returncode,run.stdout,run.stderr)
  if case.endswith('missing-stage'):assert 'mktemp' in run.stderr,(case,run.stderr)
  if case=='metadata-parse-failure':assert 'No appcast entry found' in run.stderr,(case,run.stderr)
  assert not list(tmp.iterdir()),(case,'key outside workspace leaked')
  assert not stage.exists() or not list(stage.iterdir()),(case,'workspace/probe/metadata leaked',list(stage.iterdir()))
  assert (b/'key').read_text()=='synthetic-fixture-key\n'
  results.append({'case':case,'exit':run.returncode,'cleanup':'pass','pathWithSpaceAndQuote':'pass','externalMutations':'stubbed','credentials':'synthetic'})
if os.environ.get('CODEXBAR_RELEASE_CLEANUP_EVIDENCE'):
 Path(os.environ['CODEXBAR_RELEASE_CLEANUP_EVIDENCE']).write_text(json.dumps(results,indent=2)+'\n')
print(f'Release temporary cleanup tests passed ({len(results)} cases).')
