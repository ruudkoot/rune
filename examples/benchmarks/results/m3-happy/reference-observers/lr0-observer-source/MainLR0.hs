module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import LALR
import qualified Data.Set as S
import Data.List(intercalate)
import System.Environment
arr xs="["++intercalate","xs++"]"
pair(a,b)=arr[show a,show b]
main=do
 [input]<-getArgs
 text<-readFile input
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     closure=precalcClosure0 g
     states=genLR0items g closure
 putStrLn(arr(map(\n->arr[show n,arr(map pair(closure n))])(non_terminals g)))
 putStrLn(arr(map(\(set,gotos)->arr[arr(map pair(S.toAscList set)),arr(map pair gotos)])states))
