module Main where
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
