module Main where
import qualified Program as P
import qualified Activity as A
import qualified Spark as S
import qualified Pool as O
import GRIP
import Parse
import Graph
import NofibUtils
import System.Environment
main=do
 [mode,file,out]<-getArgs
 input<-readFile file
 let flags=case mode of
       "activity"->[]
       "spark"->["-S"]
       "pool"->["-P"]
       "eps"->["-E"]
       "portrait"->["-G"]
       "selected"->["-p[14.1]"]
       _->error "unknown mode"
 let text=P.control input(map parseLine flags)
 writeFile(out++".ps")text
 let(pes,ticks,ordered)=getParameters(parseFile input)
 writeFile(out++".lines")(unlines(map show ordered))
 writeFile(out++".parameters")(show(pes,ticks,length ordered)++"\n")
 putStrLn(unwords[mode,show(length text),show(hash text)])
