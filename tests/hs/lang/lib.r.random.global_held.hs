-- Report 27: the global generator is seeded differently in two runs, usually; a property of two runs, which waits
-- for a runner that runs a program twice and compares (ruling 34). This run prints a value in range.
-- jit: output only: the global generator is seeded from the clock, so each run's path, and its count, is its own
module Main (main) where

import Random

main :: IO ()
main = do
  x <- randomRIO (1, 6 :: Int)
  print (x >= 1 && x <= 6)
