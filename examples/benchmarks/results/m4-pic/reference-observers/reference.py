from pathlib import Path
import subprocess,shutil,resource,json
p=Path(__file__).resolve().parent;up=p.parent/'pinned/nofib/real/pic';d=p/'source';d.mkdir(exist_ok=True)
for file in up.iterdir():
 if file.is_file():shutil.copyfile(file,d/file.name)
def cap():resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
with(d/'original-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','original','Main.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
(d/'KernelPic.hs').write_text((d/'Pic.hs').read_text().replace('module Pic (pic) where','module KernelPic where'))
(d/'Observer.hs').write_text('''module Main where
import KernelPic
import PicType
import Consts
import Data.Array
import NofibUtils
import System.Environment
numbers name values=putStrLn(name++" "++unwords(map show values))
emit particles k=do
 let initial=initParticles particles
 let phi=initPhi initial
 let(dt,grid,(positions,velocities))=timeStep initial phi 0.001 0 k
 putStrLn("step "++show k)
 numbers "dt" [dt]
 numbers "phi"(elems grid)
 numbers "positions"(concatMap(\\(x,y)->[x,y])positions)
 numbers "velocities"(concatMap(\\(x,y)->[x,y])velocities)
main=do
 [arg]<-getArgs
 let n=read arg
 putStrLn("pic "++pic n)
 putStrLn("hash "++show(hash(arg++pic n)))
 mapM_(emit n)[0..10]
''')
with(d/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
metadata=[]
for n in [1,2,3,18,80,300]:
 raw=subprocess.check_output([str(d/'observer'),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=300,preexec_fn=cap)
 (p/(str(n)+'.trace')).write_bytes(raw)
 first=raw.decode().splitlines()[:2];metadata.append(dict(particles=n,header=first,steps=11));print(metadata[-1],flush=True)
for profile,repeats,n in [('fast',200,18),('normal',500,80),('slow',1000,300)]:
 raw=subprocess.check_output([str(d/'original'),str(repeats),str(n),'+RTS','-M1g','-RTS'],cwd=d,timeout=600,preexec_fn=cap);assert raw==b''
 print('Original',profile,repeats,n,'empty stdout verified',flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ghc=subprocess.check_output(['ghc','--numeric-version'],text=True).strip(),nofib_revision='b7391df4540ac8b11b35e1b2e2c15819b5171798',observation_scope='Export-only module header; repeated timeStep prefixes force full states beyond original scalar demand',traces=metadata),indent=2)+'\n')
