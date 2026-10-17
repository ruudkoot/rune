from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/para';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.lhs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
records=[]
for name,n in [('smoke',1),('normal',8),('large',40)]:
 r=subprocess.run([str(d/'original'),str(n),'runtime_files/input-data','+RTS','-M512m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 assert not r.stdout
 (p/(name+'.stdout')).write_bytes(r.stdout);(p/(name+'.stderr')).write_bytes(r.stderr)
 records.append(dict(profile=name,iterations=n,empty_stdout=True,upstream_fixture_present=(d/'para.stdout').exists()))
 print(records[-1],flush=True)
obs=p/'observer-source';obs.mkdir(exist_ok=True)
s=(d/'Main.lhs').read_text();assert'>module Main where'in s
(obs/'Kernel.lhs').write_text(s.replace('>module Main where','>module Kernel where'))
(obs/'Observer.hs').write_text("""module Main where
import qualified Kernel as K
import System.Environment
main = do
 [path] <- getArgs
 text <- readFile path
 putStr (if null text then [] else K.fmt text)
""")
with(obs/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=obs,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(obs/'observer'),str(d/'runtime_files/input-data')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
(p/'formatted.reference').write_bytes(r.stdout)
records.append(dict(formatted_bytes=len(r.stdout),input_bytes=(d/'runtime_files/input-data').stat().st_size))
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
