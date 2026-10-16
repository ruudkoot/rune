from pathlib import Path
import shutil,subprocess,resource,json,math
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel';shutil.copy(up/'Fast2haskell.hs',p/'Fast2haskell.hs');d=p/'wang';d.mkdir(exist_ok=True)
for file in(up/'wang').iterdir():
 if file.is_file():shutil.copy(file,d/file.name)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
with(d/'original-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
(d/'Kernel.hs').write_text((d/'Main.hs').read_text().replace('module Main (main)','module Kernel',1))
(d/'Observer.hs').write_text('''module Main where
import Kernel
import System.Environment
main=do
 [n]<-getArgs
 mapM_ (putStrLn . unwords . map show) (f_solution (f_bigmatrix(read n)))
''')
with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
rows=[]
for profile,n,fixture in [('smoke',25,'wang.faststdout'),('normal',80,'wang.stdout'),('large',150,'wang.slowstdout')]:
 output=subprocess.check_output([str(d/'original'),str(n)],cwd=d,timeout=60,preexec_fn=cap);assert output==(d/fixture).read_bytes();(p/(profile+'.stdout')).write_bytes(output)
 trace=subprocess.check_output([str(d/'observer'),str(n)],cwd=d,timeout=60,preexec_fn=cap);(p/(profile+'.values')).write_bytes(trace);values=[float(x)for x in trace.split()];assert len(values)==n*(n+1)and all(math.isfinite(v)for v in values)
 rows.append(dict(profile=profile,n=n,count=len(values),maximum_error=max(abs(v-1)for v in values),stdout=output.decode().strip()))
 print(rows[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(rows,indent=2)+'\n')
