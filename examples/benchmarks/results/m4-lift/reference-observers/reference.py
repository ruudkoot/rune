from pathlib import Path
import subprocess,shutil,resource,time,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/lift'
shutil.copytree(up,p/'source',dirs_exist_ok=True)
with(p/'build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,count in [('source-fast',400),('normal',4000),('source-slow',20000)]:
 start=time.monotonic();r=subprocess.run([str(p/'source/original'),str(count),'+RTS','-M512m','-RTS'],capture_output=True,check=True,timeout=600,preexec_fn=cap)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 suffix='faststdout'if count==400 else'stdout'if count==4000 else'slowstdout'
 assert r.stdout==(p/'source'/('lift.'+suffix)).read_bytes()
 records.append(dict(profile=profile,repetitions=count,bytes=len(r.stdout),seconds=time.monotonic()-start));print(records[-1],flush=True)
(p/'reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
