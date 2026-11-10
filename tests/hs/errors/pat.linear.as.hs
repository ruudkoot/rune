-- Report 3.17.1: x@(x, y) is not linear.
module Main (main) where

f :: (Int, Int) -> Int
f x@(x, y) = y

main :: IO ()
main = return ()
