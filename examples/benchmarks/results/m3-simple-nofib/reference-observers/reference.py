from pathlib import Path
import shutil,subprocess,resource,time,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/simple'
shutil.copytree(up,p/'source',dirs_exist_ok=True)
with(p/'build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','Main.hs','-o','original'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,steps in [('source-fast',1),('normal',20),('source-slow',100)]:
 start=time.monotonic();r=subprocess.run([str(p/'source/original'),str(steps),'+RTS','-M512m','-RTS'],capture_output=True,check=True,timeout=600,preexec_fn=cap)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 assert r.stdout==b''
 records.append(dict(profile=profile,steps=steps,stdout_bytes=0,seconds=time.monotonic()-start,fixture='no upstream stdout fixture; source total-scalar consumer prints nothing'))
 print(records[-1],flush=True)
(p/'reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
