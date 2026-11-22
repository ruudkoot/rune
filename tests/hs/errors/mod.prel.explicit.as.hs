-- Report 5.6.1: an explicit import of the Prelude replaces the implicit one: import Prelude as P.
module Main (main) where

import Prelude as P

main :: IO ()
main = print (Prelude.map id [1])
