-- Report: do uses Prelude's >>= whatever is in scope (3.14); this program's do is in IO and prints 3.
-- Shim: RebindableSyntax makes do use the module's own (>>=), which has another type: rejected.
module Main where
import Prelude hiding ((>>=))
import qualified Prelude as P
(>>=) :: Int -> Int -> Int
a >>= b = a + b
main = do { x <- return 1 P.>>= \y -> return (y + 2); print (x :: Int) }
