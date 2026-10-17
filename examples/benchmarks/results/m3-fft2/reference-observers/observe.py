from pathlib import Path
import subprocess,shutil,json,resource
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,dirs_exist_ok=True)
(d/'Observer.hs').write_text('''module Main where
import Fourier
import Complex_Vectors
import Data.Complex
import System.Environment
point z=unwords[show(realPart z),show(imagPart z)]
main=do
 [count,out]<-getArgs
 let n=read count
 let xs=[0..fromIntegral(n-1)]::[Double]
 let zs=map(:+0)xs
 let functions=[("fft",fft zs),("fftinv",fftinv zs),("dft",dft zs),("dftinv",dftinv zs),("sft",sft zs)]
 mapM_(\\(name,result)->writeFile(out++"."++name)(unlines(map point result)))functions
 writeFile(out++".sct")(unlines(map show(sct xs)))
 putStrLn(show n)
''')
(d/'Magnitude.hs').write_text('''module Main where
import Data.Complex
samples=[(3,4),(0,4),(1e200,1e200),(1e-200,1e-200),(1e-200,0)]::[(Double,Double)]
main=mapM_(\\(a,b)->putStrLn(unwords[show a,show b,show(magnitude(a:+b))]))samples
''')
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
for target,file in[('observer','Observer.hs'),('magnitude','Magnitude.hs')]:
 with(d/(target+'-build.log')).open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o',target,file],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
for n in[2,3,4,5,8,16]:
 r=subprocess.check_output([str(d/'observer'),str(n),str(p/str(n))],cwd=d,timeout=60,preexec_fn=cap)
 print(n,'source transforms observed',flush=True)
raw=subprocess.check_output([str(d/'magnitude')],cwd=d,timeout=30);(p/'magnitude.reference').write_bytes(raw);print(raw.decode(),flush=True)
