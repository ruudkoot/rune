-- rows: pre.class.bounded pre.class.bounded.minbound pre.class.bounded.maxbound
-- Report 8: class Bounded has minBound and maxBound and no defaults: an instance defines both.
module Main (main) where

data A = A Int deriving Show
instance Bounded A where
  minBound = A 0
  maxBound = A 9

main :: IO ()
main = print (minBound :: A, maxBound :: A)
