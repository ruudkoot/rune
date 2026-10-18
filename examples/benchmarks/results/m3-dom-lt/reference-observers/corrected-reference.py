from pathlib import Path
import subprocess,resource,shutil,difflib,json
p=Path(__file__).resolve().parent;d=p/'corrected-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
original=(d/'Dom.hs').read_text()
old='    sw <- sdnoM w\n';assert original.count(old)==1
corrected=original.replace(old,'',1)
old='      su <- sdnoM u\n      when (su < sw)'
new='      su <- sdnoM u\n      sw <- sdnoM w\n      when (su < sw)'
assert corrected.count(old)==1
corrected=corrected.replace(old,new,1);(d/'Dom.hs').write_text(corrected)
(p/'semidominator-minimum.patch').write_text(''.join(difflib.unified_diff(original.splitlines(keepends=True),corrected.splitlines(keepends=True),fromfile='a/spectral/dom-lt/Dom.hs',tofile='b/spectral/dom-lt/Dom.hs')))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','corrected-main','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,n,fixture in [('source-fast',50,'dom-lt.faststdout'),('normal',400,'dom-lt.stdout'),('large',2000,'dom-lt.slowstdout')]:
 r=subprocess.run([str(d/'corrected-main'),'ghc-examples.in',str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/('corrected-'+profile+'.stdout')).write_bytes(r.stdout);assert r.stdout==(p/'source'/fixture).read_bytes()
 records.append(dict(profile=profile,argument=n,original_fixture_matches=True,result=r.stdout.decode().strip()));print(records[-1],flush=True)
(p/'corrected-reference.json').write_text(json.dumps(records,indent=2)+'\n')
