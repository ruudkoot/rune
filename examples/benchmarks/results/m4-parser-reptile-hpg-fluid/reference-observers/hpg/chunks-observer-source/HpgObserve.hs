module HpgObserve where
import qualified Main as H
import Data.IORef
import System.Directory
main=mapM_ run [("smoke",8,4,10,6,6),("normal",40,5,60,6,6),("large",80,8,100,8,8)]
 where run (name,nt,dt,nv,dv,de)=do
         index<-newIORef(0::Int)
         let output value=do
               n<-readIORef index
               writeFile("../"++name++"-chunk-"++show n++".reference")value
               print(name,n,length value)
               writeIORef index(n+1)
         H.hpg (9807,65,32975) nt dt nv dv de "Main" output
