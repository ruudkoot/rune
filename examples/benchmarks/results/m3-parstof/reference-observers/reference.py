from pathlib import Path
import subprocess,resource,shutil,time,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel'
shutil.copytree(up/'parstof',p/'source',dirs_exist_ok=True);shutil.copy(up/'Fast2haskell.hs',p/'Fast2haskell.hs')
with(p/'build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,depth in [('source-fast',1),('normal',8),('source-slow',40)]:
 start=time.monotonic();r=subprocess.run([str(p/'source/original'),str(depth),'+RTS','-M512m','-RTS'],capture_output=True,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 suffix='faststdout'if depth==1 else'stdout'if depth==8 else'slowstdout'
 assert r.stdout==(p/'source'/('parstof.'+suffix)).read_bytes()
 records.append(dict(profile=profile,depth=depth,repetitions=100,bytes=len(r.stdout),seconds=time.monotonic()-start));print(records[-1],flush=True)
(p/'reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
