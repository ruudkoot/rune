from pathlib import Path
import subprocess,shutil,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel/ida';d=p/'source'
shutil.copytree(up,d,dirs_exist_ok=True);shutil.copy(up.parent/'Fast2haskell.hs',p/'Fast2haskell.hs')
# Preserve the source include layout by giving CPP the original parent directory.
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-I'+str(up),'-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for profile,repetitions,width in [('smoke',1,2),('source-fast',1500,2),('normal',600,3),('large',3000,3)]:
 t=time.monotonic();o=subprocess.run([str(d/'original'),str(repetitions),str(width),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(profile+'.stdout')).write_bytes(o.stdout);(p/(profile+'.stderr')).write_bytes(o.stderr)
 if profile!='smoke':assert o.stdout==(d/('ida.'+dict(**{'source-fast':'faststdout','normal':'stdout','large':'slowstdout'})[profile])).read_bytes()
 rows=o.stdout.splitlines(keepends=True);assert len(rows)==repetitions*2
 one=b''.join(rows[:2]);assert o.stdout==one*repetitions;(p/(profile+'.one')).write_bytes(one)
 records.append(dict(profile=profile,repetitions=repetitions,width=width,elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
