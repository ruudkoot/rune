-- rows: lib.r.system.term.error R37
-- Report 23: exitFailure ends with a status that is not 0; an error ends as exitFailure does (readings.md R37). It waits for B's primitives for the process and its environment.
module Main (main) where

import System

main :: IO ()
main = do
  putStrLn "before"
  exitFailure
