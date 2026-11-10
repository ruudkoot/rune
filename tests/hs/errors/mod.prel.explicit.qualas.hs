-- Report 5.6.1: an explicit import of the Prelude replaces the implicit one: import qualified Prelude as P.
module Main (main) where

import qualified Prelude as P

main :: P.IO ()
main = P.print (map id [1])
