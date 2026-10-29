import json,subprocess,hashlib,os
from pathlib import Path
r=Path('/Volumes/StudioSSD/Projects/working/apple/CodexBar');s=Path('/Volumes/StudioSSD/Developer/BuildScratch/CodexBar/Upstream082');os.chdir(r)
repo='o1xhack/CodexBar-Mobile';releaseID=427366941;tag='v0.82.0.1-mobile.3.2.0';draftTag='untagged-780e47f927e739ed48a3'
def api():
 d=json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/releases/{releaseID}'],text=True))
 assert d['id']==releaseID and d['draft'] and d['tag_name']==draftTag
 return d
d=api();assert d['draft'] and d['tag_name']==draftTag
verified=json.loads((s/'mac-artifacts-verified.json').read_text());cast=json.loads((s/'appcast-candidate/verification.json').read_text());assert verified['allInputHashesMatch'] and cast['clientBundlePublicKeyVerified'] and cast['ed25519Verified']
zipAsset=next(a for a in verified['assets'] if a['name'].endswith('.zip') and not a['name'].endswith('.dSYM.zip'))
assert cast['zipSHA256']==zipAsset['sha256'] and cast['length']==zipAsset['size'] and cast['version']==verified['sparkleVersion']
assert verified['sourceCommit']==json.loads((s/'mac-draft-source-manifest.json').read_text())['sourceCommit']
notes=(s/'mac-final-release-notes.md').read_text();assert verified['sourceCommit'] in notes and 'placeholder' in notes
from urllib.parse import quote, urlsplit
original=json.loads((s/'mac-draft-release.json').read_text())
for a in verified['assets']:
 d=api()
 path=r/a['name'];assert path.stat().st_size==a['size'] and hashlib.sha256(path.read_bytes()).hexdigest()==a['sha256']
 match=[x for x in d['assets'] if x['name']==a['name']];assert len(match)<=1
 if match and match[0]['size']==a['size'] and match[0].get('digest')=='sha256:'+a['sha256']:continue
 if match:
  old=match[0];originalMatch=[x for x in original['assets'] if x['id']==old['id'] and x['name']==old['name'] and x.get('digest')==old.get('digest')]
  assert len(originalMatch)==1,'Unexpected asset mutation; preserve it instead of clobbering'
  preserved=s/'superseded-appgroup-candidate'/old['name'];assert preserved.is_file() and 'sha256:'+hashlib.sha256(preserved.read_bytes()).hexdigest()==old['digest']
  fresh=api();assert any(x['id']==old['id'] and x['name']==old['name'] and x.get('digest')==old['digest'] for x in fresh['assets'])
  subprocess.run(['gh','api','--method','DELETE',f'repos/{repo}/releases/assets/{old["id"]}','--silent'],check=True)
 d=api();assert not any(x['name']==a['name'] for x in d['assets'])
 base=d['upload_url'].split('{',1)[0];url=urlsplit(base)
 assert url.scheme=='https' and url.netloc=='uploads.github.com' and url.path==f'/repos/{repo}/releases/{releaseID}/assets'
 response=subprocess.check_output(['gh','api','--method','POST',base+'?name='+quote(a['name'],safe=''),'--header','Content-Type: application/zip','--input',str(path)],text=True)
 uploaded=json.loads(response);assert uploaded['name']==a['name'] and uploaded['size']==a['size'] and uploaded['digest']=='sha256:'+a['sha256']
 d=api()
assert d['draft'] and d['tag_name']==draftTag
payload={'body':notes,'draft':True,'target_commitish':'mobile-dev'};(s/'mac-final-draft-update.json').write_text(json.dumps(payload)+'\n')
subprocess.run(['gh','api','--method','PATCH',f'repos/{repo}/releases/{releaseID}','--input',str(s/'mac-final-draft-update.json'),'--silent'],check=True)
d=api();assert d['draft'] and d['tag_name']==draftTag and d['target_commitish']=='mobile-dev'
for a in verified['assets']:
 match=[x for x in d['assets'] if x['name']==a['name']];assert len(match)==1 and match[0]['size']==a['size'] and match[0]['digest']=='sha256:'+a['sha256']
assert subprocess.run(['git','show-ref','--verify','--quiet','refs/tags/'+tag]).returncode==1
assert not subprocess.check_output(['git','ls-remote','--tags','origin','refs/tags/'+tag],text=True).strip()
(s/'mac-draft-release-final.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps({'url':d['html_url'],'id':d['id'],'draft':True,'targetPlaceholder':'mobile-dev','assetsDigestVerified':True,'gitTagAbsent':True,'sourceCommit':verified['sourceCommit']}))
