from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent
observer=r'''module Main where
import Kernel
import Data.Array
import Control.Exception
import GHC.Float(castDoubleToWord64)
import Numeric(showHex)
hex x=let h=showHex(castDoubleToWord64 x)"" in replicate(16-length h)'0'++h
main=do
 let((a,b),(c,d))=bounds nbc
 putStrLn(unwords["NBC",show a,show b,show c,show d])
 mapM_(\z@(i,j)->do
  result<-try(evaluate(nbc!z))::IO(Either SomeException Int)
  putStrLn(unwords[show i,show j,case result of Right v->show v;Left _->"U"]))(indices nbc)
 putStrLn"TABLES"
 mapM_(\(name,t)->do
  putStrLn(name++" "++show(length(elems t)))
  mapM_(putStrLn.hex)(elems t))[("pbb",pbb),("pb",pb),("qb",qb),("rho",rho_table),("theta",theta_table)]
'''
for grid,folder in [(100,'observer-source'),(8,'small-observer-source')]:
 o=p/folder;(o/'Boundary.hs').write_text(observer)
 with(p/('boundary-build-'+str(grid)+'.log')).open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','Boundary.hs','-o','boundary'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run([str(o/'boundary')],capture_output=True,check=True,timeout=60)
 (p/('boundary-'+str(grid)+'.reference')).write_bytes(r.stdout)
 (p/'data'/('boundary-'+str(grid)+'.reference')).write_bytes(r.stdout)
 print(grid,len(r.stdout),flush=True)
