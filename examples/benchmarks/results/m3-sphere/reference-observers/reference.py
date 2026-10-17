from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/sphere';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n in [('smoke',30),('normal',100),('large',250)]:
 r=subprocess.run([str(d/'original'),str(n),'+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True)
 expected=(d/('sphere'+('.fast'if name=='smoke'else'.slow'if name=='large'else'.')+'stdout')).read_bytes()
 assert r.stdout==expected
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 records.append(dict(profile=name,size=n,repetitions=100,hash=r.stdout.decode().splitlines()[0],fixture_match=True));print(records[-1],flush=True)
obs=p/'observer-source';obs.mkdir(exist_ok=True)
s=(d/'Main.lhs').read_text();assert'> module Main where'in s
(obs/'Kernel.lhs').write_text(s.replace('> module Main where','> module Kernel where'))
(obs/'Observer.hs').write_text("""module Main where
import qualified Kernel as K
import System.Environment
main = do
 [size] <- getArgs
 mapM_ (\\((i,j),(r,g,b))->putStrLn(unwords[show i,show j,show r,show g,show b,show(round(255*r)::Integer),show(round(255*g)::Integer),show(round(255*b)::Integer)])) (K.ray(read size))
""")
with(obs/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=obs,stdout=f,stderr=subprocess.STDOUT,check=True)
for name,n in [('smoke',30),('normal',100),('large',250)]:
 r=subprocess.run([str(obs/'observer'),str(n)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 (p/(name+'.pixels')).write_bytes(r.stdout);h=0
 rows=[line.split()for line in r.stdout.decode().splitlines()];assert len(rows)==n*n
 for row in reversed(rows):
  r,g,b=map(int,row[5:]);h=(r+7*g+23*b+61*h)%(2**64)
 signed=h if h<2**63 else h-2**64
 assert signed==int((p/(name+'.stdout')).read_text().splitlines()[0])
 print(name,len(rows),'pixels independently reproduce hash',signed,flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),runs=records),indent=2)+'\n')
