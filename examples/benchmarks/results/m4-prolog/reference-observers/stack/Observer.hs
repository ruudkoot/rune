module Main where
import qualified Program as P
import PrologData
import Parse
import System.Environment
import NofibUtils
main=do
 [file,out]<-getArgs
 lib<-readFile "runtime_files/stdlib"
 input<-readFile file
 let clauses=[r|((r,""):_ )<-map clause(lines lib)]
 let db=foldl addClause emptyDb clauses
 let text=P.loop db input
 writeFile out text
 print(length text,hash text)
