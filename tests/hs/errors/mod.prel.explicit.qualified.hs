-- Report 5.6.1: an explicit import of the Prelude replaces the implicit one: import qualified Prelude.
module Main (main) where

import qualified Prelude

main :: Prelude.IO ()
main = Prelude.print (map id [1])
