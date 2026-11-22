-- Report 8: take takes an Int, not an Integral: take (2 :: Integer) is refused.
module Main (main) where

x :: [Int]
x = take (2 :: Integer) [1, 2, 3]
main :: IO ()
main = return ()
