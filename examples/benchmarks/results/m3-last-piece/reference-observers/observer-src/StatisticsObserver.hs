module Main where
import Kernel
import qualified Data.Map as M
import System.Environment
boards(Soln b)=[b]
boards(Choose children)=concatMap boards children
boards(Fail _ _) =[]
stats :: Solution -> (Int,Int,Int)
stats(Soln _)=(1,0,1)
stats(Fail _ _)=(1,1,0)
stats(Choose children)=foldl (\(a,b,c)(x,y,z)->(a+x,b+y,c+z))(1,0,0)(map stats children)
main=do
 [arg]<-getArgs
 let n=read arg
     first=head(boards solutions)
     ids=[ident|P ident _ _<-take(13-n)initialPieces]
     cells=[(sq,ident)|(sq,ident)<-M.toAscList first,ident`elem`ids]
     board=foldl(\b(sq,ident)->M.insert sq ident b)initialBoard cells
 print(stats(search(1,2)Female board(drop(13-n)initialPieces)))
