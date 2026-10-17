from pathlib import Path
import subprocess,resource,shutil,json,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/event';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True);shutil.copy(up.parent/'Fast2haskell.hs',p/'Fast2haskell.hs')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,limit,fixture in [('smoke',200,'event.faststdout'),('normal',100000,'event.stdout'),('large',500000,'event.slowstdout')]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),str(limit),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 fixture_match=None if profile=='smoke'else r.stdout==(d/fixture).read_bytes()
 assert len(r.stdout.splitlines())==100 and all(row==r.stdout.splitlines()[0]for row in r.stdout.splitlines())
 assert fixture_match is not False
 records.append(dict(profile=profile,end_time=limit,repetitions=100,fixture_match=fixture_match,final_state=r.stdout.splitlines()[0].decode(),elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
