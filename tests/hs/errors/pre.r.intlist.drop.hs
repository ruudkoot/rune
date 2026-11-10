-- Report 8: drop takes an Int.
module Main (main) where

x :: [Int]
x = drop (2 :: Integer) [1, 2, 3]
main :: IO ()
main = return ()
