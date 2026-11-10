-- Report 3.17.1: the Report's example: f (x, x) = x is refused, patterns being linear.
module Main (main) where

f :: (Int, Int) -> Int
f (x, x) = x

main :: IO ()
main = return ()
