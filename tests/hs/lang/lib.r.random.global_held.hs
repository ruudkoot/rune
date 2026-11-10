-- Report 27: the global generator is seeded differently in two runs, usually; a property of two runs, which waits
-- for a runner that runs a program twice and compares (ruling 34). This run prints a value in range.
module Main (main) where

import Random

main :: IO ()
main = do
  x <- randomRIO (1, 6 :: Int)
  print (x >= 1 && x <= 6)
