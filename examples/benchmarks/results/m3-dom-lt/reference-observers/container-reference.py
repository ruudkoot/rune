from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'container-reference';d.mkdir(exist_ok=True)
(d/'Observer.hs').write_text('''module Main where
import qualified Data.IntMap.Strict as M
import qualified Data.IntSet as S
keys=[-130,-65,-64,-63,-1,0,1,2,63,64,65,127,128,1024]
a=S.fromList keys
b=S.fromList[-65,0,2,128,2048]
m=M.fromList[(key,key+1)|key<-keys]
n=M.fromList[(-65,9),(0,8),(128,7),(2048,6)]
main=do
 putStrLn "SETS"
 mapM_(print . S.toList)[a,b,S.union a b,S.difference a b,S.difference b a,S.filter even a,
   S.fromList[65,64,63,0,64],S.insert(-66)a]
 putStrLn "MAPS"
 mapM_(print . M.toList)[m,n,M.unionWith(-)m n,M.unionWith(-)n m,
   M.insertWith(-)64 100 m,M.adjust(+5)(-1)m,M.adjust(+5)999 m,
   M.fromList[(2,5),(2,9),(1,4)],M.map(*2)n]
 putStrLn "FOLDS"
 print(S.foldr(\\k acc->k-acc)0 a)
 print(M.foldlWithKey'(\\acc k v->acc+k-v)0 m)
 print(M.foldrWithKey(\\k v acc->k-v-acc)0 m)
''')
with(d/'build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(d/'observer')],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=True)
(p/'containers.reference').write_bytes(r.stdout);print(r.stdout.decode(),end='')
