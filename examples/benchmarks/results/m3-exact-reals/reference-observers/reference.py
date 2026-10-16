from pathlib import Path
import subprocess,shutil,resource,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/exact-reals';d=p/'source';d.mkdir(exist_ok=True)
for file in up.iterdir():
 if file.is_file():shutil.copyfile(file,d/file.name)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
with(d/'original-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
(d/'Kernel.hs').write_text((d/'Main.hs').read_text().replace('module Main where','module Kernel where',1))
(d/'Observer.hs').write_text('''module Main where
import Kernel
import System.Environment
sine x=sin(x*pi)
main=do
 [arg]<-getArgs
 let n=read arg::Int
 let value=sum(map sine [1..fromIntegral n::CR])
 print(bits(digitsToBits digits)value)
 putStrLn(get_str digits value)
''')
with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
meta=[]
for profile,n in [('smoke',60),('normal',350),('large',800)]:
 raw=subprocess.check_output([str(d/'original'),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=180,preexec_fn=cap);fixture='exact-reals'+dict(smoke='.faststdout',normal='.stdout',large='.slowstdout')[profile];fixture=fixture if (d/fixture).exists() else 'exact-reals.stdout';assert raw==(d/fixture).read_bytes();(p/(profile+'.stdout')).write_bytes(raw)
 observed=subprocess.check_output([str(d/'observer'),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=180,preexec_fn=cap);(p/(profile+'.observe')).write_bytes(observed);meta.append(dict(profile=profile,n=n,fixture=fixture,stdout=raw.decode().strip(),observer=observed.decode().splitlines()));print(meta[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
