-- Report 4.4.1: each use has the declared type: sqr at Int, given 0.1.
module Main (main) where

sqr :: Int -> Int
sqr x = x * x

y :: Int
y = sqr 0.1

main :: IO ()
main = return ()
