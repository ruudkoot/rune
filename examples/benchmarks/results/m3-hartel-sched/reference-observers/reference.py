from pathlib import Path
import subprocess,shutil,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/sched';d=p/'source'
shutil.copytree(up,d,dirs_exist_ok=True);shutil.copy(up.parent/'Fast2haskell.hs',p/'Fast2haskell.hs')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-I'+str(up),'-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,repetitions,size in [('smoke',1,3),('source-fast',200,10),('normal',100,11),('large',500,11)]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),str(repetitions),str(size),'+RTS','-M512m','-RTS'],cwd=d,capture_output=True,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(r.stdout);(p/(profile+'.stderr')).write_bytes(r.stderr)
 if profile!='smoke':
  suffix={'source-fast':'faststdout','normal':'stdout','large':'slowstdout'}[profile]
  assert r.stdout==(d/('sched.'+suffix)).read_bytes()
 lines=r.stdout.splitlines(keepends=True);assert len(lines)==repetitions and r.stdout==lines[0]*repetitions
 (p/(profile+'.one')).write_bytes(lines[0])
 records.append(dict(profile=profile,repetitions=repetitions,size=size,seconds=time.monotonic()-t))
 print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
