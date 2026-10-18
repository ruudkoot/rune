module Work where
import qualified Main as N
import Types
import Data.IORef
import System.IO.Unsafe(unsafePerformIO)
import Control.Exception(evaluate)
import GHC.Float(castFloatToWord32)
{-# NOINLINE counts #-}
counts=unsafePerformIO(newIORef(0,0,0,0,0,0::Int))
{-# NOINLINE predicate #-}
predicate v@(N.Var i _ _) partial=unsafePerformIO $ do
 pass<-evaluate(N.pseudoknot_constraint v partial)
 modifyIORef' counts $ \(a,b,c,d,e,f)->(a+1,b+if pass then 1 else 0,c+if i==18 then 1 else 0,d+if i==18&&pass then 1 else 0,e+if i==6 then 1 else 0,f+if i==6&&pass then 1 else 0)
 return pass
main=do
 let xs=N.search [] N.pseudoknot_domains predicate
 result<-evaluate(N.most_distant_atom xs)
 print(length xs,castFloatToWord32 result)
 readIORef counts >>= print
