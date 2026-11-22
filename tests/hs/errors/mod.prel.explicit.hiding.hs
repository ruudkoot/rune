-- Report 5.6.1: an explicit import of the Prelude replaces the implicit one: import Prelude hiding (map).
module Main (main) where

import Prelude hiding (map)

main :: IO ()
main = print (map id [1])
