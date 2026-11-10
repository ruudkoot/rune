-- rows: lib.ix.class.ix.range lib.ix.class.ix.index lib.ix.class.ix.inrange lib.r.ix.rangesize
-- Report 15.2: rangeSize's default is 0 for an empty range and index b h + 1 otherwise, a defined rangeSize overrides
-- it, and range, index and inRange are the instance's own; an empty range of pairs whose bounds are ordered too.
module Main (main) where

import Ix

data C = A | B | D deriving (Eq, Ord, Show)

instance Ix C where
  range (l, u) = filter (\c -> l <= c && c <= u) [A, B, D]
  index b c = length (takeWhile (/= c) (range b))
  inRange (l, u) c = l <= c && c <= u

data E = E Int deriving (Eq, Ord, Show)

instance Ix E where
  range (E l, E u) = map E [l .. u]
  index (E l, _) (E i) = i - l
  inRange (E l, E u) (E i) = l <= i && i <= u
  rangeSize _ = 42

main :: IO ()
main = do
  print (range (A, D), index (A, D) B, inRange (B, D) A)
  print (rangeSize (A, D), rangeSize (B, B), rangeSize (D, A))
  print (range (E 1, E 3), index (E 1, E 3) (E 2), rangeSize (E 1, E 3), rangeSize (E 3, E 1))
  print (rangeSize ((1, 2), (2, 1) :: (Int, Int)), (1, 2) <= (2, 1 :: Int), rangeSize ((1, 1), (2, 3) :: (Int, Int)), rangeSize (5, 4 :: Int))
