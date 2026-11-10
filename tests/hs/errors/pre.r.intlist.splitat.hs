-- Report 8: splitAt takes an Int.
module Main (main) where

x :: ([Int], [Int])
x = splitAt (2 :: Integer) [1, 2, 3]
main :: IO ()
main = return ()
