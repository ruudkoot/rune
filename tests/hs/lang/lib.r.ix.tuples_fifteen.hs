-- Report 15.1: Ix instances for tuples up to at least size 15, by Figure 15.1's scheme: a 15-tuple's range, index and
-- inRange.
module Main (main) where

import Ix

type T15 = (Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)

lo, hi :: T15
lo = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
hi = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2)

main :: IO ()
main = do
  print (length (range (lo, hi)), index (lo, hi) hi, inRange (lo, hi) lo, rangeSize (lo, hi))
  print (index (lo, hi) (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0), inRange (lo, hi) (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0))
