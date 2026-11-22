-- Report 4.4.3.1: a function's clauses are contiguous.
module Main (main) where

f :: Int -> Int
f 0 = 1
g :: Int
g = 2
f n = n

main :: IO ()
main = return ()
