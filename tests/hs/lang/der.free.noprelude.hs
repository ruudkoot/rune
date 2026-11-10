-- Report 10: a module with only a qualified Prelude derives by qualified class names, and the instances run.
module Main (main) where

import qualified Prelude as P

data T = A | B deriving (P.Eq, P.Show)

main :: P.IO ()
main = P.print (A P.== A, B)
