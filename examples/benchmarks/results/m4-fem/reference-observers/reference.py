from pathlib import Path
import shutil,subprocess,resource,time,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/fem'
shutil.copytree(up,p/'source',dirs_exist_ok=True)
with(p/'build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,reps in [('source-fast',20),('normal',100),('source-slow',500)]:
 start=time.monotonic()
 r=subprocess.run([str(p/'source/original'),str(reps),'+RTS','-M512m','-RTS'],input=(p/'source/fem.stdin').read_bytes(),capture_output=True,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 assert r.stdout==b''
 records.append(dict(profile=profile,repetitions=reps,seconds=time.monotonic()-start,stdout_bytes=0))
 print(records[-1],flush=True)
(p/'reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
