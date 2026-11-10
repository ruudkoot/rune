-- Report 10: a class in a deriving clause may be named qualified: P.Eq.
module Main (main) where

import qualified Prelude as P

data T = A deriving P.Eq

main :: P.IO ()
main = P.print (A P.== A)
