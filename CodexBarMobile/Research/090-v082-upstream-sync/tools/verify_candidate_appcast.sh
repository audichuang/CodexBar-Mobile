#!/bin/bash
set -euo pipefail
ROOT=/Volumes/StudioSSD/Projects/working/apple/CodexBar
SCRATCH=/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Upstream082
cd "$ROOT"
source Scripts/load-release-secrets.sh
source Scripts/sparkle_helpers.sh
source version.env
STAGE="$SCRATCH/appcast-candidate"
mkdir "$STAGE"
KEY_FILE="$SPARKLE_PRIVATE_KEY_FILE"
[[ -f "$KEY_FILE" ]]
ZIP="CodexBar-${MARKETING_VERSION}-mobile.${MOBILE_VERSION}.zip"
cp "$ROOT/$ZIP" "$STAGE/$ZIP"
cp "$ROOT/appcast.xml" "$STAGE/appcast.xml"
"$ROOT/Scripts/changelog-to-html.sh" "$MARKETING_VERSION" > "$STAGE/${ZIP%.zip}.html"
generate_appcast --ed-key-file "$KEY_FILE" \
 --download-url-prefix "https://github.com/o1xhack/CodexBar-Mobile/releases/download/v${MARKETING_VERSION}-mobile.${MOBILE_VERSION}/" \
 --embed-release-notes \
 --link https://raw.githubusercontent.com/o1xhack/CodexBar-Mobile/mobile-dev/appcast.xml "$STAGE"
python3 - "$STAGE" "$ROOT" <<'PY'
import sys,json,hashlib,xml.etree.ElementTree as E,subprocess
from pathlib import Path
stage,root=map(Path,sys.argv[1:]); ns={'s':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
a=E.parse(stage/'appcast.xml');items=[x for x in a.findall('./channel/item') if x.findtext('s:shortVersionString',namespaces=ns)=='0.82.0.1'];assert len(items)==1
x=items[0];assert x.findtext('s:version',namespaces=ns)=='175.1.3.2.0'; e=x.find('enclosure'); name='CodexBar-0.82.0.1-mobile.3.2.0.zip';z=root/name
assert e.attrib['url']=='https://github.com/o1xhack/CodexBar-Mobile/releases/download/v0.82.0.1-mobile.3.2.0/'+name
assert int(e.attrib['length'])==z.stat().st_size
sig=e.attrib['{'+ns['s']+'}edSignature'];assert sig
(stage/'signature.txt').write_text(sig)
version=tuple(map(int,x.findtext('s:version',namespaces=ns).split('.')))
for old in E.parse(root/'appcast.xml').findall('./channel/item'):
 value=old.findtext('s:version',namespaces=ns)
 if value and all(p.isdigit() for p in value.split('.')): assert version>tuple(map(int,value.split('.')))
proof={'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'candidateXML':str(stage/'appcast.xml'),'candidateXMLSHA256':hashlib.sha256((stage/'appcast.xml').read_bytes()).hexdigest(),'repositoryFeedSHA256':hashlib.sha256((root/'appcast.xml').read_bytes()).hexdigest(),'version':'175.1.3.2.0','shortVersion':'0.82.0.1','enclosureURL':e.attrib['url'],'length':z.stat().st_size,'zipSHA256':hashlib.sha256(z.read_bytes()).hexdigest(),'signaturePresent':True,'monotonic':True,'published':False}
(stage/'verification.json').write_text(json.dumps(proof,indent=2)+'\n')
PY
SIGNATURE=$(cat "$STAGE/signature.txt")
sign_update --verify "$ROOT/$ZIP" "$SIGNATURE" --ed-key-file "$KEY_FILE"
swift -module-cache-path "$SCRATCH/swift-public-key-module-cache" "$SCRATCH/verify_sparkle_public_key.swift" "$SCRATCH/mac-artifact-verification/CodexBar.app/Contents/Info.plist" "$ROOT/$ZIP" "$SIGNATURE"
python3 - "$STAGE/verification.json" <<'PY'
import sys,json
from pathlib import Path
p=Path(sys.argv[1]);d=json.loads(p.read_text());d['ed25519Verified']=True;d['clientBundlePublicKeyVerified']=True;p.write_text(json.dumps(d,indent=2)+'\n')
PY
git diff --exit-code -- appcast.xml
printf 'CANDIDATE_APPCAST_VERIFIED_NO_FEED_CHANGE\n'
