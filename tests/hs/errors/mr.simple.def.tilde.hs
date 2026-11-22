-- rows: R18
-- Report 4.5.5: ~x is not a single variable (R18, D32), so ~x = 1 is restricted, and its signature cannot
-- lift it.
module Main (main) where

x :: Num a => a
~x = 1

main :: IO ()
main = print (x :: Int, x :: Double)
