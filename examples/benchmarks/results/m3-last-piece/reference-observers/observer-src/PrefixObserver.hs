module Main where
import Kernel
import qualified Data.Map as M
import System.Environment
boards(Soln b)=[b]
boards(Choose children)=concatMap boards children
boards(Fail _ _) =[]
main=do
 [arg]<-getArgs
 let n=read arg
     first=head(boards solutions)
     ids=[ident|P ident _ _<-take(13-n)initialPieces]
     cells=[(sq,ident)|(sq,ident)<-M.toAscList first,ident`elem`ids]
     board=foldl(\b(sq,ident)->M.insert sq ident b)initialBoard cells
 printDoc(display(search(1,2)Female board(drop(13-n)initialPieces)))
