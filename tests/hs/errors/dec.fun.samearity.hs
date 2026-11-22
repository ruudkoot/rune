-- Report 4.4.3.1: each clause has the same number of patterns.
module Main (main) where

f :: Int -> Int
f 0 = 1
f x y = 2

main :: IO ()
main = return ()
