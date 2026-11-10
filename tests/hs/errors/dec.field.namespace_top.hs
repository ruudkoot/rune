-- Report 4.2.1: field names share the top-level namespace: a field x and a top-level x.
module Main (main) where

data A = A { x :: Int }

x :: Int
x = 1

main :: IO ()
main = return ()
