-- Report 3.3: a lambda's patterns are linear: \x x -> x is refused.
module Main (main) where

f :: Int -> Int -> Int
f = \x x -> x

main :: IO ()
main = return ()
