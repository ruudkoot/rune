-- rows: R45
-- Report 6.4.2 (R45; ruling 49 makes the row a run): what division by zero does at an integral type is stated
-- nowhere, the laws holding for non-zero y, and 6.4's "exceptional conditions" cover the fixed-precision types only.
-- rhc's choice, R45's seed: an error at Int and at Integer, for div, mod, quot and rem alike; here Integer's div.
module Main (main) where

main :: IO ()
main = do
  print (7 `div` 2 :: Integer, 7 `quot` (-2) :: Int)
  print (1 `div` (0 :: Integer))
