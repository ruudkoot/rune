-- Report 16 (the Array library): a programmer may expect rapid access to an array's components; rhc's policy is constant
-- time: n reads of an array of n cost about n. lib.r.array.rapid.budget: the count at 2n against n.
module Main (main) where

import Array

main :: IO ()
main = do
  n <- readLn
  let a = listArray (1, n) [1 .. n] :: Array Int Int
  print (sum [a ! i | i <- [1 .. n]])
