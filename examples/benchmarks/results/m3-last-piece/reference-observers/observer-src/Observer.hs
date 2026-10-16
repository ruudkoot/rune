module Main where
import Kernel
import qualified Data.Map as M
import System.Environment
boards(Soln b)=[b]
boards(Choose children)=concatMap boards children
boards(Fail _ _)=[]
main=do
 [mode]<-getArgs
 case mode of
  "data"->do
   print[(ident,male,female)|P ident male female<-initialPieces]
   print(M.toAscList initialBoard)
  "boards"->mapM_(print.M.toAscList)(boards solutions)
