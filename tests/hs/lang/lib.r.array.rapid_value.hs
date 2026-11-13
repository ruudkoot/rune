-- Report 16: a programmer may reasonably expect rapid access to an array's components. This is the value of the
-- program whose --count budget, tests/hs/perf/lib.r.array.rapid (hs/perf/lib.r.array.rapid), holds rhc to its policy:
-- n reads of an array of n cost about n, the count at 2n about twice that at n.
module Main (main) where

import Array

main :: IO ()
main = do
  n <- readLn
  let a = listArray (1, n) [1 .. n] :: Array Int Int
  print (sum [a ! i | i <- [1 .. n]])
