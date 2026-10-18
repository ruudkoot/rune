from pathlib import Path
import shutil,subprocess,json,resource
p=Path(__file__).resolve().parent;o=p/'observer-source';shutil.copytree(p/'source',o,dirs_exist_ok=True)
t=(o/'Main.hs').read_text().replace('module Main where','module Kernel where')
(o/'Kernel.hs').write_text(t)
observer=r'''module Main where
import Kernel
import Data.Array
import GHC.Float(castDoubleToWord64)
import Numeric(showHex)
import System.Environment
hex x=showHex(castDoubleToWord64 x)""
totals(t0,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,t11,t12)=[t0,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,t11,t12]
emitA name array=do
 putStrLn(name++"\t"++show(bounds array)++"\t"++show(length(elems array)))
 mapM_(\(index,value)->putStrLn(show index++"\t"++hex value++"\t"++show value))(assocs array)
main=do
 [mode,ntext]<-getArgs
 let n=read ntext
 if mode=="totals"then mapM_(\(i,v)->putStrLn(show i++"\t"++hex v++"\t"++show v))(zip[0::Int ..](totals(simple_total n)))
 else do
  let((u,v),(r,z),a,s,rho,p,q,e,t,dt,err)=simple n
  mapM_(\(name,array)->emitA name array)[("u",u),("v",v),("r",r),("z",z),("alpha",a),("s",s),("rho",rho),("p",p),("q",q),("epsilon",e),("theta",t)]
  putStrLn("deltat\t"++hex dt++"\t"++show dt)
  putStrLn("error\t"++hex err++"\t"++show err)
'''
(o/'Observe.hs').write_text(observer)
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','Observe.hs','-o','observe'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
for n in [0,1,2,5,20,100]:
 for mode in ['totals','state']:
  r=subprocess.run([str(o/'observe'),mode,str(n),'+RTS','-M512m','-RTS'],capture_output=True,timeout=600,preexec_fn=cap)
  (p/(mode+'-'+str(n)+'.reference')).write_bytes(r.stdout);(p/(mode+'-'+str(n)+'.stderr')).write_bytes(r.stderr)
  print(mode,n,r.returncode,len(r.stdout),flush=True);r.check_returncode()
