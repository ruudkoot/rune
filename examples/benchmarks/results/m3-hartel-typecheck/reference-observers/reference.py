from pathlib import Path
import subprocess,shutil,resource,json,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/typecheck';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True);shutil.copy(up.parent/'Fast2haskell.hs',p/'Fast2haskell.hs')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-ddump-simpl','-dsuppress-all','-ddump-to-file','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,n,fixture in [('smoke',1,None),('source-fast',500,'typecheck.faststdout'),('normal',5000,'typecheck.stdout'),('large',25000,'typecheck.slowstdout')]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 if fixture:assert r.stdout==(d/fixture).read_bytes()
 records.append(dict(profile=profile,repetitions=n,result=r.stdout.decode().strip(),elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
