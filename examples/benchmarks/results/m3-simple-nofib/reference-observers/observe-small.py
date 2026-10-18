from pathlib import Path
import subprocess,shutil,resource,json
p=Path(__file__).resolve().parent
o=p/'small-observer-source';shutil.copytree(p/'observer-source',o,dirs_exist_ok=True,ignore=shutil.ignore_patterns('*.o','*.hi','observe','simple'))
t=(o/'Kernel.hs').read_text();assert 'grid_max = 100 :: Int'in t
(o/'Kernel.hs').write_text(t.replace('grid_max = 100 :: Int','grid_max = 8 :: Int'))
with(p/'small-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','Observe.hs','-o','observe'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for n in [0,1,2,5]:
 for mode in ['totals','state']:
  r=subprocess.run([str(o/'observe'),mode,str(n),'+RTS','-M512m','-RTS'],capture_output=True,timeout=60,preexec_fn=cap)
  (p/('small-'+mode+'-'+str(n)+'.reference')).write_bytes(r.stdout)
  (p/('small-'+mode+'-'+str(n)+'.stderr')).write_bytes(r.stderr)
  print(mode,n,r.returncode,len(r.stdout),flush=True);r.check_returncode()
