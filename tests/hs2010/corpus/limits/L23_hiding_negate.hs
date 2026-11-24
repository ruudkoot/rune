-- Report: negation is Prelude's negate whatever is in scope (3.4).  Shim: RebindableSyntax uses the module's own.
module Main where
import Prelude hiding (negate)
negate :: Int -> Int
negate x = x
main = print (- (3 :: Int))
