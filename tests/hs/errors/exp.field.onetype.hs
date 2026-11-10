-- Report 3.15.1: a field label is of one type: two types may not share one.
module Main (main) where

data A = A {x :: Int}
data B = B {x :: Int}

main :: IO ()
main = return ()
