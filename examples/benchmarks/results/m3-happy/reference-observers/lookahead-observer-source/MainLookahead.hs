module Main where
import Parser
import ParseMonad
import Grammar
import GenUtils(MaybeErr(..))
import First
import LALR
import qualified Data.Set as S
import Data.Array
import Data.List(intercalate)
import System.Environment
arr xs="["++intercalate","xs++"]"
pair(a,b)=arr[show a,show b]
names s=arr(map show(S.toAscList s))
spont(i,item,s)=arr[show i,pair item,names s]
prop(item,i,target)=arr[pair item,show i,pair target]
la(item,s)=arr[pair item,names s]
lr1(rule,dot,s)=arr[show rule,show dot,names s]
main=do
 [input]<-getArgs
 text<-readFile input
 let OkP ast=runP ourParser text 1
     Succeeded g=mangler "input.y" ast
     first=mkFirst g
     states=genLR0items g(precalcClosure0 g)
     (s,p)=propLookaheads g states first
     final=calcLookaheads(length states)s p
     merged=mergeLookaheadInfo final states
 putStrLn(arr(map spont s))
 putStrLn(arr(map(\(i,edges)->arr[show i,arr(map prop edges)])(assocs p)))
 putStrLn(arr(map(\(i,items)->arr[show i,arr(map la items)])(assocs final)))
 putStrLn(arr(map(\(items,gotos)->arr[arr(map lr1 items),arr(map pair gotos)])merged))
