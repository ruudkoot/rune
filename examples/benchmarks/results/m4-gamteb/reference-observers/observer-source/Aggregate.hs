module Main where
import GamtebMain
import InitTable
import Data.Array
import System.Environment
main=do
 [size,out]<-getArgs
 let n=read size
 let(results,stats)=sources 0.5 n 6
 let sums=elems(accumArray(+)0(1,12)stats)
 let cells=elems(accumArray(+)0((1,1),(3,35))results)
 writeFile out(unlines["tables "++unwords(map show[ergs!1,xComp!1,xPair!1,xPhot!1]),
   "stats "++unwords(map show sums),"cells "++unwords(map show cells)])
