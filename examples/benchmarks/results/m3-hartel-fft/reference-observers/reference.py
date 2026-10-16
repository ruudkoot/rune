from pathlib import Path
import shutil,subprocess,resource,json,hashlib
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/spectral/hartel';shutil.copyfile(up/'Fast2haskell.hs',p/'Fast2haskell.hs');meta=[]
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
for name,profiles,reps in [('fft',[('smoke',1),('normal',3),('large',5)],360),('genfft',[('smoke',3),('normal',6),('large',8)],300)]:
 d=p/name;d.mkdir(exist_ok=True)
 for file in(up/name).iterdir():
  if file.is_file():shutil.copyfile(file,d/file.name)
 with(d/'original-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 source=(d/'Main.hs').read_text();assert'module Main (main)'in source;(d/'Kernel.hs').write_text(source.replace('module Main (main)','module Kernel',1))
 observer='''module Main where
import Kernel
import Data.Complex
import System.Environment
showComplex x=show(realPart x)++" "++show(imagPart x)
main=do
 [arg]<-getArgs
 let input=f_large(read arg)64
 putStrLn "INPUT"
 mapM_(putStrLn.showComplex)input
 putStrLn "IAA"
 mapM_(putStrLn.showComplex)(f_iaamain input)
 putStrLn "RLL"
 mapM_(putStrLn.showComplex)(f_rllmain input)
'''if name=='fft'else'''module Main where
import Kernel
import System.Environment
main=do
 [arg]<-getArgs
 putStr(concat[f_generate n|n<-[1..read arg]])
'''
 (d/'Observer.hs').write_text(observer)
 with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 for profile,n in profiles:
  fixture=name+dict(smoke='.faststdout',normal='.stdout',large='.slowstdout')[profile]
  raw=subprocess.check_output([str(d/'original'),str(n)],cwd=d,timeout=180,preexec_fn=cap);assert raw==(d/fixture).read_bytes();(d/(profile+'.stdout')).write_bytes(raw);lines=raw.decode().splitlines();assert len(lines)==reps and len(set(lines))==1
  observed=subprocess.check_output([str(d/'observer'),str(n)],cwd=d,timeout=180,preexec_fn=cap);(d/(profile+('.values'if name=='fft'else'.program'))).write_bytes(observed)
  row=dict(name=name,profile=profile,n=n,repetitions=reps,checksum=lines[0],observer_bytes=len(observed),source_sha256=hashlib.sha256((d/'Main.hs').read_bytes()).hexdigest());meta.append(row);print(row,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
