module Main where
import Parse
import Simulate
import Types
import Data.Array
import Data.Ratio
import System.Environment
main=do
 [path,seedArg,dtArg,endArg,tempArg,rbcArg]<-getArgs
 text<-readFile path
 let [(circuit,names)]=parse_circuit text
 let [seed]=parse_integer seedArg
 let [dt]=parse_exact dtArg
 let [end]=parse_exact endArg
 let [temp]=parse_approx tempArg
 let [rbc]=parse_approx rbcArg
 print(tail names)
 mapM_ (\(t,v)->putStrLn(show(numerator t)++" "++show(denominator t)++" "++show(elems v)))
       (simulate circuit seed dt end temp rbc)
