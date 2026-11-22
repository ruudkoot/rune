-- Report 15.2: module Ix exports each of these: an explicit import of every one compiles, and each name is used.
module Main (main) where

import Ix (Ix(range, index, inRange, rangeSize))

c0 :: (Ix a) => a -> ()
c0 _ = ()
s0_0 _ = range
s0_1 _ = index
s0_2 _ = inRange
s0_3 _ = rangeSize

main :: IO ()
main = return ()
