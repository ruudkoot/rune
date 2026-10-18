from pathlib import Path
import shutil,subprocess,resource,time,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel'
shutil.copytree(up/'comp_lab_zift',p/'source',dirs_exist_ok=True);shutil.copy(up/'Fast2haskell.hs',p/'Fast2haskell.hs')
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(p/'build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=p/'source',stdout=log,stderr=subprocess.STDOUT,check=True)
records=[]
for name,size in [('source-fast',2),('normal',5),('source-slow',9)]:
 start=time.monotonic()
 r=subprocess.run([str(p/'source/original'),str(size),'+RTS','-M512m','-RTS'],capture_output=True,timeout=600,preexec_fn=cap,check=True)
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 suffix='faststdout'if size==2 else'stdout'if size==5 else'slowstdout'
 assert r.stdout==(p/'source'/('comp_lab_zift.'+suffix)).read_bytes()
 records.append(dict(profile=name,size=size,repetitions=100,bytes=len(r.stdout),seconds=time.monotonic()-start))
 print(records[-1],flush=True)
(p/'reference-results.json').write_text(json.dumps(records,indent=2)+'\n')
