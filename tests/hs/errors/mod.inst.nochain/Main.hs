-- rows: R26
-- Report 5.4: an instance is in scope only where a chain of imports leads to its module. Main imports Orphan and
-- Used, so Orphan's instance is in the program, but Used, which uses it, imports nothing that leads to Orphan: in
-- Used it is not in scope, and Used is refused (R26). GHC refuses it so; Hugs, whose instances are global, runs it.
module Main (main) where

import Orphan ()
import Used

main :: IO ()
main = putStrLn u
