-- Report 3.15.1: a constructor names a field once.
module Main (main) where

data A = A {x :: Int, x :: Int}

main :: IO ()
main = return ()
