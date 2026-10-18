module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import First
import qualified Data.Set as S
import Data.Array
import System.Environment
main=do
 [input,queries]<-getArgs
 text<-readFile input
 qs<-readFile queries
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     f=mkFirst g
 mapM_(\line->print(S.toAscList(f(read line::[Int]))))(lines qs)
