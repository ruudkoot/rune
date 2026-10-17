module Main where
import qualified Cg
import qualified Matrix as M
import qualified Input as I
import qualified Matlib as P
import qualified Misc
import System.Environment
main = do
 [text,limitText] <- getArgs
 let n=read text
 let a=I.a_hard n
 let soln=I.x1 n
 let b=M.mvmult a soln
 let conv (Cg.Cg_stateC _ r _ _ _) = sqrt(M.norm r) < 0.0000004
 let states=Misc.takeuntil conv(take(read limitText)(Cg.cgiters P.scale(P.precond 0)a b))
 mapM_ (\(Cg.Cg_stateC x r _ _ cnt)->putStrLn(unwords[show cnt,show(M.norm(M.vsub x soln)),show(M.norm r)]))states
