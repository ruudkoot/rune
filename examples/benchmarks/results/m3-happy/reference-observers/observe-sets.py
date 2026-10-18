from pathlib import Path
import subprocess,json,random
p=Path(__file__).resolve().parent;o=p/'set-observer-source';o.mkdir(exist_ok=True)
observer=r'''module Main where
import qualified Data.Set.Internal as S
import System.Environment
import Data.List(intercalate)
js xs="["++intercalate","xs++"]"
shape S.Tip=js["0"]
shape(S.Bin n x l r)=js[show n,show x,shape l,shape r]
main=do
 [path]<-getArgs
 text<-readFile path
 let [xs,ys,modulus]=lines text
     a=S.fromList(read xs::[Int]);b=S.fromList(read ys::[Int]);m=read modulus
 mapM_ putStrLn[shape a,shape b,shape(S.union a b),shape(S.difference a b),shape(S.filter(\n->mod n m/=0)a)]
'''
(o/'Main.hs').write_text(observer)
rng=random.Random(217);cases=[]
for n in [0,1,2,3,4,8,16,31,64]:
 for mode in ['ascending','descending','duplicates','random']:
  xs=list(range(n))
  if mode=='descending':xs.reverse()
  elif mode=='duplicates':xs=xs+xs[::2]
  elif mode=='random':rng.shuffle(xs)
  ys=[rng.randrange(-5,n+5)for _ in range(n+3)]
  cases.append((xs,ys,3))
data=p/'set-data';data.mkdir(exist_ok=True)
with(p/'set-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','Main.hs','-o','observe-set'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
for i,(xs,ys,m)in enumerate(cases):
 (data/(str(i)+'.input')).write_text(json.dumps(xs)+'\n'+json.dumps(ys)+'\n'+str(m)+'\n')
 r=subprocess.run([str(o/'observe-set'),str(data/(str(i)+'.input'))],capture_output=True,check=True,timeout=30)
 (data/(str(i)+'.reference')).write_bytes(r.stdout)
(p/'set-cases.json').write_text(json.dumps(cases,indent=2)+'\n')
print(len(cases),'set inputs;',len(cases)*5,'complete source tree shapes')
