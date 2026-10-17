module Main where
import qualified Densematrix as D
import qualified Matrix as M
import qualified Input as I
import qualified Matlib as P
main = do
 let a=I.a_hard 2
 let x=I.x1 2
 let b=M.mvmult a x
 let (scaled,rhs)=P.scale a b
 let inv=D.minverse(M.msubscript 0 0 a)
 putStrLn("inverse "++unwords(map show(concat inv)))
 mapM_ (\row->mapM_(\(r,c,block)->putStrLn(unwords(["scaled",show r,show c]++map show(concat block))))row)scaled
 putStrLn("precondition "++unwords(map show(concat(P.precond 0 scaled rhs))))
 let unit=[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]
 let mixed=M.mkmatrix[[(0,0,unit),(0,1,[[0.1],[0.2],[0.3],[0.4]])],[(1,0,[[0.1,0.2,0.3,0.4]]),(1,1,[[2]])]]
 let v=M.mkvector[[1,2,3,4],[5]]
 putStrLn("well "++unwords(map show(concat(P.precond 1 mixed v))))
