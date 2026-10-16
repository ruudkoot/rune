module Main where
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
