-- Report 4.4.1: no signature for a variable of an outer scope: f inside a let.
module Main (main) where

f :: Int
f = 1

g :: Int
g = let f :: Int in 2

main :: IO ()
main = return ()
