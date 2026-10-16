module Main where
import qualified ExactPrepare as E
import Parse
import Types
import Data.Array
import Data.Ratio
import GHC.Float
import System.Environment
value x = putStrLn(show(numerator x)++" "++show(denominator x)++" "++show(castDoubleToWord64(fromRational x)))
main=do
 [path,dtArg]<-getArgs
 text<-readFile path
 let [(circuit,names)]=parse_circuit text
 let [dt]=parse_exact dtArg
 let (initial,solve,integrate,correct,backdate)=E.prepare circuit dt
 print names
 putStrLn("initial "++show(snd(bounds initial))++" 1")
 mapM_ value (elems initial)
 mapM_ (\(name,m)->do
  let ((_,_),(rows,cols))=bounds m
  putStrLn(name++" "++show rows++" "++show cols)
  mapM_ value (elems m)) [("solve",solve),("integrate",integrate),("correct",correct),("backdate",backdate)]
