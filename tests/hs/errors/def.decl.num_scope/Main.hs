-- Report 4.3.4 with 5.4: each type of a default declaration must be one for which Num holds, by an instance in
-- scope, and an instance is in scope only where a chain of imports leads to its module. A's default names N, whose
-- Num instance Orphan declares, and A imports nothing that leads to Orphan: refused, though this module imports it.
module Main (main) where

import Orphan
import A

main :: IO ()
main = putStrLn a
