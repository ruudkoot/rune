from pathlib import Path
import subprocess,shutil,json,resource,time
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/knights';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n in [('smoke',8),('normal',14),('large',20)]:
 t=time.monotonic();r=subprocess.run([str(d/'original'),str(n),'1','+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 fixture=d/('knights.faststdout'if name=='smoke'else'knights.slowstdout'if name=='large'else'knights.stdout');assert r.stdout==fixture.read_bytes()
 records.append(dict(profile=name,side=n,repetitions=100,output_length=int(r.stdout.splitlines()[0]),fixture_match=True,elapsed_seconds=time.monotonic()-t));print(records[-1],flush=True)
obs=p/'observer-source';shutil.copytree(up,obs,dirs_exist_ok=True)
s=(obs/'Main.lhs').read_text().replace('module Main(main) where','module Knights where');(obs/'Knights.lhs').write_text(s)
(obs/'Observer.hs').write_text('''module Main where
import Knights
import System.Environment
main = getArgs >>= putStr . printTour
''')
with(obs/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=obs,stdout=f,stderr=subprocess.STDOUT,check=True)
for n,k in [(6,1),(8,1),(8,3),(14,1),(20,1),(4,1),(8,0)]:
 r=subprocess.run([str(obs/'observer'),str(n),str(k),'+RTS','-M512m','-RTS'],cwd=obs,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
 (p/(str(n)+'-'+str(k)+'.tour')).write_bytes(r.stdout);print('tour',n,k,len(r.stdout),flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
