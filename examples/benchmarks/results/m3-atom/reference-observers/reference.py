from pathlib import Path
import subprocess,shutil,resource,json,hashlib,struct,math
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/atom';d=p/'source';d.mkdir(exist_ok=True)
for file in up.iterdir():
 if file.is_file():shutil.copyfile(file,d/file.name)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
with(d/'original-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
(d/'Kernel.hs').write_text((d/'Main.hs').read_text().replace('module Main where','module Kernel where',1))
(d/'Observer.hs').write_text('''module Main where
import Kernel
import GHC.Float(castFloatToWord32)
import Numeric(showHex)
import System.Environment
main=do
 [arg]<-getArgs
 mapM_ (\\(State p v)->putStrLn(unwords(map(\\x->showHex(castFloatToWord32 x)"")p)++" | "++unwords(map(\\x->showHex(castFloatToWord32 x)"")v))) (take(read arg)test)
''')
with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
metadata=[]
for profile,n in [('smoke',1000),('normal',2500),('large',4000)]:
 raw=subprocess.check_output([str(d/'original'),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=180,preexec_fn=cap);fixture='atom'+dict(smoke='.faststdout',normal='.stdout',large='.slowstdout')[profile];assert raw==(d/fixture).read_bytes();(p/(profile+'.stdout')).write_bytes(raw)
 bits=subprocess.check_output([str(d/'observer'),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=180,preexec_fn=cap);(p/(profile+'.bits')).write_bytes(bits);assert len(bits.splitlines())==n
 metadata.append(dict(profile=profile,n=n,stdout_bytes=len(raw),source_sha256=hashlib.sha256((d/'Main.hs').read_bytes()).hexdigest(),observer='forces both position and velocity; primary source shows only positions',runtime_options=['-M1g']));print(metadata[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
