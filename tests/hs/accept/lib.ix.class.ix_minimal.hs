-- Report 15.2: class Ord a => Ix a with range, index, inRange and rangeSize: an instance with range, index and inRange
-- compiles and takes rangeSize's default; Ix's superclass is Ord.
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

f :: (Ix a) => (a, a) -> a -> Bool
f b x = x <= x && inRange b x

main :: IO ()
main = return ()
